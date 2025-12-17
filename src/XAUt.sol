// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { L2UpgradableERC20 } from "./L2UpgradableERC20.sol";

/**
 * @title L2XAUtToken
 * @dev L2XAUtToken implementation of L2UpgradableERC20 for Tether Gold (XAUt).
 */
contract XAUt is L2UpgradableERC20 {
    /**
     * @notice Initialize the contract with XAUt specific parameters.
     * @param _bridge L2 Bridge address
     * @param _remoteToken L1 Token address
     * @param _admin Admin address for roles
     */
    function initialize(address _bridge, address _remoteToken, address _admin) public initializer {
        __L2UpgradableERC20_init("Tether Gold", "XAUt", _bridge, _remoteToken, _admin);
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * Override to return 6 for XAUt.
     */
    function decimals() public view virtual override returns (uint8) {
        return 6;
    }
}
