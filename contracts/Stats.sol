//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Stats{
    mapping (uint => mapping (address =>uint[])) public collectionDepositsByToken;  //collectionId => tokenAddress => deposit[]
    mapping (uint => mapping (address => uint256)) public collectionSumByToken;     //collectionId => tokenAddress => poolSum
    mapping (uint => mapping (address => uint256)) public depositSumByToken;        //collectionId => tokenAddress => depositSum
    mapping (uint => mapping (address => uint256)) public feeSumByToken;            //collectionId => tokenAddress => feeSum

    constructor() {
        //rewardToken = ERC20(_rewardAddr);
    }
}