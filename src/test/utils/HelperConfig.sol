// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

contract HelperConfig {
    NetworkConfig public activeNetworkConfig;

    struct NetworkConfig {
        address nonfungiblePositionManager;
        address swapRouter;
        address liquidityPoolFactoryUniswapV3;
        address addGBPT;
        address addAGEUR;
        address addUSDC;
    }

    mapping(uint256 => NetworkConfig) public chainIdToNetworkConfig;

    constructor() {
        chainIdToNetworkConfig[1] = getMainnetForkConfig();
        // chainIdToNetworkConfig[11155111] = getSepoliaEthConfig();
        // chainIdToNetworkConfig[31337] = getAnvilConfig();

        activeNetworkConfig = chainIdToNetworkConfig[block.chainid];
    }

    function getActiveNetworkConfig()
        public
        view
        returns (NetworkConfig memory)
    {
        return activeNetworkConfig;
    }

    function getMainnetForkConfig()
        internal
        pure
        returns (NetworkConfig memory mainnetNetworkConfig)
    {
        mainnetNetworkConfig = NetworkConfig({
            nonfungiblePositionManager: 0xC36442b4a4522E871399CD717aBDD847Ab11FE88,
            swapRouter: 0xE592427A0AEce92De3Edee1F18E0157C05861564,
            liquidityPoolFactoryUniswapV3: 0x1F98431c8aD98523631AE4a59f267346ea31F984,
            addGBPT: 0x86B4dBE5D203e634a12364C0e428fa242A3FbA98,
            addAGEUR: 0x1aBaEA1f7C830bD89Acc67eC4af516284b1bC33c,
            addUSDC: 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48
        });
    }
}
