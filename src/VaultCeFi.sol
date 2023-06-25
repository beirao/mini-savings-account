// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@solmate/mixins/ERC4626.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

// Errors
error Vault__NOT_ENOUGH_LIQUIDITY(uint256 maxBorrowCapatity);

contract VaultCeFi is ERC4626, Ownable {
    using SafeTransferLib for ERC20;

    uint256 private borrowedFunds; // Funds currently used by positions
    uint256 private MAX_BORROW_RATIO = 8000; // in basis points => 80%

    constructor(
        ERC20 _asset,
        address _admin
    )
        ERC4626(
            _asset,
            string.concat("Bank-", _asset.symbol()),
            string.concat("B", _asset.symbol())
        )
    {
        transferOwnership(_admin);
    }

    // --------------- Admin Zone (only when the vault is a CeFi)---------------

    /**
     * @notice Borrow funds from the vault to invest in traitionnal finance
     * @dev Only the admin can borrow funds
     * @param _amountToBorrow amount to borrow
     */
    function borrow(uint256 _amountToBorrow) external onlyOwner {
        uint256 borrowCapacity = borrowCapacityLeft();
        if (_amountToBorrow > borrowCapacity)
            revert Vault__NOT_ENOUGH_LIQUIDITY(borrowCapacity);
        borrowedFunds += _amountToBorrow;
        asset.safeTransfer(msg.sender, _amountToBorrow);

        emit Borrow(_amountToBorrow);
    }

    /**
     * @notice Refund funds and interests to the vaults
     * @dev admin will need to approve the Vault to transfer funds
     * @param _amountBorrowed amount that was borrowed
     * @param _interests interest earned
     * @param _losses losses if there is any
     */
    function refund(
        uint256 _amountBorrowed,
        uint256 _interests,
        uint256 _losses
    ) external onlyOwner {
        // Losses are taken by the pool
        borrowedFunds = uint256(
            int256(borrowedFunds) - int256(_amountBorrowed)
        );
        uint256 sum_ = _amountBorrowed + _interests - _losses;
        asset.safeTransferFrom(msg.sender, address(this), sum_);
        emit Refund(sum_);
    }

    // --------------- Views/Pures ---------------

    function totalAssets() public view override returns (uint256) {
        return asset.balanceOf(address(this)) + borrowedFunds;
    }

    function rawTotalAsset() public view returns (uint256) {
        return asset.balanceOf(address(this));
    }

    function getBorrowedFund() external view returns (uint256) {
        return borrowedFunds;
    }

    function borrowCapacityLeft() public view returns (uint256) {
        return ((totalAssets() * MAX_BORROW_RATIO) / 10000) - borrowedFunds;
    }

    // --------------- Events ---------------
    event Borrow(uint256 amount);
    event Refund(uint256 amount);
}
