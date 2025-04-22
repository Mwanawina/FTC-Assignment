//
// this script executes when you run 'yarn harhat:test'
//

import hre from "hardhat";
import { expect } from "chai";
import {
  LiquidityCustodian,
  IERC20,
  IWETH9,
  IUniswapV3Pool,
  INonfungiblePositionManager,
  ISwapRouter,
} from "../typechain-types";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { EventLog } from "ethers";

const { ethers } = hre;

describe("🚩 Uniswap Dex: 🏵 Liquidity Custodian 🤖", function () {
  // TODO: insert the factoryAddress
  const factoryAddress = "";

  let swapRouter: ISwapRouter;
  // TODO: insert the swapRouterAddress
  const swapRouterAddress = "";

  // TODO: insert the positionManagerAddress
  let positionManager: INonfungiblePositionManager;
  const positionManagerAddress = "";

  let WETHToken: IWETH9;
  // TODO: insert the WETHTokenAddress
  const WETHTokenAddress = "";

  let liquidityPoolAddress: string;
  let liquidityPool: IUniswapV3Pool;

  let MCToken: IERC20;
  let MCTokenAddress = "";

  let liquidityCustodian: LiquidityCustodian;
  let liquidityCustodianAddress = "";

  let owner: HardhatEthersSigner;
  let user1: HardhatEthersSigner;
  let user2: HardhatEthersSigner;
  let user3: HardhatEthersSigner;

  before(async () => {
    // Get the Signers object from ethers
    [owner, user1, user2, user3] = await ethers.getSigners();

    WETHToken = (await ethers.getContractAtWithSignerAddress(
      "IWETH9",
      WETHTokenAddress,
      owner.address,
    )) as unknown as IWETH9;

    positionManager = (await ethers.getContractAtWithSignerAddress(
      "INonfungiblePositionManager",
      positionManagerAddress,
      owner.address,
    )) as unknown as INonfungiblePositionManager;

    swapRouter = (await ethers.getContractAtWithSignerAddress(
      "ISwapRouter",
      swapRouterAddress,
      owner.address,
    )) as unknown as ISwapRouter;
  });

  it("Should deploy MemeCoin", async function () {
    const MemeCoinFactory = await ethers.getContractFactory("MemeCoin");

    MCToken = (await MemeCoinFactory.deploy()) as IERC20;
    MCTokenAddress = await MCToken.getAddress();
  });

  it("Should deploy LiquidityCustodian", async function () {
    const LiquidityCustodianFactory = await ethers.getContractFactory("LiquidityCustodian");

    liquidityCustodian = (await LiquidityCustodianFactory.deploy(
      factoryAddress,
      positionManagerAddress,
      MCTokenAddress,
      WETHTokenAddress,
    )) as LiquidityCustodian;

    await liquidityCustodian.waitForDeployment();
    liquidityCustodianAddress = await liquidityCustodian.getAddress();
  });

  it("Should set Liquidity Pool", async function () {
    const txn = await liquidityCustodian.connect(owner).createPool();

    // Wait for transaction to be mined
    const receipt = await txn.wait();

    // Unlike view functions, transactions do not return values directly.
    // This is because they need to be mined on the blockchain first
    // Instead we'll retrieve the event emitted by the transaction
    const poolEventLog = receipt!.logs.find(l => {
      const eventLog = l as EventLog;
      return eventLog.fragment && eventLog.fragment.name === "PoolCreated";
    }) as EventLog;
    const iface = new ethers.Interface(["event PoolCreated(address tk, address pool, uint160 sqrtPriceX96)"]);
    const decodedLog = iface.decodeEventLog("PoolCreated", poolEventLog.data, poolEventLog.topics);

    liquidityPoolAddress = decodedLog.pool as string;
    liquidityPool = (await ethers.getContractAtWithSignerAddress(
      "IUniswapV3Pool",
      liquidityPoolAddress,
      owner.address,
    )) as unknown as IUniswapV3Pool;
  });

  it("Should mint Liquidity", async function () {
    const depositWethTxn = await WETHToken.connect(owner).deposit({ value: ethers.parseUnits("1000", "ether") });
    console.log("\t", "Deposit WETH for owner result", depositWethTxn.hash);

    console.log("\t", "Waiting for deposit confirmation...");
    const depositWethTxResult = await depositWethTxn.wait();
    expect(depositWethTxResult?.status).to.equal(1, "Error when expecting the deposit transaction result to be 1");

    const tokenAmount = await MCToken.connect(owner).balanceOf(owner.address);
    expect(tokenAmount).to.equal(ethers.parseUnits("1000", "ether"));
    console.log("\t", `Owner has ${tokenAmount} MC tokens`);

    const wethAmount = await WETHToken.connect(owner).balanceOf(owner.address);
    expect(wethAmount).to.greaterThanOrEqual(ethers.parseUnits("1000", "ether"));
    // NOTE: Because we are running the test on the local network, the WETH will keep increasing
    console.log("\t", `Owner has ${wethAmount} WETH tokens`);

    // approve weth
    const approveWETHTxn = await WETHToken.connect(owner).approve(
      liquidityCustodianAddress,
      ethers.parseUnits("1000", "ether"),
    );
    console.log("\t", "Approve liquidity custodian for 10 WETH tokens", depositWethTxn.hash);

    console.log("\t", "Waiting for approval confirmation...");
    const approveWETHTxResult = await approveWETHTxn.wait();
    expect(approveWETHTxResult?.status).to.equal(1, "Error when expecting the approval transaction result to be 1");

    // approve mc
    const approveMCTxn = await MCToken.connect(owner).approve(
      liquidityCustodianAddress,
      ethers.parseUnits("1000", "ether"),
    );
    console.log("\t", "Approve liquidity custodian for 1000 MC tokens", approveMCTxn.hash);

    console.log("\t", "Waiting for approval confirmation...");
    const approveMCTxResult = await approveMCTxn.wait();
    expect(approveMCTxResult?.status).to.equal(1, "Error when expecting the approval transaction result to be 1");

    // mint liquidity position
    console.log("\t", "Minting liquidity position...");
    const mintPositionTxn = await liquidityCustodian
      .connect(owner)
      .mintNewPosition(ethers.parseUnits("1000", "ether"), ethers.parseUnits("1000", "ether"));

    console.log("\t", "Waiting for minting confirmation...");
    const mintPositionTxnResult = await mintPositionTxn.wait();
    expect(mintPositionTxnResult?.status).to.equal(1, "Error when expecting the minting transaction result to be 1");

    // check that a liquidityToken has been minted
    console.log("\t", "Getting liquidity tokenId...");
    const tokenId = await liquidityCustodian.liquidityTokenByIndex(owner.address, 0);
    console.log("\t", `Liquidity tokenId: ${tokenId}`);

    // get the details of the position represented by the token from the uniswap V3 non fungible position manager
    const position = await positionManager.connect(owner).positions(tokenId);

    expect(position.token0).to.equal(WETHTokenAddress < MCTokenAddress ? WETHTokenAddress : MCTokenAddress);
    expect(position.token1).to.equal(WETHTokenAddress < MCTokenAddress ? MCTokenAddress : WETHTokenAddress);
    expect(position.fee).to.equal(10000);
  });
});
