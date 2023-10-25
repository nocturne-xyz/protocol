// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

import "../../libs/Types.sol";
import {AssetUtils} from "../../libs/AssetUtils.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

uint256 constant GAS_PER_JOINSPLIT_VERIFY = 100_000;

enum OperationFailureType {
    NONE,
    JOINSPLIT_BAD_ROOT,
    JOINSPLIT_NF_ALREADY_IN_SET,
    JOINSPLIT_NFS_SAME,
    BAD_CHAIN_ID,
    EXPIRED_DEADLINE
}

struct FormatOperationArgs {
    address[] joinSplitTokens;
    uint256[] joinSplitRefundValues;
    uint256[][] joinSplitsPublicSpends;
    address gasToken;
    uint256 root;
    TrackedAsset[] trackedRefundAssets;
    uint256 gasAssetRefundThreshold;
    uint256 executionGasLimit;
    uint256 gasPrice;
    Action[] actions;
    bool atomicActions;
    OperationFailureType operationFailureType;
}

struct Erc20TransferRequest {
    address token;
    address recipient;
    uint256 amount;
}

library NocturneUtils {
    uint256 constant DEADLINE_BUFFER = 1000;

    function defaultStealthAddress()
        internal
        pure
        returns (CompressedStealthAddress memory)
    {
        return
            CompressedStealthAddress({
                h1: 16950150798460657717958625567821834550301663161624707787222815936182638968203,
                h2: 49380694508107827227871038662877111842066638251616884143503987031630145436076
            });
    }

    function dummyProof() internal pure returns (uint256[8] memory _values) {
        for (uint256 i = 0; i < 8; i++) {
            _values[i] = uint256(4757829);
        }
    }

    function fillJoinSplitPublicSpends(
        uint256 perJoinSplitPublicSpend,
        uint256 numJoinSplits
    ) internal pure returns (uint256[] memory) {
        uint256[] memory joinSplitPublicSpends = new uint256[](numJoinSplits);
        for (uint256 i = 0; i < numJoinSplits; i++) {
            joinSplitPublicSpends[i] = perJoinSplitPublicSpend;
        }
        return joinSplitPublicSpends;
    }

    function formatDepositRequest(
        address spender,
        address asset,
        uint256 value,
        uint256 id,
        CompressedStealthAddress memory depositAddr,
        uint256 nonce,
        uint256 gasCompensation
    ) internal pure returns (DepositRequest memory) {
        EncodedAsset memory encodedAsset = AssetUtils.encodeAsset(
            AssetType.ERC20,
            asset,
            id
        );

        return
            DepositRequest({
                spender: spender,
                encodedAsset: encodedAsset,
                value: value,
                depositAddr: depositAddr,
                nonce: nonce,
                gasCompensation: gasCompensation
            });
    }

    function formatDeposit(
        address spender,
        address asset,
        uint256 value,
        uint256 id,
        CompressedStealthAddress memory depositAddr
    ) internal pure returns (Deposit memory) {
        EncodedAsset memory encodedAsset = AssetUtils.encodeAsset(
            AssetType.ERC20,
            asset,
            id
        );

        return
            Deposit({
                spender: spender,
                encodedAsset: encodedAsset,
                value: value,
                depositAddr: depositAddr
            });
    }

    function formatSingleTransferActionArray(
        address token,
        address recipient,
        uint256 amount
    ) public pure returns (Action[] memory) {
        Action[] memory actions = new Action[](1);
        actions[0] = formatTransferAction(
            Erc20TransferRequest({
                token: token,
                recipient: recipient,
                amount: amount
            })
        );
        return actions;
    }

    function formatTransferAction(
        Erc20TransferRequest memory transferRequest
    ) public pure returns (Action memory) {
        return
            Action({
                contractAddress: address(transferRequest.token),
                encodedFunction: abi.encodeWithSelector(
                    IERC20(transferRequest.token).transfer.selector,
                    transferRequest.recipient,
                    transferRequest.amount
                )
            });
    }

    function formatOperation(
        FormatOperationArgs memory args
    ) internal view returns (Operation memory) {
        uint256 totalNumJoinSplits = _totalNumJoinSplitsForArgs(args);
        OperationFailureType operationFailure = args.operationFailureType;
        if (operationFailure == OperationFailureType.JOINSPLIT_BAD_ROOT) {
            args.root = 0x12345; // fill with garbage root
        } else if (
            operationFailure == OperationFailureType.JOINSPLIT_NF_ALREADY_IN_SET
        ) {
            require(
                totalNumJoinSplits >= 2,
                "Must specify at least 2 joinsplits for JOINSPLIT_NF_ALREADY_IN_SET failure type"
            );
        }

        uint256 root = args.root;
        EncryptedNote memory newNoteEncrypted = _dummyEncryptedNote();

        uint256 numConfJoinSplits = _getNumConfJoinSplitsFromPublicSpendsArray(
            args.joinSplitsPublicSpends
        );
        PublicJoinSplit[] memory pubJoinSplits = new PublicJoinSplit[](
            totalNumJoinSplits - numConfJoinSplits
        );
        JoinSplit[] memory confJoinSplits = new JoinSplit[](numConfJoinSplits);

        {
            uint256 pubIndex = 0;
            uint256 confIndex = 0;
            for (uint256 i = 0; i < args.joinSplitsPublicSpends.length; i++) {
                for (
                    uint256 j = 0;
                    j < args.joinSplitsPublicSpends[i].length;
                    j++
                ) {
                    uint256 publicSpend = args.joinSplitsPublicSpends[i][j];
                    if (publicSpend > 0) {
                        pubJoinSplits[pubIndex] = PublicJoinSplit({
                            joinSplit: JoinSplit({
                                commitmentTreeRoot: root,
                                nullifierA: uint256(2 * (pubIndex + confIndex)),
                                nullifierB: uint256(
                                    2 * (pubIndex + confIndex) + 1
                                ),
                                newNoteACommitment: uint256(pubIndex),
                                newNoteAEncrypted: newNoteEncrypted,
                                newNoteBCommitment: uint256(pubIndex),
                                newNoteBEncrypted: newNoteEncrypted,
                                senderCommitment: uint256(pubIndex),
                                joinSplitInfoCommitment: uint256(pubIndex),
                                proof: dummyProof()
                            }),
                            assetIndex: uint8(i),
                            publicSpend: publicSpend
                        });
                        pubIndex++;
                    } else {
                        confJoinSplits[confIndex] = JoinSplit({
                            commitmentTreeRoot: root,
                            nullifierA: uint256(2 * (pubIndex + confIndex)),
                            nullifierB: uint256(2 * (pubIndex + confIndex) + 1),
                            newNoteACommitment: uint256(confIndex),
                            newNoteAEncrypted: newNoteEncrypted,
                            newNoteBCommitment: uint256(confIndex),
                            newNoteBEncrypted: newNoteEncrypted,
                            senderCommitment: uint256(confIndex),
                            joinSplitInfoCommitment: uint256(confIndex),
                            proof: dummyProof()
                        });
                        confIndex++;
                    }
                }
            }
        }

        if (operationFailure == OperationFailureType.JOINSPLIT_NFS_SAME) {
            pubJoinSplits[0].joinSplit.nullifierA = uint256(2 * 0x1234);
            pubJoinSplits[0].joinSplit.nullifierB = uint256(2 * 0x1234);
        } else if (
            operationFailure == OperationFailureType.JOINSPLIT_NF_ALREADY_IN_SET
        ) {
            pubJoinSplits[1].joinSplit.nullifierA = pubJoinSplits[0]
                .joinSplit
                .nullifierA; // Matches last joinsplit's NFs
            pubJoinSplits[1].joinSplit.nullifierA = pubJoinSplits[0]
                .joinSplit
                .nullifierB;
        }

        uint256 deadline = block.timestamp + DEADLINE_BUFFER;
        if (
            args.operationFailureType == OperationFailureType.EXPIRED_DEADLINE
        ) {
            deadline = 0;
        }

        TrackedAsset[] memory trackedAssets = new TrackedAsset[](
            args.joinSplitsPublicSpends.length + args.trackedRefundAssets.length
        );
        for (uint256 i = 0; i < args.joinSplitTokens.length; i++) {
            trackedAssets[i] = TrackedAsset({
                encodedAsset: AssetUtils.encodeAsset(
                    AssetType.ERC20,
                    args.joinSplitTokens[i],
                    ERC20_ID
                ),
                minRefundValue: args.joinSplitRefundValues[i]
            });
        }
        for (uint256 i = 0; i < args.trackedRefundAssets.length; i++) {
            trackedAssets[i + args.joinSplitTokens.length] = args
                .trackedRefundAssets[i];
        }

        Operation memory op = Operation({
            pubJoinSplits: pubJoinSplits,
            confJoinSplits: confJoinSplits,
            refundAddr: defaultStealthAddress(),
            trackedAssets: trackedAssets,
            actions: args.actions,
            encodedGasAsset: AssetUtils.encodeAsset(
                AssetType.ERC20,
                address(args.gasToken),
                ERC20_ID
            ),
            gasAssetRefundThreshold: args.gasAssetRefundThreshold,
            executionGasLimit: args.executionGasLimit,
            gasPrice: args.gasPrice,
            deadline: deadline,
            atomicActions: args.atomicActions,
            isForcedExit: false
        });

        return op;
    }

    function formatDummyOperationResult(
        Operation memory op
    ) internal pure returns (OperationResult memory result) {
        return
            OperationResult({
                opProcessed: true,
                assetsUnwrapped: true,
                failureReason: "",
                callSuccesses: new bool[](0),
                callResults: new bytes[](0),
                executionGas: op.executionGasLimit,
                verificationGas: op.pubJoinSplits.length *
                    GAS_PER_JOINSPLIT_VERIFY,
                numRefunds: op.trackedAssets.length,
                preOpMerkleCount: 0,
                postOpMerkleCount: 0
            });
    }

    function _getNumConfJoinSplitsFromPublicSpendsArray(
        uint256[][] memory joinSplitsPublicSpends
    ) internal pure returns (uint256) {
        uint256 numConfJoinSplits = 0;
        for (uint256 i = 0; i < joinSplitsPublicSpends.length; i++) {
            for (uint256 j = 0; j < joinSplitsPublicSpends[i].length; j++) {
                if (joinSplitsPublicSpends[i][j] == 0) {
                    numConfJoinSplits++;
                }
            }
        }
        return numConfJoinSplits;
    }

    function _totalNumJoinSplitsForArgs(
        FormatOperationArgs memory args
    ) internal pure returns (uint256) {
        uint256 totalJoinSplits = 0;
        for (uint256 i = 0; i < args.joinSplitsPublicSpends.length; i++) {
            totalJoinSplits += args.joinSplitsPublicSpends[i].length;
        }

        return totalJoinSplits;
    }

    function _joinSplitTokensArrayOfOneToken(
        address joinSplitToken
    ) internal pure returns (address[] memory) {
        address[] memory joinSplitTokens = new address[](1);
        joinSplitTokens[0] = joinSplitToken;
        return joinSplitTokens;
    }

    function _publicSpendsArrayOfOnePublicSpendArray(
        uint256[] memory publicSpends
    ) internal pure returns (uint256[][] memory) {
        uint256[][] memory publicSpendsArray = new uint256[][](1);
        publicSpendsArray[0] = publicSpends;
        return publicSpendsArray;
    }

    function _dummyEncryptedNote()
        internal
        pure
        returns (EncryptedNote memory)
    {
        bytes memory ciphertextBytes = new bytes(181);
        bytes memory encapsulatedSecretBytes = new bytes(64);

        return
            EncryptedNote({
                ciphertextBytes: ciphertextBytes,
                encapsulatedSecretBytes: encapsulatedSecretBytes
            });
    }
}
