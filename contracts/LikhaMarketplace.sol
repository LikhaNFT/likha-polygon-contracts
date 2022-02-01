//SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import './Implem/Interfaces/IEIP2981.sol';
import "hardhat/console.sol";

contract LikhaNFTMarketplace is ReentrancyGuard {
    uint256 PlatformFee1stPurchase;
    uint256 PlatformFee2ndPurchase;
    address payable LikhaWalletAddress;

    // Events

    // ItemPostEvent
    // Item is Posted
    // dbID = from likha server
    // seller = sellerr address
    // price = posting price in wei 
    // message = custom message 
    event ItemPostEvent(
        string dbID,
        address seller, 
        uint256 price,
        string message
    );
    // NFTSaleEvent
    // Item is sold event
    // dbID =  likha server dbID
    // buyer = buyer address 
    // seller = sellerr address
    // price = posting price in wei 
    // credited = received by seller 
    // royalty = royalty received by creator of NFT
    // message = custom message 
    event NFTSaleEvent(
        string dbID,
        address buyer,
        address seller,
        uint256 price,
        uint256 credited,
        uint256 royalty,
        string message
    );
    // Objects
    struct MarketItem {
        string dbID;
        address NFTContractAddress;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        uint256 NFTFirstPurchaseDone;
        MarketSaleStatus status;
    }
    struct MarketSaleStatus{
        string value;
    }

    mapping(string => MarketItem) private idToMarketItem;
    mapping(address => mapping(uint256 => uint256)) private _firstPurchaseDone;
    mapping(address => mapping(uint256 => uint256)) private _lockSecondPosting;
    //Modifiers
    modifier onlyOwner() {
        require(msg.sender == LikhaWalletAddress);
        _;
    }

    constructor() {
        LikhaWalletAddress = payable(msg.sender);
        PlatformFee1stPurchase = 1000;
        PlatformFee2ndPurchase = 250;
    }

    // Views
    function getPlatformFee1stPurchase() public view returns (uint256) {
        return PlatformFee1stPurchase;
    }
     function getPlatformFee2ndPurchase() public view returns (uint256) {
        return PlatformFee2ndPurchase;
    }

    function setPlatformFee1stPurchase(uint256 newPlatformFee) external onlyOwner {
        PlatformFee1stPurchase = newPlatformFee;
    }
    function setPlatformFee2ndPurchase(uint256 newPlatformFee) external onlyOwner {
        PlatformFee2ndPurchase = newPlatformFee;
    }

    function nftSellPosting(
        string memory dbID,
        address NFTAddress,
        address seller,
        uint256 NFTTokenID,
        uint256 price
    ) external onlyOwner {
        require(price >= 1 ether, "Price must be at least 1 MATIC"); // or 1 default coin in the network based on ethereum blockchain technology
        require(IERC721(NFTAddress).ownerOf(NFTTokenID) == seller, "Posting of NFT not owner of address is not allowed");
        require(IERC721(NFTAddress).isApprovedForAll(seller, address(this)), "Contract is not approved to trade on behalf of user");
        require(price % 100 == 0, "processing of price not divisible by 100 is not allowed");
        require(_lockSecondPosting[NFTAddress][NFTTokenID] == 0, "posting the same item while another one is active is not allowed");
        _lockSecondPosting[NFTAddress][NFTTokenID] = 1;
        idToMarketItem[dbID] = MarketItem(
            dbID,
            NFTAddress,
            NFTTokenID,
            payable(seller),
            price,
            _firstPurchaseDone[NFTAddress][NFTTokenID],
            MarketSaleStatus("For Sale")
        );
        emit ItemPostEvent(
            dbID,
            seller,
            price,
            "An NFT was listed for Sale"
        );
    }

    function buyNFT(string memory dbID)
        public
        payable
        nonReentrant
    {
        uint256 price = idToMarketItem[dbID].price;
        uint256 tokenId = idToMarketItem[dbID].tokenId;
        address payable seller  = idToMarketItem[dbID].seller;
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        require(
            msg.value == price,
            "Asking price are not the same with the paying price. Please submit a valid value"
        );
        require( 
            msg.sender != seller,
            "buyer and seller are the same."
        );
        require(msg.value % 100 == 0, "processing of transaction value not divisible by 100 is not allowed");
        require(IERC721(nftContract).ownerOf(tokenId) == seller, "Seller no longer owns the NFT");
        require(IERC721(nftContract).isApprovedForAll(seller, address(this)), "Contract was disallowed to trade on seller's behalf");
        
        if(IERC165(nftContract).supportsInterface(type(IERC2981Royalties).interfaceId) && idToMarketItem[dbID].NFTFirstPurchaseDone == 1){
            (address receiver, uint256 royalties) = IERC2981Royalties(nftContract).royaltyInfo(tokenId, price);
            uint256 commission = (msg.value  * PlatformFee2ndPurchase) / 10000;
            uint256 creditToSeller = msg.value - (commission + royalties);
            address payable royalty_beneficiary = payable(receiver);
              IERC721(nftContract).safeTransferFrom(
                idToMarketItem[dbID].seller,
                msg.sender,
                tokenId
            );
            idToMarketItem[dbID].seller.transfer(creditToSeller);
            royalty_beneficiary.transfer(royalties);
            idToMarketItem[dbID].status = MarketSaleStatus("Sold");
            LikhaWalletAddress.transfer(commission);
            emit NFTSaleEvent(
                dbID,
                msg.sender,
                seller,
                price,
                creditToSeller,
                royalties,
                "An NFT from marketplace has been sold"
            );
        }
        else{
            uint256 commission = (msg.value  * PlatformFee1stPurchase) / 10000;
            uint256 creditToSeller = msg.value - commission;
            IERC721(nftContract).safeTransferFrom(
                idToMarketItem[dbID].seller,
                msg.sender,
                tokenId
            );
            idToMarketItem[dbID].seller.transfer(creditToSeller);
            idToMarketItem[dbID].status = MarketSaleStatus("Sold");
            LikhaWalletAddress.transfer(commission);
            emit NFTSaleEvent(
                dbID,
                msg.sender,
                seller,
                price,
                creditToSeller,
                0,
                "An NFT from marketplace has been sold"
            );
            _firstPurchaseDone[nftContract][tokenId] = 1;
        }
         _lockSecondPosting[nftContract][tokenId] = 0;
    }
    /* Gets listing status by ID */
    function fetchPostingStatus(string memory dbID) public view returns (MarketItem memory) {
        return idToMarketItem[dbID];
    }
    // Returns if item is locked 
    function isItemLocked(uint256 tokenID, address nftContract) public view returns (uint256){
        return _lockSecondPosting[nftContract][tokenID];
    }
    // remove this contract for good. 
    function burnContract() external onlyOwner{
        selfdestruct(LikhaWalletAddress);
    }
}