import { deployments, ethers, getNamedAccounts } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getAddresses } from "../hardhat/addresses";
import { sleep } from "../src/utils";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name === "matic" || hre.network.name === "mumbai") {
    console.log(
      `Deploying AaveStrategy to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await sleep(10000);
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const addresses = getAddresses("hardhat");
  await deploy("Option", {
    from: deployer,
    args: [
      addresses.NonfungiblePositionManager,
      addresses.PokeMe,
      addresses.WETH,
    ],
    log: hre.network.name != "hardhat" ? true : false,
  });
};

export default func;

func.skip = async (hre: HardhatRuntimeEnvironment) => {
  const shouldSkip =
    hre.network.name === "matic" || hre.network.name === "mumbai";
  return shouldSkip ? true : false;
};
func.tags = ["Options"];
