// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { XAUt } from "../src/XAUt.sol";
import { L2TokenDeployBase } from "./base/L2TokenDeployBase.sol";

/**
 * @title DeployXAUt
 * @dev XAUt Token deployment script using the base class
 * @notice This is a simplified version - only ~15 lines of code!
 */
contract DeployXAUt is L2TokenDeployBase {
    function getTokenImplementation() internal override returns (address) {
        return address(new XAUt());
    }

    function getTokenSymbol() internal pure override returns (string memory) {
        return "XAUt";
    }
}
