# Changelog

## 2.0.1

### Patch Changes

- 5a525bf: initialize ReentrancyGuard upgradeable in DepositManager initialization function
- 1cbbc76: Add tokenOut check for exactInputSingle in UniswapV3Adapter
- a3fd094: Make rocketpool storage contract public on rETHAdapter

## 2.0.0

### Major Changes

- 1131f3e: remove unnecessary fields from `DepositRetrieved` and `DepositCompleted`

### Minor Changes

- f1b2deb: Add UniswapV3Adapter to validate calldata after audit finding

### Patch Changes

- 0848a7b: add check for ops with no joinsplits

## 1.2.1

### Patch Changes

- add `getPoseidonBytecode` function

## 1.2.0

### Minor Changes

- c717e4d9: Revert forcedExit changes across the stack

### Patch Changes

- c717e4d9: Add onlyEoa check for processBundle to ensure processBundle cannot be called atomically with another action like a DEX imbalance

## 1.1.1

### Patch Changes

- 6ec2a7ac: Make spacing consistent for SPDX licenses

## 1.1.0

### Minor Changes

- 54b1caf2: add PoseidonExt
- f80bff6a: Include `op.forcedExit` flag to tell Handler not to create refund/output notes
- 5d90ac8e: Make bundler role permissioned and add forcedExit method that wraps \_processBundle

### Patch Changes

- 5d90ac8e: Remove double abstraction layer for poseidon hashers and just have IPoseidon and IPoseidonExt in tests and Teller

## 1.0.0

### Major Changes

- 444321c0: In wsteth and reth adapter, rename 'convert' to 'deposit'

### Minor Changes

- 444321c0: Add RethAdapter for rocket pool support + fork tests

### Patch Changes

- 444321c0: Add additional excludeSender(ethTransferAdapter) to invariant tests which was previously forgotten

## 0.5.0

### Minor Changes

- 7d151856: Add eth transfer adapter and integrate into unit and invariant tests
- 46e47762: Add foundry script for deploying eth transfer adapter + shell script for calling forge script

### Patch Changes

- 7d151856: Replace all instances of erc20.reserveTokens (simpleerc20) with foundry deal()"

## 0.4.0

### Minor Changes

- 6998bb7c: make deposit reset window configurable by adding `resetWindowHours` to erc20 cap struct
- 77c4063c: Add CanonicalAddressRegistry contract which integrates canon addr sig check verifier, add unit tests as well for EIP712 hashing and registry state changes
- de88d6f0: add wsteth adapter contract, add fork tests for wsteth, balancer, and uniswap for weth<>wsteth testing
- 58b363a4: add `joinSplitInfoCommitment` PI to JoinSplitCircuit
- 589e0230: add `CanonAddrSigCheckVerifier` contract

### Patch Changes

- 1ffcf31f: update contract and sdk bundler gas comp estimate numbers
- 1ffcf31f: update gas calculation math in Types.sol and core op request gas to come within ~50k of actual gas spent by bundler

## 0.3.0

### Minor Changes

- fix publish command

## 0.2.0

### Minor Changes

- 6c0a5d7c: overhaul monorepo structure & start proper versioning system

### Unreleased

- add bitmap checks to offchain merkle unit tests
- modify invariant tests to accomodate `retrieveETHDeposit`
- add `retrieveETHDeposit` to DepositManager + fallback fn for receiving ETH when calling `weth.withdraw`
- track pre/post op merkle count and attach to `OperationResult` and `OperationProcessed` event
- propagate which merkle index a deposit is for and add `merkleIndex` to `DepositCompleted` event
- rename/reorder some joinsplit circuit fields
- add `validateOperation` function to `ValidationLib` which ensures that:
  - the operation has only > 0 public spends for pubJoinSplits (between circuits and this check, we know for sure that all pub joinsplits are spending non-masked assets and all conf joinsplits are spending masked assets)
  - the encoded gas asset is an erc20
