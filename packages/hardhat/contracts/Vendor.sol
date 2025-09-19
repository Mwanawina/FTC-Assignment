//Do not change the solidity version as it negatively impacts submission grading
pragma solidity ^0.8.2; 
// SPDX-License-Identifier: MIT

import "./MemeCoin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// COMLETED TODO make the Vendor contract Ownable
// We are making Vendor inherit from Ownable so only the contract deployer can call withdraw... could be the contract deployer or assigned owner
contract Vendor is Ownable {
    event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);

    // NOTE: 1 ETH buys 100 tokens (100 * 10**18 in smallest units)
    uint256 public constant tokensPerEth = 100;

    MemeCoin public memeCoin;

    // COMLETED TODO edit the constructor to set the owner's address
    constructor(address tokenAddress, address owner) Ownable(owner) {
        memeCoin = MemeCoin(tokenAddress);
    }

    // COMLETED TODO create a payable buyTokens() function
    // buyTokens() is payable so it calculates based on ETH sent ad transfers tokens to the buyer
    function buyTokens() public payable {
        // COMLETED TODO check that the msg.value is set
        require(msg.value > 0, "Send ETH to buy tokens");

        // COMLETED TODO calculate the amount of tokens buyable
        uint256 tokensToBuy = msg.value * tokensPerEth;

        // COMLETED TODO check that vendor has enough tokens to sell to msg.sender
        uint256 vendorBalance = memeCoin.balanceOf(address(this));
        require(vendorBalance >= tokensToBuy, "Vendor has insufficient tokens");

        // COMLETED TODO transfer the tokens from the vendor to the msg.sender
        memeCoin.transfer(msg.sender, tokensToBuy);

        // COMLETED TODO emit a BuyTokens event
        emit BuyTokens(msg.sender, msg.value, tokensToBuy);
    }

    // COMLETED TODO create a withdraw() function that lets the owner withdraw ETH
    // Lets the owner take accumulated ETH
    function withdraw() public onlyOwner {
        uint256 vendorBalance = address(this).balance;

        // COMLETED TODO check that the owner has a balance to withdraw first
        require(vendorBalance > 0, "No ETH to withdraw");

        // COMLETED TODO withdraw the total amount to the owner
        (bool success, ) = owner().call{value: vendorBalance}("");
        require(success, "Withdraw failed");
    }

    // COMLETED TODO create a sellTokens(uint256 _amount) function:
    // sellTokens() checks balances, transfers tokens from the user, vendor then pays
    function sellTokens(uint256 _amount) public {
        // COMLETED TODO check that the requested tokens to sell > 0
        require(_amount > 0, "Specify an amount greater than 0");

        // COMLETED TODO check that the user has enough tokens to do the swap
        require(memeCoin.balanceOf(msg.sender) >= _amount, "Insufficient token balance");

        // COMLETED TODO calculate ETH amount to send
        uint256 ethAmount = _amount / tokensPerEth;

        // COMLETED TODO check that the vendor has enough ETH to pay for the tokens
        require(address(this).balance >= ethAmount, "Vendor has insufficient ETH");

        // COMLETED TODO transfer tokens to the vendor and check for success
        bool sent = memeCoin.transferFrom(msg.sender, address(this), _amount);
        require(sent, "Token transfer failed");

        // COMLETED TODO transfer ETH to the seller and check for success
        (bool success, ) = msg.sender.call{value: ethAmount}("");
        require(success, "ETH transfer failed");
    }
}
