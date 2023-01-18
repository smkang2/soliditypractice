// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract PARK is ERC721, ERC721URIStorage, ERC721Burnable, AccessControl {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant TRANSFER_ROLE = keccak256("TRANSFER_ROLE");

    constructor() ERC721("PARK", "PARK") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(TRANSFER_ROLE, msg.sender);
    }

    mapping (uint => uint) _productionCost;

    function getProductionCost(uint tokenId) public view returns(uint) {
        return _productionCost[tokenId];
    }
    //KRW
    function safeMint(address to, uint256 tokenId, string memory uri,uint256 cost)
        public
        onlyRole(MINTER_ROLE)
    {
        _safeMint(to, tokenId);
        _setTokenURI(tokenId, uri);
        _productionCost[tokenId] = cost;

        approvalForAllProxy(to);
    }

    function approvalForAllProxy(address holder) public onlyRole(TRANSFER_ROLE) {
        _setApprovalForAll(holder,msg.sender,true);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721, ERC721URIStorage) {
        super._burn(tokenId);
        delete _productionCost[tokenId];
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
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function transferFrom(
        address from,
        address to,
        uint256 tokenId
    ) public virtual override onlyRole(TRANSFER_ROLE) {
        //solhint-disable-next-line max-line-length
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");

        _transfer(from, to, tokenId);
    }

    function safeTransferFrom(
        address from,
        address to,
        uint256 tokenId,
        bytes memory data
    ) public virtual override onlyRole(TRANSFER_ROLE) {
        require(_isApprovedOrOwner(_msgSender(), tokenId), "ERC721: caller is not token owner or approved");
        _safeTransfer(from, to, tokenId, data);
    }
    
}

contract market is Ownable {
    IERC20 token;
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds; //total number of items ever created
    Counters.Counter private _itemsSold; //total number of items sold
    PARK park;

    constructor(address _park) {
        park = PARK(_park);
    }

    mapping (uint => address) _whiteList; // mapping 타입으로 바꾸기 (tokenid -> whitelist)
    mapping (uint256 => MarketItem) private idMarketItem; //a way to access values of the MarketItem struct above by passing an integer ID

    struct MarketItem {
        uint itemId;
        uint256 tokenId;
        address payable seller; //person selling the nft
        address payable owner; //owner of the nft
        uint256 price;
        bool sold;
    }

    //log message (when Item is sold)
    event MarketItemCreated (
        uint indexed itemId,
        uint256 indexed tokenId,
        address  seller,
        address  owner,
        uint256 price,
        bool sold
    );

    function setToken (address tokenAddress) public onlyOwner returns (bool) {
        require(tokenAddress != address(0x0));
        token = IERC20(tokenAddress);
        return true;
    }

    function listing(address owner, uint256 tokenId, uint _cost) public {
        uint Origin_cost = park.getProductionCost(tokenId);
        require(_cost < Origin_cost);
        if(!park.isApprovedForAll(owner, address(this))) {
            park.approvalForAllProxy(owner);
        }

        _itemIds.increment(); //add 1 to the total number of items ever created
        uint256 itemId = _itemIds.current();

        idMarketItem[tokenId] = MarketItem(
            itemId,
            tokenId,
            payable(owner), //address of the seller putting the nft up for sale
            payable(address(0)), //no owner yet (set owner to empty address)
            _cost,
            false
        );

        emit MarketItemCreated(
            itemId,
            tokenId,
            owner,
            address(0),
            _cost,
            false
        );
    }

    function whiteListing(address owner, address to, uint256 tokenId, uint _cost) public {
        _whiteList[tokenId] = to; 
        uint Origin_cost = park.getProductionCost(tokenId);
        require(_cost < Origin_cost);
        if(!park.isApprovedForAll(owner, address(this))) {
            park.approvalForAllProxy(owner);
        }  

        _itemIds.increment(); //add 1 to the total number of items ever created
        uint256 itemId = _itemIds.current();

        idMarketItem[tokenId] = MarketItem(
            itemId,
            tokenId,
            payable(owner), //address of the seller putting the nft up for sale
            payable(address(0)), //no owner yet (set owner to empty address)
            _cost,
            false
        );

        emit MarketItemCreated(
            itemId,
            tokenId,
            owner,
            address(0),
            _cost,
            false
        );
    }

    function publicPurchase(address owner, address to, uint256 tokenId, uint _cost) public {
        park.transferFrom(owner, to, tokenId);
        token.transferFrom(owner, to, _cost);

        idMarketItem[tokenId].owner = payable(to); //mark buyer as new owner
        idMarketItem[tokenId].sold = true; //mark that it has been sold
        _itemsSold.increment(); //increment the total number of Items sold by 1
    }

    function privatePurchase(address owner, address to, uint256 tokenId, uint _cost) public {
        require(_whiteList[tokenId]==to);
        park.transferFrom(owner, to, tokenId);
        delete _whiteList[tokenId];
        token.transferFrom(owner, to, _cost);

        idMarketItem[tokenId].owner = payable(to); //mark buyer as new owner
        idMarketItem[tokenId].sold = true; //mark that it has been sold
        _itemsSold.increment(); //increment the total number of Items sold by 1
    }

}