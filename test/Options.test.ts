import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { IUniswapV3Factory, Option } from "../typechain";

const { ethers, deployments } = hre;

describe("Options", function () {
  this.timeout(0);
  let option: Option;
  let user: Signer;
  let user2: Signer;
  let uniFactory: IUniswapV3Factory;

  beforeEach(async () => {
    await deployments.fixture();
    [user, user2] = await ethers.getSigners();
    option = (await ethers.getContract("Option")) as Option;
    uniFactory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      "0x1F98431c8aD98523631AE4a59f267346ea31F984"
    )) as IUniswapV3Factory;
  });

  it("#0: should revert when tick is out of the range", async function () {
    const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const DAI = "0x8f3Cf7ad23Cd3CaDbD9735AFf958023239c6A063";
    const pool = await uniFactory.getPool(
      WETH,
      DAI,
      ethers.utils.parseUnits("3000", 6)
    );
    const optionData = {
      pool: pool,
      optionType: 1,
      strike: ethers.utils.parseUnits("2300", 6),
      notional: ethers.utils.parseUnits("1000", 6),
      maturity: 2,
      maker: await user.getAddress(),
      resolver: await user2.getAddress(),
      price: ethers.utils.parseEther("0.93"),
      fee: ethers.utils.parseEther("0.01"),
    };
    await expect(
      option.connect(user).createOption(optionData)
    ).to.be.revertedWith(
      "VM Exception while processing transaction: reverted with reason string 'The deposit criteria aren't satified.'"
    );
  });
});
