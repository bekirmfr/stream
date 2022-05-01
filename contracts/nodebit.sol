//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Nodebit is ERC20, Ownable {

    constructor() ERC20("Nodebit", "NBT") {
    }

    function  mint(address _to, uint256 _amount) public onlyOwner returns (bool){
        uint256 beforeBalance = balanceOf(_to);
        _mint(_to, _amount);
        require (balanceOf(_to) == beforeBalance + _amount, "Mint failed!");
        return true;
    }
} 