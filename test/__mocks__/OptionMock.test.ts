import { expect } from "chai";
import { Signer } from "ethers";
import hre from "hardhat";
import { Addresses, getAddresses } from "../../hardhat/addresses";
import {
  IERC20,
  ISwapRouter,
  IUniswapV3Factory,
  IUniswapV3Pool,
  OptionFunctionMock,
} from "../../typechain";

const { ethers, deployments } = hre;

describe("OptionMock", function () {
  this.timeout(0);
  let optionFunctionMock: OptionFunctionMock;
  let user: Signer;
  let swapRouter: ISwapRouter;
  let uniFactory: IUniswapV3Factory;
  let addresses: Addresses;
  let cDAI: IERC20;
  let weth: IERC20;

  this.beforeEach(async () => {
    await deployments.fixture();
    [user] = await ethers.getSigners();

    addresses = getAddresses(hre.network.name);

    optionFunctionMock = (await ethers.getContract(
      "OptionFunctionMock"
    )) as OptionFunctionMock;

    swapRouter = (await ethers.getContractAt(
      "ISwapRouter",
      addresses.SwapRouter,
      user
    )) as ISwapRouter;
    uniFactory = (await ethers.getContractAt(
      "IUniswapV3Factory",
      addresses.UniswapV3Factory
    )) as IUniswapV3Factory;

    cDAI = (await ethers.getContractAt("IERC20", addresses.DAI)) as IERC20;
    weth = (await ethers.getContractAt("IERC20", addresses.WETH)) as IERC20;
  });

  it("#0: Test getStrikeTicks function. Call", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 0; // Call.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - (slot0.tick % tickSpacing) + tickSpacing; // Just above tick

    const ticks = await optionFunctionMock.getStrikeTicksMock(
      pool.address,
      optionType,
      strike,
      slot0.tick
    );

    expect(ticks.lowerTick).to.be.eq(strike);
    expect(ticks.upperTick).to.be.eq(strike + tickSpacing);
  });

  it("#1: Test getStrikeTicks function. Call | Should return tick in range revert", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 0; // Call.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing; // Just above tick

    await expect(
      optionFunctionMock.getStrikeTicksMock(
        pool.address,
        optionType,
        strike,
        slot0.tick
      )
    ).to.be.revertedWith("FOption::getStrikeTicks:: strike in wrong side");
  });

  it("#1: Test getStrikeTicks function. Call | Should return tick in range revert", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 1; // Call.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - (slot0.tick % tickSpacing); // Just above tick

    await expect(
      optionFunctionMock.getStrikeTicksMock(
        pool.address,
        optionType,
        strike,
        slot0.tick
      )
    ).to.be.revertedWith("FOption::getStrikeTicks:: strike in wrong side");
  });

  it("#2: Test getStrikeTicks function. Call | Should return tick in range revert", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 1; // Call.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - (slot0.tick % tickSpacing); // Just above tick

    await expect(
      optionFunctionMock.getStrikeTicksMock(
        pool.address,
        optionType,
        strike,
        slot0.tick
      )
    ).to.be.revertedWith("FOption::getStrikeTicks:: strike in wrong side");
  });

  it("#3: Test getStrikeTicks function. Put | Should return tick in range revert", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 1; // Put.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - (slot0.tick % tickSpacing) + tickSpacing; // Just above tick

    await expect(
      optionFunctionMock.getStrikeTicksMock(
        pool.address,
        optionType,
        strike,
        slot0.tick
      )
    ).to.be.revertedWith("FOption::getStrikeTicks:: strike in wrong side");
  });

  it("#4: Test getStrikeTicks function. Put | Should return tick in range revert", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 1; // Put.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - (slot0.tick % tickSpacing) - tickSpacing; // Just above tick

    await expect(
      optionFunctionMock.getStrikeTicksMock(
        pool.address,
        optionType,
        strike,
        slot0.tick
      )
    ).to.be.not.reverted;
  });

  it("#5: Test getStrikeTicks function. Put | uninitializable tick", async function () {
    // Get WETH DAI pool.

    const poolAddress = await uniFactory.getPool(
      addresses.WETH,
      addresses.DAI,
      500
    );

    const pool: IUniswapV3Pool = (await ethers.getContractAt(
      "IUniswapV3Pool",
      poolAddress,
      user
    )) as IUniswapV3Pool;

    const optionType = 1; // Put.

    const slot0 = await pool.slot0();
    const tickSpacing = await pool.tickSpacing();

    const strike = slot0.tick - tickSpacing; // Just above tick

    await expect(
      optionFunctionMock.getStrikeTicksMock(
        pool.address,
        optionType,
        strike,
        slot0.tick
      )
    ).to.be.revertedWith(
      "FOption::getStrikeTicks:: strike is not initializable tick"
    );
  });

  it("#6: Test safeTransferFrom function. Transfert Ether.", async function () {
    const notional = ethers.utils.parseEther("1");
    const tokenIn = weth.address;
    const WETH = weth.address;
    const receiver = optionFunctionMock.address;

    await optionFunctionMock
      .connect(user)
      .safeTransferFromMock(notional, tokenIn, WETH, receiver, {
        value: notional,
      });

    const balanceOfETH = await weth.balanceOf(optionFunctionMock.address);

    expect(balanceOfETH).to.be.eq(notional);
  });

  it("#7: Test safeTransferFrom function. Transfert Ether | msg.value < notional.", async function () {
    const notional = ethers.utils.parseEther("1");
    const tokenIn = weth.address;
    const WETH = weth.address;
    const receiver = optionFunctionMock.address;

    await expect(
      optionFunctionMock
        .connect(user)
        .safeTransferFromMock(notional, tokenIn, WETH, receiver, {
          value: notional.sub(1),
        })
    ).to.be.revertedWith("RangeOrder:setRangeOrder:: Invalid notional in.");
  });

  it("#7: Test safeTransferFrom function. Transfert Ether | tokenIn =! WETH.", async function () {
    const notional = ethers.utils.parseEther("1");
    const tokenIn = cDAI.address;
    const WETH = weth.address;
    const receiver = optionFunctionMock.address;

    await expect(
      optionFunctionMock
        .connect(user)
        .safeTransferFromMock(notional, tokenIn, WETH, receiver, {
          value: notional,
        })
    ).to.be.revertedWith(
      "RangeOrder:setRangeOrder:: ETH range order should use WETH token."
    );
  });

  it("#8: Test safeTransferFrom function. Transfert DAI | without approve", async function () {
    const notional = ethers.utils.parseUnits("1000", 18);
    const tokenIn = cDAI.address;
    const WETH = weth.address;
    const receiver = optionFunctionMock.address;

    // Swap Eth to DAI.
    await swapRouter.connect(user).exactOutputSingle(
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

    await expect(
      optionFunctionMock
        .connect(user)
        .safeTransferFromMock(notional, tokenIn, WETH, receiver)
    ).to.be.revertedWith("Dai/insufficient-allowance");
  });

  it("#9: Test safeTransferFrom function. Transfert DAI | with approve", async function () {
    const notional = ethers.utils.parseUnits("1000", 18);
    const tokenIn = cDAI.address;
    const WETH = weth.address;
    const receiver = optionFunctionMock.address;

    // Swap Eth to DAI.
    await swapRouter.connect(user).exactOutputSingle(
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

    await cDAI.connect(user).approve(optionFunctionMock.address, notional);

    await expect(
      optionFunctionMock
        .connect(user)
        .safeTransferFromMock(notional, tokenIn, WETH, receiver)
    ).to.not.be.reverted;

    expect(await cDAI.balanceOf(optionFunctionMock.address)).to.be.eq(notional);
  });
});
