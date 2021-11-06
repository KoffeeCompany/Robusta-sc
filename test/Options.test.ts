import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { abi as IUniswapV3PoolAbi } from "@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json";
import { IUniswapV3Factory, IUniswapV3Pool, Option } from "../typechain";

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

  it("#0: should revert when tick is out of range", async function () {
    const WETH = "0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2";
    const DAI = "0x6B175474E89094C44Da98b954EedeAC495271d0F";
    const pokeMeAddress = "0xB3f5503f93d5Ef84b06993a1975B9D21B962892F";
    const poolAddress = await uniFactory.getPool(WETH, DAI, 500);
    const pool: IUniswapV3Pool = await ethers.getContractAt(
      IUniswapV3PoolAbi,
      poolAddress,
      user
    );

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    // strike is the corresponding tick of the wanted Strike
    const strike = slot0.tick - tickSpacing;
    const notional = ethers.utils.parseUnits("10000", 18);
    const currentBlock = hre.ethers.provider.getBlock("latest");
    const maturity = (await currentBlock).timestamp + 10; // 10 seconds

    const optionData = {
      pool: poolAddress,
      optionType: 0,
      strike: strike,
      notional: notional,
      maturity: maturity,
      maker: await user.getAddress(),
      resolver: pokeMeAddress,
      price: ethers.utils.parseEther("0.93"),
    };

    await expect(
      option.connect(user).createOption(optionData)
    ).to.be.revertedWith("'eject tick in range'");
  });
});
