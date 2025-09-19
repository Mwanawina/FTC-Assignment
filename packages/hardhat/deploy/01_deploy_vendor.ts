import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";

const func: DeployFunction = async function (hre: HardhatRuntimeEnvironment) {
  const { deployments, getNamedAccounts } = hre;
  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();

  // Get the MemeCoin contract that was deployed in 00_deploy_meme_coin.ts
  const memeCoin = await deployments.get("MemeCoin");

  // Deploy Vendor with BOTH constructor args:
  // 1. MemeCoin address
  // 2. Owner (use deployer account)
  await deploy("Vendor", {
    from: deployer,
    args: [memeCoin.address, deployer],
    log: true,
  });
};

export default func;
func.tags = ["Vendor"];
