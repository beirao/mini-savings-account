// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "forge-std/Test.sol";
import "@solmate/tokens/ERC20.sol";

import "@solmate/utils/FixedPointMathLib.sol";
import {UniswapV3Pool} from "@uniswapCore/contracts/UniswapV3Pool.sol";
import "@uniswapCore/contracts/libraries/FullMath.sol";
import "@uniswapPeriphery/contracts/libraries/TransferHelper.sol";
import "@uniswapPeriphery/contracts/interfaces/INonfungiblePositionManager.sol";
import "@uniswapPeriphery/contracts/interfaces/ISwapRouter.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

//! This contract do not implement slippage protection (To not be used in production)
contract UniswapV3Helper is IERC721Receiver {
    using FixedPointMathLib for uint256;
    ISwapRouter public immutable swapRouter;
    INonfungiblePositionManager public immutable nonfungiblePositionManager;

    /// @notice Represents the deposit of an NFT
    struct Deposit {
        address owner;
        uint128 liquidity;
        address token0;
        address token1;
    }

    /// @dev deposits[tokenId] => Deposit
    mapping(uint256 => Deposit) public deposits;

    constructor(address _nonfungiblePositionManager, address _swapRouter) {
        nonfungiblePositionManager = INonfungiblePositionManager(
            _nonfungiblePositionManager
        );
        swapRouter = ISwapRouter(_swapRouter);
    }

    // ------ SWAP ------

    /**
     * @notice Swap exact amount of token0 for token1
     * @param _token0 The address of token0 (input)
     * @param _token1 The address of token1 (output)
     * @param _fee The fee tier of the pool
     * @param _amountIn The amount of token0 to swap
     */
    function swapExactInputSingle(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 _amountIn,
        uint256 _amountOutMinimum
    ) public returns (uint256 amountOut_) {
        TransferHelper.safeTransferFrom(
            _token0,
            msg.sender,
            address(this),
            _amountIn
        );
        TransferHelper.safeApprove(_token0, address(swapRouter), _amountIn);

        ISwapRouter.ExactInputSingleParams memory params = ISwapRouter
            .ExactInputSingleParams({
                tokenIn: _token0,
                tokenOut: _token1,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountIn: _amountIn,
                amountOutMinimum: _amountOutMinimum,
                // NOTE: In production, this value can be used to set the limit
                // for the price the swap will push the pool to,
                // which can help protect against price impact
                sqrtPriceLimitX96: 0
            });
        amountOut_ = swapRouter.exactInputSingle(params);
    }

    /**
     * @notice swap a variable amount of token0 for a fixed amount of token1
     * @param _token0 The address of token0 (input)
     * @param _token1 The address of token1 (output)
     * @param _fee The fee tier of the pool
     * @param _amountOut The exact amount of token1 to receive
     * @param _amountInMaximum The maximum amount of token0 to spend
     */
    function swapExactOutputSingle(
        address _token0,
        address _token1,
        uint24 _fee,
        uint256 _amountOut,
        uint256 _amountInMaximum
    ) public returns (uint256 amountIn_) {
        TransferHelper.safeTransferFrom(
            _token0,
            msg.sender,
            address(this),
            _amountInMaximum
        );
        TransferHelper.safeApprove(
            _token0,
            address(swapRouter),
            _amountInMaximum
        );

        ISwapRouter.ExactOutputSingleParams memory params = ISwapRouter
            .ExactOutputSingleParams({
                tokenIn: _token0,
                tokenOut: _token1,
                fee: _fee,
                recipient: msg.sender,
                deadline: block.timestamp,
                amountOut: _amountOut,
                amountInMaximum: _amountInMaximum,
                sqrtPriceLimitX96: 0
            });

        try swapRouter.exactOutputSingle(params) returns (uint256 amountIn__) {
            amountIn_ = amountIn__;
            if (amountIn_ < _amountInMaximum) {
                // Reset approval on router
                TransferHelper.safeApprove(_token0, address(swapRouter), 0);
                // Refund _token0 to user
                TransferHelper.safeTransfer(
                    _token0,
                    msg.sender,
                    _amountInMaximum - amountIn_
                );
            }
        } catch {
            amountIn_ = 0; // So if the value return == 0 => the swap failed
            TransferHelper.safeTransfer(_token0, msg.sender, _amountInMaximum);
        }
    }

    // ----- Liquidity -----

    // Implementing `onERC721Received` so this contract can receive custody of erc721 tokens
    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        // get position information

        _createDeposit(operator, tokenId);

        return this.onERC721Received.selector;
    }

    function _createDeposit(address owner, uint256 tokenId) internal {
        (
            ,
            ,
            address token0,
            address token1,
            ,
            ,
            ,
            uint128 liquidity,
            ,
            ,
            ,

        ) = nonfungiblePositionManager.positions(tokenId);

        // set the owner and data for position
        // operator is msg.sender
        deposits[tokenId] = Deposit({
            owner: owner,
            liquidity: liquidity,
            token0: token0,
            token1: token1
        });
    }

    /// @notice Calls the mint function defined in periphery, mints the same amount of each token.
    /// For this example we are providing 1000 DAI and 1000 USDC in liquidity
    /// @return tokenId_ The id of the newly minted ERC721
    /// @return liquidity_ The amount of liquidity for the position
    /// @return amount0_ The amount of token0
    /// @return amount1_ The amount of token1
    function mintPosition(
        UniswapV3Pool _v3Pool,
        uint256 _amount0ToMint,
        uint256 _amount1ToMint,
        int24 _tickLower,
        int24 _tickUpper
    )
        external
        returns (
            uint256 tokenId_,
            uint128 liquidity_,
            uint256 amount0_,
            uint256 amount1_
        )
    {
        if (_amount0ToMint != 0) {
            TransferHelper.safeTransferFrom(
                _v3Pool.token0(),
                msg.sender,
                address(this),
                _amount0ToMint
            );
            TransferHelper.safeApprove(
                _v3Pool.token0(),
                address(nonfungiblePositionManager),
                _amount0ToMint
            );
        }
        if (_amount1ToMint != 0) {
            TransferHelper.safeTransferFrom(
                _v3Pool.token1(),
                msg.sender,
                address(this),
                _amount1ToMint
            );
            TransferHelper.safeApprove(
                _v3Pool.token1(),
                address(nonfungiblePositionManager),
                _amount1ToMint
            );
        }

        INonfungiblePositionManager.MintParams
            memory params_ = INonfungiblePositionManager.MintParams({
                token0: _v3Pool.token0(),
                token1: _v3Pool.token1(),
                fee: _v3Pool.fee(),
                tickLower: _tickLower,
                tickUpper: _tickUpper,
                amount0Desired: _amount0ToMint,
                amount1Desired: _amount1ToMint,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            });

        // Note that the pool defined by DAI/USDC and fee tier 0.3% must already be created and initialized in order to mint
        (tokenId_, liquidity_, amount0_, amount1_) = nonfungiblePositionManager
            .mint(params_);
        _createDeposit(msg.sender, tokenId_);

        // Remove allowance and refund in both assets.
        if (amount0_ < _amount0ToMint) {
            TransferHelper.safeApprove(
                _v3Pool.token0(),
                address(nonfungiblePositionManager),
                0
            );
            uint refund0_ = _amount0ToMint - amount0_;
            TransferHelper.safeTransfer(_v3Pool.token0(), msg.sender, refund0_);
        }

        if (amount1_ < _amount1ToMint) {
            TransferHelper.safeApprove(
                _v3Pool.token1(),
                address(nonfungiblePositionManager),
                0
            );
            uint refund1_ = _amount1ToMint - amount1_;
            TransferHelper.safeTransfer(_v3Pool.token1(), msg.sender, refund1_);
        }
    }

    /// @notice Collects the fees associated with provided liquidity
    /// @dev The contract must hold the erc721 token before it can collect fees
    /// @param _tokenId The id of the erc721 token
    /// @return amount0_ The amount of fees collected in token0
    /// @return amount1_ The amount of fees collected in token1
    function collectAllFees(
        uint256 _tokenId
    ) external returns (uint256 amount0_, uint256 amount1_) {
        // Caller must own the ERC721 position, meaning it must be a deposit

        // set amount0Max and amount1Max to uint256.max to collect all fees
        // alternatively can set recipient to msg.sender and avoid another transaction in `sendToOwner`
        INonfungiblePositionManager.CollectParams
            memory params_ = INonfungiblePositionManager.CollectParams({
                tokenId: _tokenId,
                recipient: address(this),
                amount0Max: type(uint128).max,
                amount1Max: type(uint128).max
            });

        (amount0_, amount1_) = nonfungiblePositionManager.collect(params_);

        // send collected feed back to owner
        _sendToOwner(_tokenId, amount0_, amount1_);
    }

    /// @notice A function that decreases the current liquidity by half. An example to show how to call the `decreaseLiquidity` function defined in periphery.
    /// @param _tokenId The id of the erc721 token
    /// @return amount0_ The amount received back in token0
    /// @return amount1_ The amount returned back in token1
    function decreaseLiquidity(
        uint256 _tokenId
    ) external returns (uint256 amount0_, uint256 amount1_) {
        // caller must be the owner of the NFT
        require(msg.sender == deposits[_tokenId].owner, "Not the owner");
        // get liquidity data for tokenId
        uint128 liquidity = deposits[_tokenId].liquidity;

        // amount0Min and amount1Min are price slippage checks
        // if the amount received after burning is not greater than these minimums, transaction will fail
        INonfungiblePositionManager.DecreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .DecreaseLiquidityParams({
                    tokenId: _tokenId,
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (amount0_, amount1_) = nonfungiblePositionManager.decreaseLiquidity(
            params
        );

        //send liquidity back to owner
        // _sendToOwner(tokenId, amount0, amount1);
    }

    /// @notice Increases liquidity in the current range
    /// @dev Pool must be initialized already to add liquidity
    /// @param _tokenId The id of the erc721 token
    /// @param _amountAdd0 The amount to add of token0
    /// @param _amountAdd1 The amount to add of token1
    /// @return liquidity_ The amount of liquidity added
    /// @return amount0_ The amount of token0 added
    /// @return amount1_ The amount of token1 added
    function increaseLiquidityCurrentRange(
        uint256 _tokenId,
        uint256 _amountAdd0,
        uint256 _amountAdd1
    )
        external
        returns (uint128 liquidity_, uint256 amount0_, uint256 amount1_)
    {
        TransferHelper.safeTransferFrom(
            deposits[_tokenId].token0,
            msg.sender,
            address(this),
            _amountAdd0
        );
        TransferHelper.safeTransferFrom(
            deposits[_tokenId].token1,
            msg.sender,
            address(this),
            _amountAdd1
        );

        TransferHelper.safeApprove(
            deposits[_tokenId].token0,
            address(nonfungiblePositionManager),
            _amountAdd0
        );
        TransferHelper.safeApprove(
            deposits[_tokenId].token1,
            address(nonfungiblePositionManager),
            _amountAdd1
        );

        INonfungiblePositionManager.IncreaseLiquidityParams
            memory params = INonfungiblePositionManager
                .IncreaseLiquidityParams({
                    tokenId: _tokenId,
                    amount0Desired: _amountAdd0,
                    amount1Desired: _amountAdd1,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                });

        (liquidity_, amount0_, amount1_) = nonfungiblePositionManager
            .increaseLiquidity(params);
    }

    /// @notice Transfers funds to owner of NFT
    /// @param _tokenId The id of the erc721
    /// @param _amount0 The amount of token0
    /// @param _amount1 The amount of token1
    function _sendToOwner(
        uint256 _tokenId,
        uint256 _amount0,
        uint256 _amount1
    ) internal {
        // get owner of contract
        address owner_ = deposits[_tokenId].owner;

        address token0_ = deposits[_tokenId].token0;
        address token1_ = deposits[_tokenId].token1;
        // send collected fees to owner
        TransferHelper.safeTransfer(token0_, owner_, _amount0);
        TransferHelper.safeTransfer(token1_, owner_, _amount1);
    }

    /// @notice Transfers the NFT to the owner
    /// @param _tokenId The id of the erc721
    function retrieveNFT(uint256 _tokenId) external {
        // must be the owner of the NFT
        require(msg.sender == deposits[_tokenId].owner, "Not the owner");
        // transfer ownership to original owner
        nonfungiblePositionManager.safeTransferFrom(
            address(this),
            msg.sender,
            _tokenId
        );
        //remove information related to tokenId
        delete deposits[_tokenId];
    }

    function getLiquidity(uint _tokenId) public view returns (uint128) {
        (, , , , , , , uint128 liquidity_, , , , ) = nonfungiblePositionManager
            .positions(_tokenId);
        return liquidity_;
    }

    // ----- Maths -----

    function sqrtPriceX96ToPrice(
        uint160 _sqrtPriceX96,
        uint8 _decimalsToken0
    ) public pure returns (uint160) {
        return
            uint160(
                FullMath.mulDiv(
                    uint256(_sqrtPriceX96) * uint256(_sqrtPriceX96),
                    10 ** _decimalsToken0,
                    (1 << 192)
                )
            );
    }

    function priceToSqrtPriceX96(
        uint160 _price,
        uint8 _decimalsToken0
    ) public pure returns (uint160) {
        return
            uint160(
                FullMath.mulDiv(
                    FixedPointMathLib.sqrt(uint256(_price)),
                    1 << 96,
                    (10 ** (_decimalsToken0 >> 1))
                )
            );
    }
}
