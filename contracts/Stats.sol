//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

contract Stats{
    mapping (uint => mapping (address =>uint[])) internal collectionDepositsByToken;  //collectionId => tokenAddress => deposit[]
    mapping (uint => mapping (address => uint256)) internal collectionSumByToken;     //collectionId => tokenAddress => poolSum
    mapping (uint => mapping (address => uint256)) internal depositSumByToken;        //collectionId => tokenAddress => depositSum
    mapping (uint => mapping (address => uint256)) internal feeSumByToken;            //collectionId => tokenAddress => feeSum

    constructor() {
        //rewardToken = ERC20(_rewardAddr);
    }
}