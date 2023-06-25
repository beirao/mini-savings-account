// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../Accountt.sol";
import "../../Bank.sol";
import "../../UniswapV3Helper.sol";
import "../../VaultCeFi.sol";
import "../../VaultDeFi.sol";

import "@solmate/tokens/ERC20.sol";

import {UniswapV3Pool} from "@uniswapCore/contracts/UniswapV3Pool.sol";
import {SwapRouter} from "@uniswapPeriphery/contracts/SwapRouter.sol";

import "forge-std/Test.sol";
import "../utils/HelperConfig.sol";
import {Utils} from "./Utils.sol";

contract Fixtures is Test, HelperConfig, Utils {
    UniswapV3Helper public uniswapV3Helper;
    Bank public bank;

    SwapRouter public swapRouter;
    address public alice;
    address public bob;
    address public carol;
    address public deployer;

    HelperConfig.NetworkConfig public conf;

    function setUp() public virtual {
        conf = getActiveNetworkConfig();

        // create users
        deployer = address(0x01);
        alice = address(0x11);
        bob = address(0x21);
        carol = address(0x31);

        // mainnet context
        swapRouter = SwapRouter(payable(conf.swapRouter));

        vm.startPrank(deployer);

        /// deployments
        // contracts
        uniswapV3Helper = new UniswapV3Helper(
            conf.nonfungiblePositionManager,
            conf.swapRouter
        );
        bank = new Bank(deployer, address(uniswapV3Helper));

        vm.stopPrank();

        // add liquidity to a pool to be able to open a short position
        vm.startPrank(alice);
        writeTokenBalance(alice, conf.addGBPT, 10000000e18);
        writeTokenBalance(alice, conf.addAGEUR, 10000000e6);
        writeTokenBalance(alice, conf.addUSDC, 10000000e6);
        vm.stopPrank();
    }
}
