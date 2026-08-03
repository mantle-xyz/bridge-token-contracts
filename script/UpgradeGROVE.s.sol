// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GROVE } from "../src/GROVE.sol";
import { L2TokenUpgradeBase } from "./base/L2TokenUpgradeBase.sol";

// V2 implementation for upgrade test
contract GROVEV2 is GROVE {
    function version() public pure returns (string memory) {
        return "v2";
    }
}

/**
 * @title UpgradeGROVE
 * @dev GROVE Token upgrade script using the base class
 */
contract UpgradeGROVE is L2TokenUpgradeBase {
    function getNewImplementation() internal override returns (address) {
        return address(new GROVEV2());
    }

    function getTokenSymbol() internal pure override returns (string memory) {
        return "GROVE";
    }
}
