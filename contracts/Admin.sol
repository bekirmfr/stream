//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./Library.sol";

contract Admin is AccessControl, ReentrancyGuard{
    using Library for *;

    address service;

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
        this.setId(collectionId);
        this.setName(collectionId, _name);
        this.setRelayer(collectionId, _relayer);
        this.addCostPair(collectionId, _costToken, _costAmount);
        this.setTotalShares(collectionId, _totalShares);
        this.setFee(collectionId, _feeNumerator, _feeDenominator);
        this.setMaxPools(collectionId, _maxPools);
        return collectionId;
    }
    function create2(string calldata _name, address _relayer, IERC20 _costToken1, uint256 _costAmount1,IERC20 _costToken2, uint256 _costAmount2,  uint16 _totalShares, uint256 _feeNumerator, uint32 _feeDenominator, uint16 _maxPools) external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint){
        collections[++collectionId];
        this.setId(collectionId);
        this.setName(collectionId, _name);
        this.setRelayer(collectionId, _relayer);
        this.addCostPair2(collectionId, _costToken1, _costAmount1, _costToken2, _costAmount2);
        this.setTotalShares(collectionId, _totalShares);
        this.setFee(collectionId, _feeNumerator, _feeDenominator);
        this.setMaxPools(collectionId, _maxPools);
        return collectionId;
    }

    function activate(uint16 _collectionId, uint16 _collectionShareLimit, uint16 _poolShareLimit, bool _isWhitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        this.setShareLimits(_collectionId, _collectionShareLimit, _poolShareLimit);
        this.setWhitelisted(_collectionId, _isWhitelisted);
        poolId++;
        pools[poolId].id = poolId;
        pools[poolId].collectionId = _collectionId;
        collections[_collectionId].activePool = poolId;
        poolsByCollection[_collectionId].push(poolId);
        this.setStatus(_collectionId, true);
        return true;
    }

    function setId(uint16 _collectionId) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].id = _collectionId;
    }
    function setName(uint16 _collectionId, string calldata _name) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].name = _name.stringToBytes32();
    }
    function setRelayer(uint16 _collectionId, address _relayer) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(RELAYER_ROLE, _relayer);
        collections[_collectionId].relayer = _relayer;
    }
    function setTotalShares(uint16 _collectionId, uint16 _totalShares) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].totalShares = _totalShares;
    }
    function setShareLimits(uint16 _collectionId, uint16 _collectionShareLimit, uint16 _poolShareLimit) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].collectionShareLimit = _collectionShareLimit;
        collections[_collectionId].poolShareLimit = _poolShareLimit;
    }
    function setWhitelisted(uint16 _collectionId, bool _whitelisted) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].isWhitelisted = _whitelisted;
    }
    function setFee (uint16 _collectionId, uint256 _numerator,  uint32 _denominator) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].feeNumerator = _numerator;
        collections[_collectionId].feeDenominator = _denominator;
    }
    function setMaxPools(uint16 _collectionId, uint16 _maxPools) external onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].maxPools = _maxPools;
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
    function addCostPair2(uint16 _collectionId, IERC20 _token1, uint256 _amount1, IERC20 _token2, uint256 _amount2) external onlyRole(DEFAULT_ADMIN_ROLE) {
        this.addCostPair(_collectionId, _token1, _amount1);
        this.addCostPair(_collectionId, _token2, _amount2);
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