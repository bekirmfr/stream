//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./Library.sol";

contract Stream is AccessControl{
    using Library for *;

    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    uint16 public collectionId;
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

    mapping (uint => mapping (address => bool)) internal whitelist; //collectionId => entity
    mapping (uint => mapping (address => bool)) internal blacklist; //collectionId => entity
    
    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function create(string calldata _name, address _relayer, IERC20 _costToken, uint256 _costAmount, uint16 _totalShares, uint256 _feeNumerator, uint32 _feeDenominator, uint16 _maxPools, uint32 _minDepositDuration) external onlyRole(DEFAULT_ADMIN_ROLE) returns(uint){
        collections[++collectionId];
        this.set(collectionId, _name, _relayer, _totalShares, _feeNumerator, _feeDenominator, _maxPools, _minDepositDuration);
        this.addCostPair(collectionId, _costToken, _costAmount);
        return collectionId;
    }
    function set(uint16 _collectionId, string calldata _name, address _relayer, uint16 _totalShares, uint256 _feeNumerator, uint32 _feeDenominator, uint16 _maxPools, uint32 _minDepositDuration) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        Collection storage c = collections[_collectionId];
        c.id =  _collectionId;
        c.name = _name.stringToBytes32();
        c.relayer = _relayer;
        grantRole(RELAYER_ROLE, _relayer);
        c.totalShares = _totalShares;
        c.feeNumerator = _feeNumerator;
        c.feeDenominator = _feeDenominator;
        c.maxPools = _maxPools;
        c.minDepositDuration = _minDepositDuration;
        return true;
    }
    function activate(uint16 _collectionId, uint16 _collectionShareLimit, uint16 _poolShareLimit, bool _isWhitelisted) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        require(collections[_collectionId].status == false && collections[_collectionId].activePool == 0, "Collection already active!");
        this.addPool(_collectionId);
        this.set2(_collectionId, _collectionShareLimit, _poolShareLimit, _isWhitelisted, true);
        return true;
    }
    function set2(uint16 _collectionId, uint16 _collectionShareLimit, uint16 _poolShareLimit, bool _isWhitelisted, bool _status) external onlyRole(DEFAULT_ADMIN_ROLE) returns(bool){
        Collection storage c = collections[_collectionId];
        c.poolShareLimit = _poolShareLimit;
        c.collectionShareLimit = _collectionShareLimit;
        c.isWhitelisted = _isWhitelisted;
        this.setStatus(_collectionId, _status);
        return true;
    }
    function addPool(uint16 _collectionId) external onlyRole(DEFAULT_ADMIN_ROLE) returns (uint32){
        poolId++;
        pools[poolId].id = poolId;
        pools[poolId].collectionId = _collectionId;
        pools[poolId].timestamp = block.timestamp;
        collections[_collectionId].activePool = poolId;
        return poolId;
    }
    function setRelayer(uint16 _collectionId, address _relayer) external onlyRole(DEFAULT_ADMIN_ROLE){
        grantRole(RELAYER_ROLE, _relayer);
        collections[_collectionId].relayer = _relayer;
    }
    function setStatus(uint16 _collectionId, bool _status) external onlyRole(DEFAULT_ADMIN_ROLE){
        if(_status == true) {
            require(collections[_collectionId].activePool > 0, "Can not activate without a pool!");
            require(this.getCostPairs(_collectionId).length > 0, "Can not activate without a cost pair!");
        }
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
    function setWhitelist(uint16 _collectionId, address[] memory _whitelistedAddresses, bool _setValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint i; i < _whitelistedAddresses.length; i++){
            whitelist[_collectionId][_whitelistedAddresses[i]] = _setValue;
        }
    }
    function setBlacklist(uint16 _collectionId, address[] memory _blacklistedAddresses, bool _setValue) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for(uint i; i < _blacklistedAddresses.length; i++){
            whitelist[_collectionId][_blacklistedAddresses[i]] = _setValue;
        }
    }

    function getCollection (uint16 _collectionId) external view returns (Collection memory) {
        return collections[_collectionId];
    }
    function getPool (uint32 _poolId) external view returns (Pool memory) {
        return pools[_poolId];
    }
    function getDeposit (uint32 _depositId) external view returns (Deposit memory) {
        return deposits[_depositId];
    }
    function getPools (uint16 _collectionId) external view returns (uint32[] memory) {
        return poolsByCollection[_collectionId];
    }
    function getCostPairs(uint16 _collectionId) external view returns(Pair[] memory) {
        return costPairsByCollection[_collectionId];
    }
    function getPoolCount(uint16 _collectionId) external view returns (uint) {
        return poolsByCollection[_collectionId].length;
    }
    function getRemainingShares(uint16 _collectionId) external view returns (uint16) {
        return collections[_collectionId].totalShares - pools[collections[_collectionId].activePool].shareSum;
    }
}