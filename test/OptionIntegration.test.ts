// import { expect } from "chai";
// import { Signer } from "@ethersproject/abstract-signer";
// import { Option, IWETH9, ISwapRouter, IPokeMe } from "../typechain";
// import { Addresses, getAddresses } from "../src/addresses";

// import hre = require("hardhat");

// const { ethers, deployments } = hre;

// describe("Option integration Test", function () {
//   this.timeout(0);

//   let user: Signer;

//   let option: Option;

//   let weth: IWETH9;
//   let dai: IERC20;
//   let pokeMe: IPokeMe;
//   let swapRouter: ISwapRouter;

//   let addresses: Addresses;

//   beforeEach("Option", async function () {
//     if (hre.network.name !== "hardhat") {
//       console.error("Test Suite is meant to be run on hardhat only");
//       process.exit(1);
//     }

//     addresses = getAddresses(hre.network.name);
//     await deployments.fixture();

//     [user] = await ethers.getSigners();

//     option = (await ethers.getContract("Option")) as Option;
//     swapRouter = (await ethers.getContractAt(
//       "ISwapRouter",
//       addresses.SwapRouter,
//       user
//     )) as ISwapRouter;
//     pokeMe = (await ethers.getContractAt(
//       "IPokeMe",
//       addresses.PokeMe,
//       user
//     )) as IPokeMe;
//   });

//   it("#0: Submit and Execute an Option", async () => {

//   })
// });
