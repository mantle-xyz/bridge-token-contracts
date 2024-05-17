// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import {Script} from 'forge-std/Script.sol';

import {L2StandardERC20} from "src/L2StandardERC20.sol";

contract Deploy is Script {

  /// @notice The main script entrypoint
  /// @return wt The deployed contract
  function run() external returns (L2StandardERC20 wt) {
    vm.startBroadcast();
    wt = new L2StandardERC20(
      0x4200000000000000000000000000000000000010,
      0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49,
      "Wrapped Token",
      "WT",
      18
    );
    vm.stopBroadcast();
  }
}