// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { Script, console2 as console } from "forge-std/Script.sol";
import { L2UpgradeableERC20 } from "../../src/L2UpgradeableERC20.sol";
import { ERC1967Proxy } from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import { TimelockController } from "@openzeppelin/contracts/governance/TimelockController.sol";

/**
 * @title L2TokenDeployBase
 * @dev Base deployment script for all L2UpgradeableERC20 tokens
 * @notice Inherit this and implement getTokenImplementation() + getTokenSymbol()
 *
 * Example Usage:
 * ```
 * contract DeployXAUt is L2TokenDeployBase {
 *     function getTokenImplementation() internal override returns (address) {
 *         return address(new XAUt());
 *     }
 *
 *     function getTokenSymbol() internal pure override returns (string memory) {
 *         return "XAUt";
 *     }
 * }
 * ```
 *
 * Usage:
 * Step 1: Deploy contracts
 * forge script script/DeployXAUt.s.sol:DeployXAUt \
 *   -s "step1_Deploy(address,address,address,uint256)" \
 *   $L2_BRIDGE $L1_TOKEN $MULTISIG_SEC 86400 \
 *   --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 *
 * Step 2: Transfer admin to Timelock and setup roles
 * forge script script/DeployXAUt.s.sol:DeployXAUt \
 *   -s "step2_TransferAdmin(address,address,address,address)" \
 *   $PROXY_ADDR $MULTISIG_SEC $MULTISIG_ENG $TIMELOCK_ADDR \
 *   --rpc-url $RPC_URL --private-key $PRIVATE_KEY --broadcast
 */
