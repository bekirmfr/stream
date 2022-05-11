//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Admin.sol";
import "./Stats.sol";

contract Service is Admin, Stats, Pausable{
    using Library for *;
    event DepositReceived(uint depositId, address from, address token, uint256 depositAmount, uint poolId);
    event PoolReady(uint32 poolId, address relayer);

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    function buy(uint16 _collectionId, uint16 _shareAmount) external nonReentrant whenNotPaused{
        require (_shareAmount > 0, "Share amount must be greater than 0!");

        Collection storage c = collections[_collectionId];

        require(c.status, "Collection is not active!");
        require(costPairsByCollection[c.id].length > 0, "No pool was initiated!");
        if(c.maxPools > 0) require(poolsByCollection[c.id].length <= c.maxPools && pools[c.activePool].shareSum < c.totalShares, "Collection reached max pool count!");
        assert (pools[c.activePool].isDeployed == false);

        if(c.poolShareLimit > 0) require(poolSharesByEntity[c.activePool][msg.sender] <= c.poolShareLimit, "Reached max collection limit!"); //check if entity is sharelimited in the pool
        if(c.collectionShareLimit > 0) require (collectionSharesByEntity[c.id][msg.sender] <= c.collectionShareLimit, "Reached max pool limit!"); //check if entity is sharelimited in the collection

        if(c.isWhitelisted) require(whitelist[c.id][msg.sender] == true, "Only whitelisted addresses are allowed!");
        require(blacklist[c.id][msg.sender] != true, "Blacklisted addresses are not allowed!");
        uint32 remainingShares_ = c.totalShares - pools[c.activePool].shareSum;
        require(remainingShares_ > 0, "No shares left!");
        require(_shareAmount <= remainingShares_, "Share amount can not exceed available shares!");

        for(uint t = 0; t < costPairsByCollection[c.id].length; t++){
            Pair storage costPair = costPairsByCollection[c.id][t];

            uint256 netAmount = costPair.amount * _shareAmount / c.totalShares;
            uint256 feeAmount = netAmount.calculateFee(c.feeNumerator, c.feeDenominator);
            uint256 amountToDeposit = netAmount + feeAmount;

            uint256 relayerAllowance = IERC20(costPair.token).allowance(msg.sender, c.relayer);
            require(relayerAllowance >= amountToDeposit, "Insufficient relayer allowance!");
            uint256 serviceAllowance = IERC20(costPair.token).allowance(msg.sender, address(this));
            require(serviceAllowance >= amountToDeposit, "Insufficient service allowance!");

            require(IERC20(costPair.token).transferFrom(msg.sender, c.relayer, amountToDeposit), "Token transfer failed!");

            deposits[++depositId] = Deposit(msg.sender, c.id, c.activePool, costPair.token, amountToDeposit, _shareAmount);
            poolDeposits[c.activePool].push(depositId);
            emit DepositReceived(depositId, msg.sender, costPair.token, amountToDeposit, c.activePool);

            collectionDepositsByToken[c.id][costPair.token].push(depositId);
            depositSumByToken[c.id][costPair.token] += amountToDeposit;
            feeSumByToken[c.id][costPair.token] += feeAmount;
            collectionSumByToken[c.id][costPair.token] += netAmount;
        }
        pools[c.activePool].shareSum += _shareAmount;

        collectionSharesByEntity[c.id][msg.sender] += _shareAmount;
        poolSharesByEntity[c.activePool][msg.sender] += _shareAmount;

        if(pools[c.activePool].shareSum >= c.totalShares){
            emit PoolReady(c.activePool, c.relayer);
            if(collections[_collectionId].maxPools > 0 && poolsByCollection[_collectionId].length < collections[_collectionId].maxPools) {
                addNewPool(_collectionId);
            }else if(collections[_collectionId].maxPools == 0){
                addNewPool(_collectionId);
            }
        }
    }

    function sign(uint _poolId, bytes32 _description, bytes32 _data, bytes32 _txHash) external nonReentrant onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "Unauthorized relayer!");
        require (_description.length > 0 && _data.length > 0, "Signature can not be empty!");
        pools[_poolId].signature.description = _description;
        pools[_poolId].signature.data = _data;
        pools[_poolId].signature.txHash = _txHash;
    }
}