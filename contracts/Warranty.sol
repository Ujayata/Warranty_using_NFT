// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract WarrantyNFT is ERC721, Ownable, AccessControl {
    using SafeMath for uint256;

    mapping(uint256 => uint256) public creationTime;

    bool public repairWarranty = true;

    struct RepairHistory {
        uint256 timestamp;
        string description;
    }

    mapping(uint256 => RepairHistory[]) public repairHistory;

    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");

    event Minted(address indexed to, uint256 indexed tokenId, string uri);
    event WarrantyVoid(bool status);
    event WarrantyReinstated(bool status);
    event RoleAdded(address indexed account, bytes32 role);
    event RoleRemoved(address indexed account, bytes32 role);

    constructor() ERC721("WarrantyNFT", "WARR") {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setRoleAdmin(RETAILER_ROLE, DEFAULT_ADMIN_ROLE);
    }

    modifier onlyManager() {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "Restricted to Managers.");
        _;
    }

    modifier onlyRetailer() {
        require(hasRole(RETAILER_ROLE, msg.sender), "Restricted to Retailers.");
        _;
    }

    function addRetailer(address account) public onlyManager {
        grantRole(RETAILER_ROLE, account);
        emit RoleAdded(account, RETAILER_ROLE);
    }

    function removeRetailer(address account) public onlyManager {
        revokeRole(RETAILER_ROLE, account);
        emit RoleRemoved(account, RETAILER_ROLE);
    }

    function addManager(address account) public onlyOwner {
        grantRole(DEFAULT_ADMIN_ROLE, account);
        emit RoleAdded(account, DEFAULT_ADMIN_ROLE);
    }

    function renounceManager() public onlyManager {
        renounceRole(DEFAULT_ADMIN_ROLE, msg.sender);
        emit RoleRemoved(msg.sender, DEFAULT_ADMIN_ROLE);
    }

    function mint(address to, string memory uri) public onlyRetailer returns (uint256) {
        uint256 tokenId = totalSupply() + 1;
        creationTime[tokenId] = block.timestamp;
        _mint(to, tokenId);
        _setTokenURI(tokenId, uri);
        emit Minted(to, tokenId, uri);
        return tokenId;
    }

    function voidWarranty() public onlyRetailer {
        repairWarranty = false;
        emit WarrantyVoid(repairWarranty);
    }

    function reinstateWarranty() public onlyRetailer {
        repairWarranty = true;
        emit WarrantyReinstated(repairWarranty);
    }

    function hasValidWarranty(address _owner) public view returns (bool) {
        uint256 tokenCount = balanceOf(_owner);

        if (tokenCount == 0) return false;

        uint256 latestTokenId = tokenOfOwnerByIndex(_owner, tokenCount - 1);
        uint256 mintTimestamp = creationTime[latestTokenId];
        uint256 warrantyPeriod = 52 weeks;

        return repairWarranty && block.timestamp < mintTimestamp + warrantyPeriod;
    }

    function transfer(address to, uint256 tokenId) public {
        require(_exists(tokenId), "Token does not exist");
        require(hasValidWarranty(msg.sender), "Your warranty has expired");
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not the owner or approved to transfer the token");

        _transfer(msg.sender, to, tokenId);
    }

    function addRepair(uint256 tokenId, string memory description) public onlyRetailer {
        require(_exists(tokenId), "Token does not exist");
        require(hasValidWarranty(msg.sender), "Your warranty has expired");
        require(_isApprovedOrOwner(msg.sender, tokenId), "Caller is not the owner or approved to update the token");

        repairHistory[tokenId].push(RepairHistory(block.timestamp, description));
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view override(ERC721, AccessControl) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}
