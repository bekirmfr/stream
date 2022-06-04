//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Stream.sol";

contract Service is Stream {
    using Library for *;
    event DepositReceived(uint depositId, address from, address token, uint256 depositAmount, uint poolId);
    event PoolReady(uint32 poolId, address relayer);
    event PoolSigned(uint32 poolId, address relayer);
    event BuyShare(address buyer, uint16 shareAmount, uint32 poolId);
    event CancelBuy(uint32 poolId, address entity);

    constructor(){
        _grantRole(DEFAULT_ADMIN_ROLE, address(this));
    }

    function buy(uint16 _collectionId, uint16 _shareAmount) external {
        require (_shareAmount > 0, "AGTZ");

        Collection storage c = collections[_collectionId];

        require(c.status, "CNA");
        if(c.maxPools > 0) require(this.getPoolCount(_collectionId) < c.maxPools, "RMPC");

        if(c.poolShareLimit > 0) require(poolSharesByEntity[c.activePool][msg.sender] <= c.poolShareLimit, "RMCL"); //check if entity is sharelimited in the pool
        if(c.collectionShareLimit > 0) require (collectionSharesByEntity[c.id][msg.sender] <= c.collectionShareLimit, "PMPL"); //check if entity is sharelimited in the collection

        if(c.isWhitelisted) require(whitelist[c.id][msg.sender] == true, "OWA");
        require(blacklist[c.id][msg.sender] != true, "BNA");
        require(this.getRemainingShares(_collectionId) > 0, "NSL");
        require(_shareAmount <= this.getRemainingShares(_collectionId), "ATH");

        for(uint t = 0; t < costPairsByCollection[c.id].length; t++){
            Pair storage costPair = costPairsByCollection[c.id][t];

            uint256 netAmount = costPair.amount * _shareAmount / c.totalShares;
            uint256 feeAmount = netAmount.calculateFee(c.feeNumerator, c.feeDenominator);
            uint256 depositAmount = netAmount + feeAmount;

            require(IERC20(costPair.token).transferFrom(msg.sender, address(this), depositAmount), "TTF");

            deposits[++depositId] = Deposit(msg.sender, c.id, c.activePool, costPair.token, depositAmount, _shareAmount);
            poolDeposits[c.activePool].push(depositId);
            emit DepositReceived(depositId, msg.sender, costPair.token, depositAmount, c.activePool);
        }
        pools[c.activePool].shareSum += _shareAmount;

        collectionSharesByEntity[c.id][msg.sender] += _shareAmount;
        poolSharesByEntity[c.activePool][msg.sender] += _shareAmount;
        emit BuyShare(msg.sender, _shareAmount, c.activePool);

        if(pools[c.activePool].shareSum >= c.totalShares){
            emit PoolReady(c.activePool, c.relayer);
            poolsByCollection[_collectionId].push(c.activePool);
            c.activePool = 0;
            if((c.maxPools > 0 && this.getPoolCount(_collectionId) < c.maxPools) || c.maxPools == 0) this.addPool(_collectionId);
        }
    }

    function cancelBuy(uint32 _collectionId) external{
        Collection storage c = collections[_collectionId];
        uint poolShares = poolSharesByEntity[c.activePool][msg.sender];
        require(poolShares > 0, "Entity has no shares in this pool!" );
        uint depositDuration = block.timestamp - pools[c.activePool].timestamp;
        require(depositDuration > c.minDepositDuration, "Pending minimum deposit duration!"); //That minimum deposit time has expired
        require(pools[c.activePool].shareSum < c.totalShares, "Pool is ready!"); //That pool is not ready
        for(uint t = 0; t < costPairsByCollection[c.id].length; t++){
            Pair storage costPair = costPairsByCollection[c.id][t];
            uint cancelAmount = costPair.amount * poolShares / c.totalShares;
            require(ERC20(costPair.token).increaseAllowance(msg.sender, cancelAmount), "Increase allowance failed!");
        }
        delete poolSharesByEntity[c.activePool][msg.sender];
        pools[c.activePool].shareSum -= uint16(poolShares);
        emit CancelBuy(c.activePool, msg.sender);
    }

    function sign(uint32 _poolId, bytes32 _description, bytes32 _data, bytes32 _txHash) external onlyRole(RELAYER_ROLE){
        require (msg.sender == collections[pools[_poolId].collectionId].relayer, "UAR");
        require (_description.length > 0 && _data.length > 0, "SNE");
        pools[_poolId].signature = Signature (_description, _data, _txHash);
        pools[_poolId].isDeployed = true;
        emit PoolSigned(_poolId, msg.sender);
    }
}