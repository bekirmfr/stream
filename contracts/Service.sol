//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract Service is AccessControl, ReentrancyGuard{
    bytes32 public constant RELAYER_ROLE = keccak256("RELAYER_ROLE");

    address public nodebitToken;
    address public rewardToken;

    uint private depositId;
    uint private collectionId;
    uint private poolId;

    struct Deposit{
        address entity;
        uint collectionId;
        uint poolId;
        address token;
        uint256 amount;
        uint shares;
    }

    struct Fee{
        uint256 numerator;          //
        uint256 denominator;        //Used only if it's a fractional number. 
        bool isFraction;            //Is this a fractional or fixed number fee.
    }

    struct Cost{
        address token;
        uint256 amount;
    }

    struct Pool{
        uint id;
        uint collectionId;
        uint[] deposits;            //Array of deposits used for thıs pool.
        uint signature1;            //This field is signed by the relayer. It will hold the outcome of pool processing. Ie, node id,  tx hash
        string signature2;          //Additional signature field
        address signature3;         //Additional signature field
        bytes signature4;           //Additional signature field
        bool isDeployed;            //Set by the relayer when the pool is processed.
    }

    struct Collection{
        uint id;
        string name;
        string description;
        address relayer;            //An address that will process deposits. This can be an automated relayer or multi-sig address.
        Cost[] costs;               //The total value of token(s) the pool needs to reach to be completed. 
                                    //This can be the same as or different from deposit token(s). 
                                    //Ex. a pool can support many different ERC20 deposits but the pool total may be valued against a stable coin.
        uint activePool;
        uint[] pools;               //Pool ids of this collection.
        uint totalShares;           //Total number of shares the cost(s) is divided into.
        uint remainingShares;       //How many shares are left to buy.
        uint maxCollecitonLimit;    //Max shares an entity can buy in the entire Collection. 0 means unlimited.
        uint maxPoolLimit;          //Max shares an entity can buy in one pool. 0 means unlimited.
        bool isWhitelisted;         //If true only whitelisted addresses can buy.
        bool isBlacklisted;         //If true blacklisted addresses can not buy.
        bool status;                //0 => inactive, 1 => active.
        Fee depositFee;
        Fee recurringFee;
        Fee claimingFee;
        uint maxPoolCount;          //Number of pools this collection can have. 0 means unlimited.
    }

    mapping (uint => Deposit) private deposits;
    mapping (uint => Collection) private collections;
    mapping (uint => Pool) private pools;

    mapping (uint => mapping (address => uint)) public collectionSharesByEntity;   //collectionId => entity => shares
    mapping (uint => mapping (uint => mapping (address => uint))) public poolSharesByEntity;   //collectionId => poolId => entity => shares

    mapping (uint => mapping (address => bool)) public whitelist;
    mapping (uint => mapping (address => bool)) public blacklist;

    mapping (uint => mapping (address =>uint[])) public collectionDepositsByToken;  //collectionId => tokenAddress => deposit[]
    mapping (uint => mapping (address => uint256)) public collectionSumByToken;     //collectionId => tokenAddress => poolSum
    mapping (uint => mapping (address => uint256)) public depositSumByToken;        //collectionId => tokenAddress => depositSum
    mapping (uint => mapping (address => uint256)) public feeSumByToken;            //collectionId => tokenAddress => feeSum

    event DepositReceived(uint depositId, address from, address token, uint256 depositAmount, uint poolId);
    event PoolReady(uint256 collectionId, uint poolId, address relayer);

    constructor() {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);

        //rewardToken = ERC20(_rewardAddr);
        uint cId = createCollection("StrongBlock Node Collection #1");
        setDescription(cId, "This pool will create a StrongBlock node.");
        setRelayer(cId, 0xdD870fA1b7C4700F2BD7f44238821C26f7392148);
        setShares(cId, 100, 100);
        setDepositFee(cId, 1, 100);
        setRecurringFee(cId, 0, 0);
        setClaimingFee(cId, 1, 100);
        setMaxPoolCount(cId, 100);
        setStatus(cId, true);
        pools[poolId++];
        pools[poolId].id = poolId;
        pools[poolId].collectionId = cId;
        collections[cId].pools.push(poolId); 
        collections[cId].activePool = poolId;
    }

    function buy(uint _collectionId, uint _shareAmount) external nonReentrant{
        require (_collectionId > 0, "Invalid collection id!");
        require (_shareAmount > 0, "Share amount must be greater than 0!");

        Collection memory c = collections[_collectionId];
        require (c.status, "Collection is not active!");
        require (c.pools.length > 0, "No pool was initiated!");
        require (c.pools.length <= c.maxPoolCount, "Collection reached max pool count!");

        require (poolSharesByEntity[c.id][c.activePool][msg.sender] <= c.maxPoolLimit); //check if entity is sharelimited in the pool
        require (collectionSharesByEntity[c.id][msg.sender] <= c.maxCollecitonLimit); //check if entity is sharelimited in the collection

        if(c.isWhitelisted) require(whitelist[_collectionId][msg.sender] == true, "Only whitelisted addresses are allowed!");
        if(c.isBlacklisted) require(blacklist[_collectionId][msg.sender] != true, "Blacklisted addresses are not allowed!");

        uint availableShares = c.remainingShares;
        require(availableShares > 0, "No shares left!");
        require(_shareAmount <= availableShares, "Share amount can not exceed avalable shares!");

        for(uint t = 0; t < c.costs.length; t++){
            Cost memory cost = c.costs[t];
            require (cost.token != address(0), "Cost address undefined!");
            require (cost.amount > 0, "Cost amount must be greater than 0!");

            uint256 netAmount = cost.amount * _shareAmount / c.totalShares;
            uint256 feeAmount = _calculateFee(c.depositFee, netAmount);
            uint256 amountToDeposit = netAmount + feeAmount;
            uint256 relayerAllowance = IERC20(cost.token).allowance(msg.sender, c.relayer);
            require(relayerAllowance >= amountToDeposit, "Insufficient relayer allowance!");
            uint256 serviceAllowance = IERC20(cost.token).allowance(msg.sender, address(this));
            require(serviceAllowance >= amountToDeposit, "Insufficient contract allowance!");

            require(IERC20(cost.token).transferFrom(msg.sender, c.relayer, amountToDeposit), "Deposit failed!");

            deposits[depositId++] = Deposit(msg.sender, _collectionId, c.activePool, cost.token, amountToDeposit, _shareAmount);

            pools[c.activePool].deposits.push(depositId);
            emit DepositReceived(depositId, msg.sender, cost.token, amountToDeposit, c.activePool);

            collectionDepositsByToken[_collectionId][cost.token].push(depositId);
            depositSumByToken[_collectionId][cost.token] += amountToDeposit;
            feeSumByToken[_collectionId][cost.token] += feeAmount;
            collectionSumByToken[_collectionId][cost.token] += netAmount;
        }
        collections[_collectionId].remainingShares -= _shareAmount;

        collectionSharesByEntity[_collectionId][msg.sender] += _shareAmount;
        poolSharesByEntity[_collectionId][0][msg.sender] += _shareAmount;

        _checkPoolReady(_collectionId, c.activePool);
    }

    function sign(uint _poolId, uint _signature) external nonReentrant onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "Unauthorized relayer!");
        require (_signature > 0, "Signature number can not be 0!");
        pools[_poolId].signature1 = _signature;
    }
    function sign(uint _poolId, string memory _signature) external nonReentrant onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "Unauthorized relayer!");
        require (bytes(_signature).length > 0, "Signature length can not be 0!");
        pools[_poolId].signature2 = _signature;
    }
    function sign(uint _poolId, address _signature) external nonReentrant onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "Unauthorized relayer!");
        require (_signature != address(0), "Signature address can not be 0!");
        pools[_poolId].signature3 = _signature;
    }
    function sign(uint _poolId, bytes memory _signature) external nonReentrant onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "Unauthorized relayer!");
        require (_signature.length > 0, "Signature length can not be 0!");
        pools[_poolId].signature4 = _signature;
    }

    /*function mintToPoolParticipants(uint _collectionId, uint _nodeId) external onlyRole(RELAYER_ROLE) nonReentrant{
        require(collections[collectionId].relayer == msg.sender, "Wrong relayer!");
        Collection memory c = getCollectionById(_collectionId);
        Poolbit[] memory pb = c.poolbits;
        
        uint256 arrayLength = pb.length;
        for (uint i=0; i < arrayLength; i++) {
            uint id = pb[i].depositId;
            address to = deposits[id].entity;
            uint256 mintAmount = pb[i].usedAmount * 10**ERC20(nodebitToken).decimals() / poolCost;
            require (Nodebit(nodebitToken).mint(to, mintAmount), "Nodebit Token mint failed!");
            pendingBalances[to] -= pb[i].usedAmount;
            deployedBalances[to] += pb[i].usedAmount;
        }
        c.deployed = true;
        c.nodeId = _nodeId;
    }*/

    function createCollection(string memory _name) public onlyRole(DEFAULT_ADMIN_ROLE) returns(uint){
        collectionId++;
        setId(collectionId);
        setName(collectionId, _name);
        return collectionId;
    }
    function createCollection(string memory _name, string memory _description, address _relayer, Cost[] memory _costs, uint _totalShares, uint _remainingShares, bool _isWhitelisted, bool _isBlacklisted, Fee memory _depositFee, Fee memory _recurringFee, Fee memory _claimingFee, uint _maxPoolCount) public onlyRole(DEFAULT_ADMIN_ROLE) returns(uint){
        collectionId++;
        setId(collectionId);
        setName(collectionId, _name);
        setDescription(collectionId, _description);
        setRelayer(collectionId, _relayer);
        setCosts(collectionId, _costs);
        setShares(collectionId, _totalShares, _remainingShares);
        setWhitelisted(collectionId, _isWhitelisted);
        setBlacklisted(collectionId, _isBlacklisted);
        collections[collectionId].depositFee = _depositFee;
        collections[collectionId].recurringFee = _recurringFee;
        collections[collectionId].claimingFee = _claimingFee;
        setMaxPoolCount(collectionId, _maxPoolCount);

        return collectionId;
    }
    function setId(uint _collectionId) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].id = _collectionId;
    }
    function setName(uint _collectionId, string memory _name) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].name = _name;
    }
    function setDescription(uint _collectionId, string memory _description) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].description = _description;
    }
    function setRelayer(uint _collectionId, address _relayer) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].relayer = _relayer;
    }
    function setShares(uint _collectionId, uint _totalShares, uint _remainingShares) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].totalShares = _totalShares;
        collections[_collectionId].remainingShares = _remainingShares;
    }
    function setWhitelisted(uint _collectionId, bool _whitelisted) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].isWhitelisted = _whitelisted;
    }
    function setBlacklisted(uint _collectionId, bool _blacklisted) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].isBlacklisted = _blacklisted;
    }
    function setDepositFee (uint _collectionId, uint256 _numerator,  uint256 _denominator) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].depositFee.numerator = _numerator;
        collections[_collectionId].depositFee.denominator = _denominator;
        if(_denominator > 0) collections[_collectionId].depositFee.isFraction = true;
    }
    function setRecurringFee (uint _collectionId, uint256 _numerator,  uint256 _denominator) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].recurringFee.numerator = _numerator;
        collections[_collectionId].recurringFee.denominator = _denominator;
        if(_denominator > 0) collections[_collectionId].recurringFee.isFraction = true;
    }
    function setClaimingFee (uint _collectionId, uint256 _numerator,  uint256 _denominator) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].claimingFee.numerator = _numerator;
        collections[_collectionId].claimingFee.denominator = _denominator;
        if(_denominator > 0) collections[_collectionId].claimingFee.isFraction = true;
    }
    function setMaxPoolCount(uint _collectionId, uint _maxPoolCount) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].maxPoolCount = _maxPoolCount;
    }
    function setStatus(uint _collectionId, bool _status) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].status = _status;
    }
    function setActivePool(uint _collectionId, uint _poolId) public onlyRole(DEFAULT_ADMIN_ROLE){
        collections[_collectionId].activePool = _poolId;
    }

    function addCost(uint _collectionId, address _token, uint256 _amount) public onlyRole(DEFAULT_ADMIN_ROLE) {
        collections[_collectionId].costs.push(Cost(_token, _amount));
    }
    function setCosts (uint _collectionId, Cost[] memory _costs) public onlyRole(DEFAULT_ADMIN_ROLE) {
        delete collections[_collectionId].costs;
        for(uint i = 0; i < _costs.length; i++){
            collections[_collectionId].costs[i] = _costs[i];
        }
    }
    function addDeposit(address _entity, uint256 _amount, address _token, uint _collectionId, uint _poolId, uint _shares) public onlyRole(DEFAULT_ADMIN_ROLE)  {
        depositId++;
        deposits[depositId] = Deposit(_entity, _collectionId, _poolId, _token, _amount, _shares);
        pools[_poolId].deposits.push(depositId);
    }

    function _checkPoolReady(uint _collectionId, uint _poolId) internal nonReentrant{
        if (collections[_collectionId].remainingShares <= 0 && collections[_collectionId].pools.length < collections[_collectionId].maxPoolCount){
            pools[poolId++];                                //add new  pool
            pools[poolId].id = poolId;
            pools[poolId].collectionId = _collectionId;

            collections[_collectionId].pools.push(poolId);  //make it active pool in the collection
            collections[_collectionId].activePool = poolId;

            collections[_collectionId].remainingShares = collections[_collectionId].totalShares;    //reset the remaining shares
            emit PoolReady(_collectionId, _poolId, collections[_collectionId].relayer);
        } 
    } 
    function _calculateFee(Fee memory _fee, uint256 _amount) internal pure returns (uint256) {
        uint256 result = 0;
        if(_fee.isFraction){
            result = _amount * _fee.numerator;
            result /= _fee.denominator;
        }else{
            result = _fee.numerator;
        }
        return result;
    }

    function getCosts(uint _collectionId) public view returns(Cost[] memory) {
        return collections[_collectionId].costs;
    }
    function getPoolCount(uint _collectionId) public view returns (uint) {
        return collections[_collectionId].pools.length;
    }
    function getDepositById (uint _id) public view returns (Deposit memory) {
        return deposits[_id-1];
    }
    function getCollectionById (uint _id) public view returns (Collection memory) {
        return collections[_id];
    }
    function getTotalShares (uint _collectionId) public view returns (uint) {
        return collections[_collectionId].totalShares;
    }
    function getRemainingShares (uint _collectionId) public view returns (uint) {
        return collections[_collectionId].remainingShares;
    }
    function getRelayer (uint _collectionId) public view returns (address) {
        return collections[_collectionId].relayer;
    }
    function getPools (uint _collectionId) public view returns (uint[] memory) {
        return collections[_collectionId].pools;
    }
    function getPoolById (uint _poolId) public view returns (Pool memory) {
        return pools[_poolId];
    }
} 