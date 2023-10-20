pragma circom 2.1.0;

include "include/babyjub.circom";
include "include/poseidon.circom";
include "include/comparators.circom";

include "tree.circom";
include "lib.circom";

//* define `l` to be the order of Baby Jubjub's prime-order subgroup

//@requires(1.1) `operationDigest is the cryptographic hash of a valid Nocturne operation that this JoinSplit is a part of
//@requires(1.2) all public inputs correspond to the same JoinSplit, and that JoinSplit is contained in the operation whose digest is `operationDigest`
//@requires(3) `pubEncodedAssetId` and `pubEncodedAssetAddrWithSignBits` were derived solely and correctly from the respective values in the JoinSplit,
//  which is contained in the operation whose digest is `operationDigest`, or 0 if `publicSpend` is 0
//  (except for the sign bits, which still correspond to the refund address)
//@requires(4) `refundAddrH1CompressedY` and `refundAddrH2CompressedY` are as specified in the op whose digest is `operationDigest`
//@requires(5.1) `nullifierA` is the nullifier of `oldNoteA` given in this JoinSplit, whose digest is `operationDigest`
//@requires(5.2) `nullifierB` is the nullifier of `oldNoteB` given in this JoinSplit, whose digest is `operationDigest`
//@requires(6) `senderCommitment` is the `senderCommitment` given in the operation whose digest is `operationDigest`
//
//@ensures(1.1) if `publicSpend` is nonzero, `pubEncodedAssetId` matches that found in the `encodedAssetId` field of both old notes and both new notes
//@ensures(1.2) if `publicSpend` is zero, `pubEncodedAssetId` is 0
//@ensures(2.1) if `publicSpend` is nonzero, and one were to mask the sign bits to zero, `pubEncodedAssetAddrWithSignBits` would match the `encodedAssetAddr` field in both old notes and both new notes
//@ensures(2.2) if `publicSpend` is zero, the asset contract address bits, asset type bits, and asset ID bits in `pubEncodedAssetAddrWithSignBits` are all 0
//@ensures(3.1) `newNoteACommitment` is the correct note commitment for the first new note, newNoteA
//@ensures(3.2) `newNoteBCommitment` is the correct note commitment for the second new note, newNoteB
//@ensures(3.3) `oldNoteACommitment` is the correct note commitment for the first old note oldNoteA 
//@ensures(3.4) `oldNoteBCommitment` is the correct note commitment for the second old note, oldNoteB 
//@ensures(4.1) the viewing key `vk` used to derive nullifiers and addresses was correctly derived from the spend pubkey `spendPubkey`
//@ensures(4.2) the viewing key `vk` is an element of the scalar field of Baby Jubjub's prime-order subgroup
//@ensures(5.1) the spending pubkey `spendPubkey` is a valid, order-l Baby Jubjub point
//@ensures(5.2) the operation signature `(c, z)` is a valid Schnorr signature of `operationDigest` under the spend pubkey `spendPubkey`
//@ensures(6.1) both points of the owner field of `oldNoteA`, `oldNoteAOwner`, are valid babyjubjub points
//@ensures(6.2) both points of the owner field of `oldNoteB`, `oldNoteBOwner`, are valid babyjubjub pointi
//@ensures(6.3) H1 of the owner field of `oldNoteA`, `oldNoteAOwner`, is of order greater than 8 (i.e. it clears the cofactor)
//@ensures(6.4) H1 of the owner field of `oldNoteB`, `oldNoteBOwner`, is of order greater than 8 (i.e. it clears the cofactor)
//@ensures(6.5) the owner field of `oldNoteA, `oldNoteAOwner`, is "owned" by the viewing key `vk` according to the Nocturne Stealth Address scheme
//@ensures(6.6) the owner field of `oldNoteB, `oldNoteBOwner`, is "owned" by the viewing key `vk` according to the Nocturne Stealth Address scheme
//@ensures(7.1) `refundAddrH1CompressedY`, along with its sign bit extracted from `pubEncodedAssetAddrWithSignBits`, represents a valid (on-curve), order-l babyjubjub point according to Nocturne's point compression scheme
//@ensures(7.2) `refundAddrH2CompressedY`, along with its sign bit extracted from `pubEncodedAssetAddrWithSignBits`, represents a valid (on-curve), but not necessarily order-l babyjubjub point according to Nocturne's point compression scheme
//@ensures(7.3) `refundAddr` is "owned" by same viewing key as the old note owners, as defined by the "ownership check" of the Nocturne Stealth Address scheme.
//@ensures(8.1) `oldNoteACommitment` is included in the quaternary Poseidon merkle tree whose root is `commitmentTreeRoot`
//@ensures(8.2) `oldNoteBCommitment` is included in the quaternary Poseidon merkle tree whose root is `commitmentTreeRoot` if `oldNoteBValue` is nonzero
//@ensures(9.1) `nullifierA` was correctly derived from the note commitment of `oldNoteA` and the viewing key `vk`
//@ensures(9.2) `nullifierB` was correctly derived from the note commitment of `oldNoteB` and the viewing key `vk`
//@ensures(9.3) `nullifierA` is the only possible nullifier that can be derived for `oldNoteA`
//@ensures(9.4) `nullifierB` is the only possible nullifier that can be derived for `oldNoteB`
//@ensures(10.1) `oldNoteAValue` is in the range [0, 2**252)
//@ensures(10.2) `oldNoteBValue` is in the range [0, 2**252)
//@ensures(10.3) `newNoteAValue` is in the range [0, 2**252)
//@ensures(10.4) `newNoteBValue` is in the range [0, 2**252)
//@ensures(10.5) `oldNoteAValue + oldNoteBValue` is in the range [0, 2**252)
//@ensures(10.6) `newNoteAValue + newNoteBValue` is in the range [0, 2**252)
//@ensures(11.1) `oldNoteAValue + oldNoteBValue >= newNoteAValue + newNoteBValue`
//@ensures(11.2) `publicSpend == oldNoteAValue + oldNoteBValue - newNoteAValue - newNoteBValue`
//@ensures(12.1) the sender's canonical address used in `senderCommitment` is the canonical address derived from `vk`
//@ensures(12.2) `senderCommitment` is computed correctly as `Poseidon(keccak256("SENDER_COMMITMENT") % p, senderCanonAddrX, senderCanonAddrY, newNoteBNonce"))`
//@ensures(13) the recipient is a valid canonical address (on curve, order-l)
//@ensures(14) `joinSplitInfoCommitment` is computed correctly as `Poseidon(keccak256("JOINSPLIT_INFO_COMMITMENT") % p, ...encodedJoinSplitInfo)` where `encodedJoinSplitInfo` is an array consisting of the following:
// - `compressedSenderCanonAddrY`
// - `compressedReceiverCanonAddrY`
// - `oldMerkleIndicesWithSignBits`, defined as `u32(oldNoteAIndex) || u32(oldNoteBIndex) << 32 || senderSignBit << 64 || receiverSignBit << 65 || noteBIsDummy << 66`
//      where `oldNoteAIndex` and `oldNoteBIndex` are computed from `pathA` and `pathB`,and `noteBIsDummy` is a single bit that's a `1` if note B is a dummy note and `0` otherwise
// - `newNoteAValue`
// - `newNoteBValue`
// - `joinSplitInfoNonce`, defined as `Poseidon(keccak256("JOINSPLIT_INFO_NONCE") % p, vk, nullifierA)`
template JoinSplit() {
    // *** PUBLIC INPUTS ***
    // digest of the operation this JoinSplit is a part of
    // this is used to bind each JoinSplit to an operation and as the message for the signature
    signal input operationDigest;

    // the lower 253 bits of the ID of the asset being transferred. In the case of ERC20, this is 0.
    // if the `publicSpend` is 0, is set to 0
    signal input pubEncodedAssetId;


    // encodedAssetAddr, but with the sign bits of refundAddr placed at bits 248 and 249 (when zero-indexed in little-endian order)
    // if publicSpend is nonzero, we assert that `encodedAssetAddr` matches that specified in the `encodedAssetAddr` bits of this input
    // if publicSpend is 0, we assert that this the `encodedAssetAddr` part of this PI is 0.
    // the address of the asset being transferred, with the upper 3 bits of the asset ID, 2 bits for the asset type and the sign bits of `refundAddrH1CompressedY` and `refundAddrH2CompressedY` packed-in
    // the bit packing is defined as follows, from the most significant bit to the least significant bit:
    // - 3 0 bits
    // - 3 bits for the the upper 3 bits of the asset ID
    // - 1 sign bit for `refundAddrH1CompressedY`
    // - 1 sign bit for `refundAddrH2CompressedY`
    // - 86 bits that are left unspecified
    // - 2 bits for the asset type - 00 for ERC20, 01 for ERC721, 10 for ERC1155, 11 is unsupported (illegal)
    // - 160 bits for the asset's contract address
    signal input pubEncodedAssetAddrWithSignBits;

    // the Y coordinates of both components of the operation's refund address
    // the circuit will ensure that the refund address is "owned" by the spender, preventing transfers via refunds
    signal input refundAddrH1CompressedY;
    signal input refundAddrH2CompressedY;

    // the note commitments of the two notes being created as a result of this JoinSplit
    signal output newNoteACommitment;
    signal output newNoteBCommitment;

    // the root of the commitment tree root in the Nocturne Handler contract
    signal output commitmentTreeRoot;
    // the amount of the asset to be spent publicly by withdrawing it from the Teller contract. This is the difference between the sum of the old note values and the sum of the new note values.
    // as per the protocol, this must be in the range [0, 2**252)
    signal output publicSpend;

    // nullifiers for the two notes being spent via this JoinSplit
    signal output nullifierA;
    signal output nullifierB;

    // blinded commitment to the sender's canonical address so that the recipient can verify the sender.
    // defined as Poseidon(keccak256("SENDER_COMMITMENT") % p, senderCanonAddrX, senderCanonAddrY, newNoteBNonce"))
    signal output senderCommitment;

    signal output joinSplitInfoCommitment;

    // *** WITNESS ***

    // viewing key 
    signal input vk;

    // spend pubkey
    signal input spendPubkey[2];
    // nonce used to generate the viewing key from the spend pubkey
    signal input vkNonce;

    // operation signature
    signal input c;
    signal input z;

    // info indentifying the asset this JoinSplit is spending
    // encoded into field elements. See above for encoding
    signal input encodedAssetId;
    signal input encodedAssetAddr;

    // the uncompressed refund address specified by the operation
    signal input refundAddrH1X;
    signal input refundAddrH1Y;
    signal input refundAddrH2X;
    signal input refundAddrH2Y;

    // Old note A
    signal input oldNoteAOwnerH1X;
    signal input oldNoteAOwnerH1Y;
    signal input oldNoteAOwnerH2X;
    signal input oldNoteAOwnerH2Y;
    signal input oldNoteANonce;
    signal input oldNoteAValue;

    // Path to old note A
    signal input pathA[16];
    signal input siblingsA[16][3];

    // Old note B
    signal input oldNoteBOwnerH1X;
    signal input oldNoteBOwnerH1Y;
    signal input oldNoteBOwnerH2X;
    signal input oldNoteBOwnerH2Y;
    signal input oldNoteBNonce;
    signal input oldNoteBValue;

    // Path to old note B
    signal input pathB[16];
    signal input siblingsB[16][3];

    // New note A
    signal input newNoteAValue;

    // New note B
    signal input receiverCanonAddr[2];
    signal input newNoteBValue;

    // the "base point" of BabyJubjub 0. That is, the generator of the prime-order subgroup
    var BASE8[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];


    // check spendPubkey is on-curve and order-l
    //@satisfies(5.1) spendPubkey is a valid, order-l Baby Jubjub point
    //@argument BabyCheck ensures that spendPubkey is on-curve,
    // . and `IsOrderL` ensures that it is order-l given that it's on-curve
    BabyCheck()(spendPubkey[0], spendPubkey[1]);
    IsOrderL()(spendPubkey[0], spendPubkey[1]);

    // check VK derivation
    //@satisfies(4.1)
    //@argument follows from VKDerivation.ensures(1) since VKDerivation.requires(1) is satisfied by (5.1)
    //@satisfies(4.2)
    //@argument follows from VKDerivation.ensures(3) since VKDerivation.requires(1) is satisfied by (5.1)
    component vkDerivation = VKDerivation();
    vkDerivation.spendPubkey <== spendPubkey;
    vkDerivation.vkNonce <== vkNonce;

    //@lemma(1) `vkBits` is the correct 251-bit little-endian bit decomposition of `vk`
    //@argument follows from VKDerivation.ensures(1) since VKDerivation.requires(1) is satisfied by (5.1)
    signal vkBits[251] <== vkDerivation.vkBits;
    vk === vkDerivation.vk;

    // derive sender's canonical address from the viewing key
    //@lemma(2) senderCanonAddr is the correct canonical address derived from `vk` 
    //@argument follows from CanonAddr.ensures(2) since CanonAddr.requires(1) is satisfied by @lemma(1)
    signal senderCanonAddr[2] <== CanonAddr()(vkBits);

    // new note A's owner is sender's canonical address
    signal newNoteAOwnerH1X <== BASE8[0];
    signal newNoteAOwnerH1Y <== BASE8[1];
    signal newNoteAOwnerH2X <== senderCanonAddr[0];
    signal newNoteAOwnerH2Y <== senderCanonAddr[1];

    // new note B's owner is receiver's canonical address
    signal newNoteBOwnerH1X <== BASE8[0];
    signal newNoteBOwnerH1Y <== BASE8[1];
    signal newNoteBOwnerH2X <== receiverCanonAddr[0];
    signal newNoteBOwnerH2Y <== receiverCanonAddr[1];

    // check receiver canon addr is a valid babyjubjub point
    //@satisfies(13)
    //@argument BabyCheck ensures that spendPubkey is on-curve,
    //   and `IsOrderL` ensures that it is order-l given that it's on-curve
    BabyCheck()(receiverCanonAddr[0], receiverCanonAddr[1]);
    IsOrderL()(receiverCanonAddr[0], receiverCanonAddr[1]);

    // check old note A owner is composed of valid babyjubjub points
    //@satisfies(6.1)
    //@argument BabyCheck ensures that oldNoteAOwnerH1 and oldNoteAOwnerH2 are on-curve,
    //@lemma(3) oldNoteAOwnerH1 is order-l
    //@argument (6.1) satisfies IsOrderL.requires(1), and IsOrderL.ensures(1) ensures that H1 is of order-l
    //@satisfies(6.3)
    //@argument H1 is of order-l due to @lemma(3) and it's on the curve due to (6.1)
    BabyCheck()(oldNoteAOwnerH1X, oldNoteAOwnerH1Y);
    BabyCheck()(oldNoteAOwnerH2X, oldNoteAOwnerH2Y);
    IsOrderL()(oldNoteAOwnerH1X, oldNoteAOwnerH1Y);

    // check old note B owner is composed of valid babyjubjub points
    //@satisfies(6.2)
    //@argument same as (6.1),
    //@lemma(4) oldNoteBOwnerH1 is order-l
    //@argument same as @lemma(3)
    //@satisfies(6.4)
    //@argument H1 is of order-l due to @lemma(4) and it's on the curve due to (6.2)
    BabyCheck()(oldNoteBOwnerH1X, oldNoteBOwnerH1Y);
    BabyCheck()(oldNoteBOwnerH2X, oldNoteBOwnerH2Y);
    IsOrderL()(oldNoteBOwnerH1X, oldNoteBOwnerH1Y);

    // check that old note owner addresses correspond to user's viewing key 
    //@satisfies(6.5)
    //@argument StealthAddrOwnership.requires(1) is satisfied by (6.1) and @lemma(3), and StealthAddrOwnership.requires(2) is satisfied by (6.1)
    //   therefore, by StealthAddrOwnership.ensures(1, 2), old note A owner is "owned" by the viewing key according to the Nocturne Stealth Address scheme
    StealthAddrOwnership()(oldNoteAOwnerH1X, oldNoteAOwnerH1Y, oldNoteAOwnerH2X, oldNoteAOwnerH2Y, vkBits);

    //@satisfies(6.6)
    //@argument StealthAddrOwnership.requires(1) is satisfied by (6.2) and @lemma(4), and StealthAddrOwnership.requires(2) is satisfied by (6.1)
    //   therefore, by StealthAddrOwnership.ensures(1, 2), old note A owner is "owned" by the viewing key according to the Nocturne Stealth Address scheme
    StealthAddrOwnership()(oldNoteBOwnerH1X, oldNoteBOwnerH1Y, oldNoteBOwnerH2X, oldNoteBOwnerH2Y, vkBits);

    // check that the sum of old and new note values are in range [0, 2**252)
    // this can't overflow because all four note values are in range [0, 2**252) and field is 254 bits
    //@satisfies(10.1) 
    //@argument follows from `RangeCheckNBits` and `RangeCheckNBits.ensures(1)`, and `RangeCheckNBits.requires(1)` is satisfied since `n < 254`
    //@satisfies(10.2)
    //@satisfies(10.3)
    //@argument same as (10.1)
    //@satisfies(10.4)
    //@argument same as (10.1)
    //@satisfies(10.5)
    //@argument same as (10.1)
    //@satisfies(10.6)
    //@argument same as (10.1)
    signal valInput <== oldNoteAValue + oldNoteBValue;
    signal valOutput <== newNoteAValue + newNoteBValue;
    RangeCheckNBits(252)(newNoteAValue);
    RangeCheckNBits(252)(newNoteBValue);
    RangeCheckNBits(252)(oldNoteAValue);
    RangeCheckNBits(252)(oldNoteBValue);
    RangeCheckNBits(252)(valInput);
    RangeCheckNBits(252)(valOutput);

    // check that old note values hold at least as much value as new note values
    //@satisfies(11.1)
    //@argument this is what `LessEqThan` does, and we've already RC'd the values to be in range [0, 2**252)
    signal compOut <== LessEqThan(252)([valOutput, valInput]);
    compOut === 1;

    // compute publicSpend
    //@satisfies(11.2)
    //@argument (10.3-6) together with (11.1) ensures that there's no over/underflow, therefore (11.2) holds
    publicSpend <== valInput - valOutput;

    // get sign bits of refund addr out of pubEncodedAssetAddrWithSignBits
    // don't need Num2Bits_strict here because it's only 253 bits
    signal pubEncodedAssetAddrWithSignBitsBits[253] <== Num2Bits(253)(pubEncodedAssetAddrWithSignBits);
    signal refundAddrH1Sign <== pubEncodedAssetAddrWithSignBitsBits[248];
    signal refundAddrH2Sign <== pubEncodedAssetAddrWithSignBitsBits[249];

    // get encodedAssetAddr out of pubEncodedAssetAddrWithSignBits
    //@lemma(5) `encodedAssetAddrDecoded` is what one would get if they masked the refund addr sign bits in `pubEncodedAssetAddrWithSignBits` to zero
    //@argument: encoding is correct due to @requires(3)
    // 1. `pubEncodedAssetAddrWithSignBitsBits` is the correct, unique 253-bit little-endian bit decomposition of `pubEncodedAssetAddrWithSignBits`
    //    Num2Bits(253) guarantees this because a 253-bit decomp cannot overflow the field
    // 2. encodedAssetAddrSubend is defined as the numerical value of the sign bits, i.e. 2**248 * refundAddrH2Sign + 2**249 * refundAddrH1Sign
    // 3. therefore, encodedAssetAddrDecoded, as written, is the numerical value of `pubEncodedAssetAddrWithSignBits` with the sign bits masked to zero.
    //    this cannot underflow the field as `encodedAssetAddrSubend` is guaranteed to (numerically) be <= `pubEncodedAssetAddrWithSignBits`
    signal refundAddrH1SignTimes2ToThe248 <== (1 << 248) * refundAddrH1Sign;
    signal encodedAssetAddrSubend <== (1 << 249) * refundAddrH2Sign + refundAddrH1SignTimes2ToThe248;
    signal encodedAssetAddrDecoded <== pubEncodedAssetAddrWithSignBits - encodedAssetAddrSubend;

  
    signal publicSpendIsZero <== IsZero()(publicSpend);
    // if publicSpend is nonzero, check that `pubEncodedAssetId` matches `encodedAssetId`
    // otherwise, assert that `pubEncodedAssetId` is also zero
    //@satisfies(1.1)  if publicSpend is nonzero, `1 - publicSpendIsZero == 1`, so this constraint is satisfied IFF `pubEncodedAssetId == encodedAssetId`
    // (1.1) follows from here by noting that we use `encodedAssetId` when computing the note commitments below
    //@satisfies(1.2) if publicSpend is zero, `1 - publicSpendIsZero == 0`, so this constraint is satisfied IFF `pubEncodedAssetId == 0`
    pubEncodedAssetId === (1 - publicSpendIsZero) * encodedAssetId;

    // if publicSpend is nonzero, check that encodedAssetAddr matches encodedAssetAddrDecoded
    // otherwise, assert that encodedAssetAddrDecoded is also zero
    //@satisfies(2.1)
    //@argument if publicSpend is nonzero, `1 - publicSpendisZero == 1`, so this constraint is satisfied IFF `encodedAssetAddr == encodedAssetAddrDecoded`
    // (2.1) follows from here by noting that we use `encodedAssetAddr` when computing the note commitments below
    // and that `encodedAssetAddrDecoded` is `pubEncodedAssetAddrWithSignBits` with the sign bits masked to zero (@lemma(5)).
    //@satisfies (2.2)
    //@argument if publicSpend is zero, `1 - publicSpendIsZero == 0`, so this constraint is satisfied IFF `encodedAssetAddrDecoded == 0`.
    // since `encodedAssetAddrDecoded` is `pubEncodedAssetAddrWithSignBits` with the sign bits masked to zero (@lemma(5)) => (2.2)
    encodedAssetAddrDecoded === (1 - publicSpendIsZero) * encodedAssetAddr;

    // compute oldNoteACommitment
    //@satisfies(3.3)
    //@argument NoteCommit.requires(1) is satisfied by definition (exactly what code does), and (3.3) follows from NoteCommit.ensures(1)
    signal oldNoteACommitment <== NoteCommit()(
      Poseidon(4)([oldNoteAOwnerH1X, oldNoteAOwnerH1Y, oldNoteAOwnerH2X, oldNoteAOwnerH2Y]),
      oldNoteANonce,
      encodedAssetAddr,
      encodedAssetId,
      oldNoteAValue
    );

    // compute oldNoteBCommitment
    //@satisfies(3.4)
    //@argument same as (3.3)
    signal oldNoteBCommitment <== NoteCommit()(
      Poseidon(4)([oldNoteBOwnerH1X, oldNoteBOwnerH1Y, oldNoteBOwnerH2X, oldNoteBOwnerH2Y]),
      oldNoteBNonce,
      encodedAssetAddr,
      encodedAssetId,
      oldNoteBValue
    );

    // check merkle tree inclusion proof for oldNoteACommitment
    //@satisfies(8.1)
    //@argument MerkleTreeInclusionProof.requires(1) is satisfied by definition (exactly what code does).
    //  since we set `leaf` to `oldNoteACommitment` and `root` to `commitmentTreeRoot`
    //  (8.1) follows from MerkleTreeInclusionProof.ensures(1)
    commitmentTreeRoot <== MerkleTreeInclusionProof(16)(oldNoteACommitment, pathA, siblingsA);

    // check merkle tree inclusion proof for oldNoteBCommitment only if oldNoteBValue is nonzero
    //@satisfies(8.2)
    //@argument there are two cases:
    // 1. oldNoteBValue is 0. In this case, (8.2) follows from the fact that the constraint below
    //   will always be satisfied
    // 2. oldNoteBValue is nonzero. In this case (8.2) follows from the fact that the constraint below
    //    will only be satisfied if `commitmentTreeRootB == commitmentTreeRoot`, which can only be the case
    //    if there exists a valid merkle membership proof for `oldNoteBCommitment` in the tree
    signal commitmentTreeRootB <== MerkleTreeInclusionProof(16)(oldNoteBCommitment, pathB, siblingsB);
    oldNoteBValue * (commitmentTreeRoot - commitmentTreeRootB) === 0;


    // keccakk256("NULLIFIER") % p 
    var NULLIFIER_DOMAIN_SEPARATOR = 624938365879860864124725276109956130503531086404788051782372112403658760742;

    // derive nullifier for oldNoteA
    //@satisfies(9.1)
    //@argument correct by definition of Nocturne's nullifier derivation
    //@satisfies(9.3)
    //@argument due to StealthAddrOwnership.ensures(3) in the check made above on oldNoteAOwner and (3.3),
    // `vk` is the only possible viewing key that can be used to derive `nullifierA`.
    // therefore, by (9.3) and Poseidon collision resistance, `nullifierA` is the only possible nullifier that can be
    // derived for this note
    nullifierA <== PoseidonWithDomainSeparator(2, NULLIFIER_DOMAIN_SEPARATOR)([oldNoteACommitment, vk]);

    // derive nullifier for oldNoteB
    //@satisfies(9.2)
    //@argument correct by definition of Nocturne's nullifier derivation
    //@satsifes(9.4)
    //@argument same as (9.3)
    nullifierB <== PoseidonWithDomainSeparator(2, NULLIFIER_DOMAIN_SEPARATOR)([oldNoteBCommitment, vk]);


    // check spend signature
    //@argument SigVerify.requires(1) is satisfied by (5.1), and (5.2) is satisfied by SigVerify.ensures(1)
    SigVerify()(spendPubkey, operationDigest, [c, z]);

    // deterministically derive nonce for outgoing notes
    // keccak256("NEW_NOTE_NONCE") % p
    var NEW_NOTE_NONCE_DOMAIN_SEPARATOR = 10280686533006751903887122138624177312632532207046457339587660245394110285166;
    signal newNoteANonce <== PoseidonWithDomainSeparator(2, NEW_NOTE_NONCE_DOMAIN_SEPARATOR)([vk, nullifierA]);
    signal newNoteBNonce <== PoseidonWithDomainSeparator(2, NEW_NOTE_NONCE_DOMAIN_SEPARATOR)([vk, nullifierB]);

    // newNoteACommitment
    //@satisfies(3.1)
    //@argument NoteCommit.requires(1) is satisfied by definition (exactly what code does), and (3.1) follows from NoteCommit.ensures(1)
    newNoteACommitment <== NoteCommit()(
      Poseidon(4)([newNoteAOwnerH1X, newNoteAOwnerH1Y, newNoteAOwnerH2X, newNoteAOwnerH2Y]),
      newNoteANonce,
      encodedAssetAddr,
      encodedAssetId,
      newNoteAValue
    );

    // newNoteBCommitment
    //@satisfies(3.2)
    //@argument NoteCommit.requires(1) is satisfied by definition (exactly what code does), and (3.2) follows from NoteCommit.ensures(1)
    newNoteBCommitment <== NoteCommit()(
      Poseidon(4)([newNoteBOwnerH1X, newNoteBOwnerH1Y, newNoteBOwnerH2X, newNoteBOwnerH2Y]),
      newNoteBNonce,
      encodedAssetAddr,
      encodedAssetId,
      newNoteBValue
    );

    // check refund addr is valid and derived from same VK to prevent transfers via refunds
    //@lemma(6) `(refundAddrH1X, refundAddrH1Y)` is a valid, order-l Baby Jubjub point
    //@argument BabyCheck ensures it's on-curve, IsOrderL ensures it's order-l
    //@lemma(7) `(refundAddrH2X, refundAddrH2Y)` is a valid, but not necessarily order-l Baby Jubjub point
    //@argument same as @lemma(6)
    BabyCheck()(refundAddrH1X, refundAddrH1Y);
    BabyCheck()(refundAddrH2X, refundAddrH2Y);
    IsOrderL()(refundAddrH1X, refundAddrH1Y);

    // compress the two points of the refund addr.
    // connect the y cordinates to the output signals
    // and assert that the sign bits match what was given in `pubEncodedAssetAddrWithSignBits`
    //@satisfies(7.1)
    //@argument CompressPoint.requires(1) is satisfied due to @lemma(6), 
    //   and CompressPoint.ensures(1) satisfies (7.1)
    component compressors[2];
    compressors[0] = CompressPoint();
    compressors[0].in[0] <== refundAddrH1X;
    compressors[0].in[1] <== refundAddrH1Y;
    refundAddrH1CompressedY === compressors[0].y;
    refundAddrH1Sign === compressors[0].sign;

    //@satisfies(7.2)
    //@argument same as (7.1), but without the requirement that the point is order-l and using @lemma(7) instead of @lemma(6)
    compressors[1] = CompressPoint();
    compressors[1].in[0] <== refundAddrH2X;
    compressors[1].in[1] <== refundAddrH2Y;
    refundAddrH2CompressedY === compressors[1].y;
    refundAddrH2Sign === compressors[1].sign;

    //@satisfies(7.3)
    //@argument StealthAddrOwnership.requires(1) and StealthAddrOwnership.requires(2) is satisfied by (7.1) and (7.2),
    //  and StealthAddrOwnership.ensures(1) satisfies (7.3)
    StealthAddrOwnership()(refundAddrH1X, refundAddrH1Y, refundAddrH2X, refundAddrH2Y, vkBits);

    // hash the sender's canon addr as `Poseidon4(keccak256("SENDER_COMMITMENT") % p, senderCanonAddrX, senderCanonAddrY, newNoteBNonce)`
    //@satisfies(12.1)
    //@argument @lemma(2) ensures `senderCanonAddr` is the correct canonical address derived from vk, and `senderCommitment` uses `senderCanonAddr` below
    //@satisfies(12.2)
    //@argument correct by definition (exactly what the code does)

    // keccak256("SENDER_COMMITMENT") % p
    var SENDER_COMMITMENT_DOMAIN_SEPARATOR = 5680996188676417870015190585682285899130949254168256752199352013418366665222;
    senderCommitment <== PoseidonWithDomainSeparator(3, SENDER_COMMITMENT_DOMAIN_SEPARATOR)([senderCanonAddr[0], senderCanonAddr[1], newNoteBNonce]);

    //@satisfies(14)
    //@argument
    // 1. `compressedSenderCanonAddrY`, `senderSignBit` is correct decomposition of `senderCanonAddr` due to @lemma(2) and `CompressPoint.ensures(1)`
    //    and `CompressPoint.requires(1)` is guaranteed by `CanonAddr` derivation above
    // 2. `compressedReceiverCanonAddrY`, `receiverSignBit` is correct decomposition of `receiverCanonAddr` due to @lemma(9) and `CompressPoint.ensures(1)`
    // 3. `oldNoteMerkleIndicesWithSignBits` is encoded correctly by construction due to @lemma(8) and @lemma(9)
    // 4. `joinSplitInfoNonce` is computed correctly by construction
    // 5. `joinSplitInfoCommitment` is computed correctly by construction given the above
    // therefore (14) holds 
    component canonAddrCompressors[2];
    canonAddrCompressors[0] = CompressPoint();
    canonAddrCompressors[0].in[0] <== senderCanonAddr[0];
    canonAddrCompressors[0].in[1] <== senderCanonAddr[1];
    signal compressedSenderCanonAddrY <== canonAddrCompressors[0].y;
    signal senderSignBit <== canonAddrCompressors[0].sign;

    canonAddrCompressors[1] = CompressPoint();
    canonAddrCompressors[1].in[0] <== receiverCanonAddr[0];
    canonAddrCompressors[1].in[1] <== receiverCanonAddr[1];
    signal compressedReceiverCanonAddrY <== canonAddrCompressors[1].y;
    signal receiverSignBit <== canonAddrCompressors[1].sign;

    //@lemma(8) oldNoteAIndex is the 32-bit index of the leaf in the tree that corresponds to pathA
    //@argument `MerkleInclusionProof.ensures(2)` guarantees that each element of `pathA` is a 2-bit number.
    // Therefore `TwoBitLimbsTonNum.requires(1)` is satisfied. The merkle index of a path in a merkle tree is equivalent to the base-b sum
    // of the path indices from leaf to root, so `TwoBitLimbsToNum.ensures(1)` guarantees that `oldNoteAIndex` is the correct, 32-bit merkle index
    signal oldNoteAIndex <== TwoBitLimbsToNum(16)(pathA);

    //@lemma(9) oldNoteBIndex is the 32-bit index of the leaf in the tree that corresponds to pathB
    //@argument same as @lemma(8).
    // Note that `MerkleInclusionProof.ensures(2)` is still relevant in the case when oldNoteB is a dummy note
    // because the second `MerkleInclusionProof` still has to be a valid inclusion proof against *some* root,
    // so even if the prover can put in whatever root they want, `pathB` is still checked to consist only of 2-bit numbers
    signal oldNoteBIndex <== TwoBitLimbsToNum(16)(pathB);
    signal oldNoteMerkleIndices <== oldNoteAIndex + (1 << 32) * oldNoteBIndex;
    signal oldNoteBIsDummy <== IsZero()(oldNoteBValue);
    signal oldNoteMerkleIndicesWithSignBits <== oldNoteMerkleIndices + (1 << 64) * senderSignBit + (1 << 65) * receiverSignBit + (1 << 66) * oldNoteBIsDummy;

    // keccak256("JOINSPLIT_INFO_NONCE") % p
    var JOINSPLIT_INFO_NONCE_DOMAIN_SEPARATOR = 9902041836430008087134187177357348214750696281851093507858998440354218646130;
    // keccak256("JOINSPLIT_INFO_COMMITMENT") % p
    var JOINSPLIT_INFO_COMMITMENT_DOMAIN_SEPARATOR = 8641380568873709859334930917483971124167266522634964152243775747603865574453 ;

    signal joinSplitInfoNonce <== PoseidonWithDomainSeparator(2, JOINSPLIT_INFO_NONCE_DOMAIN_SEPARATOR)([vk, nullifierA]);
    joinSplitInfoCommitment <== PoseidonWithDomainSeparator(6, JOINSPLIT_INFO_COMMITMENT_DOMAIN_SEPARATOR)([compressedSenderCanonAddrY, compressedReceiverCanonAddrY, oldNoteMerkleIndicesWithSignBits, newNoteAValue, newNoteBValue, joinSplitInfoNonce]);
}

component main { public [pubEncodedAssetAddrWithSignBits, pubEncodedAssetId, operationDigest, refundAddrH1CompressedY, refundAddrH2CompressedY] } = JoinSplit();
