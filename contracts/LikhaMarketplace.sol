//SPDX-License-Identifier: MIT
pragma solidity ^0.8.3;

import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./Implem/Interfaces/IEIP2981.sol";
import "hardhat/console.sol";

contract LikhaNFTMarketplace is ReentrancyGuard {
    using Counters for Counters.Counter;
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
        address ERC20Token,
        string message
    );
    event NFTBidEvent(
        string dbID,
        address bidder,
        uint256 bidAmount,
        uint256 bidID
    );
    event ItemCancelEvent(string dbID, address seller, string message);
    // Objects
    struct MarketItem {
        string dbID;
        address NFTContractAddress;
        uint256 tokenId;
        address payable seller;
        uint256 price;
        uint256 biddable;
        uint256 bidMinimum;
        uint256 timeOfAuctionEnd;
        address ERC20Preferred;
        uint256 NFTFirstPurchaseDone;
        MarketSaleStatus status;
    }
    struct MarketSaleStatus {
        string value;
        uint256 valueID;
    }
    struct BidItem {
        address bidder;
        uint256 bidAmount;
        uint256 processed;
    }

    mapping(string => MarketItem) private idToMarketItem;
    mapping(address => mapping(uint256 => uint256)) private _firstPurchaseDone;
    mapping(address => mapping(uint256 => uint256)) private _lockSecondPosting;
    mapping(string => BidItem[]) private _bids;
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

    function setPlatformFee1stPurchase(uint256 newPlatformFee)
        external
        onlyOwner
    {
        PlatformFee1stPurchase = newPlatformFee;
    }

    function setPlatformFee2ndPurchase(uint256 newPlatformFee)
        external
        onlyOwner
    {
        PlatformFee2ndPurchase = newPlatformFee;
    }

    function endAuction(string memory dbID) external onlyOwner {
        require(
            idToMarketItem[dbID].timeOfAuctionEnd != 0,
            "Item posted is not subjected to auction"
        );
        require(
            idToMarketItem[dbID].timeOfAuctionEnd >= block.timestamp,
            "Current time does not yet past due date of auction"
        );
        _doSell(dbID, 2, _bids[dbID].length - 1);
    }

    function nftBidPlacing(string memory dbID, uint256 amount) external {
        require(
            idToMarketItem[dbID].seller != msg.sender,
            "Bidder and seller cannot be the same"
        );
        require(
            IERC20(idToMarketItem[dbID].ERC20Preferred).allowance(
                msg.sender,
                address(this)
            ) >= amount,
            "Approved allowance amount does not match"
        );
        require(
            IERC20(idToMarketItem[dbID].ERC20Preferred).balanceOf(msg.sender) >=
                amount,
            "Approved amount does not match"
        );
        require(
            idToMarketItem[dbID].status.valueID < 2,
            "Item is no longer available"
        );
        if (_bids[dbID].length > 0) {
            require(
                _bids[dbID][_bids[dbID].length - 1].bidAmount >= amount,
                "bid is lower or equal than current highest bid"
            );
        }
        IERC20(idToMarketItem[dbID].ERC20Preferred).transferFrom(
            msg.sender,
            address(this),
            amount
        );
        _bids[dbID].push(BidItem(msg.sender, amount, 0));
        emit NFTBidEvent(dbID, msg.sender, amount, _bids[dbID].length - 1);
    }

    function nftBidAccept(string memory dbID, uint256 bidID) external {
        require(_bids[dbID].length > bidID, "bid ID index out of bounds");
        require(
            IERC20(idToMarketItem[dbID].ERC20Preferred).allowance(
                _bids[dbID][bidID].bidder,
                address(this)
            ) >= _bids[dbID][bidID].bidAmount,
            "Approved allowance amount does not match on buyer"
        );
        require(
            IERC20(idToMarketItem[dbID].ERC20Preferred).balanceOf(
                _bids[dbID][bidID].bidder
            ) >= _bids[dbID][bidID].bidAmount,
            "Approved amount does not match"
        );
        require(
            idToMarketItem[dbID].seller == msg.sender,
            "Only Owner can accept bids"
        );
        _doSell(dbID, 2, bidID);
    }

    function nftBidPosting(
        string memory dbID,
        address NFTAddress,
        address seller,
        uint256 NFTTokenID,
        uint256 timeOfAuctionEnd,
        address ERC20Preferred,
        uint256 bidMinumum
    ) external {
        require(
            IERC721(NFTAddress).ownerOf(NFTTokenID) == seller,
            "Posting of NFT not owner of address is not allowed"
        );
        require(
            IERC721(NFTAddress).isApprovedForAll(seller, address(this)),
            "Contract is not approved to trade on behalf of user"
        );
        require(
            _lockSecondPosting[NFTAddress][NFTTokenID] == 0,
            "posting the same item while another one is active is not allowed"
        );
        _lockSecondPosting[NFTAddress][NFTTokenID] = 1;
        idToMarketItem[dbID] = MarketItem(
            dbID,
            NFTAddress,
            NFTTokenID,
            payable(seller),
            0,
            1,
            bidMinumum,
            timeOfAuctionEnd,
            ERC20Preferred,
            _firstPurchaseDone[NFTAddress][NFTTokenID],
            MarketSaleStatus("For auction", 1)
        );
        emit ItemPostEvent(dbID, seller, 0, "An NFT was listed for Auction");
    }

    function nftSellPosting(
        string memory dbID,
        address NFTAddress,
        address seller,
        uint256 NFTTokenID,
        uint256 price,
        uint256 biddable,
        address ERC20Preferred,
        uint256 bidMinimum
    ) external {
        require(
            IERC721(NFTAddress).ownerOf(NFTTokenID) == seller,
            "Posting of NFT not owner of address is not allowed"
        );
        require(
            IERC721(NFTAddress).isApprovedForAll(seller, address(this)),
            "Contract is not approved to trade on behalf of user"
        );
        require(
            price % 100 == 0,
            "processing of price not divisible by 100 is not allowed"
        );
        require(
            _lockSecondPosting[NFTAddress][NFTTokenID] == 0,
            "posting the same item while another one is active is not allowed"
        );
        _lockSecondPosting[NFTAddress][NFTTokenID] = 1;
        idToMarketItem[dbID] = MarketItem(
            dbID,
            NFTAddress,
            NFTTokenID,
            payable(seller),
            price,
            biddable,
            0,
            bidMinimum,
            ERC20Preferred,
            _firstPurchaseDone[NFTAddress][NFTTokenID],
            MarketSaleStatus("For Sale", 0)
        );
        emit ItemPostEvent(dbID, seller, price, "An NFT was listed for Sale");
    }

    function cancelPosting(string memory dbID) external {
        address payable seller = idToMarketItem[dbID].seller;
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        uint256 tokenID = idToMarketItem[dbID].tokenId;
        require(msg.sender == seller, "TX sender is not the seller.");
        require(
            idToMarketItem[dbID].status.valueID < 2,
            "Cannot cancel items that are not active"
        );
        idToMarketItem[dbID].status = MarketSaleStatus("Cancelled", 3);
        _lockSecondPosting[nftContract][tokenID] = 0;
        if (idToMarketItem[dbID].biddable == 1) {
            _release_bids(dbID);
        }
        emit ItemCancelEvent(dbID, seller, "An posting was cancelled");
    }

    function buyNFT(string memory dbID) public payable nonReentrant {
        uint256 price = idToMarketItem[dbID].price;
        uint256 tokenId = idToMarketItem[dbID].tokenId;
        address payable seller = idToMarketItem[dbID].seller;
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        require(
            idToMarketItem[dbID].price != 0,
            "Item is for auction. Please place a bid instead"
        );
        require(
            msg.value == price,
            "Asking price are not the same with the paying price. Please submit a valid value"
        );
        require(msg.sender != seller, "buyer and seller are the same.");
        require(
            msg.value % 100 == 0,
            "processing of transaction value not divisible by 100 is not allowed"
        );
        require(
            IERC721(nftContract).ownerOf(tokenId) == seller,
            "Seller no longer owns the NFT"
        );
        require(
            IERC721(nftContract).isApprovedForAll(seller, address(this)),
            "Contract was disallowed to trade on seller's behalf"
        );
        require(
            idToMarketItem[dbID].status.valueID < 2,
            "Item is no longer available"
        );
        _doSell(dbID, 1, 0);
    }

    /* Gets listing status by ID */
    function fetchPostingStatus(string memory dbID)
        public
        view
        returns (MarketItem memory)
    {
        return idToMarketItem[dbID];
    }

    function fetchBidItems(string memory dbID)
        public
        view
        returns (BidItem[] memory)
    {
        return _bids[dbID];
    }

    // Returns if item is locked
    function isItemLocked(uint256 tokenID, address nftContract)
        public
        view
        returns (uint256)
    {
        return _lockSecondPosting[nftContract][tokenID];
    }

    // remove this contract for good.
    function burnContract() external onlyOwner {
        selfdestruct(LikhaWalletAddress);
    }

    // Private Func
    function _doSell(
        string memory dbID,
        uint256 mode,
        uint256 bidID
    ) internal {
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        if (
            IERC165(nftContract).supportsInterface(
                type(IERC2981Royalties).interfaceId
            ) && idToMarketItem[dbID].NFTFirstPurchaseDone == 1
        ) {
            _doSecondPurchase(dbID, mode, bidID);
        } else {
            _doFirstPurchase(dbID, mode, bidID);
        }
    }

    function _doFirstPurchase(
        string memory dbID,
        uint256 mode,
        uint256 bidID
    ) internal {
        uint256 price = 0;
        uint256 creditToSeller = 0;
        address ERC20Token = address(0);
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        if (mode == 1) {
            price = idToMarketItem[dbID].price;
            uint256 commission = (msg.value * PlatformFee1stPurchase) / 10000;
            creditToSeller = msg.value - commission;
            idToMarketItem[dbID].seller.transfer(creditToSeller);
            idToMarketItem[dbID].status = MarketSaleStatus("Sold", 2);
            LikhaWalletAddress.transfer(commission);
            IERC721(nftContract).safeTransferFrom(
                idToMarketItem[dbID].seller,
                msg.sender,
                idToMarketItem[dbID].tokenId
            );
        } else if (mode == 2) {
            price = idToMarketItem[dbID].price;
            ERC20Token = idToMarketItem[dbID].ERC20Preferred;
            uint256 commission = (_bids[dbID][bidID].bidAmount *
                PlatformFee1stPurchase) / 10000;
            creditToSeller = _bids[dbID][bidID].bidAmount - commission;
            IERC20(ERC20Token).transfer(
                idToMarketItem[dbID].seller,
                creditToSeller
            );
            idToMarketItem[dbID].status = MarketSaleStatus("Sold", 2);
            IERC20(ERC20Token).transfer(LikhaWalletAddress, commission);
            _bids[dbID][bidID].processed = 1;
            IERC721(nftContract).safeTransferFrom(
                idToMarketItem[dbID].seller,
                msg.sender,
                idToMarketItem[dbID].tokenId
            );
            _release_bids(dbID);
        }
        emit NFTSaleEvent(
            dbID,
            msg.sender,
            idToMarketItem[dbID].seller,
            price,
            creditToSeller,
            0,
            ERC20Token,
            "An NFT from marketplace has been sold"
        );
        _firstPurchaseDone[nftContract][idToMarketItem[dbID].tokenId] = 1;
        _lockSecondPosting[nftContract][idToMarketItem[dbID].tokenId] = 0;
    }

    function _doSecondPurchase(
        string memory dbID,
        uint256 mode,
        uint256 bidID
    ) internal {
        if (mode == 1) {
            _doSecondPurchaseMode1(dbID);
        } else if (mode == 2) {
            _doSecondPurchaseMode2(dbID, bidID);
        }
    }

    function _doSecondPurchaseMode1(
        string memory dbID
    ) internal {
        uint256 price = 0;
        uint256 creditToSeller = 0;
        uint256 royalties = 0;
        address ERC20Token = address(0);
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        (address receiver, uint256 res_royalties) = IERC2981Royalties(
            nftContract
        ).royaltyInfo(idToMarketItem[dbID].tokenId, idToMarketItem[dbID].price);
        royalties = res_royalties;
        uint256 commission = (msg.value * PlatformFee2ndPurchase) / 10000;
        creditToSeller = msg.value - (commission + royalties);
        address payable royalty_beneficiary = payable(receiver);
        idToMarketItem[dbID].seller.transfer(creditToSeller);
        royalty_beneficiary.transfer(royalties);
        idToMarketItem[dbID].status = MarketSaleStatus("Sold", 2);
        LikhaWalletAddress.transfer(commission);
        IERC721(nftContract).safeTransferFrom(
            idToMarketItem[dbID].seller,
            msg.sender,
            idToMarketItem[dbID].tokenId
        );
        emit NFTSaleEvent(
            dbID,
            msg.sender,
            idToMarketItem[dbID].seller,
            price,
            creditToSeller,
            royalties,
            ERC20Token,
            "An NFT from marketplace has been sold"
        );
        _lockSecondPosting[nftContract][idToMarketItem[dbID].tokenId] = 0;
    }

    function _doSecondPurchaseMode2(
        string memory dbID,
        uint256 bidID
    ) internal {
        uint256 price = 0;
        uint256 creditToSeller = 0;
        uint256 royalties = 0;
        address ERC20Token = address(0);
        address nftContract = idToMarketItem[dbID].NFTContractAddress;
        (address receiver, uint256 res_royalties) = IERC2981Royalties(
            nftContract
        ).royaltyInfo(
                idToMarketItem[dbID].tokenId,
                _bids[dbID][bidID].bidAmount
            );
        royalties = res_royalties;
        uint256 commission = (_bids[dbID][bidID].bidAmount *
            PlatformFee2ndPurchase) / 10000;
        creditToSeller =
            _bids[dbID][bidID].bidAmount -
            (commission + royalties);
        address royalty_beneficiary = receiver;
        IERC20(ERC20Token).transfer(
            idToMarketItem[dbID].seller,
            creditToSeller
        );
        IERC20(ERC20Token).transfer(royalty_beneficiary, royalties);
        idToMarketItem[dbID].status = MarketSaleStatus("Sold", 2);
        IERC20(ERC20Token).transfer(LikhaWalletAddress, commission);
        _bids[dbID][bidID].processed = 1;
        IERC721(nftContract).safeTransferFrom(
            idToMarketItem[dbID].seller,
            msg.sender,
            idToMarketItem[dbID].tokenId
        );
        _release_bids(dbID);
        emit NFTSaleEvent(
            dbID,
            msg.sender,
            idToMarketItem[dbID].seller,
            price,
            creditToSeller,
            royalties,
            ERC20Token,
            "An NFT from marketplace has been sold"
        );
        _lockSecondPosting[nftContract][idToMarketItem[dbID].tokenId] = 0;
    }

    function _release_bids(string memory dbID) internal {
        for (uint256 i = 0; i < _bids[dbID].length; i++) {
            if (_bids[dbID][i].processed != 1) {
                IERC20(idToMarketItem[dbID].ERC20Preferred).transfer(
                    _bids[dbID][i].bidder,
                    _bids[dbID][i].bidAmount
                );
            }
        }
    }
}
