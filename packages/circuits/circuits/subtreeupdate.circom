pragma circom 2.0.0;

include "include/poseidon.circom";
include "bitifyBE.circom";
include "include/sha256/sha256.circom";

include "lib.circom";
include "tree.circom";

// Update a quaternary subtree of depth 2, where overall tree is of depth r + 2
//@requires(1) encodedPathAndHash is a 2*r + 3 bit number, where (in little-endian order) the first 2*r bits are the path indices
//   represented as a series of two-byit numbers indicating which child to traverse, in order from leaf to root,
//   and the last 3 bits are the high bits of the accumulator hash
//@requires(2) `accumulatorHash` is the low-253 bits of the batch `accumulatorHash` from the commitment tree in `OffchainMerkleTree.sol`
//@requires(3) `2*r + 3` is less than 254 and `r > 0`
//@requires(4) `oldRoot` is the current commitment tree root
//@ensures(1) `accumulatorHash` is the correct accumulator hash over the batch of notes to be inserted
//@ensures(2) `newRoot` is the commitment tree root that results from inserting the batch with accumulator hash `accumulatorHash` (+ 3 hi-bits form `encodedPathAndHash`) into the commitment tree with root `oldRoot`
template SubtreeUpdate4(r) {
    var s = 2;
    // public inputs
    signal input encodedPathAndHash;
    signal input accumulatorHash;
    signal output oldRoot;
    signal output newRoot;

    // merkle proof for the subtree's root
    signal input siblings[r][3];
    // note commitments
    signal input leaves[4**s];
    // bitmap indicating which of the leaves don't appear in the accumulator hash
    // i.e. if the leaf was inserted by a joinsplit, then its corresponding bit will be 0, as we don't know the entire note
    // otherwise, it's 1, since the note was revealed on-chain
    signal input bitmap[4**s];

    // notes to be inserted
    signal input ownerH1Xs[4**s];
    signal input ownerH1Ys[4**s];
    signal input ownerH2Xs[4**s];
    signal input ownerH2Ys[4**s];
    signal input nonces[4**s];
    signal input encodedAssetAddrs[4**s];
    signal input encodedAssetIds[4**s];
    signal input values[4**s];

    //@satisfies(1, 2)
    //@argument SubtreeUpdate.requires(1, 2, 3) are satisfied by @requires(...),
    //   SubtreeUpdate.requires(4) is satisfied by the assignment below,
    //   and SubtreeUpdate.ensures(1, 2) is identical to (1, 2)
    component inner = SubtreeUpdate(r, s);

    // root of the depth-2 subtree filled with `ZERO_VALUE = KECCAK256("nocturne") % p`
    inner.emptySubtreeRoot <== 6810774033780416412415162199345403563615586099663557224316660575326988281139;

    for (var i = 0; i < r; i++) {
        inner.siblings[i] <== siblings[i];
    }

    for (var i = 0; i < 4**s; i++) {
        inner.leaves[i] <== leaves[i];
        inner.bitmap[i] <== bitmap[i];
        inner.ownerH1Xs[i] <== ownerH1Xs[i];
        inner.ownerH1Ys[i] <== ownerH1Ys[i];
        inner.ownerH2Xs[i] <== ownerH2Xs[i];
        inner.ownerH2Ys[i] <== ownerH2Ys[i];
        inner.nonces[i] <== nonces[i];
        inner.encodedAssetAddrs[i] <== encodedAssetAddrs[i];
        inner.encodedAssetIds[i] <== encodedAssetIds[i];
        inner.values[i] <== values[i];
    }

    inner.encodedPathAndHash <== encodedPathAndHash;
    inner.accumulatorHash <== accumulatorHash;
    oldRoot <== inner.oldRoot;
    newRoot <== inner.newRoot;
}

