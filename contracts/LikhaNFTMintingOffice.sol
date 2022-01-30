pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "hardhat/console.sol";
import "./Implem/EIP2981PerToken.sol"; 

contract LikhaNFT is ERC721URIStorage, EIP2981PerTokenRoyalties{
    using Counters for Counters.Counter;
    address contractOwner;
    Counters.Counter private _tokenIds;

    //events
    event MintEvent(uint256 indexed tokenID, string indexed dbID, string message);
    event BurnEvent(uint256 indexed tokenID, string message);

    constructor() ERC721("Likha", "LKHA") {
        contractOwner = msg.sender;
    }
    modifier onlyOwner() {
        require(msg.sender == contractOwner);
        _;
    }
    /// @inheritdoc	ERC165
    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, IERC2981)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
    function replaceOwner(address newOwner) external onlyOwner{
        contractOwner = newOwner;
    }
    function mintToken(string memory tokenURI, address nft_owner, string memory dbID, uint256 royaltyValue) external onlyOwner returns (uint256) {
        uint256 newItemId = _tokenIds.current(); 
        _safeMint(nft_owner, newItemId);
        _setTokenURI(newItemId, tokenURI);  
        if (royaltyValue > 0) {
            _setTokenRoyalty(newItemId, nft_owner, royaltyValue);
        }
        _tokenIds.increment();
        emit MintEvent(newItemId, dbID, "An NFT was minted successfully");
        return newItemId;  
    }
    /*
    function burnToken(uint256 tokenId) public {
        require(ownerOf(tokenId) == msg.sender,  "You are not the owner of this token");
        _burn(tokenId);
        emit BurnEvent(tokenId, "An NFT was burned");
    }
    */
}