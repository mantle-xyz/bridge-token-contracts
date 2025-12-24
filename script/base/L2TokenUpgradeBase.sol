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
 * Modular Functions:
 * 1. deployNewImplementation()           - Deploy new implementation contract
 * 2. generateCalldata(...)               - Generate schedule & execute calldata (view, no private key)
 * 3. executeSchedule(...)                - Execute schedule operation (requires PROPOSER_ROLE)
 * 4. executeUpgrade(...)                 - Execute upgrade operation (requires EXECUTOR_ROLE)
 *
 * Usage Examples:
 *
 * A. Multisig Workflow (RECOMMENDED):
 *
 * Step 1: Deploy implementation
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "deployNewImplementation()" \
 *   --rpc-url $RPC_URL \
 *   --broadcast \
 *   --verify \
 *   --etherscan-api-key $API_KEY
 *
 * Step 2: Generate calldata (no private key!)
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "generateCalldata(address,address,address)" \
 *   $PROXY $TIMELOCK $NEW_IMPL \
 *   --rpc-url $RPC_URL
 *
 * Step 3: Submit schedule calldata to multisig
 * Step 4: Wait for timelock delay
 * Step 5: Submit execute calldata to multisig
 *
 * B. Direct Execution (with private key):
 *
 * Step 1: Deploy implementation
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "deployNewImplementation()" \
 *   --rpc-url $RPC_URL \
 *   --broadcast
 *
 * Step 2: Execute schedule
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "executeSchedule(address,address,address,bytes32)" \
 *   $PROXY $TIMELOCK $NEW_IMPL $SALT \
 *   --rpc-url $RPC_URL \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast
 *
 * Step 3: Wait for timelock delay
 *
 * Step 4: Execute upgrade
 * forge script script/UpgradeXAUt.s.sol:UpgradeXAUt \
 *   -s "executeUpgrade(address,address,address,bytes32)" \
 *   $PROXY $TIMELOCK $NEW_IMPL $SALT \
 *   --rpc-url $RPC_URL \
 *   --private-key $PRIVATE_KEY \
 *   --broadcast
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
    //                      MODULAR FUNCTIONS
    // =============================================================

    /**
     * @notice 1. Deploy new implementation contract
     * @return newImplementation The deployed implementation address
     * @dev Call with --broadcast to deploy
     */
    function deployNewImplementation() external returns (address newImplementation) {
        console.log("==============================================");
        console.log("Deploy New Implementation");
        console.log("Token: ", getTokenSymbol());
        console.log("==============================================");

        vm.startBroadcast();
        newImplementation = getNewImplementation();
        vm.stopBroadcast();

        console.log("\n-> New Implementation:", newImplementation);
        console.log("==============================================");
        console.log("\nNext Step:");
        console.log("Call generateCalldata() with:");
        console.log("  - Proxy address");
        console.log("  - Timelock address");
        console.log("  - New Implementation:", newImplementation);
        console.log("==============================================");

        return newImplementation;
    }

    /**
     * @notice 2. Generate schedule and execute calldata for multisig
     * @param proxyAddr Token Proxy address
     * @param timelockAddr Timelock address
     * @param newImplementation New implementation address
     * @return salt The salt for operation
     * @return scheduleCallData Calldata for scheduling upgrade
     * @return executeCallData Calldata for executing upgrade
     * @dev Call WITHOUT --broadcast and --private-key (view function, no permission needed)
     */
    function generateCalldata(
        address proxyAddr,
        address timelockAddr,
        address newImplementation
    )
        external
        view
        returns (bytes32 salt, bytes memory scheduleCallData, bytes memory executeCallData)
    {
        console.log("==============================================");
        console.log("Generate Calldata for Multisig");
        console.log("Token:              ", getTokenSymbol());
        console.log("Proxy:              ", proxyAddr);
        console.log("Timelock:           ", timelockAddr);
        console.log("New Implementation: ", newImplementation);
        console.log("==============================================");

        // Prepare upgrade call data
        bytes memory upgradeCallData = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, "");

        // Calculate operation ID and salt
        salt = keccak256(abi.encodePacked(getTokenSymbol(), "-Upgrade-", block.timestamp));
        bytes32 operationId = TimelockController(payable(timelockAddr)).hashOperation(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        console.log("Operation ID:", vm.toString(operationId));
        console.log("Salt:        ", vm.toString(salt));

        // Get min delay
        uint256 minDelay = TimelockController(payable(timelockAddr)).getMinDelay();
        console.log("Min Delay:   ", minDelay, "seconds");
        console.log("             (", minDelay / 3600, "hours)");

        // Prepare schedule calldata
        scheduleCallData = abi.encodeWithSignature(
            "schedule(address,uint256,bytes,bytes32,bytes32,uint256)",
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt, // salt
            minDelay // delay
        );

        // Prepare execute calldata
        executeCallData = abi.encodeWithSignature(
            "execute(address,uint256,bytes,bytes32,bytes32)",
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        // Print schedule calldata
        console.log("==============================================");
        console.log("STEP 1: SCHEDULE UPGRADE");
        console.log("==============================================");
        console.log("Target (Timelock): ", timelockAddr);
        console.log("Value:             ", "0");
        console.log("Schedule Calldata:");
        console.logBytes(scheduleCallData);
        console.log("==============================================");

        // Print execute calldata
        console.log("==============================================");
        console.log("STEP 2: EXECUTE UPGRADE (After", minDelay, "seconds)");
        console.log("==============================================");
        console.log("Target (Timelock): ", timelockAddr);
        console.log("Value:             ", "0");
        console.log("Execute Calldata:");
        console.logBytes(executeCallData);
        console.log("==============================================");

        // Print summary
        console.log("\n==============================================");
        console.log("Summary");
        console.log("==============================================");
        console.log("New Implementation: ", newImplementation);
        console.log("Operation ID:       ", vm.toString(operationId));
        console.log("Salt:               ", vm.toString(salt));
        console.log("Min Delay:          ", minDelay, "seconds");
        console.log("                    (", minDelay / 3600, "hours)");
        console.log("Execute after:      ", block.timestamp + minDelay);
        console.log("==============================================");
        console.log("\nMultisig Workflow:");
        console.log("1. Submit 'Schedule Calldata' to multisig");
        console.log("2. Wait", minDelay, "seconds");
        console.log("   (", minDelay / 3600, "hours)");
        console.log("3. Submit 'Execute Calldata' to multisig");
        console.log("==============================================");

        return (salt, scheduleCallData, executeCallData);
    }

    /**
     * @notice 3. Execute schedule operation (requires PROPOSER_ROLE)
     * @param proxyAddr Token Proxy address
     * @param timelockAddr Timelock address
     * @param newImplementation New implementation address
     * @param salt Salt for operation (from generateCalldata or use custom)
     * @return operationId The operation ID
     * @dev Call with --broadcast and --private-key
     */
    function executeSchedule(
        address proxyAddr,
        address timelockAddr,
        address newImplementation,
        bytes32 salt
    )
        external
        returns (bytes32 operationId)
    {
        console.log("==============================================");
        console.log("Execute Schedule");
        console.log("Token:              ", getTokenSymbol());
        console.log("Proxy:              ", proxyAddr);
        console.log("Timelock:           ", timelockAddr);
        console.log("New Implementation: ", newImplementation);
        console.log("Salt:               ", vm.toString(salt));
        console.log("==============================================");

        // Prepare upgrade call data
        bytes memory upgradeCallData = abi.encodeWithSignature("upgradeToAndCall(address,bytes)", newImplementation, "");

        // Calculate operation ID
        operationId = TimelockController(payable(timelockAddr)).hashOperation(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );

        // Get min delay
        uint256 minDelay = TimelockController(payable(timelockAddr)).getMinDelay();

        console.log("\nOperation ID:", vm.toString(operationId));
        console.log("Min Delay:   ", minDelay, "seconds");
        console.log("             (", minDelay / 3600, "hours)");

        // Execute schedule
        vm.startBroadcast();
        TimelockController(payable(timelockAddr)).schedule(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt, // salt
            minDelay // delay
        );
        vm.stopBroadcast();

        console.log("\n-> Schedule executed successfully");
        console.log("-> Execute after:", block.timestamp + minDelay);
        console.log("==============================================");
        console.log("\nNext Step:");
        console.log("Wait", minDelay, "seconds");
        console.log("(", minDelay / 3600, "hours)");
        console.log("Then call executeUpgrade() with:");
        console.log("  - Proxy:    ", proxyAddr);
        console.log("  - Timelock: ", timelockAddr);
        console.log("  - New Impl: ", newImplementation);
        console.log("  - Salt:     ", vm.toString(salt));
        console.log("==============================================");

        return operationId;
    }

    /**
     * @notice 4. Execute upgrade operation (requires EXECUTOR_ROLE)
     * @param proxyAddr Token Proxy address
     * @param timelockAddr Timelock address
     * @param newImplementation New implementation address
     * @param salt Salt for operation (must match executeSchedule)
     * @dev Call with --broadcast and --private-key after timelock delay
     */
    function executeUpgrade(
        address proxyAddr,
        address timelockAddr,
        address newImplementation,
        bytes32 salt
    )
        external
    {
        console.log("==============================================");
        console.log("Execute Upgrade");
        console.log("Token:              ", getTokenSymbol());
        console.log("Proxy:              ", proxyAddr);
        console.log("Timelock:           ", timelockAddr);
        console.log("New Implementation: ", newImplementation);
        console.log("Salt:               ", vm.toString(salt));
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

        // Check status
        TimelockController timelock = TimelockController(payable(timelockAddr));
        bool isPending = timelock.isOperationPending(operationId);
        bool isReady = timelock.isOperationReady(operationId);
        bool isDone = timelock.isOperationDone(operationId);

        console.log("Is Pending:  ", isPending);
        console.log("Is Ready:    ", isReady);
        console.log("Is Done:     ", isDone);

        require(isReady, "Operation is not ready yet");
        require(!isDone, "Operation already executed");

        // Execute upgrade
        vm.startBroadcast();
        timelock.execute(
            proxyAddr, // target
            0, // value
            upgradeCallData, // data
            bytes32(0), // predecessor
            salt // salt
        );
        vm.stopBroadcast();

        console.log("\n-> Upgrade executed successfully");

        // Verify upgrade
        L2UpgradeableERC20 proxy = L2UpgradeableERC20(proxyAddr);
        console.log("\n==============================================");
        console.log("Verification");
        console.log("==============================================");
        console.log("Proxy name:   ", proxy.name());
        console.log("Proxy symbol: ", proxy.symbol());
        console.log("Proxy bridge: ", proxy.bridge());
        console.log("==============================================");
        console.log("\nUpgrade Complete!");
        console.log("==============================================");
    }

    // =============================================================
    //                      HELPER FUNCTIONS
    // =============================================================

    /**
     * @notice Check upgrade operation status
     * @param timelockAddr Timelock address
     * @param operationId Operation ID
     * @dev View function to check if upgrade is ready
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
            console.log("             (", remainingTime / 3600, "hours)");
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
