// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { GROVE } from "../src/GROVE.sol";
import { L2TokenDeployBase } from "./base/L2TokenDeployBase.sol";

/**
 * @title DeployGROVE
 * @dev GROVE Token deployment script using the base class
 */
contract DeployGROVE is L2TokenDeployBase {
    function getTokenImplementation() internal override returns (address) {
        return address(new GROVE());
    }

    function getTokenSymbol() internal pure override returns (string memory) {
        return "GROVE";
    }
}
