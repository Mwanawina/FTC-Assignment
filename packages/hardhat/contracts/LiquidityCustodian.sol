// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.7.0;
pragma abicoder v2;

import '@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol';
import '@uniswap/v3-core/contracts/interfaces/IUniswapV3Pool.sol';
import '@uniswap/v3-core/contracts/libraries/TickMath.sol';
import '@uniswap/v3-periphery/contracts/interfaces/ISwapRouter.sol';
import '@uniswap/v3-periphery/contracts/interfaces/INonfungiblePositionManager.sol';
import '@uniswap/v3-periphery/contracts/libraries/TransferHelper.sol';
import '@uniswap/v3-periphery/contracts/base/LiquidityManagement.sol';

import "hardhat/console.sol";

// This contract will act like a custodian for Uniswap liquidity NFTs.

// COMPLETED TODO: Make this contract a IERC721Receiver
// The contract must be able to receive Uniswap V3 Position NFTS which are the ERC721 tokens
contract LiquidityCustodian {
    address public immutable token;
    address public immutable weth;
    address public liquidityPoolAddress;

    int24 private _poolTick;
    uint24 private constant _dexPoolFee = 10_000; // 1%

    INonfungiblePositionManager public immutable uniswapPositionManager;
    IUniswapV3Factory public immutable uniswapV3Factory;

    event PoolCreated(address tk, address pool, uint160 sqrtPriceX96);

    /// @notice Represents the deposit of an NFT
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    /// @dev liquidityTokens[address] => uint256[]
    mapping(address => uint256[]) public liquidityTokens;

    constructor(
        address _uniswapV3Factory, 
        address _uniswapPositionManager,
        address _token,
        address _weth
    ) {
        uniswapV3Factory = IUniswapV3Factory(_uniswapV3Factory);
        uniswapPositionManager = INonfungiblePositionManager(_uniswapPositionManager);

        token = _token;
        weth = _weth;
    }

    /// @notice Creates and initializes a WETH/TOKEN liquidity pool
    function createPool() public {
        // COMPLETED TODO: assign WETH and MC addresses to new variables token0_ and token1_ addresses
        // NOTE: for a uniswap pool token0 address should be strictly less than token1
        // token0 and token1 must be given in dictionary order (alphabetical by address) becuase this is required by Uniswap
        (address token0_, address token1_) = token < weth ? (token, weth) : (weth, token);

        // COMPLETED TODO: create a liquidity pool of WETH and MC token using uniswap factory
        // Actually create the pool using Uniswap's factory
        address liquidityPoolAddress_ = uniswapV3Factory.createPool(token0_, token1_, _dexPoolFee);

        // COMPLETED TODO: assign the liquidityPoolAddress
        // The pool address created needs to be stored for future use
        liquidityPoolAddress = liquidityPoolAddress_;

        // COMPLETED TODO: get the square of the price using at the _poolTick TickMath library from Uniswap
        // NOTE: sqrtPriceX96 is a A Fixed point Q64.96 number representing the sqrt of the ratio of the two assets (token1/token0)
        // Figure out the starting price in Uniswap’s math system (sqrt ratio format)
        uint160 sqrtPriceX96 = TickMath.getSqrtRatioAtTick(_poolTick);

        // COMPLETED TODO: initialize the pool with the sqrtPriceX96
        // With the starting sqrtPrice, initialise the new pool
        IUniswapV3Pool(liquidityPoolAddress_).initialize(sqrtPriceX96);

        // COMPLETED TODO: emit the PoolCreate event
        // Let the world know a pool was created
        emit PoolCreated(token, liquidityPoolAddress_, sqrtPriceX96);
    }

    // COMPLETED TODO: create the onERC721Received function. It will create a deposit in the custodian contract
    // NOTE: the function should create an NFT deposit for the sender of NFT to this smart contract
    // Triggered when someone sends this contract a liquidity NFT (ERC721)
    // saves details about the NFT for bookkeeping
    function onERC721Received(
        address operator,
        address from,
        uint256 tokenId,
        bytes calldata data
    ) external returns (bytes4) {
        _createDeposit(from, tokenId);
        return this.onERC721Received.selector;
    } 
    // We had .... external override returns (bytes4) .... above there initially   

    /// @notice Stores the details of the deposited liquidity position's NFT
    /// @param owner The address of the liquidity position owner
    /// @param tokenId Id of the ERC721 token minted to represent ownership of the liquidity position
    
    // An internal helper that stores info about a newly receibed liquidity NFT
    function _createDeposit(address owner, uint256 tokenId) internal {
        // COMPLETED TODO: get the details of the liquidity position from the uniswap NFT manager
        // Ask Uniswap's position manager for details about the NFT
        // All the commas and empty spaces mean "ignore this return value". The ones listed are the ones we need, Solidity won't let us skip without a comma
        (
            , 
            , 
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = uniswapPositionManager.positions(tokenId);

        // COMPLETED TODO: create Deposit object using the detail above and store it in the deposits mapping
        // NOTE: the owner of the deposit is whoever has created the liquidity position through this contract or elsewhere and sent this contract their NFT
        // Save the details under this tokenId
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });

        // COMPLETED TODO: store the tokenId in the owners' token array that is in the liquidityTokens mapping
        // Add the tokenId to the owner's list
        liquidityTokens[owner].push(tokenId);
    }

    /// @notice Takes in an address and index as parameters and returns a tokenId.
    /// @param owner The address of the liquidity position owner
    /// @param index The index of the tokenId to be returned if the owner has more than 1 liquidity positions
    /// @return uint256 TokenId that represents the liquidity position owned by the address
    
    // Lets us look up one of our NFTs by index if we have multiple
    function liquidityTokenByIndex(address owner, uint256 index) public view virtual returns (uint256) {
        require(liquidityTokens[owner].length > 0, "The address has no liquidity tokens");
        
        uint256[] memory _liquidityTokens = liquidityTokens[owner];

        require(index < _liquidityTokens.length, "The index is out of bounds");

        return _liquidityTokens[index];
    }

    /// @notice Calls the mint function defined in periphery, mints amounts of tokens passed in the parameters
    /// Providing liquidity in both assets means liquidity will be earning fees and is considered in-range.
    /// @return tokenId The id of the newly minted ERC721
    /// @return liquidity The amount of liquidity for the position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mintNewPosition(uint256 tokenAmountToMint, uint256 wethAmountToMint)
        external
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        )
    {
        (address token0_, address token1_) = token < weth ? (token, weth) : (weth, token);
        (uint256 amount0ToMint, uint256 amount1ToMint) = token < weth ? (tokenAmountToMint, wethAmountToMint) : (wethAmountToMint, tokenAmountToMint);

        // COMPLETED TODO: transfer the token0, amount0ToMint, from the msg.sender to this contract
        // Move user's tokens into this contract
        TransferHelper.safeTransferFrom(token0_, msg.sender, address(this), amount0ToMint);

        // COMPLETED TODO: transfer the token1, amount1ToMint, from the msg.sender to this contract
        // Same thing, move user's tokens into this contract
        TransferHelper.safeTransferFrom(token1_, msg.sender, address(this), amount1ToMint);

        // COMPLETED TODO: approve the uniswap position manager to transfer amount0ToMint of token0
        // Approve Uniswap's position manager to use them
        TransferHelper.safeApprove(token0_, address(uniswapPositionManager), amount0ToMint);
        
        // COMPLETED TODO: approve the uniswap position manager to transfer amount1ToMint of token1
        // Same thing, approve Uniswap's position manager to use them
        TransferHelper.safeApprove(token1_, address(uniswapPositionManager), amount1ToMint);

        // Here, the parameters for miniting the position are set 
        INonfungiblePositionManager.MintParams memory params =
            INonfungiblePositionManager.MintParams({
                token0: token0_,
                token1: token1_,
                fee: _dexPoolFee,
                tickLower: -887200, 
                tickUpper: 887200,
                amount0Desired: amount0ToMint,
                amount1Desired: amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        // COMPLETED TODO: mint the liquidity position in the uniswap position manager using the params above
        // NOTE: this returns the tokenId of the minted NFT that represents the liquidity position
        // Mint the NFT (returns its ID, liquidity amount, and actual token usage)
        (tokenId, liquidity, amount0, amount1) = uniswapPositionManager.mint(params);

        // COMPLETED TODO: create the deposit record for the minter/msg.sender
        // Record this NFT as belonging to the user
        _createDeposit(msg.sender, tokenId);

        // Remove allowance and refund in both assets
        // If Uniswap didn’t need all of the user’s tokens, refund the leftovers
        if (amount0 < amount0ToMint) {
            TransferHelper.safeApprove(token0_, address(uniswapPositionManager), 0);
            uint256 refund0 = amount0ToMint - amount0;
            TransferHelper.safeTransfer(token0_, msg.sender, refund0);
        }

        if (amount1 < amount1ToMint) {
            TransferHelper.safeApprove(token1_, address(uniswapPositionManager), 0);
            uint256 refund1 = amount1ToMint - amount1;
            TransferHelper.safeTransfer(token1_, msg.sender, refund1);
        }
    }

    /// @notice Transfers the NFT to the owner
    /// @param tokenId The id of the erc721
    function retrieveNFT(uint256 tokenId) external {
        // must be the owner of the NFT
        require(msg.sender == deposits[tokenId].owner, 'Not the owner');
        // transfer ownership to original owner
        uniswapPositionManager.safeTransferFrom(address(this), msg.sender, tokenId);
        //remove information related to tokenId
        delete deposits[tokenId];
        _deleteLiquidityToken(msg.sender, tokenId);
    }

    // COMPLETED TODO: complete the functions _deleteLiquidityToken
    // Internal helper to remove a tokenId from the owner’s list
    function _deleteLiquidityToken(address ownerAddress, uint256 tokenId) private {
        uint256[] storage tokens = liquidityTokens[ownerAddress];
        for (uint256 i = 0; i < tokens.length; i++) {
            if (tokens[i] == tokenId) {
                tokens[i] = tokens[tokens.length - 1];
                tokens.pop();
                break;
            }
        }
    }
}

