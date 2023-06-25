// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "./utils/Utils.sol";
import "./utils/Fixtures.sol";
import "./../Accountt.sol";

contract InitTest is Fixtures {
    function test__initVariableChecks() public {
        // check that the contract is deployed
        assertEq(bank.uniswapV3Helper(), address(uniswapV3Helper));
        assertEq(bank.owner(), deployer);
    }

    function test__addAsset() public {
        // check that the contract is deployed
        vm.startPrank(deployer);
        bank.addAsset(conf.addAGEUR);
        bank.addAsset(conf.addGBPT);
        bank.addAsset(conf.addUSDC);
        vm.stopPrank();

        assertEq(bank.isAssetSupported(conf.addAGEUR), true);
        assertEq(bank.isAssetSupported(conf.addGBPT), true);
        assertEq(bank.isAssetSupported(conf.addUSDC), true);
        assertEq(bank.isAssetSupported(address(0x525646546)), false);

        vm.startPrank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Bank__ASSET_ALREADY_ADDED.selector,
                conf.addAGEUR
            )
        );
        bank.addAsset(conf.addAGEUR);
        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        bank.addAsset(address(0x525646546));
        vm.stopPrank();
    }

    function test__addVault() public {
        // check that the contract is deployed
        vm.startPrank(deployer);
        vm.expectRevert(
            abi.encodeWithSelector(
                Bank__ASSET_NOT_SUPPORTED.selector,
                conf.addAGEUR
            )
        );
        bank.createVaultCeFi(conf.addAGEUR, deployer);
        bank.addAsset(conf.addAGEUR);

        address newVault = bank.createVaultCeFi(conf.addAGEUR, deployer);

        assertEq(bank.isVaultSupported(newVault), true);

        vm.stopPrank();

        vm.startPrank(bob);
        vm.expectRevert("Ownable: caller is not the owner");
        bank.createVaultCeFi(conf.addAGEUR, deployer);
        vm.stopPrank();
    }

    function test__createAccountAndAccountTransfer() public {
        vm.startPrank(deployer);
        bank.addAsset(conf.addUSDC);
        vm.stopPrank();

        vm.startPrank(alice);
        Accountt account = Accountt(bank.createAccount());

        assertEq(alice, bank.ownerOf(addToId(address(account))));

        ERC20(conf.addUSDC).approve(address(account), 1000e6);
        account.deposit(conf.addUSDC, 1000e6);
        bank.transferFrom(alice, bob, addToId(address(account)));
        assertEq(bank.ownerOf(addToId(address(account))), bob);

        vm.stopPrank();

        vm.startPrank(bob);
        assertEq(account.getBalance(conf.addUSDC, 0), 1000e6);

        account.withdraw(conf.addUSDC, 1000e6);
        assertEq(account.getBalance(conf.addUSDC, 0), 0);
        assertEq(ERC20(conf.addUSDC).balanceOf(bob), 1000e6);
        vm.stopPrank();
    }
}
