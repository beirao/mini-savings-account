// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Utils} from "./utils/Utils.sol";
import "./utils/Fixtures.sol";
import "../Accountt.sol";
import "../VaultCeFi.sol";

contract AccountTest is Fixtures {
    address vaultEURT;
    address vaultGBPT;
    address vaultUSDC;
    Accountt public account0;
    Accountt public account1;

    function setUp() public override {
        super.setUp();

        vm.startPrank(deployer);
        bank.addAsset(conf.addAGEUR);
        bank.addAsset(conf.addGBPT);
        bank.addAsset(conf.addUSDC);

        vaultEURT = bank.createVaultCeFi(conf.addAGEUR, deployer);
        vaultGBPT = bank.createVaultCeFi(conf.addGBPT, deployer);
        vaultUSDC = bank.createVaultCeFi(conf.addUSDC, deployer);

        vm.stopPrank();

        vm.prank(alice);
        account0 = Accountt(bank.createAccount());
        vm.prank(bob);
        account1 = Accountt(bank.createAccount());
        vm.stopPrank();
    }

    function test__accountInternalTransfertAndWithdraw() public {
        vm.startPrank(alice);
        ERC20(conf.addUSDC).approve(address(account0), 1000e6);
        account0.deposit(conf.addUSDC, 1000e6);
        account0.internalTransfer(conf.addUSDC, 500e6, 0, 1);
        vm.stopPrank();
        assertEq(account0.getBalance(conf.addUSDC, 0), 500e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 500e6);

        vm.startPrank(alice);
        account0.withdraw(conf.addUSDC, 500e6, 1);
        vm.stopPrank();

        assertEq(account0.getBalance(conf.addUSDC, 1), 0);
    }

    function test__internalSwap() public {
        vm.startPrank(alice);
        ERC20(conf.addUSDC).approve(address(account0), 1000e6);
        account0.deposit(conf.addUSDC, 1000e6);
        uint amountOut = account0.internalSwap(
            conf.addUSDC,
            conf.addAGEUR,
            500e6,
            500,
            0
        );
        vm.stopPrank();
        assertEq(account0.getBalance(conf.addUSDC, 0), 500e6);
        assertEq(account0.getBalance(conf.addAGEUR, 0), amountOut);
    }

    function test__linkVautToSubaccount() public {
        vm.startPrank(alice);

        ERC20(conf.addUSDC).approve(address(account0), 1000e6);
        account0.deposit(conf.addUSDC, 1000e6);
        account0.internalTransfer(conf.addUSDC, 500e6, 0, 1);
        // subaccount 1 has 500 USDC

        account0.linkSubaccountToVault(1, vaultUSDC);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 500e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 500e6);
        vm.stopPrank();
    }

    function test__linkVautToSubaccountAndTransfertToNotLinkedSubaccount()
        public
    {
        vm.startPrank(alice);

        ERC20(conf.addUSDC).approve(address(account0), 1000e6);
        account0.deposit(conf.addUSDC, 1000e6);
        account0.internalTransfer(conf.addUSDC, 500e6, 0, 1);
        // subaccount 1 has 500 USDC

        account0.linkSubaccountToVault(1, vaultUSDC);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 500e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 500e6);

        account0.internalTransfer(conf.addUSDC, 500e6, 1, 0);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 0);
        assertEq(account0.getBalance(conf.addUSDC, 1), 0);
        assertEq(account0.getBalance(conf.addUSDC, 0), 1000e6);

        vm.stopPrank();
    }

    function test__linkVautToSubaccountAndTransfertToLinkedSubaccount1()
        public
    {
        vm.startPrank(alice);

        ERC20(conf.addUSDC).approve(address(account0), 5000e6);
        account0.deposit(conf.addUSDC, 5000e6);

        // subaccount 1 and 2 has 1000 USDC
        account0.internalTransfer(conf.addUSDC, 2000e6, 0, 1);
        account0.internalTransfer(conf.addUSDC, 1000e6, 1, 2);

        assertEq(account0.getBalance(conf.addUSDC, 0), 3000e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 1000e6);
        assertEq(account0.getBalance(conf.addUSDC, 2), 1000e6);

        // sub account 1 and 2 are linked to vaultUSDC
        account0.linkSubaccountToVault(1, vaultUSDC);
        account0.linkSubaccountToVault(2, vaultUSDC);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 2000e6);

        account0.internalTransfer(conf.addUSDC, 500e6, 1, 0);
        account0.internalTransfer(conf.addUSDC, 500e6, 0, 2);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 2000e6);
        assertEq(account0.getBalance(conf.addUSDC, 0), 3000e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 500e6);
        assertEq(account0.getBalance(conf.addUSDC, 2), 1500e6);

        vm.stopPrank();
    }

    function test__linkVautToSubaccountAndTransfertToLinkedSubaccount2()
        public
    {
        vm.startPrank(alice);

        ERC20(conf.addUSDC).approve(address(account0), 5000e6);
        account0.deposit(conf.addUSDC, 5000e6);

        // subaccount 1 and 2 has 1000 USDC
        account0.internalTransfer(conf.addUSDC, 2000e6, 0, 1);
        account0.internalTransfer(conf.addUSDC, 1000e6, 1, 2);

        assertEq(account0.getBalance(conf.addUSDC, 0), 3000e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 1000e6);
        assertEq(account0.getBalance(conf.addUSDC, 2), 1000e6);

        // sub account 1 and 2 are linked to vaultUSDC
        account0.linkSubaccountToVault(1, vaultUSDC);
        account0.linkSubaccountToVault(2, vaultUSDC);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 2000e6);

        account0.internalTransfer(conf.addUSDC, 500e6, 1, 2);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 2000e6);
        assertEq(account0.getBalance(conf.addUSDC, 0), 3000e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 500e6);
        assertEq(account0.getBalance(conf.addUSDC, 2), 1500e6);

        vm.stopPrank();
    }

    function test__vaultGeneratingInterest() public {
        vm.startPrank(alice);

        ERC20(conf.addUSDC).approve(address(account0), 5000e6);
        account0.deposit(conf.addUSDC, 5000e6);

        // subaccount 1 has 2000 USDC
        account0.internalTransfer(conf.addUSDC, 2000e6, 0, 1);

        // sub account 1 is linked to vaultUSDC
        account0.linkSubaccountToVault(1, vaultUSDC);

        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 2000e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), 2000e6);

        vm.stopPrank();

        // admin will generate interest
        vm.startPrank(deployer);
        VaultCeFi(vaultUSDC).borrow(1000e6);
        vm.warp(block.timestamp + 1 weeks);
        uint256 interest = 100e6;
        assertEq(account0.getBalance(conf.addUSDC, 1), 2000e6);
        assertEq(ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)), 1000e6);
        ERC20(conf.addUSDC).approve(address(vaultUSDC), 1000e6 + interest);
        VaultCeFi(vaultUSDC).refund(1000e6, interest, 0);
        vm.stopPrank();

        assertEq(
            ERC20(conf.addUSDC).balanceOf(address(vaultUSDC)),
            2000e6 + interest
        );

        vm.startPrank(alice);

        account0.internalTransfer(conf.addUSDC, 2000e6, 1, 2);
        assertEq(account0.getBalance(conf.addUSDC, 2), 2000e6);
        assertEq(account0.getBalance(conf.addUSDC, 0), 3000e6);
        assertEq(account0.getBalance(conf.addUSDC, 1), interest);

        vm.stopPrank();
    }
}
