// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@solmate/utils/FixedPointMathLib.sol";
import "@solmate/utils/SafeTransferLib.sol";
import "@solmate/tokens/ERC20.sol";

import "./UniswapV3Helper.sol";
import "./Bank.sol";
import "@solmate/mixins/ERC4626.sol";

//Errors
error Account__NOT_THE_OWNER(address owner);
error Account__ASSET_NOT_SUPPORTED(address asset);
error Account__INSUFFICIENT_BALANCE(
    address asset,
    uint256 balance,
    uint256 amount
);
error Account__VAULT_NOT_SUPPORTED(address vault);
error Account__DEFAULT_SUBACCOUNT_CAN_BE_LINKED();

// I Account is a Foundry reserved interface name so we use Accountt
contract Accountt {
    using SafeTransferLib for ERC20;
    Bank public bank;
    UniswapV3Helper public uniswapV3Helper;

    struct VaultInfo {
        ERC4626 vault;
        uint256 share;
    }

    /** @dev account id = 0 is the default account */
    mapping(uint256 => mapping(address => uint256))
        public subaccountIdToAssetToBalance;
    mapping(uint256 => VaultInfo) public subaccountIdToVault;

    constructor(address _bank, address _uniswapV3Helper) {
        bank = Bank(_bank);
        uniswapV3Helper = UniswapV3Helper(_uniswapV3Helper);
    }

    // --------------- Modifier ---------------
    modifier onlyOwner() {
        if (bank.ownerOf(uint256(uint160(address(this)))) != msg.sender) {
            revert Account__NOT_THE_OWNER(msg.sender);
        }
        _;
    }
    modifier isAssetSupported(address _asset) {
        if (!bank.isAssetSupported(_asset)) {
            revert Account__ASSET_NOT_SUPPORTED(_asset);
        }
        _;
    }

    modifier enoughBalance(
        address _asset,
        uint256 _amount,
        uint256 _subaccountId
    ) {
        checkBalance(_asset, _amount, _subaccountId);
        _;
    }

    // --------------- Externals/Publics ---------------

    /**
     * @notice Deposit the given amount of the given asset to the default account (id = 0)
     * @param _asset The address of the asset to deposit
     * @param _amount The amount of the asset to deposit
     * @dev The caller must approve the Bank contract to spend the given amount of the given asset
     */
    function deposit(
        address _asset,
        uint256 _amount
    ) external isAssetSupported(_asset) {
        ERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        subaccountIdToAssetToBalance[0][_asset] += _amount;
        emit Deposit(_asset, _amount, 0);
    }

    /**
     * @notice Deposit the given amount of the given asset to the given account
     * @param _asset The address of the asset to deposit
     * @param _amount The amount of the asset to deposit
     * @param _subaccountId The id of the account to deposit to
     * @dev The caller must approve the Bank contract to spend the given amount of the given asset
     */
    function deposit(
        address _asset,
        uint256 _amount,
        uint256 _subaccountId
    ) external isAssetSupported(_asset) {
        ERC20(_asset).safeTransferFrom(msg.sender, address(this), _amount);
        VaultInfo memory vaultInfo_ = subaccountIdToVault[_subaccountId];

        if (
            address(vaultInfo_.vault) != address(0) &&
            address(vaultInfo_.vault.asset()) == _asset
        ) {
            updateVaultDeposit(vaultInfo_, _amount);
        }
        unchecked {
            subaccountIdToAssetToBalance[_subaccountId][_asset] += _amount;
        }

        emit Deposit(_asset, _amount, _subaccountId);
    }

    /**
     * @notice Withdraw the given amount of the given asset from the default account (id = 0)
     * @param _asset The address of the asset to withdraw
     * @param _amount The amount of the asset to withdraw
     */
    function withdraw(
        address _asset,
        uint256 _amount
    )
        external
        onlyOwner
        isAssetSupported(_asset)
        enoughBalance(_asset, _amount, 0)
    {
        unchecked {
            subaccountIdToAssetToBalance[0][_asset] -= _amount;
        }
        ERC20(_asset).safeTransfer(msg.sender, _amount);
        emit Withdraw(_asset, _amount, 0);
    }

    /**
     * @notice Withdraw the given amount of the given asset from the given account
     * @param _asset The address of the asset to withdraw
     * @param _amount The amount of the asset to withdraw
     * @param _subaccountId The id of the account to withdraw from
     */
    function withdraw(
        address _asset,
        uint256 _amount,
        uint256 _subaccountId
    )
        external
        onlyOwner
        isAssetSupported(_asset)
        enoughBalance(_asset, _amount, _subaccountId)
    {
        VaultInfo memory vaultInfo_ = subaccountIdToVault[_subaccountId];

        if (
            address(vaultInfo_.vault) != address(0) &&
            address(vaultInfo_.vault.asset()) == _asset
        ) {
            updateVaultWithdraw(vaultInfo_, _asset, _amount, _subaccountId);
        } else {
            checkBalance(_asset, _amount, _subaccountId);
            unchecked {
                subaccountIdToAssetToBalance[_subaccountId][_asset] -= _amount;
            }
        }

        ERC20(_asset).safeTransfer(msg.sender, _amount);
        emit Deposit(_asset, _amount, _subaccountId);
    }

    /**
     * @notice Transfer the given amount of the given asset from the _subaccountIdFrom to the _subaccountIdTo
     * @param _asset The address of the asset to transfer
     * @param _amount The amount of the asset to transfer
     * @param _subaccountIdFrom The id of the account to transfer from
     * @param _subaccountIdTo The id of the account to transfer to
     */
    function internalTransfer(
        address _asset,
        uint256 _amount,
        uint256 _subaccountIdFrom,
        uint256 _subaccountIdTo
    ) external onlyOwner isAssetSupported(_asset) {
        VaultInfo memory vaultInfoFrom_ = subaccountIdToVault[
            _subaccountIdFrom
        ];
        VaultInfo memory vaultInfoTo_ = subaccountIdToVault[_subaccountIdTo];

        if (
            address(vaultInfoFrom_.vault) != address(0) &&
            address(vaultInfoFrom_.vault.asset()) == _asset
        ) {
            updateVaultWithdraw(
                vaultInfoFrom_,
                _asset,
                _amount,
                _subaccountIdFrom
            );
        } else {
            checkBalance(_asset, _amount, _subaccountIdFrom);
            unchecked {
                subaccountIdToAssetToBalance[_subaccountIdFrom][
                    _asset
                ] -= _amount;
            }
        }

        if (
            address(vaultInfoTo_.vault) != address(0) &&
            address(vaultInfoTo_.vault.asset()) == _asset
        ) {
            updateVaultDeposit(vaultInfoTo_, _amount);
        }
        unchecked {
            subaccountIdToAssetToBalance[_subaccountIdTo][_asset] += _amount;
        }

        emit Transfer(_asset, _amount, _subaccountIdFrom, _subaccountIdTo);
    }

    /**
     * @notice internal swap (only on default sub account id = 0)
     * @param _assetIn The address of the asset to swap from
     * @param _assetOut The address of the asset to swap to
     * @param _amountIn The amount of the asset to swap from
     * @param _fee The fee of the uniswap v3 pool
     * @param _amountOutMin The minimum amount of the asset to swap to
     */
    function internalSwap(
        address _assetIn,
        address _assetOut,
        uint256 _amountIn,
        uint24 _fee,
        uint256 _amountOutMin
    )
        external
        onlyOwner
        isAssetSupported(_assetIn)
        isAssetSupported(_assetOut)
        enoughBalance(_assetIn, _amountIn, 0)
        returns (uint256)
    {
        unchecked {
            subaccountIdToAssetToBalance[0][_assetIn] -= _amountIn;
        }

        ERC20(_assetIn).safeApprove(address(uniswapV3Helper), _amountIn);
        uint256 amountOut_ = uniswapV3Helper.swapExactInputSingle(
            _assetIn,
            _assetOut,
            _fee,
            _amountIn,
            _amountOutMin
        );

        unchecked {
            subaccountIdToAssetToBalance[0][_assetOut] += amountOut_;
        }
        emit Swap(_assetIn, _assetOut, _amountIn, amountOut_, _fee);
        return amountOut_;
    }

    /**
     * @notice Link the given subaccount id to the given vault
     * @param _subaccountId The id of the subaccount to link
     * @param _vault The address of the vault to link to
     */
    function linkSubaccountToVault(
        uint256 _subaccountId,
        address _vault
    ) external onlyOwner {
        if (_subaccountId == 0) {
            revert Account__DEFAULT_SUBACCOUNT_CAN_BE_LINKED();
        }
        if (!bank.isVaultSupported(_vault)) {
            revert Account__VAULT_NOT_SUPPORTED(_vault);
        }
        ERC4626 vault_ = ERC4626(_vault);
        address asset_ = address(vault_.asset());
        subaccountIdToVault[_subaccountId].vault = vault_;

        uint256 balance_ = subaccountIdToAssetToBalance[_subaccountId][
            address(asset_)
        ];
        if (balance_ != 0) {
            ERC20(asset_).safeApprove(address(vault_), balance_);
            subaccountIdToVault[_subaccountId].share = vault_.deposit(
                balance_,
                address(this)
            );
        }

        emit SubaccountLinkedToVault(_subaccountId, _vault);
    }

    // --------------- Internals/Privates ---------------

    function updateVaultDeposit(
        VaultInfo memory _vaultInfo,
        uint256 _amount
    ) internal {
        ERC20 asset_ = _vaultInfo.vault.asset();
        asset_.safeApprove(address(_vaultInfo.vault), _amount);
        _vaultInfo.share += _vaultInfo.vault.deposit(_amount, address(this));
    }

    function updateVaultWithdraw(
        VaultInfo memory _vaultInfo,
        address _asset,
        uint256 _amount,
        uint256 _subaccountId
    ) internal {
        // update subaccount balance with accrued interest
        uint256 newBalance_ = _vaultInfo.vault.previewRedeem(_vaultInfo.share);

        if (newBalance_ < _amount) {
            revert Account__INSUFFICIENT_BALANCE(
                _asset,
                subaccountIdToAssetToBalance[_subaccountId][_asset],
                _amount
            );
        }

        _vaultInfo.share -= _vaultInfo.vault.withdraw(
            _amount,
            address(this),
            address(this)
        );

        subaccountIdToAssetToBalance[_subaccountId][address(_asset)] =
            newBalance_ -
            _amount;
    }

    function checkBalance(
        address _asset,
        uint256 _amount,
        uint256 _subaccountId
    ) internal view {
        if (subaccountIdToAssetToBalance[_subaccountId][_asset] < _amount) {
            revert Account__INSUFFICIENT_BALANCE(
                _asset,
                subaccountIdToAssetToBalance[_subaccountId][_asset],
                _amount
            );
        }
    }

    // --------------- Views/Pures ---------------
    function getBalance(
        address _asset,
        uint256 _subaccountId
    ) external view returns (uint256) {
        return subaccountIdToAssetToBalance[_subaccountId][_asset];
    }

    // --------------- Events ---------------
    event Deposit(address asset, uint256 amount, uint256 subaccountId);
    event Withdraw(address asset, uint256 amount, uint256 subaccountId);
    event Transfer(
        address asset,
        uint256 amount,
        uint256 subaccountIdFrom,
        uint256 subaccountIdTo
    );
    event Swap(
        address assetIn,
        address assetOut,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fee
    );
    event SubaccountLinkedToVault(uint256 subaccountId, address vault);
}
