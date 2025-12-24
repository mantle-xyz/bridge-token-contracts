// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { XAUt } from "../src/XAUt.sol";
import { L2TokenTestBase } from "./L2TokenTestBase.sol";

/**
 * @title XAUtV2
 * @dev V2 implementation for upgrade test
 */
contract XAUtV2 is XAUt {
    function version() public pure returns (string memory) {
        return "v2";
    }
}

/**
 * @title XAUtTest
 * @dev XAUt token test using base class
 * @notice This demonstrates how simple it is to test a token using the base class
 */
contract XAUtTest is L2TokenTestBase {
    function getTokenContract() internal override returns (address) {
        return address(new XAUt());
    }

    function getTokenMetadata()
        internal
        pure
        override
        returns (string memory name, string memory symbol, uint8 decimals)
    {
        return ("Tether Gold", "XAUt", 6);
    }

    function getV2Implementation() internal override returns (address) {
        return address(new XAUtV2());
    }
}
