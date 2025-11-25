// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MyToken is ERC721, ERC721URIStorage, ERC721Burnable, Ownable {
    constructor(address initialOwner)
        ERC721("MyPET", "MPT")
        Ownable(initialOwner)
    {}
    struct Pet {
        uint256 xp;        
        uint256 hunger;    
        uint256 happiness; 
        uint256 lastFed;   
    }
    uint256 public constant MAX_HUNGER = 100;
    uint256 public constant MAX_HAPPINESS = 100;
    uint256 public XP_PER_LEVEL = 50;      
    bool public mintingPaused = false;

    mapping(uint256 => Pet) private pets;

    // Events
    event PetMinted(address indexed owner, uint256 indexed tokenId);
    event PetFed(address indexed owner, uint256 indexed tokenId, uint256 hunger);
    event PetTrained(address indexed owner, uint256 indexed tokenId, uint256 xp, uint256 level);

    function safeMint(address to, uint256 tokenId, string memory uri)
        public
        onlyOwner
    {
        _safeMint(to, tokenId);
        pets[tokenId] = Pet({
            xp: 0,
            hunger: MAX_HUNGER,
            happiness: 50,
            lastFed: block.timestamp
        });
        _setTokenURI(tokenId, uri);
    }


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
}