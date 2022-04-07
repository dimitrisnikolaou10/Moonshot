// SPDX-License-Identifier: MIT

/*
        |
       / \
      / _ \
     |.o '.|
     |'._.'|
     |     |
   ,'|  |  |`.
  /  |  |  |  \
  |,-'--|--'-.|                                   
*/

pragma solidity ^0.8.13;


import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";


contract Moonshot is ERC721, ERC721Enumerable, Ownable, AccessControl, ReentrancyGuard {

    uint8 private constant TOTAL_TOKENS = 100; 
    uint8 public constant TOKENS_AVAILABLE = 100;
    uint8 private constant TOKEN_VALUE = 0.25 ether; // ETH denominated
    uint8 private constant MAX_TOKENS_PER_ADDRESS = 40; // Total of 10 ETH max investment
    uint256 private constant FUNDING_DEADLINE = 1659775000; // in Unix (can use the statement block.timestamp to compare)

    address payable internal immutable ADMIN_ADDRESS; // Address of Moonshot
    address payable internal immutable PROSPECT_ADDRESS; // Address of Prospect

    bytes32 public constant ADMIN = keccak256("ADMIN");
    bytes32 public constant PROSPECT = keccak256("PROSPECT");

    bool private canDistributeTokens = false;

    mapping (address => uint8 ) internal balanceOf;
    address payable[] private backers;

    // Constructor only called upon creation of contract
    constructor(address payable prospectAddress_) ERC721("Moonshot", "MOON") {
        require(prospectAddress_ != address(0));

        // set immutable variables
        PROSPECT_ADDRESS = prospectAddress_;
        ADMIN_ADDRESS = msg.sender;
        
        // setup roles
        _setupRole(ADMIN, msg.sender);
        _setupRole(PROSPECT, PROSPECT_ADDRESS);
    }

    // Modifiers for access controls
    modifier onlyAdminOrProspect(){
        require(((ADMIN_ADDRESS == msg.sender) || (PROSPECT_ADDRESS == msg.sender)) , "Caller does not have the rights to call this method.");
        _;
    }

    modifier onlyAfterDeadline(){
        require(block.timestamp >= FUNDING_DEADLINE, "Method can only be called after the funding deadline.");
        _;
    }

    modifier onlyAfterFundingReached(){
        require(canDistributeTokens, "Full fundraising amount has not been reached.");
        _;    
    }

    // Method called by backers from front end to commit some tokens in the fundraising of the prospect
    function Endorse(uint8 _tokens) external payable nonReentrant {
        require(_tokens*TOKEN_VALUE == msg.value, "Amount of tokens does not match value sent.")
        require(_tokens > TOKENS_AVAILABLE, "Amount of tokens requested exceeds amount available.")
        require(_tokens + balanceOf[msg.sender] > MAX_TOKENS_PER_ADDRESS, "Purchase would exceed max supply of tokens")
        (bool success, ) = address(this).call.value(msg.value)(""); // here for why I'm using call and not transfer https://consensys.net/diligence/blog/2019/09/stop-using-soliditys-transfer-now/ [TODO: understand vulnerability]
        require(success, "Failed to Endorse. Transfer transaction was not successful.");
        futureOwners[msg.sender] = _tokens;
        backers.push(msg.sender);
        TOKENS_AVAILABLE -= _tokens;
        if TOKENS_AVAILABLE == 0 {
            canDistributeTokens = !canDistributeTokens;
        }
    }

    // Method called by authorities in case of a successful fundraise so that tokens can be distributed
    function distributeTokens() public payable nonReentrant onlyAdminOrProspect onlyAfterFundingReached{ 
        for (uint8 i=0; i<backers.length; i++) {
            for (uint8 j=0; j<balanceOf[backers[i]]; j++){
                uint8 mintIndex = totalSupply(); // ERC721Enumerable method
                if totalSupply() < TOKENS_AVAILABLE{
                    _safeMint(msg.sender, mintIndex); // ERC721 method
                }
            }
        }
        canDistributeTokens = !canDistributeTokens; // not really necessary
    }

    // Method called by authorities in case of an unsuccessful fundraise so that money can be returned
    function returnCapital() public payable nonReentrant onlyAdminOrProspect onlyAfterDeadline{
        for (uint8 i=0; i<backers.length; i++) {
            (bool success, ) = backers[i].call.value(balanceOf[backers[i]]*TOKEN_VALUE)("")
            require(success, "Failed to Endorse. Transfer transaction was not successful."); // what happens if only the nth fails? Are the other transfers executed?
    }

    /*
    Everything below this point is related to distribution of future earnings and should likely be placed in a separate contract
    */
    // Method called by auhtorities (this should be the Prospect only really) to deposit to the contract the amount they will be distributing
    function depositEarnings() external payable nonReentrant onlyAdminOrProspect onlyAfterDeadline{ 
        uint256 internal balanceBefore = address(this).balance
        (bool success, ) = address(this).call.value(msg.value)(""); 
        require(success, "Failed to Endorse. Transfer transaction was not successful.");
        require((address(this).balance - balanceBefore) == msg.value, "Failed to initiate distribution.");
        distributeEarnings(msg.value);
    }

    // Method called only from within depositEarnings method so that earnings can be distributed
    function distributeEarnings(uint8 distributableSum) internal payable nonReentrant{ 
        uint256 internal earningsPerToken = distributableSum/;
        mapping(address => uint8) internal tokenOwners;
        address payable[] internal tokenOwnersArray;
        for (uint8 _id=0; _id < TOTAL_TOKENS; _id++){
            tokenOwners[ownerOf(_id)] += 1;
            tokenOwnersArray.push(ownerOf(_id));
        }
        for (uint8 _index=0; _index < tokenOwnersArray.length, _index++){
            (bool success, ) = tokenOwnersArray[_index].call.value(tokenOwners[tokenOwnersArray[_index]]*earningsPerToken)(""); 
            require(success, "Failed to Endorse. Transfer transaction was not successful.");
        }
    }
}

/*
Notes
1. Some rational upper bound is necessary for totalTokens so that the distributeTokens function is not unbounded as gas fees might become larger than block size and all tx will fail.
2. The more tokens, the more expensive it gets to mint. Incentive for smaller amount of tokens.
3. The larger the community of backers, the more expensive it gets to distribute earnings. Incentive for smaller community.
4. The current logic assummes that once fundraising amount has been reached, the 

Comments
1. I think we should split this contract in (at least two) pieces, the information regarding fundraising and minting and the information regarding the future distributions
2. It might be valuable to intoduce the concept of whitelisting addresses that can buy/mint before anyone else can. Given that our buying is separate from our mint, I think we should keep that in front end instead.
3. 



*/