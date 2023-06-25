// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

import "../../../lib/forge-std/src/Test.sol";
import "../../../lib/solmate/src/tokens/ERC20.sol";

contract Utils is Test {
    using stdStorage for StdStorage;

    function writeTokenBalance(address who, address token, uint256 amt) public {
        stdstore
            .target(token)
            .sig(ERC20(token).balanceOf.selector)
            .with_key(who)
            .checked_write(amt);
    }

    function addToId(address a) public pure returns (uint256) {
        return uint256(uint160(a));
    }

    function abs(int x) private pure returns (int) {
        return x >= 0 ? x : -x;
    }
}
