// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Test, console } from "forge-std/Test.sol";
import { L2UpgradeableERC20 } from "../src/L2UpgradeableERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title L2TokenTestBase
 * @dev Base test contract for all L2UpgradeableERC20 tokens
 * @notice Inherit this and implement getTokenContract() + getTokenMetadata() + getV2Implementation()
 *
 * Example Usage:
 * ```
 * // V2 implementation for upgrade test
 * contract MyTokenV2 is MyToken {
 *     function version() public pure returns (string memory) {
 *         return "v2";
 *     }
 * }
 *
 * contract MyTokenTest is L2TokenTestBase {
 *     function getTokenContract() internal override returns (address) {
 *         return address(new MyToken());
 *     }
 *
 *     function getTokenMetadata()
 *         internal
 *         pure
 *         override
 *         returns (string memory, string memory, uint8)
 *     {
 *         return ("My Token", "MTK", 18);
 *     }
 *
 *     function getV2Implementation() internal override returns (address) {
 *         return address(new MyTokenV2());
 *     }
 *
 *     // Optional: Add token-specific tests
 *     // function test_CustomFeature() public { ... }
 * }
 * ```
 *
 * Provided Tests:
 * - test_Initialization: Validates initial setup and roles
 * - test_MintBurn_BridgeOnly: Tests mint/burn permissions
 * - test_PauseLogic: Tests pause/unpause functionality
 * - test_BlocklistLogic: Tests blocklist add/remove
 * - test_TimelockUpgradeFlow: Tests complete upgrade flow with timelock
 */
