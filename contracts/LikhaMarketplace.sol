pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import "hardhat/console.sol";

contract LikhaNFTMarketplace is ReentrancyGuard {
    uint256 commissionRate;
    address payable LikhaWalletAddress;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _eventId;

    // Events
    event MarketplaceEvent(
        uint256 indexed eventId,
        address initiator,
        string message
    );

    // Objects
    struct MarketItem {
        uint256 itemId;
        address NFTContractAddress;
        uint256 tokenId;
        address payable seller;
        address payable owner;
        uint256 price;
        bool sold;
    }

    mapping(uint256 => MarketItem) private idToMarketItem;

    //Modifiers
    modifier onlyOwner() {
        require(msg.sender == LikhaWalletAddress);
        _;
    }

    constructor() {
        LikhaWalletAddress = payable(msg.sender);
        commissionRate = 10;
    }

    // Views
    function getCommissionRate() public view returns (uint256) {
        return commissionRate;
    }

    function setCommissionRate(uint256 newCommissionRate) external onlyOwner {
        commissionRate = newCommissionRate;
    }

    function listItem(
        address contractAddress,
        address lister,
        uint256 tokenId,
        uint256 price
    ) external payable nonReentrant onlyOwner {
        require(price > 1 ether, "Price must be at least 1 MATIC"); // or 1 default coin in the network based on ethereum blockchain technology

        _itemIds.increment();
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            contractAddress,
            tokenId,
            payable(lister),
            payable(address(0)),
            price,
            false
        );
        _eventId.increment();

        emit MarketplaceEvent(
            _eventId.current(),
            msg.sender,
            "A Token was listed for sale"
        );
    }

    function itemSale(address nftContract, uint256 itemId)
        public
        payable
        nonReentrant
    {
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address payable seller  = idToMarketItem[itemId].seller;
        require(
            msg.value == price,
            "Asking price are not the same with the paying price. Please submit a valid value"
        );
        require( 
            msg.sender != seller,
            "buyer and seller are the same."
        );
        require(msg.value % 100 == 0);
        // divide by 100 because commission percentage is expressed as a uint
        uint256 commission = (msg.value  * commissionRate) / 100;

        idToMarketItem[itemId].seller.transfer(msg.value - commission);
        IERC721(nftContract).transferFrom(
            idToMarketItem[itemId].seller,
            msg.sender,
            tokenId
        );
        idToMarketItem[itemId].owner = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        LikhaWalletAddress.transfer(commission);
        _eventId.increment();
        emit MarketplaceEvent(
            _eventId.current(),
            msg.sender,
            "An item was sold"
        );
    }


    /* Gets All Items listed */
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            uint256 currentId = i + 1;
            MarketItem storage currentItem = idToMarketItem[currentId];
            items[currentIndex] = currentItem;
            currentIndex += 1;
        }
        return items;
    }

    /* Returns only items that a user has purchased */
    function fetchMyNFTs() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].owner == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /* Returns only items a user has created */
    function fetchItemsCreated() public view returns (MarketItem[] memory) {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i + 1].seller == msg.sender) {
                uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }
}
