pragma circom 2.1.0;

include "include/poseidon.circom";
include "include/escalarmulany.circom";
include "include/aliascheck.circom";
include "include/compconstant.circom";
include "include/bitify.circom";
include "include/comparators.circom";
include "scalarMulWitGen.circom";

// compute note commitment
//@requires(1) `ownerHash` is `Poseidon4([ownerH1X, ownerH1Y, ownerH2X, ownerH2Y])
//@ensures(1) `out` is the correct note commitment of the note with fields:
//   - owner: (`ownerH1X`, `ownerH1Y`, `ownerH2X`, `ownerH2Y`)
//   - nonce: `nonce`
//   - encodedAssetAddr: `encodedAssetAddr`
//   - encodedAssetId: `encodedAssetId`
//   - value: `value`
template NoteCommit() {
    signal input ownerHash;
    signal input nonce;
    signal input encodedAssetAddr;
    signal input encodedAssetId;
    signal input value;

    signal output out;

    //@satisfies(1)
    //@argument true by definition (exactly what this code does) from @requires(1) and definition of Nocturne note commitment
    component noteHash = Poseidon(5);
    noteHash.inputs[0] <== ownerHash;
    noteHash.inputs[1] <== nonce;
    noteHash.inputs[2] <== encodedAssetAddr;
    noteHash.inputs[3] <== encodedAssetId;
    noteHash.inputs[4] <== value;
    out <== noteHash.out;
}

//@requires(1) `PX` and `PY` comprise a valid Baby Jubjub point (i.e. it's on-curve)
//@ensures(1) `PX` and `PY` comprise a Baby Jubjub point in the prime-order subgroup (i.e. it's a point of order l)
template IsOrderL() {
    signal input PX;
    signal input PY;

    // inverse of 8 mod l, the order of Baby Jubjub's prime-order subgroup
    // in little-endian bit repr
    // 2394026564107420727433200628387514462817212225638746351800188703329891451411
    var inv8[251] = [1, 1, 0, 0, 1, 0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 1, 1, 1, 1, 1,
        1, 1, 0, 0, 0, 1, 1, 0, 1, 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1,
        0, 0, 0, 1, 0, 0, 0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1,
        0, 0, 0, 0, 0, 1, 0, 1, 1, 0, 0, 1, 1, 1, 1, 1, 1, 1, 0, 0, 0, 1, 1, 0,
        0, 1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 0, 0, 0, 1, 1, 1, 0, 1, 0, 1,
        1, 1, 0, 1, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 1, 0, 1, 1, 0, 1, 0, 0, 1, 0,
        0, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 1, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1, 0, 0,
        1, 1, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 1, 0, 1, 0, 0, 0, 0, 0, 0, 1, 0, 0,
        1, 0, 0, 1, 0, 0, 0, 0, 1, 1, 0, 1, 1, 0, 1, 1, 0, 1, 0, 0, 0, 0, 1, 0,
        1, 0, 0, 0, 0, 1, 0, 0, 1, 0, 0, 1, 0, 1, 0, 0, 1, 0, 0, 0, 1, 1, 1, 1,
        1, 0, 1, 0, 1, 0, 0, 1, 0, 1, 0, 1
    ];

    // witness Q = (inv(8) mod l) * P
    signal Q[2] <-- scalarMul(PX, PY, 251, inv8);
    BabyCheck()(Q[0], Q[1]);

    signal Q2X, Q2Y, Q4X, Q4Y, Q8X, Q8Y;

    (Q2X, Q2Y) <== BabyDbl()(Q[0], Q[1]);
    (Q4X, Q4Y) <== BabyDbl()(Q2X, Q2Y);
    (Q8X, Q8Y) <== BabyDbl()(Q4X, Q4Y);

    // check that 8Q = P
    //@lemma(2) if 8Q == P, then either P has order l or 1
    //@argument
    //   1. BabyCheck above guarantees Q is a valid baby Jubjub point.
    //   2. by lagrange's theorem, the order of Q must divide 8*l (Baby Jubjub order), so ord(Q) must be 1, 2, 4, 8, l, 2l, 4l, or 8l.
    //   3. for any group element Q, ord(kQ) = ord(Q) / gcd(ord(Q), k)
    //   therefore:
    //   - if ord(Q) is 1, 2, 4, or 8, ord(P) == ord(8Q) == 1 due to the formula above
    //   - if ord(Q) is l, 2l, 4l, 8l, ord(P) == ord(8Q) == l due to the formula above
    //   in every case, @lemma(2) is satisfied
    PX === Q8X;
    PY === Q8Y;

    // check that PX is not the identity
    //@satisfies(1)
    //@argument @lemma(2) guarantees ord(P) is either 1 or l because otherwise the constraints above (P == 8Q) would be unsatisfiable
    //  the constraint below is unsatisfiable if the order is 1, because the only element with order 1 is the identity, (0, 1),
    //  which has X coordinate 0
    signal Q8XIsZero <== IsZero()(PX);
    Q8XIsZero === 0;
}

