// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script, console2 as console } from "forge-std/Script.sol";
import { L2UpgradeableERC20 } from "../../src/L2UpgradeableERC20.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title L2TokenUpgradeBase
 * @dev Base upgrade script for all L2UpgradeableERC20 tokens
 * @notice Inherit this and implement getNewImplementation() + getTokenSymbol()
 *
 * Example Usage:
 * ```
 * // V2 implementation
 * contract XAUtV2 is XAUt {
 *     function version() public pure returns (string memory) {
 *         return "v2";
 *     }
 * }
 *
 * contract UpgradeXAUt is L2TokenUpgradeBase {
 *     function getNewImplementation() internal override returns (address) {
 *         return address(new XAUtV2());
 *     }
 *
 *     function getTokenSymbol() internal pure override returns (string memory) {
 *         return "XAUt";
 *     }
 * }
 * ```
 *
 * Usage:
 * Step 1: Deploy new implementation and schedule upgrade
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "step1_ScheduleUpgrade(address,address)" \
 *   $PROXY_ADDR $TIMELOCK_ADDR \
 *   --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 *
 * Step 2: Execute upgrade after timelock delay
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "step2_ExecuteUpgrade(address,address,address,bytes32)" \
 *   $PROXY_ADDR $TIMELOCK_ADDR $NEW_IMPL $SALT \
 *   --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
