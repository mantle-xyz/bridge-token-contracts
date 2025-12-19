// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { XAUt } from "../src/XAUt.sol";
import { L2TokenUpgradeBase } from "./base/L2TokenUpgradeBase.sol";

// V2 implementation for upgrade test
contract XAUtV2 is XAUt {
    function version() public pure returns (string memory) {
        return "v2";
    }
}

/**
 * @title UpgradeXAUt
 * @dev XAUt Token upgrade script using the base class
 */
contract UpgradeXAUt is L2TokenUpgradeBase {
    function getNewImplementation() internal override returns (address) {
        return address(new XAUtV2());
    }

    function getTokenSymbol() internal pure override returns (string memory) {
        return "XAUt";
    }
}
