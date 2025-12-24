// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import { ERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { ERC20PermitUpgradeable } from
    "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20PermitUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/PausableUpgradeable.sol";
import { IERC165 } from "@openzeppelin/contracts/utils/introspection/IERC165.sol";
import { IOptimismMintableERC20, ILegacyMintableERC20 } from "./IOptimismMintableERC20.sol";

/**
 * @title L2UpgradeableERC20
 * @dev Abstract L2UpgradeableERC20 Token base contract on L2 Network.
 *      Designed to be inherited by specific token implementations.
 */
abstract contract L2UpgradeableERC20 is
    Initializable,
    IOptimismMintableERC20,
    ILegacyMintableERC20,
    ERC20Upgradeable,
    ERC20PermitUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    UUPSUpgradeable
{
    // =============================================================
    //                           ROLES
    // =============================================================

    bytes32 public constant UPGRADER_ROLE = keccak256("UPGRADER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant UNPAUSER_ROLE = keccak256("UNPAUSER_ROLE");
    bytes32 public constant BLOCKLIST_MANAGER_ROLE = keccak256("BLOCKLIST_MANAGER_ROLE");

    // =============================================================
    //                           STATE
    // =============================================================

    address public remoteToken;
    address public bridge;

    mapping(address => bool) public isBlocked;

    // =============================================================
    //                           EVENTS
    // =============================================================

    event Mint(address indexed account, uint256 amount);
    event Burn(address indexed account, uint256 amount);
    event BlockPlaced(address indexed user);
    event BlockReleased(address indexed user);

    // =============================================================
    //                           MODIFIERS
    // =============================================================

    modifier onlyBridge() {
        require(msg.sender == bridge, "L2Token: caller not bridge");
        _;
    }

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Internal initializer for the base contract.
     * @param _name Token name
     * @param _symbol Token symbol
     * @param _bridge L2 Bridge address
     * @param _remoteToken L1 Token address
     * @param _admin Admin address for roles
     */
    function __L2UpgradeableERC20_init(
        string memory _name,
        string memory _symbol,
        address _bridge,
        address _remoteToken,
        address _admin
    )
        internal
        onlyInitializing
    {
        require(_bridge != address(0), "L2Token: bridge is zero address");
        require(_remoteToken != address(0), "L2Token: remote token is zero address");
        require(_admin != address(0), "L2Token: admin is zero address");

        __ERC20_init(_name, _symbol);
        __ERC20Permit_init(_name);
        __Pausable_init();
        __AccessControl_init();
        __UUPSUpgradeable_init();

        bridge = _bridge;
        remoteToken = _remoteToken;

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(UPGRADER_ROLE, _admin);
        _grantRole(PAUSER_ROLE, _admin);
        _grantRole(UNPAUSER_ROLE, _admin);
        _grantRole(BLOCKLIST_MANAGER_ROLE, _admin);
    }

    // =============================================================
    //               OPTIMISM/MANTLE BRIDGE INTERFACE
    // =============================================================

    function mint(
        address _to,
        uint256 _amount
    )
        external
        override(ILegacyMintableERC20, IOptimismMintableERC20)
        onlyBridge
    {
        _mint(_to, _amount);
        emit Mint(_to, _amount);
    }

    function burn(
        address _from,
        uint256 _amount
    )
        external
        override(ILegacyMintableERC20, IOptimismMintableERC20)
        onlyBridge
    {
        _burn(_from, _amount);
        emit Burn(_from, _amount);
    }

    function l1Token() external view returns (address) {
        return remoteToken;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(IERC165, AccessControlUpgradeable)
        returns (bool)
    {
        return interfaceId == type(IOptimismMintableERC20).interfaceId
            || interfaceId == type(ILegacyMintableERC20).interfaceId || super.supportsInterface(interfaceId);
    }

    // =============================================================
    //                     COMPLIANCE & SECURITY
    // =============================================================

    function addToBlockedList(address _user) external onlyRole(BLOCKLIST_MANAGER_ROLE) {
        isBlocked[_user] = true;
        emit BlockPlaced(_user);
    }

    function removeFromBlockedList(address _user) external onlyRole(BLOCKLIST_MANAGER_ROLE) {
        isBlocked[_user] = false;
        emit BlockReleased(_user);
    }

    function pause() external onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() external onlyRole(UNPAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Hook that is called before any transfer of tokens.
     * This includes minting and burning.
     */
    function _update(address from, address to, uint256 amount) internal override {
        // Pause Check
        require(!paused(), "L2Token: token transfer while paused");

        // BlockList Check
        if (from != address(0)) {
            require(!isBlocked[from], "L2Token: sender is blocked");
        }
        if (to != address(0)) {
            require(!isBlocked[to], "L2Token: receiver is blocked");
        }

        // Call parent hook
        super._update(from, to, amount);
    }

    // =============================================================
    //                     OVERRIDES
    // =============================================================

    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }

    uint256[50] private __gap;
}
