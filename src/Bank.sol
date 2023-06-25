// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@solmate/tokens/ERC20.sol";

import "./Accountt.sol";
import "./VaultCeFi.sol";
import "./VaultDeFi.sol";

// Errors
error Bank__ACCOUNT_ALREADY_CREATED(address user);
error Bank__ASSET_ALREADY_ADDED(address asset);
error Bank__VAULT_ALREADY_ADDED(address vault);
error Bank__ASSET_NOT_SUPPORTED(address asset);

/**
 * @title Bank
 * @notice The Bank contract act as a factory for Accounts and Vaults
 * @dev The Bank contract is Ownable, meaning that the owner can create new
 *      Vaults. The Bank contract is also an ERC721 contract, meaning that
 *      each Account is represented by an ERC721 token.
 */
contract Bank is ERC721, Ownable {
    mapping(address => bool) private supportedVaults;
    mapping(address => bool) private supportedAssets;
    address public uniswapV3Helper;

    constructor(
        address _admin,
        address _uniswapHelper
    ) ERC721("Mini-Bank", "BANK") {
        transferOwnership(_admin);
        uniswapV3Helper = _uniswapHelper;
    }

    // --------------- Modifiers ---------------
    modifier vaultNotAdded(address _vault) {
        if (!supportedVaults[_vault]) {
            revert Bank__VAULT_ALREADY_ADDED(_vault);
        }
        _;
    }

    modifier assetAdded(address _asset) {
        if (!supportedAssets[_asset]) {
            revert Bank__ASSET_NOT_SUPPORTED(_asset);
        }
        _;
    }

    // --------------- Externals/Publics ---------------

    /**
     * @notice Creates a new account for the caller
     * @return The address of the new account
     */
    function createAccount() external returns (address) {
        address account_ = address(
            new Accountt(address(this), uniswapV3Helper)
        );
        _safeMint(msg.sender, uint256(uint160(account_)));
        emit AccountCreated(account_);
        return account_;
    }

    /**
     * @notice Adds the given asset to the list of supported assets
     * @param _asset The address of the asset to add
     * @dev Only the owner of the Bank can call this function
     */
    function addAsset(address _asset) external onlyOwner {
        if (supportedAssets[_asset]) {
            revert Bank__ASSET_ALREADY_ADDED(_asset);
        }
        supportedAssets[_asset] = true;
        emit AssetAdded(_asset);
    }

    /**
     * @notice Creates a new VaultCeFi for the given asset
     * @param _asset The address of the asset to create a VaultCeFi for
     * @param _admin The address of the admin of the new VaultCeFi
     */
    function createVaultCeFi(
        address _asset,
        address _admin
    ) external onlyOwner assetAdded(_asset) returns (address) {
        address vault = address(new VaultCeFi(ERC20(_asset), _admin));
        supportedVaults[vault] = true;
        emit VaultCreated(vault);
        return vault;
    }

    /**
     * @notice Creates a new VaultDeFi
     * @dev The VaultDeFi must be created beforehand, since implementing
     *      DeFi strategies can't be done with a standard contract.
     * @param _vault The address of the Vault to create
     */
    function createVaultDeFi(
        address _vault
    ) external onlyOwner vaultNotAdded(_vault) {
        address asset_ = address(ERC4626(_vault).asset());
        if (!supportedAssets[asset_]) {
            revert Bank__ASSET_NOT_SUPPORTED(asset_);
        }
        supportedVaults[_vault] = true;
        emit VaultCreated(_vault);
    }

    // --------------- Views/Pures ---------------
    function getUserAccount(
        address _accountAddress
    ) external view returns (address) {
        return ownerOf(uint256(uint160(_accountAddress)));
    }

    function isVaultSupported(address _vault) external view returns (bool) {
        return supportedVaults[_vault];
    }

    function isAssetSupported(address _asset) external view returns (bool) {
        return supportedAssets[_asset];
    }

    // --------------- Events ---------------
    event AccountCreated(address indexed account);
    event VaultCreated(address indexed vault);
    event AssetAdded(address indexed asset);
}
