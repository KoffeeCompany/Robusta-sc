import { expect } from "chai";
import { Signer } from "ethers";
import hre = require("hardhat");
import { abi as IUniswapV3PoolAbi } from "@uniswap/v3-core/artifacts/contracts/UniswapV3Pool.sol/UniswapV3Pool.json";
import {
  IERC20,
  IUniswapV3Factory,
  IUniswapV3Pool,
  ISwapRouter,
  INonfungiblePositionManager,
  OptionResolver,
  Option,
  IPokeMe,
} from "../typechain";
import { getAddresses, Addresses } from "../hardhat/addresses";

const { ethers, deployments } = hre;

describe("Options", function () {
  this.timeout(0);
  let option: Option;
  let optionResolver: OptionResolver;
  let user: Signer;
  let user2: Signer;
  let uniFactory: IUniswapV3Factory;
  let swapRouter: ISwapRouter;
  let addresses: Addresses;
  let cDAI: IERC20;
  let nonfungiblePositionManager: INonfungiblePositionManager;
  let resolver: OptionResolver;
  const delay = (ms) => new Promise((res) => setTimeout(res, ms));

  beforeEach(async () => {
    await deployments.fixture();
    [user, user2] = await ethers.getSigners();

    addresses = getAddresses(hre.network.name);

    option = (await ethers.getContract("Option")) as Option;
    uniFactory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      "0x1F98431c8aD98523631AE4a59f267346ea31F984"
    )) as IUniswapV3Factory;
    cDAI = (await ethers.getContractAt("IERC20", addresses.DAI)) as IERC20;

    swapRouter = (await ethers.getContractAt(
      "ISwapRouter",
      addresses.SwapRouter,
      user
    )) as ISwapRouter;

    nonfungiblePositionManager = (await ethers.getContractAt(
      "INonfungiblePositionManager",
      addresses.NonfungiblePositionManager,
      user
    )) as INonfungiblePositionManager;
    resolver = (await ethers.getContract("OptionResolver")) as OptionResolver;
  });

  it("#0: should revert when tick is out of range", async function () {
    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      cDAI.address,
      500
    );
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
      resolver: addresses.PokeMe,
      price: ethers.utils.parseEther("0.93"),
    };

    await expect(
      option.connect(user).createOption(optionData)
    ).to.be.revertedWith("'eject tick in range'");
  });

  it("#1: should create call successfully", async function () {
    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );
    const pool: IUniswapV3Pool = await ethers.getContractAt(
      IUniswapV3PoolAbi,
      poolAddress,
      user
    );

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    // strike is the corresponding tick of the wanted Strike
    const strike = slot0.tick - (slot0.tick % tickSpacing) + tickSpacing;
    const notional = ethers.utils.parseUnits("10000", 18);
    const currentBlock = hre.ethers.provider.getBlock("latest");
    const maturity = (await currentBlock).timestamp + 10; // 10 seconds

    // Swap Eth to DAI.
    await swapRouter.exactOutputSingle(
      {
        tokenIn: addresses.WETH,
        tokenOut: addresses.DAI,
        fee: 500,
        recipient: await user.getAddress(),
        deadline: ethers.constants.MaxUint256,
        amountOut: ethers.utils.parseUnits("10000", 18),
        amountInMaximum: ethers.utils.parseEther("3"),
        sqrtPriceLimitX96: ethers.constants.Zero,
      },
      {
        value: ethers.utils.parseEther("3"),
      }
    );

    const optionData = {
      pool: poolAddress,
      optionType: 0,
      strike: strike,
      notional: notional,
      maturity: maturity,
      maker: await user.getAddress(),
      resolver: addresses.PokeMe,
      price: ethers.utils.parseEther("0.93"),
    };

    await cDAI.connect(user).approve(option.address, notional);

    await expect(option.connect(user).createOption(optionData)).to.not.be
      .reverted;

    const tokenId = 145227;

    // console.log(await nonfungiblePositionManager.positions(tokenId));

    // Checker (Resolver) should return false
    let checkerResult = await resolver.checker(tokenId, optionData);
    expect(checkerResult.canExec).to.equal(false);

    // Manipulate market to put call in execution position
    console.log(slot0.tick);
    (slot0.tick as number) = strike + tickSpacing;
    //console.log(slot0.tick);

    // Wait to maturity
    await delay(10000);

    // Checker (Resolver) should return true
    checkerResult = await resolver.checker(tokenId, optionData);
    expect(checkerResult.canExec).to.equal(true);

    const balanceUserBefore = await cDAI.balanceOf(await user.getAddress());
    // Settle
    option.connect(user).settleOption(tokenId, optionData);

    // Expect Check
    const balanceUserAfter = await cDAI.balanceOf(await user.getAddress());
    expect(balanceUserAfter).to.equal(balanceUserBefore + notional);
  });
});
