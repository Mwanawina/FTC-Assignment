//Do not change the solidity version as it negatively impacts submission grading
pragma solidity ^0.8.2; 
// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./Vendor.sol";

contract MemeCoin is ERC20, Ownable {

    uint8 constant _decimals = 18; 
    Vendor public vendor;
    address public vendorAddress;

    // COMLETED TODO create a _totalSupply of 1000 tokens which has 18 decimal places
    // By convention, ERC20 tokens use 18 decimals so this is the proper supply
    uint256 private constant _totalSupply = 1000 * (10 ** uint256(_decimals));

    constructor(address owner) ERC20("Meme Coin", "MC") Ownable(owner) {
        // COMLETED TODO create a vendor smart contract. This contract will be responsible for buying and selling your token in ETH
        // The Vendor contract is deployed from inside the constructor causes contacts can deploy other contracts
        vendor = new Vendor(address(this), owner);

        // COMLETED TODO assign the vendorAddress
        vendorAddress = address(vendor);

        // COMLETED TODO mint the _totalSupply of tokens to the vendor address
        // Minting to the vendor ensures it holds the initial supply to sell to users
        _mint(vendorAddress, _totalSupply);
    }
}
