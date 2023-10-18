// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;

uint256 constant GAS_PER_JOINSPLIT_HANDLE = 110_000; // two 20k SSTOREs from NF insertions, ~70k for merkle tree checks + NF mapping checks + processing joinsplits not including tree insertions
uint256 constant GAS_PER_INSERTION_SUBTREE_UPDATE = 25_000; // Full 16 leaf non-zero subtree update = 320k / 16 = 20k per insertion (+5k buffer)
uint256 constant GAS_PER_INSERTION_ENQUEUE = 25_000; // 20k for enqueueing note commitment not including subtree update cost (+5k buffer)
uint256 constant GAS_PER_OPERATION_MISC = 100_000; // remaining gas cost for operation including  miscellaneous costs such as sending gas tokens to bundler, requesting assets from teller, sending tokens back for refunds, calldata, event, etc.

uint256 constant ERC20_ID = 0;

enum AssetType {
    ERC20,
    ERC721,
    ERC1155
}

struct EncodedAsset {
    uint256 encodedAssetAddr;
    uint256 encodedAssetId;
}

struct CompressedStealthAddress {
    uint256 h1;
    uint256 h2;
}

struct EncryptedNote {
    bytes ciphertextBytes;
    bytes encapsulatedSecretBytes;
}

struct PublicJoinSplit {
    JoinSplit joinSplit;
    uint8 assetIndex; // Index in op.joinSplitAssets
    uint256 publicSpend;
}

struct JoinSplit {
    uint256 commitmentTreeRoot;
    uint256 nullifierA;
    uint256 nullifierB;
    uint256 newNoteACommitment;
    uint256 newNoteBCommitment;
    uint256 senderCommitment;
    uint256 joinSplitInfoCommitment;
    uint256[8] proof;
    EncryptedNote newNoteAEncrypted;
    EncryptedNote newNoteBEncrypted;
}

struct JoinSplitInfo {
    uint256 compressedSenderCanonAddr;
    uint256 compressedReceiverCanonAddr;
    uint256 oldMerkleIndicesWithSignBits;
    uint256 newNoteValueA;
    uint256 newNoteValueB;
    uint256 nonce;
}

struct EncodedNote {
    uint256 ownerH1;
    uint256 ownerH2;
    uint256 nonce;
    uint256 encodedAssetAddr;
    uint256 encodedAssetId;
    uint256 value;
}

struct DepositRequest {
    address spender;
    EncodedAsset encodedAsset;
    uint256 value;
    CompressedStealthAddress depositAddr;
    uint256 nonce;
    uint256 gasCompensation;
}

struct Deposit {
    address spender;
    EncodedAsset encodedAsset;
    uint256 value;
    CompressedStealthAddress depositAddr;
}

struct Action {
    address contractAddress;
    bytes encodedFunction;
}

struct TrackedAsset {
    EncodedAsset encodedAsset;
    uint256 minRefundValue;
}

struct Operation {
    PublicJoinSplit[] pubJoinSplits;
    JoinSplit[] confJoinSplits;
    CompressedStealthAddress refundAddr;
    TrackedAsset[] trackedAssets;
    Action[] actions;
    EncodedAsset encodedGasAsset;
    uint256 gasAssetRefundThreshold;
    uint256 executionGasLimit;
    uint256 gasPrice;
    uint256 deadline;
    bool atomicActions;
}

// An operation is processed if its joinsplitTxs are processed.
// If an operation is processed, the following is guaranteeed to happen:
// 1. Encoded calls are attempted (not necessarily successfully)
// 2. The bundler is compensated verification and execution gas
// Bundlers should only be submitting operations that can be processed.
struct OperationResult {
    bool opProcessed;
    bool assetsUnwrapped;
    string failureReason;
    bool[] callSuccesses;
    bytes[] callResults;
    uint256 verificationGas;
    uint256 executionGas;
    uint256 numRefunds;
    uint128 preOpMerkleCount;
    uint128 postOpMerkleCount;
}

struct Bundle {
    Operation[] operations;
}

struct CanonAddrRegistryEntry {
    address ethAddress;
    uint256 compressedCanonAddr;
    uint256 perCanonAddrNonce;
}

library OperationLib {
    function maxGasLimit(
        Operation calldata self,
        uint256 perJoinSplitVerifyGas
    ) internal pure returns (uint256) {
        uint256 numJoinSplits = totalNumJoinSplits(self);
        return
            self.executionGasLimit +
            ((perJoinSplitVerifyGas + GAS_PER_JOINSPLIT_HANDLE) *
                numJoinSplits) +
            ((GAS_PER_INSERTION_SUBTREE_UPDATE + GAS_PER_INSERTION_ENQUEUE) *
                (self.trackedAssets.length + (numJoinSplits * 2))) + // NOTE: assume refund for every asset
            GAS_PER_OPERATION_MISC;
    }

    function maxGasAssetCost(
        Operation calldata self,
        uint256 perJoinSplitVerifyGas
    ) internal pure returns (uint256) {
        return self.gasPrice * maxGasLimit(self, perJoinSplitVerifyGas);
    }

    function totalNumJoinSplits(
        Operation calldata self
    ) internal pure returns (uint256) {
        return self.pubJoinSplits.length + self.confJoinSplits.length;
    }
}
