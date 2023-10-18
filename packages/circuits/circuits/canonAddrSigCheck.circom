pragma circom 2.1.0;

include "lib.circom";
include "include/babyjub.circom";

//@ensures(1) `compressedCanonAddr` and the sign bit from `msgAndSignBit` are a valid canonical address
//@ensures(2) the prover can produce a valid signature of bottom 252-bits of `msgAndSignBit` with sk corresponding to the canon addr encoded in PIs
template CanonAddrSigCheck() {
    // *** PUBLIC INPUTS ***
	signal input compressedCanonAddrY;
	signal input msgAndSignBit;

	// *** WITNESS ***
	// signature used to prove knowledge of spending key
	signal input sig[2];
	signal input spendPubkey[2];
	signal input vkNonce;

	signal msgAndSignBitBits[253] <== Num2Bits(253)(msgAndSignBit);
	signal signBit <== msgAndSignBitBits[252];
	signal msg <== msgAndSignBit - (1 << 252) * signBit;

	BabyCheck()(spendPubkey[0], spendPubkey[1]);
	IsOrderL()(spendPubkey[0], spendPubkey[1]);

	//@lemma(1) prover can generate valid sig against spendPubkey
	//@argument `SigVerify.requires(1)` is guaranteed by checks above. lemma follows from `SigVerify.ensures(1)` 
	SigVerify()(spendPubkey, msg, sig);

	//@satisfies(2)
	//@argument `VKDerivation.requires(1)` is guranteed by checks above.
	// `VKDerivation.ensures(3, 1)` => vkBits is the LE repr of the correct VK derived from spendPubkey and vkNonce
	// => `CanonAddr.requires(1)` is satisfied. Then, (2) follows from `CanonAddr.ensures(2)`, `@lemma(1)`, and compression checks below
	//@satisfies(1) follows from (2) and `CanonAddr.ensures(1)`
	component vkDerivation = VKDerivation();	
	vkDerivation.spendPubkey <== spendPubkey;
	vkDerivation.vkNonce <== vkNonce;
	signal vkBits[251] <== vkDerivation.vkBits;
	signal canonAddr[2] <== CanonAddr()(vkBits);

	component compressor = CompressPoint();
	compressor.in <== canonAddr;
	compressedCanonAddrY === compressor.y;
	signBit === compressor.sign;
}

component main { public [compressedCanonAddrY, msgAndSignBit] } = CanonAddrSigCheck();
