//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Library.sol";

contract Admin is AccessControl, ReentrancyGuard{
    using Library for *;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    address public nodebitToken;
    address public rewardToken;

    uint16 internal collectionId;
    uint32 internal poolId;
    uint32 internal depositId;

    mapping (uint => Deposit) internal deposits;
    mapping (uint => Collection) internal collections;
    mapping (uint => Pool) internal pools;

    mapping (uint => uint32[]) internal poolsByCollection;
    mapping (uint => Pair[]) internal costPairsByCollection;

    mapping (uint => mapping (address => uint)) internal collectionSharesByEntity;   //collectionId => entity => shares
    mapping (uint => mapping (address => uint)) internal poolSharesByEntity;   //collectionId => poolId => entity => shares
    mapping (uint => uint[]) internal poolDeposits; //poolId => depositId[]

    mapping (uint => mapping (address => bool)) internal whitelist;
    mapping (uint => mapping (address => bool)) internal blacklist;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function create(string calldata _name, address _relayer, IERC20 _costToken, uint256 _costAmount, uint16 _totalShares, uint256 _feeNumerator, uint32 _feeDenominator, uint16 _maxPools) external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint){
        collections[++collectionId];
        this.set(collectionId, _name, _relayer, _costToken, _costAmount, _totalShares, _feeNumerator, _feeDenominator, _maxPools);
        return collectionId;
    }
    function set(uint16 _collectionId, string calldata _name, address _relayer, IERC20 _costToken, uint256 _costAmount, uint16 _totalShares, uint256 _feeNumerator, uint32 _feeDenominator, uint16 _maxPools) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        Collection storage c = collections[_collectionId];
        c.id =  _collectionId;
        c.name = _name.stringToBytes32();
        c.relayer = _relayer;
        grantRole(RELAYER_ROLE, _relayer);
        costPairsByCollection[_collectionId].push(Pair(address(_costToken), _costAmount));
        c.totalShares = _totalShares;
        c.feeNumerator = _feeNumerator;
        c.feeDenominator = _feeDenominator;
        c.maxPools = _maxPools;
        return true;
    }
    function activate(uint16 _collectionId, uint16 _collectionShareLimit, uint16 _poolShareLimit, bool _isWhitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        this.set2(_collectionId, _collectionShareLimit, _poolShareLimit, _isWhitelisted, true);
        addNewPool(_collectionId);
        return true;
    }
    function set2(uint16 _collectionId, uint16 _collectionShareLimit, uint16 _poolShareLimit, bool _isWhitelisted, bool _status) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        Collection storage c = collections[_collectionId];
        c.poolShareLimit = _poolShareLimit;
        c.collectionShareLimit = _collectionShareLimit;
        c.isWhitelisted = _isWhitelisted;
        c.status = _status;
        return true;
    }
    function addNewPool(uint16 _collectionId) internal returns (uint32){
        poolId++;
        pools[poolId].id = poolId;
        pools[poolId].collectionId = _collectionId;
        collections[_collectionId].activePool = poolId;
        poolsByCollection[_collectionId].push(poolId);
        return poolId;
    }

    function setRelayer(uint16 _collectionId, address _relayer) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(RELAYER_ROLE, _relayer);
        collections[_collectionId].relayer = _relayer;
    }
    function setStatus(uint16 _collectionId, bool _status) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].status = _status;
    }
    function setActivePool(uint16 _collectionId, uint32 _poolId) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].activePool = _poolId;
    }
    function addCostPair(uint16 _collectionId, IERC20 _token, uint256 _amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
        costPairsByCollection[_collectionId].push(Pair(address(_token), _amount));
    }
    function deleteCostPairs(uint16 _collectionId) external onlyRole(DEFAULT_ADMIN_ROLE) {
        delete costPairsByCollection[_collectionId];
    }

    function getCollectionById (uint16 _id) external view returns (Collection memory) {
        return collections[_id];
    }
    function getPoolById (uint32 _poolId) external view returns (Pool memory) {
        return pools[_poolId];
    }
    function getDepositById (uint32 _id) external view returns (Deposit memory) {
        return deposits[_id];
    }
    function getPoolsByCollection (uint16 _collectionId) external view returns (uint32[] memory) {
        return poolsByCollection[_collectionId];
    }
    function getPoolCount(uint16 _collectionId) external view returns (uint) {
        return poolsByCollection[_collectionId].length;
    }
    function getCostPairsByCollection(uint16 _collectionId) external view returns(Pair[] memory) {
        return costPairsByCollection[_collectionId];
    }
} 