abstract contract L2TokenTestBase is Test {
    L2UpgradeableERC20 public token;
    address public implementation;
    address public proxy;

    address public deployer = makeAddr("deployer");
    address public bridge = makeAddr("bridge");
    address public remoteToken = makeAddr("remoteToken");
    address public multisig = makeAddr("multisig");
    address public user1 = makeAddr("user1");
    address public user2 = makeAddr("user2");

    // Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant BRIDGE_ROLE = keccak256("BRIDGE_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant BLOCKLIST_MANAGER_ROLE = keccak256("BLOCKLIST_MANAGER_ROLE");

    // =============================================================
    //                      ABSTRACT METHODS
    // =============================================================

    /**
     * @dev Return token implementation address
     * @return Token implementation address
     */
    function getTokenContract() internal virtual returns (address);

    /**
     * @dev Return token metadata (name, symbol, decimals)
     * @return name Token name
     * @return symbol Token symbol
     * @return decimals Token decimals
     */
    function getTokenMetadata()
        internal
        view
        virtual
        returns (string memory name, string memory symbol, uint8 decimals);

    /**
     * @dev Return V2 implementation for upgrade test
     * @return V2 implementation address
     */
    function getV2Implementation() internal virtual returns (address);

    // =============================================================
    //                           SETUP
    // =============================================================

    function setUp() public virtual {
        vm.startPrank(deployer);

        // 1. Deploy Implementation
        implementation = getTokenContract();

        // 2. Deploy Proxy and Initialize
        bytes memory initData =
            abi.encodeWithSignature("initialize(address,address,address)", bridge, remoteToken, deployer);
        proxy = address(new ERC1967Proxy(implementation, initData));
        token = L2UpgradeableERC20(proxy);

        vm.stopPrank();
    }

    // =============================================================
    //                        STANDARD TESTS
    // =============================================================

    function test_Initialization() public view {
        (string memory expectedName, string memory expectedSymbol, uint8 expectedDecimals) = getTokenMetadata();

        assertEq(token.name(), expectedName);
        assertEq(token.symbol(), expectedSymbol);
        assertEq(token.decimals(), expectedDecimals);
        assertEq(token.bridge(), bridge);
        assertEq(token.remoteToken(), remoteToken);

        // Check roles
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, deployer));
        assertTrue(token.hasRole(UPGRADER_ROLE, deployer));
        assertTrue(token.hasRole(BRIDGE_ROLE, bridge));
    }

    function test_MintBurn_BridgeOnly() public {
        // Bridge can mint
        vm.prank(bridge);
        token.mint(user1, 1000);
        assertEq(token.balanceOf(user1), 1000);

        // Bridge can burn
        vm.prank(bridge);
        token.burn(user1, 500);
        assertEq(token.balanceOf(user1), 500);

        // Others cannot mint
        vm.prank(user1);
        vm.expectRevert();
        token.mint(user1, 1000);
    }

    function test_PauseLogic() public {
        // Setup Pauser
        vm.prank(deployer);
        token.grantRole(PAUSER_ROLE, multisig);

        // Mint some tokens before pause
        vm.prank(bridge);
        token.mint(user1, 1000);

        // Pause
        vm.prank(multisig);
        token.pause();
        assertTrue(token.paused());

        // 1. Normal transfer should fail
        vm.prank(user1);
        vm.expectRevert("L2Token: token transfer while paused");
        token.transfer(user2, 100);

        // 2. Minting (Bridge Deposit) should ALSO fail when paused
        vm.prank(bridge);
        vm.expectRevert("L2Token: token transfer while paused");
        token.mint(user1, 100);

        // Unpause
        vm.prank(multisig);
        token.unpause();

        // Transfer should work now
        vm.prank(user1);
        token.transfer(user2, 100);
        assertEq(token.balanceOf(user2), 100);

        // Minting should work now
        vm.prank(bridge);
        token.mint(user1, 100);
        assertEq(token.balanceOf(user1), 1000); // 1000 start - 100 sent + 100 mint = 1000
    }

    function test_BlocklistLogic() public {
        // Setup Blocklist Manager
        vm.prank(deployer);
        token.grantRole(BLOCKLIST_MANAGER_ROLE, multisig);

        vm.prank(bridge);
        token.mint(user1, 1000);

        // Block User1
        vm.prank(multisig);
        token.addToBlockedList(user1);
        assertTrue(token.isBlocked(user1));

        // 1. User1 cannot transfer
        vm.prank(user1);
        vm.expectRevert("L2Token: sender is blocked");
        token.transfer(user2, 100);

        // 2. User2 cannot transfer TO User1
        vm.prank(bridge);
        token.mint(user2, 1000);

        vm.prank(user2);
        vm.expectRevert("L2Token: receiver is blocked");
        token.transfer(user1, 100);

        // Unblock
        vm.prank(multisig);
        token.removeFromBlockedList(user1);

        // Transfer works
        vm.prank(user1);
        token.transfer(user2, 100);
    }

    function test_TimelockUpgradeFlow() public {
        // 1. Deploy Timelock
        address[] memory proposers = new address[](1);
        proposers[0] = multisig;
        address[] memory executors = new address[](1);
        executors[0] = multisig;

        vm.prank(deployer);
        TimelockController timelock = new TimelockController(24 hours, proposers, executors, address(0)); // min delay

        // 2. Transfer Admin/Upgrader Roles to Timelock
        vm.startPrank(deployer);
        token.grantRole(UPGRADER_ROLE, address(timelock));
        token.grantRole(DEFAULT_ADMIN_ROLE, address(timelock));
        token.renounceRole(UPGRADER_ROLE, deployer);
        token.renounceRole(DEFAULT_ADMIN_ROLE, deployer);
        vm.stopPrank();

        // Verify Roles
        assertTrue(token.hasRole(DEFAULT_ADMIN_ROLE, address(timelock)));
        assertFalse(token.hasRole(DEFAULT_ADMIN_ROLE, deployer));

        // 3. Prepare Upgrade
        address newImpl = getV2Implementation();
        bytes memory upgradeCallData = abi.encodeWithSelector(token.upgradeToAndCall.selector, newImpl, "");

        // 4. Try to upgrade directly (should fail)
        vm.prank(deployer);
        vm.expectRevert();
        token.upgradeToAndCall(newImpl, "");

        // 5. Schedule via Timelock (Proposer: multisig)
        vm.prank(multisig);
        timelock.schedule(
            address(token), // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            bytes32("salt"), // salt
            24 hours // delay
        );

        // 6. Try Execute too early (should fail)
        vm.prank(multisig);
        // TimelockController: operation is not ready
        vm.expectRevert();
        timelock.execute(address(token), 0, upgradeCallData, bytes32(0), bytes32("salt"));

        // 7. Wait for timelock delay
        vm.warp(block.timestamp + 24 hours + 1);

        // 8. Execute (Executor: multisig)
        vm.prank(multisig);
        timelock.execute(address(token), 0, upgradeCallData, bytes32(0), bytes32("salt"));

        // 9. Verify upgrade succeeded
        // State should be preserved
        (string memory expectedName, string memory expectedSymbol,) = getTokenMetadata();
        assertEq(token.name(), expectedName);
        assertEq(token.symbol(), expectedSymbol);
        assertEq(token.bridge(), bridge);
        assertEq(token.remoteToken(), remoteToken);
    }
}