// computes both poseidon and sha256 hash of a "concrete" note as defined in notion
//@ensures(1) noteCommitment is the correct note commitment for the note with fields given as inputs
//@ensures(2) sha256HashBits is the correct sha256 hash of the note with fields given as inputs, represented as a big-endian bitstring
//  where the "sha256 hash of a note" is as defined by `sha256Note` in `TreeUtils.sol`
template NoteCommitmentHash() {
    // ! NOTE: This assumes ristretto compression for addresses has been implemented
    signal input ownerH1X;
    signal input ownerH1Y;
    signal input ownerH2X;
    signal input ownerH2Y;
    signal input nonce;
    signal input encodedAssetAddr;
    signal input encodedAssetId;
    signal input value;

    // bits are in big-endian order
    signal output sha256HashBits[256];
    signal output noteCommitment;

    // compress owner address points
    //@lemma(1) h1CompressedY is the y-coordinate of the compressed point
    //@argument easy to see from implementation of CompressPoint (see `lib.circom`)
    //@lemma(2) h1Sign is the sign of the compressed point, where the x coordinate is considered
    //   "negative" (sign == 1) if it's greater than (p-1)/2, and "positive" (sign == 0) otherwise
    //@argument easy to see from implementation of CompressPoint (see `lib.circom`)
    component compressorH1 = CompressPoint();
    compressorH1.in[0] <== ownerH1X;
    compressorH1.in[1] <== ownerH1Y;
    signal h1Sign <== compressorH1.sign;
    signal h1CompressedY <== compressorH1.y;

    //@lemma(3) h2CompressedY is the y-coordinate of the compressed point
    //@argument same as lemma(1)
    //@lemma(4) h2Sign is the sign of the compressed point, where the x coordinate is considered
    //   "negative" (sign == 1) if it's greater than (p-1)/2, and "positive" (sign == 0) otherwise
    //@argument same as lemma(2) 
    component compressorH2 = CompressPoint();
    compressorH2.in[0] <== ownerH2X;
    compressorH2.in[1] <== ownerH2Y;
    signal h2Sign <== compressorH2.sign;
    signal h2CompressedY <== compressorH2.y;

    // compute sha256 hash
    component sha256Hasher = Sha256(256 * 6);
    component elemBits[6];

    // pack bits into sha256 input
    elemBits[0] = Num2BitsBE_strict();
    elemBits[0].in <== h1CompressedY;

    elemBits[1] = Num2BitsBE_strict();
    elemBits[1].in <== h2CompressedY;

    elemBits[2] = Num2BitsBE_strict();
    elemBits[2].in <== nonce;

    elemBits[3] = Num2BitsBE_strict();
    elemBits[3].in <== encodedAssetAddr;

    elemBits[4] = Num2BitsBE_strict();
    elemBits[4].in <== encodedAssetId;

    elemBits[5] = Num2BitsBE_strict();
    elemBits[5].in <== value;

    // pack bits for H1 into hasher
    sha256Hasher.in[0] <== 0;
    sha256Hasher.in[1] <== h1Sign;
    for (var j = 0; j < 254; j++) {
        sha256Hasher.in[2 + j] <== elemBits[0].out[j];
    }

    // pack bits for H2 into hasher
    sha256Hasher.in[256] <== 0;
    sha256Hasher.in[256 + 1] <== h2Sign;
    for (var j = 0; j < 254; j++) {
        sha256Hasher.in[256 + 2 + j] <== elemBits[1].out[j];
    }

    // pack bits for rest of the fields into hasher
    for (var i = 2; i < 6; i++) {
        sha256Hasher.in[i*256] <== 0;
        sha256Hasher.in[i*256 + 1] <== 0;
        for (var j = 0; j < 254; j++) {
          sha256Hasher.in[i*256 + 2 + j] <== elemBits[i].out[j];
        }
    }

    //@satisfies(2)
    //@argument elemBits[i].out is the big-endian bitstring representation of the ith field of the note, except for
    // elemBits[0] and elemBits[1], which are the big-endian bitstring representation of the y-coordinates of the compressed
    // for the first two 256-bit words, we pack the owner points in as 0 || xSign || yBits. This matches the behavior of `sha256Note`,
    // as this is the same way compressed points are encoded on-chain, and this is checked before the note is queued for insertion.
    // the rest of the fields are packed in as 0 || 0 || fieldBits, which is the same as the behavior of `sha256Note`, as, on-chain,
    // field elements are represented as uint256s, the first two 256-bit words are always 0 if the value is a valid field element,
    // and thisis checked before the note is queued for insertion
    for (var i = 0; i < 256; i++) {
        sha256HashBits[i] <== sha256Hasher.out[i];
    }

    //@satsifes(1)
    //@argument easy to see NoteCommit.requires(1) is true (exactly what code does), and (1) follows from NoteCommit.ensures(1)
    noteCommitment <== NoteCommit()(
        Poseidon(4)([ownerH1X, ownerH1Y, ownerH2X, ownerH2Y]),
        nonce,
        encodedAssetAddr,
        encodedAssetId,
        value
    );
}

