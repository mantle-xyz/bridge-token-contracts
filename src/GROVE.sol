// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { L2UpgradeableERC20 } from "./L2UpgradeableERC20.sol";

/**
 * @title L2GROVEToken
 * @dev L2GROVEToken implementation of L2UpgradeableERC20 for Grove (GROVE).
 *      Uses the default 18 decimals from ERC20Upgradeable, matching the L1 GROVE token.
 */
contract GROVE is L2UpgradeableERC20 {
    /**
     * @notice Initialize the contract with GROVE specific parameters.
     * @param _bridge L2 Bridge address
     * @param _remoteToken L1 Token address
     * @param _admin Admin address for roles
     */
    function initialize(address _bridge, address _remoteToken, address _admin) public initializer {
        __L2UpgradeableERC20_init("Grove", "GROVE", _bridge, _remoteToken, _admin);
    }
}
