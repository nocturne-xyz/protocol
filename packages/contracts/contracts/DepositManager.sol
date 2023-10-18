// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

// External
import {ReentrancyGuardUpgradeable} from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {AddressUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/AddressUpgradeable.sol";
import {Ownable2StepUpgradeable} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// Internal
import {ITeller} from "./interfaces/ITeller.sol";
import {IWeth} from "./interfaces/IWeth.sol";
import {DepositRequestEIP712} from "./DepositRequestEIP712.sol";
import {AssetUtils} from "./libs/AssetUtils.sol";
import {Utils} from "./libs/Utils.sol";
import "./libs/Types.sol";

/// @title DepositManager
/// @author Nocturne Labs
/// @notice Manages inflow of assets into the Teller. Enforces global rate limits and max deposit
///         sizes. Enables an offchain actor to filter out certain deposits.
contract DepositManager is
    DepositRequestEIP712,
    ReentrancyGuardUpgradeable,
    Ownable2StepUpgradeable
{
    using SafeERC20 for IERC20;

    // Struct for erc20 rate limit info
    struct Erc20Cap {
        // Total deposited for asset over last `resetWindowHours` (in precision units), uint128 leaves space for 3x10^20 whole tokens even with 18 decimals
        uint128 runningGlobalDeposited;
        // Global cap for asset in whole tokens, globalCapWholeTokens * 10^precision should never
        // exceed uint128.max (checked in setter)
        uint32 globalCapWholeTokens;
        // Max size of a single deposit per address
        uint32 maxDepositSizeWholeTokens;
        // block.timestamp of last reset (limit at year 2106)
        uint32 lastResetTimestamp;
        // Number of hours until `runningGlobalDeposited` will be reset by a deposit
        uint8 resetWindowHours;
        // Decimals for asset, tokens = whole tokens * 10^precision
        uint8 precision;
    }

    // Gas cost of two ETH transfers
    uint256 constant TWO_ETH_TRANSFERS_GAS = 50_000;
    // Seconds in an hour
    uint256 constant SECONDS_IN_HOUR = 3_600;

    // Teller contract to deposit assets into
    ITeller public _teller;

    // Weth contract to convert ETH into
    IWeth public _weth;

    // Set of allowed deposit screeners
    mapping(address => bool) public _screeners;

    // Nonce counter for deposit requests
    uint256 public _nonce;

    // Set of hashes for outstanding deposits
    mapping(bytes32 => bool) public _outstandingDepositHashes;

    // Mapping of erc20s to rate limit info
    mapping(address => Erc20Cap) public _erc20Caps;

    // Gap for upgrade safety
    uint256[50] private __GAP;

    /// @notice Event emitted when a screener is given/revoked permission
    event ScreenerPermissionSet(address screener, bool permission);

    /// @notice Event emitted when a deposit is instantiated, contains all info needed for
    ///         screener to sign deposit
    event DepositInstantiated(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation
    );

    /// @notice Event emitted when a deposit is retrieved
    event DepositRetrieved(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation
    );

    /// @notice Event emitted when a deposit is completed
    event DepositCompleted(
        address indexed spender,
        EncodedAsset encodedAsset,
        uint256 value,
        CompressedStealthAddress depositAddr,
        uint256 nonce,
        uint256 gasCompensation,
        uint128 merkleIndex
    );

    receive() external payable {}

    /// @notice Initializer function
    /// @param contractName Name of the contract
    /// @param contractVersion Version of the contract
    /// @param teller Address of the teller contract
    /// @param weth Address of the weth contract
    function initialize(
        string memory contractName,
        string memory contractVersion,
        address teller,
        address weth
    ) external initializer {
        __Ownable2Step_init();
        __DepositRequestEIP712_init(contractName, contractVersion);
        _teller = ITeller(teller);
        _weth = IWeth(weth);
    }

    /// @notice Ensures all values in multideposit are <= maxDepositSize
    /// @dev If erc20 has no cap, then the asset is not supported and modifier reverts
    /// @param token Address of erc20
    /// @param values Array of values (deposits)
    modifier enforceErc20DepositSize(address token, uint256[] calldata values) {
        Erc20Cap memory cap = _erc20Caps[token];

        // Ensure asset is supported (has a cap)
        require(
            (cap.runningGlobalDeposited |
                cap.globalCapWholeTokens |
                cap.maxDepositSizeWholeTokens |
                cap.lastResetTimestamp |
                cap.resetWindowHours |
                cap.precision) != 0,
            "!supported erc20"
        );

        uint256 maxDepositSize = cap.maxDepositSizeWholeTokens *
            (10 ** cap.precision);

        uint256 numValues = values.length;
        for (uint256 i = 0; i < numValues; i++) {
            require(values[i] <= maxDepositSize, "maxDepositSize exceeded");
        }

        _;
    }

    /// @notice Ensures deposit does not exceed global cap for asset
    /// @dev Resets global cap if block.timestamp > lastResetTimestamp + resetWindowHours seconds
    /// @dev Since we store running count of erc20 deposited in uint128 in Erc20Cap,
    ///      the checked value must be < uint128.max
    /// @param encodedAsset Encoded erc20 to check cap for
    /// @param value Value of deposit
    modifier enforceErc20Cap(
        EncodedAsset calldata encodedAsset,
        uint256 value
    ) {
        // Deposit value should not exceed limit on max deposit cap (uint128.max)
        require(value <= type(uint128).max, "value > uint128.max");

        (AssetType assetType, address token, uint256 id) = AssetUtils
            .decodeAsset(encodedAsset);
        require(assetType == AssetType.ERC20 && id == ERC20_ID, "!erc20");

        Erc20Cap memory cap = _erc20Caps[token];

        // Clear expired global cap if possible
        if (
            block.timestamp >
            cap.lastResetTimestamp + (cap.resetWindowHours * SECONDS_IN_HOUR)
        ) {
            cap.runningGlobalDeposited = 0;
            cap.lastResetTimestamp = uint32(block.timestamp);
        }

        // We know cap.globalCapWholeTokens * (10 ** cap.precision) <= uint128.max given setter
        uint128 globalCap = uint128(
            cap.globalCapWholeTokens * (10 ** cap.precision)
        );

        // Ensure less than global cap and less than deposit size cap
        require(
            cap.runningGlobalDeposited + uint128(value) <= globalCap,
            "globalCap exceeded"
        );

        _;

        _erc20Caps[token].runningGlobalDeposited += uint128(value);
    }

    /// @notice Gives/revokes screener permission
    /// @param screener Address of screener
    /// @param permission Permission to set
    function setScreenerPermission(
        address screener,
        bool permission
    ) external onlyOwner {
        _screeners[screener] = permission;
        emit ScreenerPermissionSet(screener, permission);
    }

    /// @notice Sets global cap for erc20, only callable by owner
    /// @dev We require that globalCapWholeTokens * (10 ** precision) <= uint128.max, since the
    ///      running deposited tokens amount is stored in uint128.
    /// @param token Address of erc20
    /// @param globalCapWholeTokens Global cap for erc20 in whole tokens
    /// @param maxDepositSizeWholeTokens Max deposit size for erc20 in whole tokens
    /// @param precision Decimals for erc20
    function setErc20Cap(
        address token,
        uint32 globalCapWholeTokens,
        uint32 maxDepositSizeWholeTokens,
        uint8 resetWindowHours,
        uint8 precision
    ) external onlyOwner {
        require(
            globalCapWholeTokens * (10 ** precision) <= type(uint128).max,
            "globalCap > uint128.max"
        );
        require(
            maxDepositSizeWholeTokens <= globalCapWholeTokens,
            "maxDepositSize > globalCap"
        );
        _erc20Caps[token] = Erc20Cap({
            runningGlobalDeposited: 0,
            globalCapWholeTokens: globalCapWholeTokens,
            maxDepositSizeWholeTokens: maxDepositSizeWholeTokens,
            lastResetTimestamp: uint32(block.timestamp),
            resetWindowHours: resetWindowHours,
            precision: precision
        });
    }

    /// @notice Instantiates one or more deposits for an erc20 token.
    /// @dev Screeners sign and complete deposits on behalf of users after instantiation. Because
    ///      of this, users include gas compensation ETH with their deposit. This gas compensation
    ///      is sent to the contract and used to cover the screener when they complete the deposit.
    ///      Any remaining comp not used for screener compensation is returned to user.
    /// @dev We require that msg value is divisible by values length, so that each deposit in a
    ///      multideposit has an equal amount of gas compensation.
    /// @param token Address of erc20
    /// @param values Array of values (deposits)
    /// @param depositAddr Stealth address to deposit to
    function instantiateErc20MultiDeposit(
        address token,
        uint256[] calldata values,
        CompressedStealthAddress calldata depositAddr
    ) external payable nonReentrant enforceErc20DepositSize(token, values) {
        uint256 numValues = values.length;
        require(msg.value % numValues == 0, "!gas comp split");

        {
            EncodedAsset memory encodedAsset = AssetUtils.encodeAsset(
                AssetType.ERC20,
                token,
                ERC20_ID
            );

            uint256 nonce = _nonce;
            DepositRequest memory req = DepositRequest({
                spender: msg.sender,
                encodedAsset: encodedAsset,
                value: 0,
                depositAddr: depositAddr,
                nonce: 0,
                gasCompensation: msg.value / numValues
            });

            for (uint256 i = 0; i < numValues; i++) {
                req.value = values[i];
                req.nonce = nonce + i;

                bytes32 depositHash = _hashDepositRequest(req);
                _outstandingDepositHashes[depositHash] = true;

                emit DepositInstantiated(
                    req.spender,
                    req.encodedAsset,
                    req.value,
                    req.depositAddr,
                    req.nonce,
                    req.gasCompensation
                );
            }
        }

        _nonce += numValues;

        uint256 totalValue = Utils.sum(values);
        IERC20(token).safeTransferFrom(msg.sender, address(this), totalValue);
    }

    /// @notice Instantiates one or more deposits for an ETH, which is converted to wETH internally.
    /// @dev Total screener gas compensation ends up being msg.value - sum(values)
    /// @param values Array of values (eth deposits)
    /// @param depositAddr Stealth address to deposit to
    function instantiateETHMultiDeposit(
        uint256[] calldata values,
        CompressedStealthAddress calldata depositAddr
    )
        external
        payable
        nonReentrant
        enforceErc20DepositSize(address(_weth), values)
    {
        uint256 totalDepositAmount = Utils.sum(values);
        require(totalDepositAmount <= msg.value, "msg.value < deposit weth");

        uint256 gasCompensation = msg.value - totalDepositAmount;
        uint256 numValues = values.length;
        require(gasCompensation % numValues == 0, "!gas comp split");

        {
            EncodedAsset memory encodedWeth = AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(_weth),
                ERC20_ID
            );

            uint256 nonce = _nonce;
            DepositRequest memory req = DepositRequest({
                spender: msg.sender,
                encodedAsset: encodedWeth,
                value: 0,
                depositAddr: depositAddr,
                nonce: 0,
                gasCompensation: gasCompensation / numValues
            });

            for (uint256 i = 0; i < numValues; i++) {
                req.value = values[i];
                req.nonce = nonce + i;

                bytes32 depositHash = _hashDepositRequest(req);
                _outstandingDepositHashes[depositHash] = true;

                emit DepositInstantiated(
                    req.spender,
                    req.encodedAsset,
                    req.value,
                    req.depositAddr,
                    req.nonce,
                    req.gasCompensation
                );
            }
        }

        _nonce += numValues;

        _weth.deposit{value: totalDepositAmount}();
    }

    /// @notice Retrieves an ETH deposit either prematurely because user cancelled or because
    ///         screener didn't complete. Unwraps weth back to eth and send to user.
    /// @dev We accept race condition where user could technically retrieve their deposit before
    ///      the screener completes it. This would grief the screener but would incur a greater
    ///      cost to the user to continually instantiate + prematurely retrieve.
    /// @dev Same code as normal retrieveDeposit except deposit is checked to be weth and weth is
    //       unwrapped to eth. The call to send gas compensation eth back to user also sends back
    ///      deposit.value eth.
    /// @param req Deposit request corresponding to ETH deposit to retrieve
    function retrieveETHDeposit(
        DepositRequest calldata req
    ) external nonReentrant {
        require(msg.sender == req.spender, "Only spender can retrieve deposit");

        // Ensure the deposit was ETH
        (AssetType assetType, address assetAddr, uint256 id) = AssetUtils
            .decodeAsset(req.encodedAsset);
        require(
            assetType == AssetType.ERC20 &&
                assetAddr == address(_weth) &&
                id == ERC20_ID,
            "!weth"
        );

        // If _outstandingDepositHashes has request, implies all checks (e.g.
        // chainId, nonce, etc) already passed upon instantiation
        bytes32 depositHash = _hashDepositRequest(req);
        require(_outstandingDepositHashes[depositHash], "deposit !exists");

        // Clear deposit hash
        _outstandingDepositHashes[depositHash] = false;

        // Unwrap WETH to ETH
        _weth.withdraw(req.value);

        // Send back eth gas compensation + deposit ETH, revert propagated
        AddressUpgradeable.sendValue(
            payable(msg.sender),
            req.gasCompensation + req.value
        );

        emit DepositRetrieved(
            req.spender,
            req.encodedAsset,
            req.value,
            req.depositAddr,
            req.nonce,
            req.gasCompensation
        );
    }

    /// @notice Retrieves a deposit either prematurely because user cancelled or because screener
    ///         never ended up completing it.
    /// @dev We accept race condition where user could technically retrieve their deposit before
    ///      the screener completes it. This would grief the screener but would incur a greater
    ///      cost to the user to continually instantiate + prematurely retrieve.
    /// @param req Deposit request corresponding to deposit to retrieve
    function retrieveDeposit(
        DepositRequest calldata req
    ) external nonReentrant {
        require(msg.sender == req.spender, "Only spender can retrieve deposit");

        // If _outstandingDepositHashes has request, implies all checks (e.g.
        // chainId, nonce, etc) already passed upon instantiation
        bytes32 depositHash = _hashDepositRequest(req);
        require(_outstandingDepositHashes[depositHash], "deposit !exists");

        // Clear deposit hash
        _outstandingDepositHashes[depositHash] = false;

        // Send back asset
        AssetUtils.transferAssetTo(req.encodedAsset, req.spender, req.value);

        // Send back eth gas compensation, revert propagated
        AddressUpgradeable.sendValue(payable(msg.sender), req.gasCompensation);

        emit DepositRetrieved(
            req.spender,
            req.encodedAsset,
            req.value,
            req.depositAddr,
            req.nonce,
            req.gasCompensation
        );
    }

    /// @notice Completes an erc20 deposit.
    /// @dev Function reverts if completing deposit would exceed global hourly cap.
    /// @param req Deposit request corresponding to deposit to complete
    /// @param signature Signature from screener
    function completeErc20Deposit(
        DepositRequest calldata req,
        bytes calldata signature
    ) external nonReentrant enforceErc20Cap(req.encodedAsset, req.value) {
        _completeDeposit(req, signature);
    }

    /// @notice Completes a deposit provides a valid screener signature on the deposit request hash.
    /// @dev We accept that gas compensation will be be imprecise. During spikes in demand, the
    ///      screener will lose money. During normal demand, the screener should at least break
    ///      even, perhaps being compensated slightly higher than gas spent to smooth out spikes.
    /// @param req Deposit request corresponding to deposit to complete
    /// @param signature Signature from screener
    function _completeDeposit(
        DepositRequest calldata req,
        bytes calldata signature
    ) internal {
        uint256 preDepositGas = gasleft();

        // Recover and check screener signature
        address recoveredSigner = _recoverDepositRequestSigner(req, signature);
        require(_screeners[recoveredSigner], "request signer !screener");

        // If _outstandingDepositHashes has request, implies all checks (e.g.
        // chainId, nonce, etc) already passed upon instantiation
        bytes32 depositHash = _hashDepositRequest(req);
        require(_outstandingDepositHashes[depositHash], "deposit !exists");

        // Clear deposit hash
        _outstandingDepositHashes[depositHash] = false;

        // Approve teller for assets and deposit funds
        AssetUtils.approveAsset(req.encodedAsset, address(_teller), req.value);
        uint128 merkleIndex = _teller.depositFunds(
            Deposit({
                spender: req.spender,
                encodedAsset: req.encodedAsset,
                value: req.value,
                depositAddr: req.depositAddr
            })
        );

        // NOTE: screener may be under-compensated for gas during spikes in
        // demand.
        // NOTE: only case where screener takes more gas than it actually spent is when
        // gasUsage * tx.gasprice > req.gasCompensation. If
        // gasUsage * tx.gasprice > req.gasCompensation then there is only enough comp for one ETH
        // transfer, in which case all gasComp might as well go to screener instead of being left
        // in contract
        uint256 gasUsage = preDepositGas - gasleft() + TWO_ETH_TRANSFERS_GAS;
        uint256 actualGasComp = Utils.min(
            gasUsage * tx.gasprice,
            req.gasCompensation
        );
        if (actualGasComp > 0) {
            // Revert propagated
            AddressUpgradeable.sendValue(payable(msg.sender), actualGasComp);
        }

        // Send back any remaining eth to user
        uint256 remainingGasComp = req.gasCompensation - actualGasComp;
        if (remainingGasComp > 0) {
            // Revert propagated
            AddressUpgradeable.sendValue(
                payable(req.spender),
                remainingGasComp
            );
        }

        emit DepositCompleted(
            req.spender,
            req.encodedAsset,
            req.value,
            req.depositAddr,
            req.nonce,
            actualGasComp,
            merkleIndex
        );
    }
}
