//Do not change the solidity version as it negatively impacts submission grading
pragma solidity ^0.8.2; 
// SPDX-License-Identifier: MIT

import "./MemeCoin.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// COMLETED TODO make the Vendor contract Ownable
// We are making Vendor inherit from Ownable so only the contract deployer (owner) can call withdraw... could be the contract deployer or assigned owner
contract Vendor is Ownable {
    
    // This event is produced whenever someone buys tokens
    event BuyTokens(address buyer, uint256 amountOfETH, uint256 amountOfTokens);

    // NOTE: 1 ETH buys 100 tokens (100 * 10**18 in smallest units)
    uint256 public constant tokensPerEth = 100;

    // Refernce to the MemeCoin contract
    MemeCoin public memeCoin;

    // COMLETED TODO edit the constructor to set the owner's address
    // The Constructor takes the token address and the owner address, it sets the MemeCoin instance and assigns ownership
    constructor(address tokenAddress, address owner) Ownable(owner) {
        memeCoin = MemeCoin(tokenAddress);
    }

    // COMLETED TODO create a payable buyTokens() function
    // buyTokens() is payable so it calculates based on ETH sent ad transfers tokens to the buyer
    function buyTokens() public payable {
        // COMLETED TODO check that the msg.value is set
        // Ensures ETH is sent
        require(msg.value > 0, "Send ETH to buy tokens");

        // COMLETED TODO calculate the amount of tokens buyable
        // This is based on the ETH sent
        uint256 tokensToBuy = (msg.value * tokensPerEth) / 1 ether;

        // COMLETED TODO check that vendor has enough tokens to sell to msg.sender
        // Self-explanatory I'd say. We get the vendor's ETH balance & ensure there's enough ETH available to withdraw
        uint256 vendorBalance = memeCoin.balanceOf(address(this));
        require(vendorBalance >= tokensToBuy, "Vendor has insufficient tokens");

        // COMLETED TODO transfer the tokens from the vendor to the msg.sender
        // Again, self-explanatory. This steps transfers tokens from vendor to buyer
        memeCoin.transfer(msg.sender, tokensToBuy);

        // COMLETED TODO emit a BuyTokens event
        // This is like announcing this event happened on the blockchain
        emit BuyTokens(msg.sender, msg.value, tokensToBuy);
    }

    // COMLETED TODO create a withdraw() function that lets the owner withdraw ETH
    // Lets the owner take accumulated ETH. ETH is collected from token sales, which the owner can withdraw
    function withdraw() public onlyOwner {
        uint256 vendorBalance = address(this).balance;

        // COMLETED TODO check that the owner has a balance to withdraw first
        // Ensures there is ETH available to withdraw
        require(vendorBalance > 0, "No ETH to withdraw");  // Include message for when there isn't enough

        // COMLETED TODO withdraw the total amount to the owner
        // Transfer ETH to the owner
        (bool success, ) = owner().call{value: vendorBalance}("");
        require(success, "Withdraw failed");   // Included message to know it failed when it fails
    }

    // COMLETED TODO create a sellTokens(uint256 _amount) function:
    // sellTokens() checks balances, transfers tokens from the user, vendor then pays
    // This function allows user to sell tokens back to the vendor for ETH
    function sellTokens(uint256 _amount) public {
        // COMLETED TODO check that the requested tokens to sell > 0
        // Can't have a negative amount, so a check that it's greater than zero is needed
        require(_amount > 0, "Specify an amount greater than 0");

        // COMLETED TODO check that the user has enough tokens to do the swap
        // Need to ensure that the user, who's the seller, has enough tokens
        require(memeCoin.balanceOf(msg.sender) >= _amount, "Insufficient token balance");  // Once again, message for when there isn't enough

        // COMLETED TODO calculate ETH amount to send
        // If you sold _amount tokens, dividing by tokensPerEth gives the proportional ETH amount. It's reversing the buyTokens calculation 
        uint256 ethAmount = _amount / tokensPerEth;

        // COMLETED TODO check that the vendor has enough ETH to pay for the tokens
        // For the vendor to pay the seller, they need to have enough ETH
        require(address(this).balance >= ethAmount, "Vendor has insufficient ETH"); // The message thing is a consistent thing, good practice

        // COMLETED TODO transfer tokens to the vendor and check for success
        // Moves the seller’s tokens into the Vendor contract so that the Vendor receives what it is buying
        bool sent = memeCoin.transferFrom(msg.sender, address(this), _amount);
        
        // Makes sure the token transfer succeeded, otherwise the whole transaction is reverted
        require(sent, "Token transfer failed");

        // COMLETED TODO transfer ETH to the seller and check for success
        // sends the corresponding ETH payment back to the seller for the tokens just received
        (bool success, ) = msg.sender.call{value: ethAmount}("");

        // Makes sure the ETH payment succeeded, otherwise the transaction reverts and the token transfer is undone
        require(success, "ETH transfer failed");
    }
}
