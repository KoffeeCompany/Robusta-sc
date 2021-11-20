import { deployments, getNamedAccounts } from "hardhat";
import { HardhatRuntimeEnvironment } from "hardhat/types";
import { DeployFunction } from "hardhat-deploy/types";
import { getAddresses } from "../hardhat/addresses";
import { sleep } from "../src/utils";

const func: DeployFunction = async (hre: HardhatRuntimeEnvironment) => {
  if (hre.network.name === "mainnet" || hre.network.name === "goerli") {
    console.log(
      `Deploying Option to ${hre.network.name}. Hit ctrl + c to abort`
    );
    await sleep(10000);
  }

  const { deploy } = deployments;
  const { deployer } = await getNamedAccounts();
  const addresses = getAddresses(hre.network.name);
  await deploy("Option", {
    from: deployer,
    args: [
      addresses.Gelato,
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
    hre.network.name === "mainnet" || hre.network.name === "goerli";
  return shouldSkip ? true : false;
};
func.tags = ["Option"];
