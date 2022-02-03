import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { OptionsPoolRegistry } from "../typechain";

const { ethers, deployments } = hre;

describe("OptionsPoolRegistry", function () {
  this.timeout(0);
  let user: Signer;
  let user2: Signer;
  let registry: OptionsPoolRegistry;

  beforeEach(async () => {
    await deployments.fixture();
    [user, user2] = await ethers.getSigners();

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

  it("#1: should registry liquidity in the right key", async function () {
    const userAddress = await user.getAddress();
    await registry.connect(user).registerLiquidity(userAddress, 10);
    const liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(10);
  });

  it("#2: should increase the liquidity when call registerLiquidity", async function () {
    const userAddress = await user.getAddress();
    const userAddress2 = await user2.getAddress();
    await registry.connect(user).registerLiquidity(userAddress, 10);
    let liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(10);

    await registry.connect(user).registerLiquidity(userAddress2, 30);
    const liquidityUser2 = await registry.providers(userAddress2);
    expect(liquidityUser2).to.equal(30);

    await registry.connect(user).registerLiquidity(userAddress, 50);
    liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(60);
  });

  it("#3: should descrease the liquidity when call revokeLiquidity", async function () {
    const userAddress = await user.getAddress();
    await registry.connect(user).registerLiquidity(userAddress, 70);
    let liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(70);

    await registry.connect(user).revokeLiquidity(userAddress, 50);
    liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(20);
  });

  it("#4: should revert when share to revoke is greater than stored", async function () {
    const userAddress = await user.getAddress();
    await registry.connect(user).registerLiquidity(userAddress, 70);
    const liquidity = await registry.providers(userAddress);
    expect(liquidity).to.equal(70);

    await expect(
      registry.connect(user).revokeLiquidity(userAddress, 80)
    ).to.be.revertedWith("share to revoke is greater than stored");
  });

  it("#5: should registry option in the right key", async function () {
    const userAddress = await user.getAddress();
    const optionAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    await registry.connect(user).registerOption(userAddress, optionAddress);
    const isSaved = await registry.options(userAddress, optionAddress);
    expect(isSaved).to.be.true;
  });

  it("#6: should revert when address is zero", async function () {
    let userAddress = ethers.constants.AddressZero;
    let optionAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    await expect(
      registry.connect(user).registerOption(userAddress, optionAddress)
    ).to.be.revertedWith("!owner_");

    userAddress = await user.getAddress();
    optionAddress = ethers.constants.AddressZero;
    await expect(
      registry.connect(user).registerOption(userAddress, optionAddress)
    ).to.be.revertedWith("!option_");
  });

  it("#3: should delete the option when call revokeOption", async function () {
    const userAddress = await user.getAddress();
    const optionAddress = "0xdAC17F958D2ee523a2206206994597C13D831ec7";
    await registry.connect(user).registerOption(userAddress, optionAddress);
    let isSaved = await registry.options(userAddress, optionAddress);
    expect(isSaved).to.be.true;

    await registry.connect(user).revokeOption(userAddress, optionAddress);
    isSaved = await registry.options(userAddress, optionAddress);
    expect(isSaved).to.be.false;
  });
});
