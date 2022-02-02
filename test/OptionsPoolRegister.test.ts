import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { OptionsPoolRegistry } from "../typechain";

const { ethers, deployments } = hre;

describe("OptionsPoolRegistry", function () {
  this.timeout(0);
  let user: Signer;
  let registry: OptionsPoolRegistry;

  beforeEach(async () => {
    await deployments.fixture();
    [user] = await ethers.getSigners();

    registry = (await ethers.getContract(
      "OptionsPoolRegistry"
    )) as OptionsPoolRegistry;
  });

  it("#0: should revert when address is address zero", async function () {
    const userAddress = ethers.constants.AddressZero;
    await expect(
      registry.connect(user).registerLiquidity(userAddress, 10)
    ).to.be.revertedWith("!owner_");
  });

  it("#1: should store the data in the right key", async function () {
    const userAddress = await user.getAddress();
    await registry.connect(user).registerLiquidity(userAddress, 10);
    const liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(10);
  });
});
