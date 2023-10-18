pragma circom 2.0.0;

include "include/bitify.circom";

template Num2BitsBE(n) {
    signal input in;
    signal output out[n];
	
	component le = Num2Bits(n);
	le.in <== in;
	
	for (var i = 0; i < n; i++) {
		out[n - i - 1] <== le.out[i];
	}
}

template Num2BitsBE_strict() {
    signal input in;
    signal output out[254];
	
	component le = Num2Bits_strict();
	le.in <== in;
	
	for (var i = 0; i < 254; i++) {
		out[254 - i - 1] <== le.out[i];
	}
}

template Bits2NumBE(n) {
    signal input in[n];
    signal output out;

	component le = Bits2Num(n);
	
	for (var i = 0; i < n; i++) {
		le.in[n - i - 1] <== in[i];
	}

	out <== le.out;
}