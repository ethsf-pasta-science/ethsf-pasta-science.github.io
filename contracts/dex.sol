pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "../node_modules/@openzeppelin/contracts/security/Pausable.sol";

contract Market is Pausable {
    
    using SafeMath for uint256; 

    address[] public adminList;
    mapping(address => bool) adminMap;

    struct DerivCard {
        uint256 id;                   // id associated with listing on the marketplace
        address tokenAddress;         // address for the OSS's token; for interfacing with the OSS NFT
        uint256 tokenId;              // ID for the NFT derivative work token; for O(1) indexing for read and write using mappings and lists
        address payable owner;        // current owner of the derivative work
        uint256 askingPrice;          // current asking price of the derivative work
        address payable beneficiary;  // OSS community that created the OSS that the derivative work uses
        uint256 fee;                  // percentage of fee from the asking price that the owner must pay to hold the derivative work proprietary
        bool isProprietary;           // if true, the license behaves as copyleft, if false the license behaves as permissive
    }

    // listing of every open-source derivative work
    DerivCard[] public derivList;

    // stores the asking prices of each derivative work listed under a certain token
    // mapping of a OSS's address to a derivative 
    mapping(address => mapping(uint256 => uint256)) derivAskPrice;

    // mapping of tokenId to if it's owned
    mapping(uint256 => bool) ownedCard;

    // mapping of a user's address to a balance of funds deposited for their proprietary software
    // total funds remaining in deposit of a patron to hold a token
    mapping(address => mapping(uint256 => uint256)) public deposit;

    // mapping of a token's id to the the last time a user paid a deposit
    mapping(address => mapping(uint256 => uint256)) private lastDepositTimestamp;  

    // total funds still owed by owner
    // mapping of the owner's address to the derivative's cost
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
     modifier OnlyOwner(uint256 id) {
        require(derivList[id].owner == msg.sender, 
            "This operation can only be executed by the card's owner");
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
         require(id < derivList.length && derivList[id].id == id, "Could not find card.");
         _;
     }

     modifier IsProprietary(uint256 id) {
         require(derivList[id].isProprietary, "Derivatice work is open-source.");
         _;
     }
     
     modifier IsOSS(uint256 id) {
         require(!derivList[id].isProprietary, "Derivative work is proprietary.");
         _;
     }

     /* EXTERNAL FUNCTIONS */
     /**
      * @notice Lists a card for auction in the market 
      */
     function addDerivToMarket(address tokenAddress, uint256 tokenId, uint256 askingPrice, address payable beneficiary, uint256 fee) 
        OnlyBenefactor(tokenAddress, tokenId) 
        HasTransferApproval(tokenAddress, tokenId)
        external
        returns(uint256)
        {
        require(fee > 0, "Derivative work must have a fee rate");
        // @TODO:require that the card isn't for auction yet?
        uint256 newCardId = derivList.length;
        derivList.push(DerivCard(newCardId, tokenAddress, tokenId, payable(msg.sender), askingPrice, beneficiary, fee, false));
        ownedCard[tokenId] = true;

        assert(derivList[newCardId].id == newCardId);
        emit cardAdded(newCardId, tokenId, askingPrice);
        return newCardId;
    } 

    /**
     *  Forces a the derivative work to be OSS by buying an already owned derivative work at a higher or equal assessed price.
     */
    function forceOSS(uint256 id, uint256 newAssessedPrice) 
        payable
        external
        CardExists(id) 
        IsProprietary(id) 
        HasTransferApproval(derivList[id].tokenAddress, derivList[id].tokenId) 
    {
        // require that the buying price is greater than the asking price
        require(msg.value >= derivList[id].askingPrice);

        // require that the owner isn't trying to buy the work from themselves
        require(msg.sender != derivList[id].owner);
        
        // update work's new price
        derivList[id].askingPrice = newAssessedPrice;
        emit cardUpdatePrice(id, msg.sender, newAssessedPrice);

        // interface the nft and safetransfer from owner to buyer
        IERC721(derivList[id].tokenAddress).safeTransferFrom(derivList[id].owner, msg.sender, derivList[id].tokenId);
        
        // transfer funds to owner 
        derivList[id].owner.transfer(msg.value);
        emit cardSold(id, msg.sender, msg.value);
        
        assert(derivList[id].owner == msg.sender);
    } 

    /**
     *  Allows a derivative work that has not yet been owned to become proprietary under the ownership of the caller. 
     */
    function makeProprietary(uint256 id, uint256 newAssessedPrice) 
        external 
        payable 
        CardExists(id)
        IsOSS(id) 
        HasTransferApproval(derivList[id].tokenAddress, derivList[id].tokenId) 
    {
        // require that the bidding price is greater than the asking price
        require(msg.value >= derivList[id].askingPrice);

        // require that the caller does not already own this derivative work
        require(msg.sender != derivList[id].owner);

        // require that the benefactor is the current owner of the derivative work
        require(benefactors[id] == derivList[id].owner);

        // require that the caller is not the benefactor
        require(msg.sender != derivList[id].beneficiary);

        // update their deposit if they've paid more money than the asking price
        if (msg.value > derivList[id].askingPrice) {
            deposit[msg.sender][id] = derivList[id].askingPrice.sub(msg.value);
        }

        // pay the asking price to the beneficiary's address
        derivList[id].beneficiary.transfer(derivList[id].askingPrice);

        // interface the nft and safetransfer from beneficiary to buyer
        IERC721(derivList[id].tokenAddress).safeTransferFrom(derivList[id].beneficiary, msg.sender, derivList[id].tokenId);

        // update the ownership of the derivative work and make it proprietary
        derivList[id].owner = payable(msg.sender); 
        derivList[id].isProprietary = true;

        // update derivatives's new asking price
        derivList[id].askingPrice = newAssessedPrice;
        emit cardUpdatePrice(id, msg.sender, newAssessedPrice);
    }

    /**
     *  Allows an owner of a proprietary derivative work to deposit funds.
     */
    function depositFunds(uint256 id) 
        external 
        payable 
        CardExists(id) 
        IsProprietary(id) 
        OnlyOwner(id)
        returns(uint256)
    {
        require(msg.value > 0, "Invalid amount of funds deposited.");
        require(msg.sender != derivList[id].beneficiary, "Cannot be the benficiary and the owner");

        // transfer the dunds to the beneficiary
        derivList[id].beneficiary.transfer(msg.value);
        lastDepositTimestamp[msg.sender][id] = block.timestamp;
        uint256 prevOwedBalance = totalOwedTokenCost[msg.sender][id];
        deposit[msg.sender][id] = deposit[msg.sender][id].add(msg.value);

        // immediately foreclose the derivative if the owner did not pay enough to cover their totalOwedTokenCost
        if (deposit[msg.sender][id] < totalOwedTokenCost[msg.sender][id]) {

            // interface the nft and safetransfer from owner to beneficiary
            IERC721(derivList[id].tokenAddress).safeTransferFrom(derivList[id].owner, derivList[id].beneficiary, derivList[id].tokenId);

            // update the fields of the derivative work
            derivList[id].isProprietary = false;
            derivList[id].owner = derivList[id].beneficiary; 
            totalOwedTokenCost[msg.sender][id] = 0;

            emit cardForeclosed(id, msg.sender, derivList[id].askingPrice);

        } else {
            totalOwedTokenCost[msg.sender][id] = totalOwedTokenCost[msg.sender][id].sub(msg.value);

            assert(prevOwedBalance.sub(msg.value) == totalOwedTokenCost[msg.sender][id]);
            emit cardDeposit(id, msg.sender, msg.value);
        }

        return totalOwedTokenCost[msg.sender][id];
    }


    /**
     *  Updates the total amount that is owed by the owner of a given derivative work after the elapsed time.   
     */
    function updateTotalOwedCost() 
        public
        OnlyAdmin(msg.sender) 
    {
        for (uint256 id = 0; id < derivList.length; id++) {
            if (derivList[id].isProprietary) {
                address owner = derivList[id].owner;
                uint256 elapsedTime = block.timestamp.sub(lastDepositTimestamp[owner][id]);
                uint256 cummFee = _calculateFee(id).mul(elapsedTime);

                totalOwedTokenCost[owner][id] = totalOwedTokenCost[owner][id].add(cummFee);
            }
        }
    }

    /**
     *  Forecloses the derivative by making the work open-source from being proprietary.
     */
    function forecloseDerivative(uint256 id)
        public 
        OnlyAdmin(msg.sender) 
        CardExists(id) 
        IsProprietary(id) 
   {
       address owner = derivList[id].owner;
       require(deposit[owner][id] == 0 || deposit[owner][id] < totalOwedTokenCost[owner][id],
        "Owner still has enough funds deposited to retain ownership of the card");

        // interface the nft and safetransfer from owner to beneficiary
        IERC721(derivList[id].tokenAddress).safeTransferFrom(derivList[id].owner, derivList[id].beneficiary, derivList[id].tokenId);

        // update the fields of the derivative work
        derivList[id].isProprietary = false;
        derivList[id].owner = derivList[id].beneficiary; 

        // update the total owed cost such that they no longer owe money to the beneficiary
        totalOwedTokenCost[msg.sender][id] = 0;

        emit cardForeclosed(id, owner, derivList[id].askingPrice);
   }

    function changeToOpenSource(uint256 id) 
        public
        CardExists(id)
        IsProprietary(id) 
        OnlyOwner(id)
    {
        // interface the nft and safetransfer from owner to beneficiary
        IERC721(derivList[id].tokenAddress).safeTransferFrom(derivList[id].owner, derivList[id].beneficiary, derivList[id].tokenId);

        // update the derivative work so that it's open-source
        derivList[id].isProprietary = false;

        // update the total owed cost such that they no longer owe money to the beneficiary
        totalOwedTokenCost[msg.sender][id] = 0;
            
    }

    function changeToProprietary(uint256 id, uint256 newAssessedPrice) 
        public
        payable 
        CardExists(id)
        IsOSS(id) 
        OnlyOwner(id)

    {
        // require that the bidding price is greater than the asking price
        require(msg.value >= derivList[id].askingPrice);

        // require that the caller is not the benefactor
        require(msg.sender != derivList[id].beneficiary);

        // update their deposit if they've paid more money than the asking price
        if (msg.value > derivList[id].askingPrice) {
            deposit[msg.sender][id] = derivList[id].askingPrice.sub(msg.value);
        }

        // pay the asking price to the beneficiary's address
        derivList[id].beneficiary.transfer(derivList[id].askingPrice);

        // interface the nft and safetransfer from beneficiary to buyer
        IERC721(derivList[id].tokenAddress).safeTransferFrom(derivList[id].beneficiary, msg.sender, derivList[id].tokenId);

        // update the derivative work to be proprietary
        derivList[id].isProprietary = true;

        // update derivatives's new asking price
        derivList[id].askingPrice = newAssessedPrice;
        emit cardUpdatePrice(id, msg.sender, newAssessedPrice);

    }

   function _calculateFee(uint256 id) 
        view 
        internal
        CardExists(id) 
        IsProprietary(id) 
        returns(uint256)
   {
       return (derivList[id].fee).mul(derivList[id].askingPrice);
   }
}