- have AssetUtil transferFrom, transferTo, and approve revert in the erc721/1155 case to make sure the Teller/Handler cannot transact with non erc20 tokens at all
- collapse tracked assets into single array to save gas/code
- add `validateNote` and `validateCompressedPoint` to new `Validation` lib
- validate refund notes before they are queued for insertion into the commitment tree
- add test lib `AlgebraicUtils` that implements BN254 field arithmetic and point decrompression
- append `bitmap` to preimage of `accumulatorHash` to prevent prover from lying about insertion type (TOB-4)
- check code size of contract called in `_makeExternalCall` (TOB-13)
- remove `op.maxNumRefunds` now that number of refund assets is statically determined
- add test cases to ensure min return value functionality works as expected
- `_ensureMinRefundValues` called after action execution returns accurate num refunds estimate so bundler gas comp estimate is more accurate (TOB-15)
- Handler ensures each joinsplit and refund asset has min return value post-action-execution otherwise revert
- separate joinSplit assets from joinSplits, split into `op.trackedJoinSplitAssets` and having joinSplits have `assetIndex` field
- Add `TrackedAsset` type for joinSplits and refunds to support "min return value" feature (TOB-10)
- add tests for erc20 approve checks in handler
- add special check for erc20.approve to ensure decoded spender is on whitelist
- change \_supportedTokens to \_supportedContracts
- Rename `DepositManagerBase` and `TellerBase` to `DepositRequestEIP712` and `OperationEIP712`
- Teller contract init function takes contract name and version
- add `TellerBase.t.sol` for eip712 unit tests
- add and integrate `TellerBase` for EIP712 op digest calculation, remove old op digest calculation
- update `EncryptedNote` type for new note encryption scheme
- use `Ownable2StepUpgradeable` instead of normal `OwnableUpgradeable` in DepositManager, Teller, and Handler (TOB-7)
- separate setting of `_teller` from Handler initialization to remove front-running risk (TOB-9)
- add functions to ensure Handler balances are zeroed out pre-operation (TOB-16)
- make protocol allowlist per-method, add separate allowlist for tokens (TOB-16)
- Remove ERC721/1155s from all unit and invariant tests
- Remove ERC721/1155 onReceived hooks in the Teller and Handler (TOB-10/16/23)
- Estimate totalNumRefundsToHandle as number of joinsplits + number of refunds assets
- Remove the `_receivedAssets` mechanism in the Handler now that the onReceived hooks are gone (TOB-10/16/23)
- fix eip712 deposit request typehash ordering
- update gas comp numbers in `Types.sol` and remove verify gas estimate since not needed
- use new compressed encoding to compute note hashes in subtree update logic
- replace `StealthAddress` with `CompressedStealthAddress`, which is composed of two points in 255-bit compressed encoding
- remove proof and root from joinsplit events
- `OperationProcessed` event removes two indexed params (more of this to come soon)
- small gas optimization where we use contiguous subarray index to avoid checking balances for joinsplits of same asset in `BalanceManager`
- remove insertion events from CTM
- remove batch refunds to save on code size and 3k of gas in 1 refund case
  - all insert "notes" plural becomes insert "note" singular (in CTM and OffchainMerkle)
  - refunds are inserted one-by-one (BalanceManager)
