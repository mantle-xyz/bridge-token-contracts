// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { L2StandardERC20 } from "./L2StandardERC20.sol";

contract ERC20Bridged is L2StandardERC20 {
    constructor(
      address _l2Bridge,
      address _l1Token
    )
    L2StandardERC20(_l2Bridge, _l1Token, "Wrapped Token", "WT", 18)
    {
    }
}