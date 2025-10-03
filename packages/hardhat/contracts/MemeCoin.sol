//Do not change the solidity version as it negatively impacts submission grading
pragma solidity ^0.7.0;
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Creating a simple ERC20 token contract for Meme Coin 
contract MemeCoin is ERC20, Ownable{

    uint8 constant _decimals = 18;

    event PoolCreated(address tk, address pool, uint160 sqrtPriceX96);

    // COMPLETED TODO: create a _totalSupply of 1000 tokens which have 18 decimal places
    // Total supply: 1000 tokens, adjusted for 18 decimals (so 1000 * 10^18 smallest units)
    uint256 private constant _totalSupply = 1000 * (10 ** uint256(_decimals));

    constructor() ERC20("Meme Coin", "MC") {
        // COMPLETED TODO: mint the _totalSupply of tokens to the owner
        // Mint the entire supply and give it to the deployer (msg.sender). This means the deployer starts with all the tokens
        _mint(msg.sender, _totalSupply);
    }
}