//@requires(1) `spendPubkey` is a valid, order-l Baby Jubjub point
//@ensures(1) `vkBits` is a 251-bit little-endian representation of `vk`, which entails that every signal in the array is binary
//@ensures(2) `vk` is an element of the scalar field of Baby Jubjub's prime-order subgroup
//@ensures(3) `vk` is correctly derived from given `spendPubkey` and `vkNonce`
template VKDerivation() {
    signal input spendPubkey[2];
    signal input vkNonce;
    signal output vk;
    signal output vkBits[251];

    var BABYJUB_SCALAR_FIELD_ORDER = 2736030358979909402780800718157159386076813972158567259200215660948447373041;

    // derive spending public key and check it matches the one given
    //@satisfies(3)
    //@argument correct by definition of Nocturne's key derivation process
    vk <== Poseidon(3)([spendPubkey[0], spendPubkey[1], vkNonce]);

    //@satisfies(1)
    //@argument this is precisely what `Num2Bits(251)` does. If `vk` is greater than 251-bits, then `Num2Bits(251)` would be unsatisfiable
    vkBits <== Num2Bits(251)(vk);

    //@satsfies(2)
    //@argument we know from the previous check that `vk` is a 251-bit number. To ensure it's a member of the scalar field,
    // we do a 251-bit comparison with the order of the scalar field, which is sufficient to ensure that it's an element of the scalar field
    component gtFrOrderMinusOne = CompConstant(BABYJUB_SCALAR_FIELD_ORDER - 1);
    for (var i=0; i<251; i++) {
      gtFrOrderMinusOne.in[i] <== vkBits[i];
    }
    gtFrOrderMinusOne.in[251] <== 0;
    gtFrOrderMinusOne.in[252] <== 0;
    gtFrOrderMinusOne.in[253] <== 0;
    0 === gtFrOrderMinusOne.out;
}

// checks that a stealth address belongs to a given vk
//@requires(1) `H1X` and `H1Y` comprise a valid, order-l Baby Jubjub point (i.e. it's on-curve)
//@requires(2) `H2X` and `H2Y` comprise a valid, but not necessarily order-l Baby Jubjub point (i.e. it's on-curve)
//@ensures(1) `H2X` and `H2Y` comprise a order-l Baby Jubjub point (i.e. it's on-curve)
//@ensures(2) `H1X`, `H1Y`, `H2X`, and `H2Y` comprise a stealth address "owned" by the viewing key represented by `vkBits` according to the stealth address scheme
//@ensures(3) the viewing key represented by `vkBits` is the only possible viewing key that can "own" the given stealth address based on the DDH assumption
template StealthAddrOwnership() {
    // X and Y coordinates of both
    // components of the stealth address
    signal input H1X;
    signal input H1Y;
    signal input H2X;
    signal input H2Y;

    // little-endian bit representation of viewing key
    // we check elsewhere that this viewing key was derived correctly
    // here we assume it was, in which case it fits in 251 bits
    // and we can avoid a Num2Bits_strict
    signal input vkBits[251];

    // G = vk * H1
    signal GX, GY, GGX, GGY, GG2X, GG2Y, GG4X, GG4Y, GG8X, GG8Y;
    signal G[2];
    G <== EscalarMulAny(251)(vkBits, [H1X, H1Y]);

    // GG = vk * H1 - H2
    (GGX, GGY) <== BabyAdd()(G[0], G[1], -H2X, H2Y);
    (GG2X, GG2Y) <== BabyDbl()(GGX, GGY);
    (GG4X, GG4Y) <== BabyDbl()(GG2X, GG2Y);
    (GG8X, GG8Y) <== BabyDbl()(GG4X, GG4Y);

    GG8X === 0;
    GG8Y === 1;
}

// verify a schnorr signature of `m` under pubkey `pk`
//@requires(1) `pk` is a valid, order-l Baby Jubjub point
//@ensures(1) `sig` is a valid schnorr signature of `m` under pubkey `pk`
template SigVerify() {
    signal input pk[2];
    signal input m;
    signal input sig[2]; // [c, z]

    var BASE8[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];
    component gz = EscalarMulFix(251, BASE8);
    component pkc = EscalarMulAny(254);

    // OPTIMIZATION:
    // let r be the order of Baby Jubjub's scalar field
    // if z > r, then wraparound will happen in the scalar mul
    // therefore, it's equivalent to simply require the prover to reduce it.
    // before plugging it into the circuit
    // The case where the reduced version isn't correct is equivalent to the case
    // where `z` is bogus - the signature check will still fail.
    // therefore we can simply assume it's 251 bits and not explicitly compare to r
    component zBits = Num2Bits(251);

    // we do, however, need to check this against an un-reduced poseidon hash computed in joinsplit.circom
    // therefore we sitll use Num2Bits_strict here
    component cBits = Num2Bits_strict();

    zBits.in <== sig[1];
    for (var i = 0; i < 251; i++) {
        gz.e[i] <== zBits.out[i];
    }

    pkc.p <== pk;
    cBits.in <== sig[0];
    for (var i = 0; i < 254; i++) {
        pkc.e[i] <== cBits.out[i];
    }

    component R = BabyAdd();
    R.x1 <== gz.out[0];
    R.y1 <== gz.out[1];
    R.x2 <== pkc.out[0];
    R.y2 <== pkc.out[1];

    signal cp <== Poseidon(4)([pk[0], R.xout, R.yout, m]);
    cp === sig[0];
}

