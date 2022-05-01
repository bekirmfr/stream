//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract RewardToken is ERC20, Ownable {

    constructor() ERC20("Reward Token", "rSTRNGR") {
    }

    function  mint(address _to, uint256 _amount) public onlyOwner returns(bool){
        uint256 beforeBalance = balanceOf(_to);
        _mint(_to, _amount * 10**decimals());
        require (balanceOf(_to) == beforeBalance + _amount);
        return true;
    }
} 