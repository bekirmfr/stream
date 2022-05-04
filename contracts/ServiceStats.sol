//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./ServiceLibrary.sol";
import "./Service.sol";

contract ServiceStats is Ownable{
    mapping (uint => mapping (address => uint)) public collectionSharesByEntity;   //collectionId => entity => shares
    mapping (uint => mapping (address => uint)) public poolSharesByEntity;   //collectionId => poolId => entity => shares

    mapping (uint => mapping (address => bool)) public whitelist;
    mapping (uint => mapping (address => bool)) public blacklist;

    mapping (uint => mapping (address =>uint[])) public collectionDepositsByToken;  //collectionId => tokenAddress => deposit[]
    mapping (uint => mapping (address => uint256)) public collectionSumByToken;     //collectionId => tokenAddress => poolSum
    mapping (uint => mapping (address => uint256)) public depositSumByToken;        //collectionId => tokenAddress => depositSum
    mapping (uint => mapping (address => uint256)) public feeSumByToken;            //collectionId => tokenAddress => feeSum

    constructor(){
    }
    function addCollectionDepositsByToken(uint _collectionId, address _token, uint256 _depositId) public onlyOwner{
        collectionDepositsByToken[_collectionId][_token].push(_depositId);
    }
    function addCollectionSumByToken(uint _collectionId, address _token, uint256 _amount) public onlyOwner{
        collectionSumByToken[_collectionId][_token] += _amount;
    }
    function addDepositSumByToken(uint _collectionId, address _token, uint256 _amount) public onlyOwner{
        depositSumByToken[_collectionId][_token] += _amount;
    }
    function addFeeSumByToken(uint _collectionId, address _token, uint256 _amount) public onlyOwner{
        feeSumByToken[_collectionId][_token] += _amount;
    }
    function addCollectionSharesByEntity(uint _collectionId, address _entity, uint256 _amount) public onlyOwner{
        collectionSharesByEntity[_collectionId][_entity] += _amount;
    }
    function addPoolSharesByEntity(uint _poolId, address _entity, uint256 _amount) public onlyOwner{
        poolSharesByEntity[_poolId][_entity] += _amount;
    }
}