abstract contract L2TokenUpgradeBase is Script {
    // =============================================================
    //                  ABSTRACT METHODS
    // =============================================================

    /**
     * @dev Return new implementation address
     * @return New implementation address
     */
    function getNewImplementation() internal virtual returns (address);

    /**
     * @dev Return token symbol for logging
     * @return Token symbol for logging
     */
    function getTokenSymbol() internal view virtual returns (string memory);

    // =============================================================
    //                      UPGRADE STEPS
    // =============================================================

    /**
     * @notice Step 1: Deploy new implementation and schedule upgrade via Timelock
     * @param proxyAddr Token Proxy address
     * @param timelockAddr Timelock address
     * @return operationId The operation ID for tracking
     * @dev This function deploys new implementation and schedules the upgrade
     */
    function step1_ScheduleUpgrade(address proxyAddr, address timelockAddr) external returns (bytes32) {
        console.log("==============================================");
        console.log("[Upgrade Step 1] Deploy & Schedule");
        console.log("Token:      ", getTokenSymbol());
        console.log("Proxy:      ", proxyAddr);
        console.log("Timelock:   ", timelockAddr);
        console.log("==============================================");

        vm.startBroadcast();

        // 1. Deploy new implementation
        address newImplementation = getNewImplementation();
        console.log("\nNew Implementation deployed at:", newImplementation);

        // 2. Prepare upgrade call data
        bytes memory upgradeCallData = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, "");

        // 3. Calculate operation ID
        bytes32 salt = keccak256(abi.encodePacked(getTokenSymbol(), "-Upgrade-", block.timestamp));
        bytes32 operationId = TimelockController(payable(timelockAddr)).hashOperation(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        console.log("\nOperation ID:", vm.toString(operationId));
        console.log("Salt:        ", vm.toString(salt));

        // 4. Get min delay
        uint256 minDelay = TimelockController(payable(timelockAddr)).getMinDelay();
        console.log("Min Delay:   ", minDelay, "seconds");
        console.log("             (", minDelay / 3600, "hours )");

        // 5. Prepare schedule calldata for multisig
        bytes memory scheduleCallData = abi.encodeWithSignature(
            "schedule(address,uint256,bytes,bytes32,bytes32,uint256)",
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt, // salt
            minDelay // delay
        );

        console.log("\n==============================================");
        console.log("MULTISIG CALLDATA FOR SCHEDULING:");
        console.log("==============================================");
        console.log("Target (Timelock):", timelockAddr);
        console.log("Value:            ", "0");
        console.log("Calldata:");
        console.logBytes(scheduleCallData);
        console.log("==============================================");

        // 6. Schedule the upgrade
        TimelockController(payable(timelockAddr)).schedule(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt, // salt
            minDelay // delay
        );

        console.log("\n-> Upgrade scheduled successfully");
        console.log("-> Execute after:", block.timestamp + minDelay);

        vm.stopBroadcast();

        console.log("\n==============================================");
        console.log("Step 1 Complete!");
        console.log("==============================================");
        console.log("\nIf using multisig:");
        console.log("1. Copy the MULTISIG CALLDATA above");
        console.log("2. Submit to multisig wallet (e.g., Safe)");
        console.log("3. Target: Timelock address");
        console.log("4. Value: 0");
        console.log("5. Data: The calldata shown above");
        console.log("\nNext Step:");
        console.log("Wait for", minDelay, "seconds");
        console.log("         (", minDelay / 3600, "hours )");
        console.log("Then run step2_ExecuteUpgrade with:");
        console.log("  Proxy:          ", proxyAddr);
        console.log("  Timelock:       ", timelockAddr);
        console.log("  New Impl:       ", newImplementation);
        console.log("  Salt:           ", vm.toString(salt));
        console.log("==============================================");

        return operationId;
    }

    /**
     * @notice Step 2: Execute the scheduled upgrade
     * @param proxyAddr Token Proxy address
     * @param timelockAddr Timelock address
     * @param newImplementation New implementation address
     * @param salt Salt used in schedule (must match step1)
     * @dev Must be called after timelock delay has passed
     */
    function step2_ExecuteUpgrade(
        address proxyAddr,
        address timelockAddr,
        address newImplementation,
        bytes32 salt
    )
        external
    {
        console.log("==============================================");
        console.log("[Upgrade Step 2] Execute");
        console.log("Token:              ", getTokenSymbol());
        console.log("Proxy:              ", proxyAddr);
        console.log("Timelock:           ", timelockAddr);
        console.log("New Implementation: ", newImplementation);
        console.log("==============================================");

        // Prepare upgrade call data
        bytes memory upgradeCallData = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, "");

        // Calculate operation ID
        bytes32 operationId = TimelockController(payable(timelockAddr)).hashOperation(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        console.log("\nOperation ID:", vm.toString(operationId));

        // Check if ready
        TimelockController timelock = TimelockController(payable(timelockAddr));
        bool isPending = timelock.isOperationPending(operationId);
        bool isReady = timelock.isOperationReady(operationId);
        bool isDone = timelock.isOperationDone(operationId);

        console.log("Is Pending:  ", isPending);
        console.log("Is Ready:    ", isReady);
        console.log("Is Done:     ", isDone);

        require(isReady, "Operation is not ready yet");
        require(!isDone, "Operation already executed");

        // Prepare execute calldata for multisig
        bytes memory executeCallData = abi.encodeWithSignature(
            "execute(address,uint256,bytes,bytes32,bytes32)",
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        console.log("\n==============================================");
        console.log("MULTISIG CALLDATA FOR EXECUTION:");
        console.log("==============================================");
        console.log("Target (Timelock):", timelockAddr);
        console.log("Value:            ", "0");
        console.log("Calldata:");
        console.logBytes(executeCallData);
        console.log("==============================================");

        vm.startBroadcast();

        // Execute the upgrade
        timelock.execute(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        console.log("\n-> Upgrade executed successfully");

        vm.stopBroadcast();

        // Verify upgrade
        L2UpgradeableERC20 proxy = L2UpgradeableERC20(proxyAddr);
        console.log("\n==============================================");
        console.log("Verifying upgrade...");
        console.log("Proxy name:   ", proxy.name());
        console.log("Proxy symbol: ", proxy.symbol());
        console.log("Proxy bridge: ", proxy.bridge());

        console.log("\n==============================================");
        console.log("Step 2 Complete!");
        console.log("Upgrade successful!");
        console.log("==============================================");
        console.log("\nIf using multisig:");
        console.log("The MULTISIG CALLDATA shown above can be used");
        console.log("to execute this upgrade via multisig wallet.");
        console.log("==============================================");
    }

    /**
     * @notice Helper: Check if upgrade is ready to execute
     * @param timelockAddr Timelock address
     * @param operationId Operation ID from step1
     */
    function checkUpgradeStatus(address timelockAddr, bytes32 operationId) external view {
        TimelockController timelock = TimelockController(payable(timelockAddr));

        console.log("==============================================");
        console.log("Upgrade Status Check");
        console.log("Token:       ", getTokenSymbol());
        console.log("Timelock:    ", timelockAddr);
        console.log("Operation ID:", vm.toString(operationId));
        console.log("==============================================");

        bool isPending = timelock.isOperationPending(operationId);
        bool isReady = timelock.isOperationReady(operationId);
        bool isDone = timelock.isOperationDone(operationId);
        uint256 timestamp = timelock.getTimestamp(operationId);

        console.log("\nIs Pending:  ", isPending);
        console.log("Is Ready:    ", isReady);
        console.log("Is Done:     ", isDone);
        console.log("Timestamp:   ", timestamp);
        console.log("Current:     ", block.timestamp);

        if (isPending && !isReady) {
            uint256 remainingTime = timestamp - block.timestamp;
            console.log("\nWait for:    ", remainingTime, "seconds");
            console.log("             (", remainingTime / 3600, "hours )");
        } else if (isReady) {
            console.log("\nStatus: READY TO EXECUTE");
        } else if (isDone) {
            console.log("\nStatus: ALREADY EXECUTED");
        } else {
            console.log("\nStatus: UNKNOWN");
        }

        console.log("==============================================");
    }
}
