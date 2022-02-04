import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { OptionsPoolManager } from "../typechain";

const { ethers, deployments } = hre;

describe("OptionsPoolManager", function () {
  this.timeout(0);
  let user: Signer;
  let manager: OptionsPoolManager;

  beforeEach(async () => {
    await deployments.fixture();
    [user] = await ethers.getSigners();

    manager = (await ethers.getContract(
      "OptionsPoolManager"
    )) as OptionsPoolManager;
  });

  it("#0: should initialized in the creation", async function () {
    const instantWithdrawalFee = await manager
      .connect(user)
      .instantWithdrawalFee();
    expect(ethers.utils.parseEther(instantWithdrawalFee.toString())).to.equal(
      ethers.utils.parseEther("5000000000000000")
    );
  });

  it("#1: should revert when fee is zero", async function () {
    await manager.initialize(await user.getAddress());
    await expect(manager.connect(user).setWithdrawalFee(0)).to.be.revertedWith(
      "withdrawalFee != 0"
    );
  });

  it("#2: should revert when fee is greater that .3 percent", async function () {
    await manager.initialize(await user.getAddress());
    await expect(
      manager.connect(user).setWithdrawalFee(ethers.utils.parseUnits("0.4", 18))
    ).to.be.revertedWith("withdrawalFee >= 30%");
  });

  it("#3: should set instantWithdrawalFee when call setWithdrawalFee", async function () {
    await manager.initialize(await user.getAddress());
    await manager
      .connect(user)
      .setWithdrawalFee(ethers.utils.parseUnits("0.25", 18));
    const instantWithdrawalFee = await manager
      .connect(user)
      .instantWithdrawalFee();
    expect(ethers.utils.parseEther(instantWithdrawalFee.toString())).to.equal(
      ethers.utils.parseEther("250000000000000000")
    );
  });
});
