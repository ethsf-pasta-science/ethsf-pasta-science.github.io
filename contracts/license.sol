pragma solidity ^0.8.0;

import "../node_modules/@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "../node_modules/@openzeppelin/contracts/utils/Address.sol";
import "../node_modules/@openzeppelin/contracts/utils/Counters.sol";


contract LicenseToken is ERC721 {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
 
   //@TODO: add name and symbol 
   constructor () ERC721("",""){}

   /**
    * Defines an nft for a derivative of OSS 
    */
    struct Derivative {

        // unique ID for given card 
        uint256 id;

        // universal resource identifier for use in frontend
        string uri;
    }
    
    mapping(address => uint256) ownerTokenCount;
    mapping(uint256 => address) tokenOwner;
    mapping(uint256 => Derivative) public Derivatives;

    /**
     * Mints a new card with a given uri
     */
    function mintDerivative(string memory uri) 
        public
    returns(uint256) {
        require(msg.sender != address(0), "beneficiary address does not exist");
        _tokenIds.increment();
        uint256 newDerivId = _tokenIds.current();
        _safeMint(msg.sender, newDerivId);

        Derivatives[newDerivId] = Derivative(newDerivId, uri);

        return newDerivId;
    }

    function tokenURI(uint256 newDerivId) public view override returns (string memory) {
        require(_exists(newDerivId), "ERC721Metadata: URI query for nonexistent token");

        return Derivatives[newDerivId].uri;
    }
} 
