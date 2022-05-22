//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;

struct Deposit{
    address entity;
    uint16 collectionId;
    uint32 poolId;
    address token;
    uint256 amount;
    uint16 shares;
}

struct Pair{
    address token;
    uint256 amount;
}

struct Signature{
    bytes32 description;
    bytes32 data;
    bytes32 txHash;
}

struct Pool{
    uint32 id;
    uint32 collectionId;
    uint16 shareSum;
    bool isDeployed;            //Set by the relayer when the pool is processed.
    Signature signature;
}

struct Collection{
    uint16 id;
    bytes32 name;
    address relayer;            //An address that will process deposits. This can be an automated relayer or multi-sig address.
    uint32 activePool;
    uint16 totalShares;           //Total number of shares the cost(s) is divided into.
    uint16 collectionShareLimit;    //Max shares an entity can buy in the entire Collection. 0 means unlimited.
    uint16 poolShareLimit;          //Max shares an entity can buy in one pool. 0 means unlimited.
    bool isWhitelisted;         //If true only whitelisted addresses can buy.
    bool status;                //0 => inactive, 1 => active.
    uint256 feeNumerator;
    uint32 feeDenominator;
    uint16 maxPools;          //Number of pools this collection can have. 0 means unlimited.
}

library Library {
    uint8 public constant ICI = 1; //Invalid collection id
    function calculateFee(uint256 self, uint _feeNumerator, uint _feeDenominator) internal pure returns (uint256) {
        uint256 result = 0;
        if(_feeDenominator > 0){
            result = self * _feeNumerator;
            result /= _feeDenominator;
        }else{
            result = _feeNumerator;
        }
        return result;
    }
    function stringToBytes32(string memory self) public pure returns (bytes32 result) {
        bytes memory tempEmptyStringTest = bytes(self);
        if (tempEmptyStringTest.length == 0) {
            return 0x0;
        }

        assembly {
            result := mload(add(self, 32))
        }
    }
    function bytes32ToString(bytes32 self) public pure returns (string memory) {
    bytes memory bytesArray = new bytes(32);
    for (uint256 i; i < 32; i++) {
        bytesArray[i] = self[i];
        }
    return string(bytesArray);
    }
}