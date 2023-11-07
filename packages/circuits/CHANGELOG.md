# Changelog

## 1.0.0

### Major Changes

- c2bcb2e: update circuit artifacts with final zkeys from trusted setup

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

- 6c0a5d7c: overhaul monorepo structure & start proper versioning system

### Unreleased

- add positive security annotations to subtreeupdate circuit
- add positive security annotations to `joinsplit.circom`
- add on-curve and order check to `spendPubkey`
- change `IsOrderGreaterThan8` to `IsOrderL`, which is a stricter condition that leaves less room for error
- add witness-gen only BJJ scalar mul
- in `subtreeupdate.circom`, append `bitmap` to preimage of the batch accumulator hash to prevent malicious prover from lying about insertion type (TOB-4)
- in `joinsplit.circom` separate "public encodedAsset`from`private encodedAsset` and check that;
  - they're equal when `publicSpend` is nonzero
  - they "public encodedAsset`is masked to 0 when`publicSpend` is 0
- force `refundAddr` to be owned by the sender
- replace ElGamal encryption with `senderCommitment`
- add `IsOrderGreaterThan8` template and use it to check BJJ points given as input in joinsplit circuit
- skip contributions for subtree update circuit in dev
- clean before building C++ witness generators
- use compressed encodings of note owners to compute accumulator hashes
- add other two coordinates of note owners to subtreeupdate circuit for computing NCs
- compress encSenderCanonAddr in joinsplit circuit:
  - rename `encSenderCanonAddrC1X` and `encSenderCanonAddrC2X` to `encSenderCanonAddrC1Y` and `encSenderCanonAddrC2Y` respectively
  - encode the sign bits of each into bits 248 and 249 of the `encodedAssetAddr` PI
  - rename the `encodedAssetAddr` PI `encodedAssetAddrWithSignBits` because it now has such a confused mix of random shit packed into it that there's no good name for it
- add `PointCompressor`, which takes a babyjubjub point and produces the new Y-coordinate + X sign compressed encoding
- hash all four coordinates of stealth address when computing note commitments
- add new solidity verifier template script
- update empty subtree root
- remove joinsplit compliance circuit (saved elsewhere, don't want dead code in repo though)
- make commitment tree quaternary:
  - add slicing util templates to lib
  - decode `encodedPathAndHash` using LE ordering
  - add `BitsToTwoBitLimbs` template to lib for getting path indices which are now 2-bit numbers
  - circuit is now back under 2^15 (~28K constraints)
- add x-coordinate of PK to hash in schnorr sig
- update verifier contract generator to use arrays instead of `Proof` structs
- force viewing key to be an element of Baby Jubjub scalar field with compconstant
- pull bitified viewing key out into `joinSplit` so we don't decompose it multiple times
- use `Num2BitsBE_strict` in subtree update circuit when necessary
- add `Num2BitsBE_strict`
- add 2^16 ptau as changes take us up a power of two
- encrypt sender's canonical address in joinsplit circuit and expose it as a PI
- clean up visual separation of joinsplit circuit & improve comments
- add range check for old note values before checking totals
- use `Num2Bits_strict` for 254-bit decomps
- Fix regression in subtree update circuit
- Rename encodedAsset to encodedAssetAddr and encodedId to encodedAssetId
- fix endianness bug in subtree update circuit's membership proofs
- add rapidsnark setup script for subtree updater
- Add batch verifier method to auto-generated solidity verifiers
- New `joinsplit` and `joinsplit_compliance` circuit
  - Removed Spend2 and old circuits
- Rename all "flax" instances to "nocturne"
- Change package version to `-alpha`
- add script to download subtreeupdate's chonky ptau file
- add rapidsnark option to subtreeupdate build script
- restructure build scripts with a layer of indirection so they can be invoked all at once
- add subtreeupdate circuit and build script for it
- update spend2 to use new address hashing scheme (2 elements instead of 4)
- Add joinsplit circuit
- Add postprocessing script for circom generated solidity verifier
- Add missing check to ensure `H1^vk === H2` holds
- Circuit packs points via hashing (packing via compression not possible in 254 bits)
- Build script copies Solidity verifier to `/packages/contracts/contracts`
- `vk` is derived from `sk` and circuit checks that signature corresponds to derived `sk` using `vk`
- Simplify `NocturneAddress` to only consist of H1 and H2 (no inclusion of `sk`)