- fix bug where empty insertion events are emitted when we have 0 refunds
- add more offchain merkle unit tests
- fix bug where invariant tests were not completing weth deposits, weth is now deposited and transacted with in ops
- unify deposit/joinsplit tokens in invariant tests such that erc20s and weth are no longer separate cases
- add `BalanceManager` test case that tests multiple contiguous subarrays for joinsplits (wasn't tested in BalanceManager gas opt PR 1)
- enable operations with more than one joinsplit token in unit and invariant tests
- BalanceManager checks if reserved - payout < threshold, if so it just gives it all to bundler so there's no refund
- add op.gasAssetRefundThreshold to operation
- move `HandlerBase` into helpers so OperationGenerator can also use
- fix bug in CTM require statement for checking batch is non empty
- move `InvariantUtils` into helpers so OperationGenerator can also use
- modify CTM/OffchainMerkle invariant handler to use seed then generate rand struct inputs rather than potentially huge array of structs which slows down test time
- group processJoinSplit transfers by contiguous subarray to save 10k gas per joinsplit of same asset
- replace `handleRefundNote` with `handleRefundNotes`, which inserts notes to tree's batch array in one go to save on SSTOREs
- replace `handleJoinSplit` with `handleJoinSplits`, which inserts NCs to tree's batch array in one go to save on SSTOREs
- don't actually store zero values to storage in `fillBatchWithZeros`. Just emit the correct events, update counts, and accumulate.
- keep `batchLenPlusOne` instead of `batchLen` to avoid setting it to 0
- use `ZERO_VALUE = keccak256("nocturne") % p` instead of `0` as the dummy value in the tree
- fix invariant `TellerHandler` bug where joinSplitUnwrapAmount > gasComp led to opMeta.totalJoinSplitUnwrapped being lower than actual (fixed by just gathering total joinsplit amount directly from op)
- rename the `subtreeIndex` field of `SubtreeUpdate` event to `subtreeBatchOffset`
- have teller balance invariants account for taking/refilling prefills
- add transferred out < joinsplits unwrapped invariant
- add room for over transfer/swap in invariant tests
- make for loop length caching consistent across all .sol files
- add fuzz tests for asset and pathAndHash encodings
- add natspec docs for NocturneReentrancyGuard
- add natspec docs for DepositManager and DepositManagerBase
- add natspec docs for Teller
- add natspec docs for handler
- Add separate deposit struct different from `DepositRequest`
- add natspec docs to balance manager
- remove admin prefill logic and replace with new scheme were handling refunds attempts to reserve 1 erc20 token each time if balance == 0
- fix invariant test address setup so all addrs come from `InvariantsBase.sol`
- add natspec docs to CTM
- move fill batch logic and state from handler into CTM (we already expose applySubtreeUpdate externally, all the related fillbatch logic should remain in the same contract)
- add 16 batch proof verification to joinsplit and subtree updater verifiers
- update AssetUtils encode/decode test with all asset types
- add unit tests for erc1155 batch received and erc20 cap setting
- move reentrancy guard from bal manager into handler
- move asset received hooks to handler so it can check protocol whitelist (move unit tests from balance manager to handler as well)
- add some extra parse utils used when debugging invariant tests
- whitelist erc721/1155 in invariant tests and ensure all assets are actually being received by teller from swapper
- deposit invariant tests add special case workaround for retrieved gas comp == gas comp cap (see inline commment)
- AssetUtils `transferAssetTo` uses `erc721.safeTransferFrom`
- AssetUtils `balanceOfAsset` avoids revert when checking erc721 `ownerOf`
- unit and invariant tests now use `vm.txGasPrice` and test screener comp with non-zero comp amounts
- rename `DepositSumSet` to `ActorSumSet`
- fix comment on guarantees around screener compensation
- ensure deposited and refunded assets are in allowlist and add corresponding unit tests
- make protocol allowlist only address, remove function selector specificity
- update invariant tests to use multideposit for erc20s and eth
- add unit tests for multidepositing 10 deposits
- add unit tests for failure cases of exceeding global cap, using unsupported asset, and depositing over max single deposit size
- `completeDeposit` becomes internal method and we expose `completeErc20Deposit` which checks global hourly cap
- replace `instantiateDeposit` and `instantiateETHDeposit` with erc20-specific methods that allow for multi deposits in same call
- add modifiers to enforce erc20 max deposit size for instantiating deposits and global cap for completing deposits
- add erc20 caps to deposit manager which includes global hourly cap and max deposit size
- use single `_nonce` for deposit manager instead of nonce mapping (cheaper)
- Add `sum` method to `Utils`
- fix `AssetUtils` to ensure erc721 methods only have `value = 1` to avoid any unexpected behavior
- make commitment tree quaternary:
  - update `TreeUtils` constants
  - update `TreeUtils` PI encoding / decoding helpers
  - update joinsplit and subtreeupdate verifiers
  - update `TreeTest` to simulate incremental quaternary tree
  - update tests
- check for compensation in `invariant_protocol_walletBalanceEqualsCompletedDepositSumMinusTransferedOutPlusBundlerPayoutErc20` and add new test case for checking bundler balance equals tracked
- add bundler compensation to `OperationGenerator.sol`
- add unit test for `AssetUtils` encode and decode after bug fix
- fix `AssetUtils` bit shift bug where `encodedAssetAddr` was being incorrectly formatted and causing high asset values to produce wrong decodings
- add comment documenting retrieve deposit griefing assumption
- add invariant RE bottom log2(batch_size) bits of `OffchainMerkle.count`
- require `OffchainMerkle.insertNoteCommitments` ncs < scalar field
- require `CTM.fillBatchWithZeros` to be called on non-empty batch
- add initial CTM invariant tests
- add `CommitmentTreeManagerHandler`
- add `TestCommitmentTreeManager` to test harnesses
- Rename `BinaryMerkle` to just `IncrementalTree` + `LibIncrementalTree`
- Add invariant tests for tracking swap token balances
- Add erc20 transfers out to net balances invariant test
- Add `WalletHandler` to track bundle-related info
- Add `OperationGenerator` contract for creating random swaps and transfers
- Add `TokenIdSet` helper to invariant tests
- Add `exists` method `SimpleERC721Token`
- Split up invariant checks again to make debugging failures easier
- add `ProtocolInvariants.t.sol`, which inherits `InvariantsBase` and groups up related assertions into single invariants (more efficient use of test runs to check all assertions on every run)
- convert `DepositManagerInvariants.invariants.t.sol` into `InvariantsBase.sol` which only exports assertions and summary printing and itself does not run tests
- move state and instantiation logic out of `DepositManagerHandler` into the actual invariant test files
- rename `handlers` folder to `actors`
- rename `OffchainMerkleInvariants.invariants.t.sol` to just `OffchainMerkleInvariants.t.sol`
- add invariant tests for offchain merkle lib
- remove unused types in `Types.sol`
- move external methods to top in wallet / balance manager
- Change `InsertNotes` event to `InsertNote` (singular)
- Remove `insertNotes` (plural) and `insertNoteCommitment` (singular) + related events since both are dead code
- include `op.atomicActions` in op digest calculation
- make `handleOperation` default revert reason more helpful
- give different revert message if action reverts silently than if `handleOption` reverts
- Add 2 PIs for encrypted sender canonical address (`encSenderCanonAddrC1X`, `encSenderCanonAddrC2X`) to joinsplit verification logic
- add encrypted sender canonical address to `JoinSplit` struct
- Remove unused fns in `Queue.sol`
- Simplify `AssetUtils` to not have pass through fns
- Simplify `Utils` to only contain min function and BN254_SCALAR_FIELD_MODULUS (no longer an "everything" utils file)
- Move tree-related utils in `Utils.sol` into `TreeUtils.sol`
- Encapsulate `Groth16.Proof` struct to Groth16 library so we don't have `Utils.proof8ToStruct` floating around everywhere
- underscore library methods that are only used internally within library currently
- resolve compiler build warnings coming from test code
- Add unit test for calling non allowed protocol
- Add `callableContractAllowlist` to handler which specifies which protocols + fn selectors users can call from handler
- remove all subtree batch fill refs from wallet
- make invariant tests exclude invariant handler from sender set
- start invariant tests, beginning with DepositManager tests
  - add `InvariantHandler.sol` for protocol-wide actor interface
  - Add helpers for tracking actors, balances, deposits
  - Add partially complete `DepositManager.invariants.t.sol`
- move all unit tests to `test/unit`
- add `EventParsing` test library that currently reads Deposit events into `DepositRequest`
- make `ParseUtils` library instead of contract
- fix deposit screener gas comp to account for cost of eth transfers
- fix bug in `DepositManager.completeDeposit` where deposit hashes were not being marked false post completion
- add support for instantiating ETH deposits + test case for success and failure
- Add test case for atomic actions + action failure
- Add `op.atomicActions` flag and revert in `handler.executeActions` if flag set to true and any action fails
- Add `opResults.assetsUnwrapped` flag to differentiate when joinsplits are processed or not
- Properly bubble up correct info in `OperationResult` between Wallet and Handler
- Reduce number of local stack vars used in `OperationUtils.computeOperationDigest`
- Delete unused `OperationUtils.unsuccessfulOperation` method
- Integrate `SafeERC20` into `AssetUtils`
  - NOTE: we are still waiting for next release from OZ to use `forceApprove` which is more gas efficient version of setting allowance to 0 then approving
- Generalize `JoinSplitsFailureType` in testing to `OperationFailureType` and add `BAD_CHAIN_ID` and `EXPIRED_DEADLINE` variants
- Add `chainId` and `deadline` to operation
- Re-order packing in `computeOperationDigest` and break into helper fns for stack size limit
- Simplify `DepositManager.instantiateDeposit` to only take asset, value, and depositAddr (convert deposit req checks into contract reads)
- Remove `chainId` from `DepositRequest` (already included in eip712 domain)
- Move `BinaryMerkle` into `test/utils`
- Move all poseidon and hasher references into `test/utils` (IHasher, IPoseidon, PoseidonHashers all go into tests because not used in production code)
- Add `Pausable` to wallet and handler + deps (balance manager & commitment tree)
  - Wallet: all non-admin external methods `whenNotPaused` (`depositFunds`, `processBundle`, `requestAsset`)
  - Handler: all non-admin external methods `whenNotPaused` (`handleDeposit`, `handleOperation`, `executeActions`)
    - BalanceManager: all onReceived hooks `whenNotPaused`
    - CommitmentTreeManager: `applySubtreeUpdate` made `whenNotPaused`
- `BalanceManager` revokes prefills for erc721s and enables for 1155s
- Rename `OperationReentrancyGuard` to `NocturneReentrancyGuard` and add `addAssetToPrefillGuard` to account for erc1155 prefills
- Add missing handler unit tests for setting subtree filler and adding to asset prefill
- Add missing wallet unit tests for bundler comp success and direct handler reentrancy into wallet
- Add balance manager token balance gas optimization, which allows for prefilling balances so we're not clearing token balance storage slots to 0 each time
- Have `TestBalanceManager` implement `IHandler` for ease of unit testing with wallet
- Rename `WalletUtils` `OperationUtils` now that both Wallet and Handler use it
- Separate `Wallet` functionality into `Wallet` (proof verification, entrypoint) and `Handler` (processing/executing operations, commitment tree)
- Remove vault contract entirely
- Fix bug where balance manager initialize was `public` not `internal`
- Add permission gate to `fillBatchWithZeros`
- Add fixture check against deposit request hash in `DepositManagerBase` unit tests
- Rename `processDeposit` and `DepositProcessed` to `completeDeposit` and `DepositCompleted`
- delegate to single verifier in batch verifier if batch size is 1
- Change Deposit events to include all info needed to recover deposit hash
- Refactor unit tests to whitelist deposit source for deposits now that we use that instead of `msg.sender == deposit.spender`
- Vault and BalanceManager now take both deposit and its `source` so they know where transfer funds from upon deposit
- Add `_depositSources` to wallet and integrate `DepositManager`
- Add `DepositManager` contract + unit tests up to process deposit failing because Wallet expects `msg.sender == deposit.spender` (to fix in followup PR)
- Bump Open Zeppelin npm deps to `4.8.2`
- Add json decoding utils for retrieving signed deposit request fixture
- Add initial `DepositManagerBase` contract and fixture unit test
- Add `Operation.gasAsset` instead of using `joinsplits[0]`
- Make `OperationReentrancyGuard` only for op processing/execution, use OZ `ReentrancyGuardUpgradable` for `processBundle` (the only actually exposed method for wallet)
- Add `Wallet` unit tests
  - Reentrancy from actions
  - In-action failure cases (call failure)
  - Pre-action failure cases (while processing joinsplits, not enough bundler comp)
  - Access control for `processOperation` and `executeActions`
  - OOG gas test
  - E2E tests with receiving assets from `TokenSwapper` test contract
- Add more `BalanceManager` tests for testing joinsplit verification failures
- Add `ForgeUtils` contract for vm expecting events
- Add `TokenSwapper` and `ReentrantCaller` test contracts for wallet tests
- Add interfaces for Simple tokens to be used in `TokenSwapper`
- Remove `verificationGasLimit` from `Operation`
- Break shared utils for Wallet and BalanceManager into `NocturneUtils` test lib
- Add separate `BalanceManager` unit tests (`BalanceManager.t.sol`)
- Move designated test contracts into `test/harnesses` folder
- Granularize in-contract gas estimate by separating joinsplit cost into verification + handling in `Types.sol`
- Add script for producing `.storage-layouts` file + commit `.storage-layouts` file
- Add storage GAP to `NocturneReentrancyGuard`
- Remove `poseidonTest` from `Wallet.t.sol`
- Delete old `gasTesting` files
- Move the Simple ERC tokens to `test`
- Rename `libs/types.sol` to uppercase `Types.sol`
- Rename:
  - `NoteTransmission` -> `EncryptedNote`
  - `NocturneAddress` -> `StealthAddress`
  - `JoinSplit` event -> `JoinSplitProcessed` event
  - `Refund` event -> `RefundProcessed` event
  - `JoinSplitTx` -> `JoinSplit`
- Remove `deployer` directory in favor of `deploy` package
- Deploy script takes mock subtree update verifier param as env var
- Deploy script logs network info and start block
- Check if bundler payout > 0 tokens and only call transfer if so
- fix loop index bug in `extractJoinSplitProofsAndPis`
- fix contract calculating opDigest differently from frontend
- put forge deps install script into this package
- Add additional unit tests for processing multiple joinsplits
- Make underscores consistent in `WalletUtils` and `AssetUtils`
- Optimizer runs 99999 -> 500 to get back under code size limit
- Modify `hardhat.config.ts` to take private keys from env for deploy script
- Add deploy script to `deployer` directory
- Replace all dependent OZ libraries with their upgradeable versions for Wallet, BalanceManager, CommitmentTreeManager, and NocturneReetrancyGuard
- Replace all constructors for initializers (in Wallet, BalanceManager, CommitmentTreeManager, and NocturneReentrancyGuard)
- Add TransparentProxy, ProxyAdmin, and Versioned to `contracts/upgrade`
- Changed to a custom implementation of ReentrancyGuard to properly reflect operation processing status
- Fixed a bug that `_receivedAssets` is modified outside an operation
- Fixed a bug that refunds in `encodedRefundAssets` are not processed
- Merge `joinSplitTx.encodedAssetAddr` and `joinSplitTx.encodedAssetId` into one `joinSplitTx.encodedAsset`
- Make `performOperation` nonReentrant
- Remove unnecessary `_nonce` state variable, use current tree size as nonce
- Remove `opSuccess` and add `opProcessed`, which indicate internal error during processing
- Fix asset/id encoding according to design doc
- Overhaul BalanceManager logic to use less storage
- Implement gas fee mechanism
- add test for subtree update PI calculation
- separate subtree update PI calculation into separate function
- Make solidity var underscore style consistent
- Add `ProcessOperation` event to wallet to emit details about processed ops
- `Wallet._makeExternalCall` no longer reverts on reverting contract call (enables us to process calls even if they revert)
- Calculate `operationDigest` in wallet instead of pushing `uint256` conversion and mod to `CommitmentTreeManager`
- Use the batch verifier to batch verify all joinsplit proofs in a bundle
- Change verifier interfaces to take structs instead of `uint256` arrays
- Add a `SubtreeUpdate` event to `CommitmentTreeManager` for when a subtree update is committed
- Add `test:gas-report` command
- Add batch proof verification
- Add a `SubtreeUpdate` event to `CommitmentTreeManager` for when a subtree update is committed
- Add `test:gas-report` command
- Migrate for joinsplit
  - Compute operationDigest once for the entire operation
- Rename all "flax" instances to "nocturne"
- Change package version to `-alpha`
- Rename `Joinsplit` to `JoinSplit`
- move `OffchainMerkleTree` into a library and have `CommitmentTreeManager` hold the state
- remove `IBatchMerkle` and `BatchBinaryMerkle`
- split `Utils` into `TreeUtils` and `Utils`
- Add fixture unit test for `SubtreeUpdateVerifier`
- Update `DummyWallet` unit test to use `OffchainMerkleTree` instead
- Add unit test for `OffchainMerkleTree`
- Add `TreeTest` lib to test utils. Containins helpers for computing / maintaining subtree roots
- Add `TestSubtreeUpdateVerifier` to test utils
- Change `CommitmentTreeManager` to use `OffchainMerkleTree` instead of `BatchBinaryMerkle`
- Remove Poseidon from all contracts
- Split `LeavesInserted` event into `InsertNoteCommitment` and `InsertNote`
- Add `IOffChainMerkleTree` and `MerkleTree` for Offchain ZK updates
- Add `Utils` lib for encoding / hashing details
- Add `SubtreeUpdateVerifier` contract
- Make Pairing library from circom reusable for different circuits
- Fix events to have fields > 32 bytes be not `indexed`
- Add `Spend` event and emit on `handleSpend`
- Rename spend transaction `value` to `valueToSpend`
- Fix merkle index bug where `insert8` and `insert16` only incremented `numberOfLeaves` by 1
- Start test suite for `PoseidonBatchBinaryMerkle`
- Break up `BatchBinaryMerkle` lib into `BinaryMerkle` and `Queue`
- Add `Refund` events to `CommitmentTreeManager`
- Update `Spend2Verifier` to match simplified `NocturneAddress` + vk/sk scheme
- Rename `SpendTransaction.noteCommitment` to `newNoteCommitment` for clarity
- Add tests for verifier contract
- Make commitment tree and hash functions generic behind interfaces
- Add contracts as package in yarn workspace
