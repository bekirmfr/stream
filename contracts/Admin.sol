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

    uint32 internal depositId;
    uint32 internal collectionId;
    uint32 internal poolId;

    mapping (uint => Deposit) internal deposits;
    mapping (uint => Collection) internal collections;
    mapping (uint => Pool) internal pools;

    mapping (uint => uint32[]) internal poolsByCollection;
    mapping (uint => Pair[]) internal costPairsByCollection;

    mapping (uint => mapping (address => uint)) internal collectionSharesByEntity;   //collectionId => entity => shares
    mapping (uint => mapping (address => uint)) internal poolSharesByEntity;   //collectionId => poolId => entity => shares

    mapping (uint => mapping (address => bool)) internal whitelist;
    mapping (uint => mapping (address => bool)) internal blacklist;

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }
    
    function createSingleCostCollection(string calldata _name, address _relayer, IERC20 _costToken, uint256 _costAmount, uint32 _totalShares, uint _feeNumerator, uint _feeDenominator, uint32 _maxPoolCount) external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint){
        collectionId++;
        setId(collectionId);
        setName(collectionId, _name);
        setRelayer(collectionId, _relayer);
        costPairsByCollection[collectionId].push(Pair(address(_costToken), _costAmount));
        setShares(collectionId, _totalShares, _totalShares);  //Assuming remainingShares == totalShares
        setFee(collectionId, _feeNumerator, _feeDenominator);
        setMaxPoolCount(collectionId, _maxPoolCount);
        return collectionId;
    }

    function activateCollection(uint32 _collectionId, uint32 collectionShareLimit, uint32 poolShareLimit, bool _isWhitelisted, bool _isBlacklisted) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        setShareLimits(_collectionId, collectionShareLimit, poolShareLimit);
        setWhitelisted(_collectionId, _isWhitelisted);
        setBlacklisted(_collectionId, _isBlacklisted);
        poolId++;
        pools[poolId].id = poolId;
        pools[poolId].collectionId = _collectionId;
        collections[_collectionId].activePool = poolId;
        poolsByCollection[_collectionId].push(poolId);
        collections[_collectionId].status = true;
        return true;
    }

    function checkPoolReady(uint32 _collectionId, uint32 _poolId) internal returns (bool){
        require(collections[_collectionId].activePool == _poolId);
        require(collections[_collectionId].remainingShares <= 0);
        require(pools[poolId].shareSum == collections[_collectionId].totalShares);
        if(collections[_collectionId].maxPoolCount > 0) require(poolsByCollection[_collectionId].length < collections[_collectionId].maxPoolCount);
        
        poolId++;
        pools[poolId].id = poolId;
        pools[poolId].collectionId = _collectionId;

        poolsByCollection[_collectionId].push(poolId);  //make it active pool in the collection
        collections[_collectionId].activePool = poolId;

        collections[_collectionId].remainingShares = collections[_collectionId].totalShares;    //reset the remaining shares
        return true;
    }

    function setId(uint32 _collectionId) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].id = _collectionId;
    }
    function setName(uint32 _collectionId, bytes32 _name) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].name = _name;
    }
    function setName(uint32 _collectionId, string calldata _name) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].name = _name.stringToBytes32();
    }
    function setRelayer(uint32 _collectionId, address _relayer) public onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(RELAYER_ROLE, _relayer);
        collections[_collectionId].relayer = _relayer;
    }
    function setShares(uint32 _collectionId, uint32 _totalShares, uint32 _remainingShares) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].totalShares = _totalShares;
        collections[_collectionId].remainingShares = _remainingShares;
    }
    function setShareLimits(uint32 _collectionId, uint32 _collectionShareLimit, uint32 _poolShareLimit) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].collectionShareLimit = _collectionShareLimit;
        collections[_collectionId].poolShareLimit = _poolShareLimit;
    }
    function setWhitelisted(uint32 _collectionId, bool _whitelisted) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].isWhitelisted = _whitelisted;
    }
    function setBlacklisted(uint32 _collectionId, bool _blacklisted) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].isBlacklisted = _blacklisted;
    }
    function setFee (uint32 _collectionId, uint256 _numerator,  uint256 _denominator) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].feeNumerator = _numerator;
        collections[_collectionId].feeDenominator = _denominator;
    }
    function setMaxPoolCount(uint32 _collectionId, uint32 _maxPoolCount) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].maxPoolCount = _maxPoolCount;
    }
    function setStatus(uint32 _collectionId, bool _status) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].status = _status;
    }
    function setActivePool(uint32 _collectionId, uint32 _poolId) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].activePool = _poolId;
    }
    function addCostPair(uint32 _collectionId, address _token, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        costPairsByCollection[_collectionId].push(Pair(_token, _amount));
    }
    function setCostPairs (uint32 _collectionId, Pair[] memory _costPairs) public onlyRole(DEFAULT_ADMIN_ROLE) {
        delete costPairsByCollection[_collectionId];
        for(uint i = 0; i < _costPairs.length; i++){
            costPairsByCollection[_collectionId][i] = _costPairs[i];
        }
    }

    function getCollectionById (uint32 _id) public view returns (Collection memory) {
        return collections[_id];
    }
    function getPoolById (uint32 _poolId) public view returns (Pool memory) {
        return pools[_poolId];
    }
    function getDepositById (uint32 _id) public view returns (Deposit memory) {
        return deposits[_id-1];
    }
    function getPoolsByCollection (uint32 _collectionId) public view returns (uint32[] memory) {
        return poolsByCollection[_collectionId];
    }
    function getPoolCount(uint32 _collectionId) public view returns (uint) {
        return poolsByCollection[_collectionId].length;
    }
    function getCostPairsByCollection(uint32 _collectionId) public view returns(Pair[] memory) {
        return costPairsByCollection[_collectionId];
    }
} 