abstract contract L2TokenDeployBase is Script {
    // Roles
    bytes32 public constant DEFAULT_ADMIN_ROLE = 0x00;
    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant BLOCKLIST_MANAGER_ROLE = keccak256("BLOCKLIST_MANAGER_ROLE");

    // =============================================================
    //                  ABSTRACT METHODS
    // =============================================================

    /**
     * @dev Return token implementation address
     * @return Token implementation address
     */
    function getTokenImplementation() internal virtual returns (address);

    /**
     * @dev Return token symbol for logging
     * @return Token symbol for logging
     */
    function getTokenSymbol() internal view virtual returns (string memory);

    // =============================================================
    //                      DEPLOYMENT STEPS
    // =============================================================

    /**
     * @notice Step 1: Deploy Token Implementation, Proxy and Timelock
     * @param l2Bridge L2 Standard Bridge address
     * @param l1Token L1 Token address
     * @param multisigSec Security Multisig wallet for Timelock (Proposer/Executor)
     * @param timelockDelay Timelock delay in seconds (e.g., 86400 = 1 day)
     */
    function step1_Deploy(address l2Bridge, address l1Token, address multisigSec, uint256 timelockDelay) external {
        address deployer = vm.envAddress("DEPLOYER");

        console.log("==============================================");
        console.log("[Step 1] Deploy", getTokenSymbol(), "Contracts");
        console.log("Deployer:      ", deployer);
        console.log("L2 Bridge:     ", l2Bridge);
        console.log("L1 Token:      ", l1Token);
        console.log("Multisig SEC:  ", multisigSec, "(Timelock Control)");
        console.log("Delay:         ", timelockDelay, "seconds");
        console.log("==============================================");

        vm.startBroadcast();

        // Deploy Implementation
        address implementation = getTokenImplementation();
        console.log("Implementation: ", implementation);

        // Deploy Proxy
        bytes memory initData =
            abi.encodeWithSignature("initialize(address,address,address)", l2Bridge, l1Token, deployer);
        address proxy = address(new ERC1967Proxy(implementation, initData));
        console.log("Proxy:          ", proxy);

        L2UpgradeableERC20 token = L2UpgradeableERC20(proxy);
        require(token.hasRole(DEFAULT_ADMIN_ROLE, deployer), "Deployer missing Admin Role");

        // Deploy Timelock (Proposer/Executor: multisigSec)
        address[] memory proposers = new address[](1);
        proposers[0] = multisigSec;
        address[] memory executors = new address[](1);
        executors[0] = multisigSec;

        address timelock = address(new TimelockController(timelockDelay, proposers, executors, address(0)));
        console.log("Timelock:       ", timelock);

        vm.stopBroadcast();

        console.log("==============================================");
        console.log("Step 1 Complete!");
        console.log("==============================================");
        console.log("\nNext Step:");
        console.log("Run step2_TransferAdmin with:");
        console.log("  Proxy:        ", proxy);
        console.log("  Multisig SEC: ", multisigSec);
        console.log("  Timelock:     ", timelock);
        console.log("==============================================");
    }

    /**
     * @notice Step 2: Setup operational roles and transfer admin rights to Timelock
     * @param proxyAddr Token Proxy address
     * @param multisigSec Security Multisig wallet (UNPAUSER_ROLE + Timelock control)
     * @param multisigEng Engineering Multisig wallet (PAUSER_ROLE + BLOCKLIST_MANAGER_ROLE)
     * @param timelockAddr Timelock address
     */
    function step2_TransferAdmin(address proxyAddr, address multisigSec, address multisigEng, address timelockAddr)
        external
    {
        address deployer = vm.envAddress("DEPLOYER");

        console.log("==============================================");
        console.log("[Step 2] Setup Roles & Transfer Admin");
        console.log("Token:         ", getTokenSymbol());
        console.log("Deployer:      ", deployer);
        console.log("Proxy:         ", proxyAddr);
        console.log("Multisig SEC:  ", multisigSec, "(Security Team)");
        console.log("Multisig ENG:  ", multisigEng, "(Engineering Team)");
        console.log("Timelock:      ", timelockAddr);
        console.log("==============================================");

        L2UpgradeableERC20 token = L2UpgradeableERC20(proxyAddr);
        require(token.hasRole(DEFAULT_ADMIN_ROLE, deployer), "Deployer is not Admin");

        vm.startBroadcast();

        // Grant operational roles to Engineering Multisig
        token.grantRole(BLOCKLIST_MANAGER_ROLE, multisigEng);
        token.grantRole(PAUSER_ROLE, multisigEng);
        console.log("\n-> Granted operational roles to Engineering Multisig");
        console.log("   - BLOCKLIST_MANAGER_ROLE");
        console.log("   - PAUSER_ROLE");

        // Grant UNPAUSER_ROLE to Security Multisig
        token.grantRole(UNPAUSER_ROLE, multisigSec);
        console.log("\n-> Granted UNPAUSER_ROLE to Security Multisig");

        // Revoke operational roles from Deployer
        token.renounceRole(BLOCKLIST_MANAGER_ROLE, deployer);
        token.renounceRole(PAUSER_ROLE, deployer);
        token.renounceRole(UNPAUSER_ROLE, deployer);
        console.log("\n-> Revoked operational roles from Deployer");

        require(token.hasRole(BLOCKLIST_MANAGER_ROLE, multisigEng), "Engineering Multisig missing roles");
        require(token.hasRole(PAUSER_ROLE, multisigEng), "Engineering Multisig missing PAUSER_ROLE");
        require(token.hasRole(UNPAUSER_ROLE, multisigSec), "Security Multisig missing UNPAUSER_ROLE");

        // Grant admin roles to Timelock
        token.grantRole(UPGRADER_ROLE, timelockAddr);
        token.grantRole(DEFAULT_ADMIN_ROLE, timelockAddr);
        console.log("\n-> Granted admin roles to Timelock");
        console.log("   - UPGRADER_ROLE");
        console.log("   - DEFAULT_ADMIN_ROLE");

        require(token.hasRole(DEFAULT_ADMIN_ROLE, timelockAddr), "Timelock grant failed");

        // Revoke admin roles from Deployer
        token.renounceRole(UPGRADER_ROLE, deployer);
        token.renounceRole(DEFAULT_ADMIN_ROLE, deployer);
        console.log("\n-> Revoked admin roles from Deployer");

        require(!token.hasRole(DEFAULT_ADMIN_ROLE, deployer), "Deployer renounce failed");

        vm.stopBroadcast();

        console.log("\n==============================================");
        console.log("Step 2 Complete!");
        console.log("All roles configured successfully");
        console.log("==============================================");
        console.log("\nRole Distribution:");
        console.log("+--------------------------------------------+");
        console.log("| Engineering Multisig                       |");
        console.log("+--------------------------------------------+");
        console.log("| - PAUSER_ROLE          (Emergency Pause)   |");
        console.log("| - BLOCKLIST_MANAGER    (Compliance)        |");
        console.log("+--------------------------------------------+");
        console.log("");
        console.log("+--------------------------------------------+");
        console.log("| Security Multisig (High Authority)         |");
        console.log("+--------------------------------------------+");
        console.log("| - UNPAUSER_ROLE        (Resume Operations) |");
        console.log("| - Timelock Control     (via Proposer/Exec) |");
        console.log("+--------------------------------------------+");
        console.log("");
        console.log("+--------------------------------------------+");
        console.log("| Timelock (Governance)                      |");
        console.log("+--------------------------------------------+");
        console.log("| - UPGRADER_ROLE        (Contract Upgrades) |");
        console.log("| - DEFAULT_ADMIN_ROLE   (Role Management)   |");
        console.log("+--------------------------------------------+");
        console.log("==============================================");
    }
}
