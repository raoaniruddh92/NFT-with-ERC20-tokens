// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    
    // --- Pet Data Structure ---
    struct Pet {
        uint256 xp;        
        uint256 hunger;    
        uint256 happiness; 
        uint256 lastInteraction; // Renamed from lastFed to track all decay
    }

    // --- Constants & Variables ---
    uint256 public constant MAX_STAT = 100; // Used for both Hunger and Happiness
    uint256 public constant STAT_DECAY_RATE = 1; // 1 unit of stat lost per hour
    uint256 public constant STAT_DECAY_INTERVAL = 1 hours; // Time period for decay
    uint256 public constant FEED_REPLENISH = 25; // Hunger units recovered on feed
    uint256 public constant TRAIN_XP_GAIN = 10; // XP gained per training session
    uint256 public constant TRAIN_HAPPINESS_COST = 5; // Happiness lost per training
    uint256 public XP_PER_LEVEL = 50;      
    bool public mintingPaused = false;

    mapping(uint256 => Pet) private pets;

    // --- Constructor ---
    constructor(address initialOwner)
        ERC721("MyPET", "MPT")
        Ownable(initialOwner)
    {}

    // --- Events ---
    event PetMinted(address indexed owner, uint256 indexed tokenId);
    event PetFed(address indexed owner, uint256 indexed tokenId, uint256 newHunger, uint256 timeElapsed);
    event PetTrained(address indexed owner, uint256 indexed tokenId, uint256 newXP, uint256 newLevel);

    // --- Modifiers ---
    modifier isPetOwner(uint256 tokenId) {
        require(_msgSender() == ownerOf(tokenId), "MPT: Not the pet owner");
        _;
    }

    // --- Core NFT Functionality ---

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        require(!mintingPaused, "MPT: Minting is paused");
        _safeMint(to, tokenId);
        pets[tokenId] = Pet({
            xp: 0,
            hunger: MAX_STAT,
            happiness: MAX_STAT, 
            lastInteraction: block.timestamp 
        });
        _setTokenURI(tokenId, uri);
        emit PetMinted(to, tokenId); 
    }
    /**
     * @notice Calculates the current decayed state of the pet's hunger and happiness.
     * @param tokenId The ID of the pet.
     */
    function _updatePetState(uint256 tokenId) internal {
        Pet storage pet = pets[tokenId];
        uint256 timeElapsed = block.timestamp - pet.lastInteraction;
        
        // Calculate the number of decay intervals that have passed
        uint256 intervalsPassed = timeElapsed / STAT_DECAY_INTERVAL;
        
        if (intervalsPassed > 0) {
            uint256 totalDecay = intervalsPassed * STAT_DECAY_RATE;
            
            // Apply decay to Hunger
            pet.hunger = pet.hunger > totalDecay ? pet.hunger - totalDecay : 0;
            
            // Apply decay to Happiness
            pet.happiness = pet.happiness > totalDecay ? pet.happiness - totalDecay : 0;
            
            // Update the lastInteraction timestamp to the effective time after decay
            pet.lastInteraction = pet.lastInteraction + (intervalsPassed * STAT_DECAY_INTERVAL);
        }
    }
    
    // --- Public Getter Functions ---

    function getPet(uint256 tokenId) public view returns (uint256 xp, uint256 hunger, uint256 happiness, uint256 lastInteraction) {
        // Since this is a view function, we must manually calculate decay
        Pet memory pet = pets[tokenId];
        uint256 timeElapsed = block.timestamp - pet.lastInteraction;
        uint256 intervalsPassed = timeElapsed / STAT_DECAY_INTERVAL;
        uint256 totalDecay = intervalsPassed * STAT_DECAY_RATE;
        
        // Apply decay to Hunger (clamped at 0)
        uint256 currentHunger = pet.hunger > totalDecay ? pet.hunger - totalDecay : 0;
        
        // Apply decay to Happiness (clamped at 0)
        uint256 currentHappiness = pet.happiness > totalDecay ? pet.happiness - totalDecay : 0;
        
        return (
            pet.xp, 
            currentHunger, 
            currentHappiness, 
            pet.lastInteraction
        );
    }
    
    function getPetLevel(uint256 tokenId) public view returns (uint256) {
        return pets[tokenId].xp / XP_PER_LEVEL;
    }

    // --- Core Interaction Logic ---

    function feed(uint256 tokenId) public isPetOwner(tokenId) {
        // 1. Update the state (applies decay)
        _updatePetState(tokenId);
        
        Pet storage pet = pets[tokenId];
        uint256 oldHunger = pet.hunger;

        // 2. Apply action effect: increase hunger
        pet.hunger = pet.hunger + FEED_REPLENISH;
        if (pet.hunger > MAX_STAT) {
            pet.hunger = MAX_STAT; 
        }
        
        emit PetFed(_msgSender(), tokenId, pet.hunger, pet.hunger - oldHunger);
    }

    function train(uint256 tokenId) public isPetOwner(tokenId) {
        // 1. Update the state (applies decay)
        _updatePetState(tokenId);
        
        Pet storage pet = pets[tokenId];

        // Ensure the pet isn't too hungry to train
        require(pet.hunger > 0, "MPT: Pet is too hungry to train");

        // 2. Apply action effects
        uint256 oldLevel = getPetLevel(tokenId);
        
        // Gain XP
        pet.xp += TRAIN_XP_GAIN;
        
        // Lose Happiness
        pet.happiness = pet.happiness > TRAIN_HAPPINESS_COST 
            ? pet.happiness - TRAIN_HAPPINESS_COST 
            : 0; // Clamp at 0

        uint256 newLevel = getPetLevel(tokenId);
        
        // 3. Emit event, checking for level up
        emit PetTrained(_msgSender(), tokenId, pet.xp, newLevel);
    }

    // --- Standard Overrides ---

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }
    
    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721, ERC721URIStorage)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    
    // The owner can update the decay/xp constants if needed
    function setXpPerLevel(uint256 newXp) public onlyOwner {
        XP_PER_LEVEL = newXp;
    }
    
    function setMintingPaused(bool _paused) public onlyOwner {
        mintingPaused = _paused;
    }
}