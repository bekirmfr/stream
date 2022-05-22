//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract tStrongBlock {
    address tStronger;

    struct Node{
        uint256 id;
        uint256 claimedBlockNumber;
        uint256 paidBlockNumber;
    }

    event Paid (address entity, uint256 nodeId, bool isBYON, bool isRenewal, uint256 upToBlockNumber);
    event Claimed (address miner, uint256 reward);

    mapping(address => Node[]) nodesByEntity;

    constructor(address _tStronger) {
        tStronger = _tStronger;
    }

      function requestAccess(bool isNaaS) payable public{
         require  (msg.value == naasRequestingFeeInWei(), "Insufficient fee!");
         uint256 allowance = ERC20(tStronger).allowance(msg.sender, address(this));
        require(allowance >= strongFeeInWei(), "Insufficient allowance!");
         if (isNaaS){
            uint256 nodeId = nodesByEntity[msg.sender].length + 1;
            nodesByEntity[msg.sender].push(Node(nodeId, block.number, block.number));
            emit Paid (msg.sender, nodeId, false, false, block.number);
            IERC20(tStronger).transferFrom(msg.sender, address(this), strongFeeInWei());
            //Transfer 10 STRNGR to Fee Collector
         }
    }

    function payFee(uint128 nodeId) payable public{
        require (msg.value == recurringNaaSFeeInWei(), "Insufficient fee!");
        nodesByEntity[msg.sender][nodeId - 1].paidBlockNumber = block.number;
        emit Paid (msg.sender, nodeId, false, true, block.number);
    }

    function payAll(uint256 nodeCount) payable public{
        require (msg.value == recurringNaaSFeeInWei() * nodeCount, "Insufficient fee!");
        for(uint128 i = 1; i < nodeCount; i++){
            nodesByEntity[msg.sender][i - 1].paidBlockNumber = block.number;
            emit Paid (msg.sender, i, false, true, block.number);  
        }
    }

    function claim(uint128 nodeId, uint256 blockNumber, bool toStrongPool) payable public{
        uint256 reward = (blockNumber -  nodesByEntity[msg.sender][nodeId - 1].claimedBlockNumber)/7/10;
        require (msg.value == reward * claimingFeeNumerator() / claimingFeeDenominator(), "Insufficient fee!");
        nodesByEntity[msg.sender][nodeId-1].claimedBlockNumber = blockNumber;
        emit Claimed (msg.sender, reward);
    }

    function claimAll(uint256 blockNumber, bool toStrongPool) payable public{
        uint256 nodeCount = nodesByEntity[msg.sender].length;
        uint256 total = 0;
        for(uint256 i = 0; i < nodeCount; i++){
            uint256 reward = (blockNumber -  nodesByEntity[msg.sender][i].claimedBlockNumber)/7/10;
            total += reward;
            nodesByEntity[msg.sender][i].claimedBlockNumber = blockNumber;
            emit Claimed (msg.sender, reward);
        }
        require (msg.value == total * claimingFeeNumerator() / claimingFeeDenominator(), "Insufficient fee!");
    }

    function naasRequestingFeeInWei() public view returns(uint256){
        return 4746031746031750;
    }
    function recurringNaaSFeeInWei() public view returns(uint256){
        return 4746031746031750;
    }
    function claimingFeeNumerator() public view returns(uint256){
        return 527355479;
    }
    function claimingFeeDenominator() public view returns(uint256){
        return 1000000000000;
    }
    function strongFeeInWei() public view returns(uint256){
        return 10000000000000000000;
    }
}