//@requires(1) `vkBits` is a 251-bit little-endian representation of `vk`, which entails that every signal in the array is binary
//@ensures(1) `addr` is a valid, order-l Baby Jubjub point
//@ensures(2) `addr` is the correct canonical address corresponding to `vk`
template CanonAddr() {
    // little-endian bit representation of viewing key
    // we check elsewhere that this viewing key was derived correctly
    // here we assume it was, in which case it fits in 251 bits
    // and we can avoid a Num2Bits_strict
    signal input userViewKeyBits[251];
    // the canonical address corresponding to given viewing key
    signal output addr[2];

    var BASE8[2] = [
        5299619240641551281634865583518297030282874472190772894086521144482721001553,
        16950150798460657717958625567821834550301663161624707787222815936182638968203
    ];

    addr <== EscalarMulFix(251, BASE8)(userViewKeyBits);
}

// Forces the input signal to be of value between 0 and 2**n - 1
//@requires(1) `n < 254`
//@ensures(1) `out` can be represented as an `n`-bit number, or equivalently that `out < 2^n`
template RangeCheckNBits(n) {
    signal input in;

    // Num2Bits does all the work here as long as n < 254. All we care is that they're all bits
    signal bits[n] <== Num2Bits(n)(in);
}

// Encrypt each input value, using poseidon as as a blockcipher in counter
// mode, with rand as initial value (IV)
template Encrypt(n) {
    signal input rand;
    signal input in[n];

    signal output out[n];

    for (var i = 0; i < n; i++) {
      var pad = Poseidon(1)([rand + i]);
      out[i] <== pad + in[i];
    }
}

// takes `2n` bits and outputs n 2-bit limbs
// interpreted in little-endian order
//@requires(1) n < 127
//@requires(2) each element of `bits` is a bit
//@ensures(1) for all i in 0..n: limbs[i] == bits[i*2] + 2*bits[i*2 + 1]
template BitsToTwoBitLimbs(n) {
    signal input bits[2*n];
    signal output limbs[n];

    for (var i = 0; i < n; i++) {
        limbs[i] <== bits[i*2] + 2*bits[i*2 + 1];
    }
}

// takes n 2-bit limbs and outputs 2n-bit number when interpreted in little-endian order
//@requires(1) `limbs` are all 2-bit numbers
//@requires(2) `n < 127`
//@ensures(1) `num` is the 2n-bit number that result from performing the quaternary sum of `limbs` in little-endian order
template TwoBitLimbsToNum(n) {
    signal input limbs[n];
    signal output num;

    var sum = 0;
    for (var i = 0; i < n; i++) {
        sum += (1 << 2*i) * limbs[i];
    }

    num <== sum;
}

// slices first k elements out of an array of n elements
// why doesn't circom support this????
//@requires(1) k <= n
//@ensures(1) forall i in 0..k: slice[i] == arr[i]
template SliceFirstK(n, k) {
    signal input arr[n];
    signal output slice[k];

    for (var i = 0; i < k; i++) {
        slice[i] <== arr[i];
    }
}

//@requires(1) k <= n
//@ensures(1) slice.length == k
//@ensures(1) forall i in 0..k: slice[i] == arr[n - k + i]
template SliceLastK(n, k) {
    signal input arr[n];
    signal output slice[k];

    for (var i = n - k; i < n; i++) {
        slice[i - (n - k)] <== arr[i];
    }
}


// same as `Point2Bits_strict` (https://github.com/iden3/circomlib/blob/cff5ab6288b55ef23602221694a6a38a0239dcc0/circuits/pointbits.circom#L136),
// but returns the result as y cordinate and x coordinate's sign bit in two field elements instead of as a bit array
//@requires(1) `in` is a valid Baby Jubjub curve point
//@ensures(1) `(y, sign)` comprise the correct compression of `in` according to Nocturne's point compression scheme
template CompressPoint() {
    signal input in[2];
    signal output y;
    signal output sign;

    y <== in[1];

    // bit-decompose x coordinate
    signal xBits[254] <== Num2Bits_strict()(in[0]);

    // get the "sign" bit by comparing x to (p-1)/2. If it's bigger, then we call it "negative"
    sign <== CompConstant(10944121435919637611123202872628637544274182200208017171849102093287904247808)(xBits);
}

// same as `Poseidon()`, but takes a constant as domain separator
// and uses that as the initial sponge state
// this is cheaper than using `Poseidon()` with an extra input
template PoseidonWithDomainSeparator(nInputs, domainSeparator) {
    signal input preimage[nInputs];
    signal output out;

    component sponge = PoseidonEx(nInputs, 1);
    sponge.initialState <== domainSeparator;
    for (var i = 0; i < nInputs; i++) {
        sponge.inputs[i] <== preimage[i];
    }

    out <== sponge.out[0];
}
