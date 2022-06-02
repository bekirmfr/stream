//SPDX-License-Identifier: Unlicense
pragma solidity 0.8.7;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

contract StreamToken is ERC20, ERC20Burnable, Ownable {

    constructor() ERC20("Stream", "STREAM") {
    }

    function  mint(address to, uint256 amount) public onlyOwner{
        _mint(to, amount);
    }
} 