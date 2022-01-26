pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract LikhaNFT is ERC721URIStorage{
    using Counters for Counters.Counter;
    address contractOwner;
    Counters.Counter private _tokenIds;

    //events
    event MinterEvent(uint256 indexed tokenID, string indexed message);

    constructor() ERC721("Likha", "LKHA") {
        contractOwner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == contractOwner);
        _;
    }
    function replaceOwner(address newOwner) external onlyOwner{
        contractOwner = newOwner;
    }
    function mintToken(string memory tokenURI, address nft_owner) external onlyOwner returns (uint256) {
        uint256 newItemId = _tokenIds.current(); 
        _mint(nft_owner, newItemId);
        _setTokenURI(newItemId, tokenURI);  
        _tokenIds.increment();
        emit MinterEvent(newItemId, "Minted Successfully");
        return newItemId;  
    }
    function burnToken(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender,  "You are not the owner of this token");
        _burn(tokenId);
        emit MinterEvent(tokenId, "Token Burned Successfully");
    }
}