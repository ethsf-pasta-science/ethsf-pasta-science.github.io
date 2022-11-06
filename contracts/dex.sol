pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./Wallet.sol";

contract Market is Wallet{
    
    using SafeMath for uint; 

    address[] public adminList;
    mapping(address => bool) adminMap;

    struct DerivCard {
        uint id;                   // id associated with listing on the marketplace
        address tokenAddress;         // address for the OSS's token; for interfacing with the OSS NFT
        uint tokenId;              // ID for the NFT derivative work token; for O(1) indexing for read and write using mappings and lists
        address payable owner;        // current owner of the derivative work
        uint askingPrice;          // current asking price of the derivative work
        address payable beneficiary;  // OSS community that created the OSS that the derivative work uses
        uint fee;                  // percentage of fee from the asking price that the owner must pay to hold the derivative work proprietary
        bool isProprietary;           // if true, the license behaves as copyleft, if false the license behaves as permissive
    }

    // listing of every open-source derivative work
    DerivCard[] public derivList;

    // mapping of a user's address to a balance of funds deposited for their proprietary software
    // total funds remaining in deposit of a patron to hold a token
    mapping(address => mapping(uint => uint)) public deposit;

    // mapping of a token's id to the the last time a user paid a deposit
    mapping(address => mapping(uint => uint)) private lastDepositTimestamp;  

    // total funds still owed by owner
    // mapping of the owner's address to the derivative's cost
    mapping(address => mapping(uint => uint)) public totalOwedTokenCost;
    

    // organization receiving tax revenue 
    mapping(uint => address) public benefactors;
    mapping(address => uint) public benefactorFunds;

    /* EVENTS */

    /// @notice emits an event when a new card is added to the market 
    event cardAdded(uint id, uint tokenId, uint askingPrice);

    /// @notice emits an event when a forced sale occurs
    event cardSold(uint id, address buyer, uint askingPrice);
    
    /// @notice emits an event when a card gets a new self-assessed price
    event cardUpdatePrice(uint id, address owner, uint askingPrice);

    /// @notice emits an event when the owner defaults on their tax and the card is foreclosed
    event cardForeclosed(uint id, address owner, uint askingPrice);

    /// @notice emits an event when a deposit is made
    event cardDeposit(uint id, address owner, uint amount);

    /* MODIFIERS */
     
    /**
     * @notice Requires that only patrons of the card can call a given function
     */
     modifier OnlyOwner(uint id) {
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
    modifier OnlyBenefactor(address tokenAddress, uint tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.ownerOf(tokenId) == msg.sender, 
            "This operation can only be executed by the card's beneficiary (minter)");
        _;
    }
 
    /** 
     * @notice Requires that the specified contract making an external call has been approved to make transfers. 
     */
    modifier HasTransferApproval(address tokenAddress, uint tokenId) {
        IERC721 tokenContract = IERC721(tokenAddress);
        require(tokenContract.getApproved(tokenId) == address(this), 
            "Contract has not been approved to make transfers");
        _;
    }
    
    /**
     * @notice Requires that the item is listed in the marketplace 
     */
     modifier CardExists(uint id) {
         require(id < derivList.length && derivList[id].id == id, "Could not find card.");
         _;
     }

     modifier IsProprietary(uint id) {
         require(derivList[id].isProprietary, "Derivatice work is open-source.");
         _;
     }
     
     modifier IsOSS(uint id) {
         require(!derivList[id].isProprietary, "Derivative work is proprietary.");
         _;
     }

     /* EXTERNAL FUNCTIONS */
     /**
      * @notice Lists a card for auction in the market 
      */
     function addDerivToMarket(address tokenAddress, uint tokenId, uint askingPrice, address payable beneficiary, uint fee) 
        OnlyBenefactor(tokenAddress, tokenId) 
        HasTransferApproval(tokenAddress, tokenId)
        external
        returns(uint)
        {
        require(fee > 0, "Derivative work must have a fee rate");
        // @TODO:require that the card isn't for auction yet?
        uint newCardId = derivList.length;
        derivList.push(DerivCard(newCardId, tokenAddress, tokenId, payable(msg.sender), askingPrice, beneficiary, fee, false));

        assert(derivList[newCardId].id == newCardId);
        emit cardAdded(newCardId, tokenId, askingPrice);
        return newCardId;
    } 

    /**
     *  Forces a the derivative work to be OSS by buying an already owned derivative work at a higher or equal assessed price.
     */
    function forceOSS(uint id, uint newAssessedPrice) 
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
    function makeProprietary(uint id, uint newAssessedPrice) 
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

        // // update their deposit if they've paid more money than the asking price
        // if (msg.value > derivList[id].askingPrice) {
        //     deposit[msg.sender][id] = derivList[id].askingPrice.sub(msg.value);
        // }

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
    function depositFunds(uint id) 
        external 
        payable 
        CardExists(id) 
        IsProprietary(id) 
        OnlyOwner(id)
        returns(uint)
    {
        require(msg.value > 0, "Invalid amount of funds deposited.");
        require(msg.sender != derivList[id].beneficiary, "Cannot be the benficiary and the owner");

        // // calculate the cumulative fees
        // updateTotalOwedCost();
        // uint cumFee = totalOwedTokenCost[msg.sender][id];

        // if (msg.value >= cumFee) {

        //     // transfer the fees to the beneficiary
        //     lastDepositTimestamp[msg.sender][id] = block.timestamp;  
        //     derivList[id].beneficiary.transfer(cumFee);  

        //     // update the total owed cost 
        //     totalOwedTokenCost[msg.sender][id] = totalOwedTokenCost[msg.sender][id].sub(cumFee);

        //     // add the excess of the value sent to the deposit
        //     uint excess = msg.value.sub(cumFee);
        //     deposit[msg.sender][id] = deposit[msg.sender][id].add(excess);
        // } else {

        //     uint diff = cumFee - msg.value;
        //     // if there is enough funds in deposit to cover the fee, pay from the fee
        //     if (deposit[msg.sender][id] >= cumFee) {
        //         // transfer the difference from the deposit and 
        //         deposit[msg.sender][id] = deposit[msg.sender][id].sub(diff);
        //         derivList[id].beneficiary.transfer(cumFee);  
        //         totalOwedTokenCost[msg.sender][id] = totalOwedTokenCost[msg.sender][id].sub(cumFee);

        //     } else {
        //         derivList[id].beneficiary.transfer(msg.value);  
        //         totalOwedTokenCost[msg.sender][id] = totalOwedTokenCost[msg.sender][id].add(diff);

        //     }
        // }

        // calculate the cumulative fees
        updateTotalOwedCost();
        uint cumFee = totalOwedTokenCost[msg.sender][id];
        derivList[id].beneficiary.transfer(cumFee);  

        // update the total owed cost 
        totalOwedTokenCost[msg.sender][id] = totalOwedTokenCost[msg.sender][id].sub(cumFee);

        return totalOwedTokenCost[msg.sender][id];
    }

    /**
     *  Updates the total amount that is owed by the owner of a given derivative work after the elapsed time.   
     */
    function updateTotalOwedCost() 
        public
    {
        for (uint id = 0; id < derivList.length; id++) {
            if (derivList[id].isProprietary) {
                address owner = derivList[id].owner;
                uint elapsedTime = block.timestamp.sub(lastDepositTimestamp[owner][id]);
                uint cummFee = _calculateFee(id).mul(elapsedTime);

                totalOwedTokenCost[owner][id] = totalOwedTokenCost[owner][id].add(cummFee);
            }
        }
    }

    /**
     *  Forecloses the derivative by making the work open-source from being proprietary.
     */
    function forecloseDerivative(uint id)
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

    function changeToOpenSource(uint id) 
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

    function changeToProprietary(uint id, uint newAssessedPrice) 
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

   function _calculateFee(uint id) 
        view 
        internal
        CardExists(id) 
        IsProprietary(id) 
        returns(uint)
   {
       return (derivList[id].fee).mul(derivList[id].askingPrice);
   }
}