# Changelog

## 1.0.0

### Major Changes

- c2bcb2e: Update circuit artifacts with final zkeys from trusted setup

## 0.5.0

### Minor Changes

- 2e641ad2: Fix mismatch between joinsplit info commitment and nonce domain separators

## 0.4.0

### Minor Changes

- 58b363a4: - add domain separators for nullifiers and new note nonces
  - set domain separator in initial poseidon sponge state to reduce constraint count
- 58b363a4: add `joinSplitInfoCommitment` PI to JoinSplitCircuit
- 77c4063c: `CanonAddrSigCheck` circuit takes msg directly as PI instead of computing it from nonce
- 589e0230: add new circuit `CanonAddrSigCheck` that can be used to prove knowledge of keys for given canonical address

## 0.3.0

### Minor Changes

- fix publish command

## 0.2.0

### Minor Changes

- 6c0a5d7c: Overhaul monorepo structure & start proper versioning system.

### Unreleased

- Add positive security annotations to subtreeupdate circuit
- Add positive security annotations to `joinsplit.circom`
- Add on-curve and order check to `spendPubkey`
- Change `IsOrderGreaterThan8` to `IsOrderL`, which is a stricter condition that leaves less room for error
- Add witness-gen only BJJ scalar mul
- In `subtreeupdate.circom`, append `bitmap` to preimage of the batch accumulator hash to prevent malicious prover from lying about insertion type (TOB-4)
- In `joinsplit.circom` separate "public encodedAsset`from`private `encodedAsset` and check that;
  - They're equal when `publicSpend` is nonzero
  - They "public encodedAsset`is masked to 0 when`publicSpend` is 0
- Force `refundAddr` to be owned by the sender
- Replace ElGamal encryption with `senderCommitment`
- Add `IsOrderGreaterThan8` template and use it to check BJJ points given as input in joinsplit circuit
- Skip contributions for subtree update circuit in dev
- Clean before building C++ witness generators
- Use compressed encodings of note owners to compute accumulator hashes
- Add other two coordinates of note owners to subtreeupdate circuit for computing NCs
- Compress encSenderCanonAddr in joinsplit circuit:
  - Rename `encSenderCanonAddrC1X` and `encSenderCanonAddrC2X` to `encSenderCanonAddrC1Y` and `encSenderCanonAddrC2Y` respectively
  - Encode the sign bits of each into bits 248 and 249 of the `encodedAssetAddr` PI
  - Rename the `encodedAssetAddr` PI `encodedAssetAddrWithSignBits` because it now has such a confused mix of random shit packed into it that there's no good name for it
- Add `PointCompressor`, which takes a babyjubjub point and produces the new Y-coordinate + X sign compressed encoding
- Hash all four coordinates of stealth address when computing note commitments
- Add new solidity verifier template script
- Update empty subtree root
- Remove joinsplit compliance circuit (saved elsewhere, don't want dead code in the repo though)
- Make commitment tree quaternary:
  - Add slicing util templates to lib
  - Decode `encodedPathAndHash` using LE ordering
  - Add `BitsToTwoBitLimbs` template to lib for getting path indices which are now 2-bit numbers
  - circuit is now back under 2^15 (~28K constraints)
- Add x-coordinate of PK to hash in schnorr sig
- Update verifier contract generator to use arrays instead of `Proof` structs
- Force viewing key to be an element of Baby Jubjub scalar field with compconstant
- Pull bitified viewing key out into `joinSplit` so we don't decompose it multiple times
- Use `Num2BitsBE_strict` in subtree update circuit when necessary
- Add `Num2BitsBE_strict`
- Add 2^16 ptau as changes take us up a power of two
- Encrypt sender's canonical address in joinsplit circuit and expose it as a PI
- Clean up visual separation of joinsplit circuit & improve comments
- Add range check for old note values before checking totals
- Use `Num2Bits_strict` for 254-bit decomps
- Fix regression in subtree update circuit
- Rename `encodedAsset` to `encodedAssetAddr` and `encodedId` to `encodedAssetId`
- Fix endianness bug in subtree update circuit's membership proofs
- Add rapidsnark setup script for subtree updater
- Add batch verifier method to auto-generated solidity verifiers
- New `joinsplit` and `joinsplit_compliance` circuit:
  - Removed Spend2 and old circuits
- Rename all "flax" instances to "nocturne"
- Change package version to `-alpha`
- Add script to download subtreeupdate's chonky ptau file
- Add rapidsnark option to subtreeupdate build script
- Restructure build scripts with a layer of indirection so they can be invoked all at once
- Add subtreeupdate circuit and build script for it
- Update spend2 to use new address hashing scheme (2 elements instead of 4)
- Add joinsplit circuit
- Add postprocessing script for circom generated solidity verifier
- Add missing check to ensure `H1^vk === H2` holds
- Circuit packs points via hashing (packing via compression not possible in 254 bits)
- Build script copies Solidity verifier to `/packages/contracts/contracts`
- `vk` is derived from `sk` and circuit checks that signature corresponds to derived `sk` using `vk`
- Simplify `NocturneAddress` to only consist of H1 and H2 (no inclusion of `sk`)
