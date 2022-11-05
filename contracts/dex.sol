pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";

contract Market is Pausable {
    
    using SafeMath for uint256; 

    address[] public adminList;
    mapping(address => bool) adminMap;

    struct AuctionCard {
        uint256 id;
        address tokenAddress;
        uint256 tokenId; 
        address payable seller; 
        uint256 askingPrice; 
        address payable beneficiary;
        uint256 fee;
        bool isOwned; // if false, then foreclosed or brand new
    }

    // listing of every card that hasn't yet been foreclosed
    AuctionCard[] public auctionCardList;

    // stores the asking prices of each card listed under a certain token
    mapping(address => mapping(uint256 => uint256)) cardsAskPrice;
    mapping(uint256 => bool) ownedCard;

    // total funds remaining in deposit of a patron to hold a token
    mapping(address => uint256) public deposit;

    // total funds still owed by patron
    mapping(address => mapping(uint256 => uint256)) public totalOwedTokenCost;
    

    // organization receiving tax revenue 
    mapping(uint256 => address) public benefactors;
    mapping(address => uint256) public benefactorFunds;

    /* EVENTS */

    /// @notice emits an event when a new card is added to the market 
    event cardAdded(uint256 id, uint256 tokenId, uint256 askingPrice);

    /// @notice emits an event when a forced sale occurs
    event cardSold(uint256 id, address buyer, uint256 askingPrice);
    
    /// @notice emits an event when a card gets a new self-assessed price
    event cardUpdatePrice(uint256 id, address owner, uint256 askingPrice);

    /// @notice emits an event when the owner defaults on their tax and the card is foreclosed
    event cardForeclosed(uint256 id, address owner, uint256 askingPrice);

    /// @notice emits an event when a deposit is made
    event cardDeposit(uint256 id, address owner, uint256 amount);

    /* MODIFIERS */
     
    /**
     * @notice Requires that only patrons of the card can call a given function
     */
     modifier OnlyPatron(uint256 id) {
        require(auctionCardList[id].seller == msg.sender, 
            "This operation can only be executed by the card's beneficiary");
         _;
     }
    /**
     * @notice 
     */
     modifier OnlyAdmin(address admin) {
         require(adminMap[msg.sender], "This operation can only be executed by admin");
         _;
     }

    /**
     * @notice Requires that only the benefactors (minters) of the car can call a given function.
     */
    modifier OnlyBenefactor(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender, 
            "This operation can only be executed by the card's beneficiary (minter)");
        _;
    }
 
    /** 
     * @notice Requires that the specified contract making an external call has been approved to make transfers. 
     */
    modifier HasTransferApproval(address tokenAddress, uint256 tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.getApproved(tokenId) == address(this), 
            "Contract has not been approved to make transfers");
        _;
    }
    
    /**
     * @notice Requires that the item is listed in the marketplace 
     */
     modifier CardExists(uint256 id) {
         require(id < auctionCardList.length && auctionCardList[id].id == id, "Could not find card.");
         _;
     }

     modifier IsOwned(uint256 id) {
         require(auctionCardList[id].isOwned, "Cannot force a sale on a foreclosed card.");
         _;
     }
     
     modifier IsForeclosed(uint256 id) {
         require(!auctionCardList[id].isOwned, "Cannot place a bid on a owned card.");
         _;
     }

     /* EXTERNAL FUNCTIONS */
     /**
      * @notice Lists a card for auction in the market 
      */
     function addCardToMarket(address tokenAddress, uint256 tokenId, uint256 askingPrice, address payable beneficiary, uint256 fee) 
        OnlyBenefactor(tokenAddress, tokenId) 
        HasTransferApproval(tokenAddress, tokenId)
        external
        returns(uint256)
        {
        require(fee > 0, "Card must have a tax rate");
        // @TODO:require that the card isn't for auction yet?
        uint256 newCardId = auctionCardList.length;
        auctionCardList.push(AuctionCard(newCardId, tokenAddress, tokenId, payable(msg.sender), askingPrice, beneficiary, fee, false));
        ownedCard[tokenId] = true;

        assert(auctionCardList[newCardId].id == newCardId);
        emit cardAdded(newCardId, tokenId, askingPrice);
        return newCardId;
    } 

    /**
     *  Forces a sale by buying an already owned card at a higher or equal assessed price.
     */
    function forceSale(uint256 id, uint256 newAssessedPrice) 
        payable
        external
        CardExists(id) 
        IsOwned(id) 
        HasTransferApproval(auctionCardList[id].tokenAddress, auctionCardList[id].tokenId) 
    {
        require(msg.value >= auctionCardList[id].askingPrice);
        require(msg.sender != auctionCardList[id].seller);
        
        // update card's new price
        auctionCardList[id].askingPrice = newAssessedPrice;
        emit cardUpdatePrice(id, msg.sender, newAssessedPrice);

        // interface the nft and safetransfer from seller to buyer
        IERC721(auctionCardList[id].tokenAddress).safeTransferFrom(auctionCardList[id].seller, msg.sender, auctionCardList[id].tokenId);
        
        // transfer funds to seller 
        auctionCardList[id].seller.transfer(msg.value);
        emit cardSold(id, msg.sender, msg.value);
        
        assert(auctionCardList[id].seller == msg.sender);
    } 

    // function bid(uint256 id, uint256 newAssessedPrice) 
    //     payable 
    //     external 
    //     CardExists(id)
    //     IsForeclosed(id) 
    //     HasTransferApproval(auctionCardList[id].tokenAddress, auctionCardList[id].tokenId) 
    // {
    //     require(msg.value >= auctionCardList[id].askingPrice);
    //     // equire(msg.sender != auctionCardList[id].seller); is this required?

    //     // update card's new price
    //     auctionCardList[id].askingPrice = newAssessedPrice;
    //     emit cardUpdatePrice(id, msg.sender, newAssessedPrice);

    //     //@TODO: in foreclose function, make sure to change the seller so they reliquinsh ownership
    //     // interface the nft and safetransfer from seller to buyer
    //     IERC721(auctionCardList[id].tokenAddress).safeTransferFrom(auctionCardList[id].seller, msg.sender, auctionCardList[id].tokenId);

    // }

    function depositFunds(uint256 id) 
        external 
        payable 
        CardExists(id) 
        IsOwned(id) 
        returns(uint256)
    {
        require(msg.sender == auctionCardList[id].seller, "Cannot deposit funds for a card you don't own");

        deposit[msg.sender].add(msg.value);
        uint256 prevOwedBalance = totalOwedTokenCost[msg.sender][id];
        totalOwedTokenCost[msg.sender][id].sub(msg.value);
         
        auctionCardList[id].beneficiary.transfer(msg.value);
        assert(prevOwedBalance.sub(msg.value) == totalOwedTokenCost[msg.sender][id]);
        emit cardDeposit(id, msg.sender, msg.value);
        return totalOwedTokenCost[msg.sender][id];
    }

    function forecloseCard(uint256 id)
        public 
        CardExists(id) 
        IsOwned(id) 
        OnlyAdmin(msg.sender)
   {
       address owner = auctionCardList[id].seller;
       require(deposit[owner] == 0 || deposit[owner] < totalOwedTokenCost[owner][id],
        "Patron still has enough funds deposited to retain ownership of the card");
        
        auctionCardList[id].isOwned = false;
        auctionCardList[id].seller = auctionCardList[id].beneficiary; 

        emit cardForeclosed(id, owner, auctionCardList[id].askingPrice);
   }

   function _calculateFee(uint256 id) 
        view 
        internal
        CardExists(id) 
        IsOwned(id) 
        returns(uint256)
   {
       return (auctionCardList[id].fee).mul(auctionCardList[id].askingPrice);
   }
}