// Update a quaternary subtree of depth s, where overall tree is of depth r + s
//@requires(1) encodedPathAndHash is a 2*r + 3 bit number, where (in little-endian order) the first 2*r bits are the path indices
//   represented as a series of two-byit numbers indicating which child to traverse, in order from leaf to root,
//   and the last 3 bits are the high bits of the accumulator hash
//@requires(2) `accumulatorHash` is the low-253 bits of the batch `accumulatorHash` from the commitment tree in `OffchainMerkleTree.sol`
//@requires(3) `2*r + 3` is less than 254 and `r > 0`
//@requires(4) `emptySubtreeRoot` is the correct root of a depth-s subtree full of "zeros", where the "zero value" is up to the caller
//@requires(5) `oldRoot` is the current commitment tree root
//@ensures(1) `accumulatorHash` is the correct accumulator hash over the batch of notes to be inserted
//@ensures(2) `newRoot` is the commitment tree root that results from inserting the batch with accumulator hash `accumulatorHash` (+ 3 hi-bits form `encodedPathAndHash`) into the commitment tree with root `oldRoot`
template SubtreeUpdate(r, s) {

    // Public signals
    // 2*r bits encodes (each path index is 2 bits) the subTreelocation, 3 bits encode the high bits of accumulatorHash
    signal input encodedPathAndHash;

    signal input accumulatorHash;
    signal output oldRoot;
    signal output newRoot;

    // Merkle inclusion witness for the subtree
    signal input siblings[r][3];

    // note commitments
    signal input leaves[4**s];
    // bitmap indicating which of the leaves aren't "opaque" commitments
    // i.e. if the leaf was inserted by a joinsplit, then its corresponding bit will be 0, as we don't know the entire note
    // otherwise, it's 1, since the note was revealed on-chain
    signal input bitmap[4**s];

    // a constant signal that should be passed in by the outer component
    // this should be set to to the value of the root of a depth-s subtree of zeros
    // this is a bit of a hack, but it's best way to do this while retaining parametricity for size
    // since circom doesn't have constant propogration yet
    signal input emptySubtreeRoot;

    // notes to be inserted
    signal input ownerH1Xs[4**s];
    signal input ownerH1Ys[4**s];
    signal input ownerH2Xs[4**s];
    signal input ownerH2Ys[4**s];
    signal input nonces[4**s];
    signal input encodedAssetAddrs[4**s];
    signal input encodedAssetIds[4**s];
    signal input values[4**s];

    // binary-check the bitmap
    for (var i = 0; i < 4**s; i++) {
        bitmap[i] * (1 - bitmap[i]) === 0;
    }

    // hash the notes to get the tree leaves and sha256 hashes to check against accumulator
    signal accumulatorInnerHashes[4**s][256];
    signal tmp1[4**s][256];
    signal tmp2[4**s][256];
    component noteHashers[4**s];
    component leafBits[4**s];
    for (var i = 0; i < 4**s; i++) {
        noteHashers[i] = parallel NoteCommitmentHash();
        noteHashers[i].ownerH1X <== ownerH1Xs[i];
        noteHashers[i].ownerH1Y <== ownerH1Ys[i];
        noteHashers[i].ownerH2X <== ownerH2Xs[i];
        noteHashers[i].ownerH2Y <== ownerH2Ys[i];
        noteHashers[i].nonce <== nonces[i];
        noteHashers[i].encodedAssetAddr <== encodedAssetAddrs[i];
        noteHashers[i].encodedAssetId <== encodedAssetIds[i];
        noteHashers[i].value <== values[i];

        //@lemma(0) `leaves[i]` is the note commitment for the ith note enqueued in the batch on-chain
        // this is clearly the case from this constaint in the case where bitmap[i] == 1
        // in the case where it's 0, the argument goes like this:
        //   - due to @lemma(3), `hasher.out` is the unique, correct accumulator hash for the batch of notes,
        //     so, due to @requires(2), the circuit will be unsatisfiable if the batch supplied as witness to this circuit does
        //     not match that which was queued for insertion on-chain (which includes bitmap)
        //   - since @lemma(1) guarantees that, in the case where bitmap[i] is 0, `accumulatorInnerHashes[i]` is set to `leaves[i]`, then
        //     that means `leaves[i]` must be match the note commitment enqueued on-chain
        bitmap[i] * (noteHashers[i].noteCommitment - leaves[i]) === 0;

        leafBits[i] = Num2BitsBE_strict();
        leafBits[i].in <== leaves[i];
        for (var j = 0; j < 254; j++) {
            tmp2[i][j + 2] <== (1 - bitmap[i]) * leafBits[i].out[j];
        }
        tmp2[i][0] <== 0;
        tmp2[i][1] <== 0;

        //@lemma(1) if `bitmap` matches the bitmap on-chain, then, for all i..4**s: `accumulatorInnerHashes[i]` contains...
        // 1) the sha256 hash of the ith note in the batch (according to `sha256Note` in `TreeUtils.sol`) if bitmap[i] is 1
        // 2) leaves[i] if bitmap[i] is 0
        //@argument `bitmap` matches what was committed to on-chain, then:
        //   1) if `bitmap[i] == 1` `tmp1[i]` is assigned to 0 (due to for loop above) and `tmp2[i]` is assigned to the correct sha256 hash of the note due to selection logic below and NoteCommitmentHash.ensures(2)
        //   2) if `bitmap[i] == 0` `tmp1[i]` is assigned to `leaves[i]` (due to for loop above) and `tmp2[i]` is assigned to 0 (due to note selection logic below)
        for (var j = 0; j < 256; j++) {
            // For some reason circcom complains if I combine these into a single (still quadratic) constraint
            // so I split it up with a temp signal
            tmp1[i][j] <== bitmap[i] * noteHashers[i].sha256HashBits[j];
            accumulatorInnerHashes[i][j] <== tmp1[i][j] + tmp2[i][j];
        }
    }

    // decode pathIndices from encodedPathAndHash
    // note that we decode in LE order here - this is because `BitsToTwoBitLimbs` assumes LE.
    // this is equivalent to the BE way of describing it in the spec
    //@lemma(2) there exists a valid membership proof of an empty depth-s subtree at the location encoded by `encodedPathAndHash` in the tree with root `oldRoot`
    //@argument `pathAndHashBits` is the unique, little-endian bit decomp of `encodedPathAndHash` because @requires(1) gaurantees `Num2Bits` to be safe.
    // => `pathBits` contains the 2*r path bits due to SliceFirstK.ensures(1) since SliceFirstK.requires(1) is satisfied by @requires(3).
    // => `pathIndices` contains pathIndices for path from empty subtree root the commitment tree root since BitsToTwoBitLimbs.ensures(1) matches encoding guaranteed by @requires(1)
    //     and BitsToTwoBitLimbs.requires(1) is guaranteed by @requires(3)
    // =>  @lemma(2) due to MerkleTreeInclusionProof.ensures(1) since MerkleTreeInclusionProof.requires(1) is guaranteed by @requires(3)
    signal pathAndHashBits[2*r+3] <== Num2Bits(2*r+3)(encodedPathAndHash);
    signal pathBits[2*r] <== SliceFirstK(2*r+3, 2*r)(pathAndHashBits);
    signal accumulatorHashTop3Bits[3] <== SliceLastK(2*r+3, 3)(pathAndHashBits);
    signal pathIndices[r] <== BitsToTwoBitLimbs(r)(pathBits);
    oldRoot <== MerkleTreeInclusionProof(r)(emptySubtreeRoot, pathIndices, siblings);

    // Compute accumulator hash for proposed leaves and bitmap (which says which leaves are notes 
    // and which leaves are note commitments)
    component hasher = Sha256(256 * (4**s + 1));

    // set accumulatorHash input
    // accumulatorHash input is a concatenation of all of the sha256 hashes for the notes as big-endian bitstrings (accumulatorInnerHashes)
    // followed by a 256-bit number with the bitmap packed into the upper bits
    // i.e. the ith bit of the bitmap is the ith bit of the last 256-bits of the input
    // i.e. the ith bit of the bitmap is the bit of the number with value 2^(255-i)
    //@satisifies(1) `hasher.out` is the correct accumulator hash for the batch of notes.
    //@argument `accumulatorhash` is defined as sha256(...innerHashes || bitmap) where each element of `innerHashes` is a 256-bit word
    // and `bitmap` is encoded as big-endian number with the ith bit of the bitmap being the ith bit of the number with value 2^(255-i)
    // (i.e. it's padded out to 256 bits, shifted all the way to the most-significant position) 
    // the assigments below match this definition since @lemma(1) guarantees that `accumulatorInnerHashes` are correct`
    // due to collision resistance of sha256 and the fact that bitmap is included in the hash, this is the only possible
    // accumulator hash for this batch

    // set accumulatorInnerHash part of input
    for (var i = 0; i < 4**s; i++) {
        for (var j = 0; j < 256; j++) {
            hasher.in[i*256 + j] <== accumulatorInnerHashes[i][j];
        }
    }
    // set bitmap part of input
    for (var i = 0; i < 4**s; i++) {
        hasher.in[256 * (4**s) + i] <== bitmap[i];
    }
    // pad the rest to 0
    for (var i = 4**s; i < 256; i++) {
        hasher.in[256 * (4**s) + i] <== 0;
    }

    // assert that the accumulatorHash matches what we computed
    signal computedHashBits[253] <== Num2BitsBE(253)(accumulatorHash);
    for (var i = 0; i < 256; i++) {
        if (i < 3) {
            // pathBits are LE, hashBits are BE
            accumulatorHashTop3Bits[2-i] === hasher.out[i];
        } else {
            computedHashBits[i-3] === hasher.out[i];
        }
    }

    //@satisfies(2)
    //@argument due to (1), `hasher.out` is the correct accumulator hash, and due to @requires(2), it will match the `accumulatorHash` PI
    //   (checks above) IFF the batch supplied as witness in this circuit matches the batch queued for insertion on-chain
    //   => that the circuit is satisfiable IFF `newRoot` is the correct root that results from inserting `leaves` into the tree.
    //   due to @lemma(0), `leaves[i]` is the "correct" sequence of leaves to be inserted into the tree, so the circuit is satisfiable
    //   IFF `newRoot` is the correct root that results from inserting the batch of notes committed to by `accumulatorhash` into the tree

    // Compute subtree root
    signal nodes[s+1][4**s];
    for (var i = 0; i < 4**s; i++) {
        nodes[s][i] <== leaves[i];
    }
    for (var i = s; i > 0; i--) {
      for (var j = 0; j < 4**(i-1); j++) {
        nodes[i-1][j] <== Poseidon(4)([
            nodes[i][4*j],
            nodes[i][4*j+1],
            nodes[i][4*j+2],
            nodes[i][4*j+3]
        ]);
      }
    }

    // Merkle tree inclusion proof for new subtree
    newRoot <== MerkleTreeInclusionProof(r)(nodes[0][0], pathIndices, siblings);
}

component main { public [encodedPathAndHash, accumulatorHash] } = SubtreeUpdate4(14);