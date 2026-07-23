// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GROVE } from "../src/GROVE.sol";
import { L2TokenTestBase } from "./L2TokenTestBase.sol";

/**
 * @title GROVEV2
 * @dev V2 implementation for upgrade test
 */
contract GROVEV2 is GROVE {
    function version() public pure returns (string memory) {
        return "v2";
    }
}

/**
 * @title GROVETest
 * @dev GROVE token test using base class
 */
contract GROVETest is L2TokenTestBase {
    function getTokenContract() internal override returns (address) {
        return address(new GROVE());
    }

    function getTokenMetadata()
        internal
        pure
        override
        returns (string memory name, string memory symbol, uint8 decimals)
    {
        return ("Grove", "GROVE", 18);
    }

    function getV2Implementation() internal override returns (address) {
        return address(new GROVEV2());
    }
}
