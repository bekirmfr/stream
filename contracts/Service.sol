//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "./Stream.sol";
import "./Stats.sol";

contract Service is Stream, Stats, Pausable{
    using Library for *;
    event DepositReceived(uint depositId, address from, address token, uint256 depositAmount, uint poolId);
    event PoolReady(uint32 poolId, address relayer);
    event PoolSigned(uint32 poolId, address relayer);

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    function buy(uint16 _collectionId, uint16 _shareAmount) external whenNotPaused{
        require (_shareAmount > 0, "Share amount must be greater than 0!");

        Collection storage c = collections[_collectionId];

        require(c.status, "Collection is not active!");
        if(c.maxPools > 0) require(this.getPoolCount(_collectionId) <= c.maxPools && pools[c.activePool].shareSum < c.totalShares, "Collection reached max pool count!");
        assert (pools[c.activePool].isDeployed == false);

        if(c.poolShareLimit > 0) require(poolSharesByEntity[c.activePool][msg.sender] <= c.poolShareLimit, "Reached max collection limit!"); //check if entity is sharelimited in the pool
        if(c.collectionShareLimit > 0) require (collectionSharesByEntity[c.id][msg.sender] <= c.collectionShareLimit, "Reached max pool limit!"); //check if entity is sharelimited in the collection

        if(c.isWhitelisted) require(whitelist[c.id][msg.sender] == true, "Only whitelisted addresses are allowed!");
        require(blacklist[c.id][msg.sender] != true, "Blacklisted addresses are not allowed!");
        require(this.getRemainingShares(_collectionId) > 0, "No shares left!");
        require(_shareAmount <= this.getRemainingShares(_collectionId), "Share amount can not exceed available shares!");

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
            bool shouldAddPool;
            if(c.maxPools > 0 && this.getPoolCount(_collectionId) < c.maxPools) {
                shouldAddPool = true;
            }else if(c.maxPools == 0){
                shouldAddPool = true;
            }
            if(shouldAddPool) {
                poolId++;
                pools[poolId].id = poolId;
                pools[poolId].collectionId = _collectionId;
                collections[_collectionId].activePool = poolId;
                poolsByCollection[_collectionId].push(poolId);
            }
        }
    }

    function redeem() external onlyRole(RELAYER_ROLE){
        
    }

    function sign(uint32 _poolId, bytes32 _description, bytes32 _data, bytes32 _txHash) external onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "Unauthorized relayer!");
        require (_description.length > 0 && _data.length > 0, "Signature can not be empty!");
        pools[_poolId].signature= Signature (_description, _data, _txHash);
        pools[_poolId].isDeployed = true;
        emit PoolSigned(_poolId, msg.sender);
    }
}