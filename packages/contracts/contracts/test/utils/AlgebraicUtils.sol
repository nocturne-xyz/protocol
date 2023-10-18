// SPDX-License-Identifier: MIT OR Apache-2.0
pragma solidity ^0.8.17;
import {Utils} from "../../libs/Utils.sol";

library AlgebraicUtils {
    uint256 public constant MODULUS = Utils.BN254_SCALAR_FIELD_MODULUS;
    uint256 public constant NON_QR = 5;
    uint256 public constant TWO_ADICITY = 28;
    uint256 public constant TWO_ADIC_SUBGROUP_ORDER = 1 << TWO_ADICITY;
    uint256 public constant TWO_ADIC_SUBGROUP_COFACTOR =
        (MODULUS - 1) / TWO_ADIC_SUBGROUP_ORDER;
    uint256 public constant P_MINUS_1_OVER_2 = (MODULUS - 1) / 2;
    uint256 public constant CURVE_A = 168700;
    uint256 public constant CURVE_D = 168696;

    uint256 public constant COMPRESSED_POINT_SIGN_MASK = 1 << 254;

    function neg(uint256 a) internal pure returns (uint256) {
        return MODULUS - a;
    }

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return addmod(a, b, MODULUS);
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return addmod(a, MODULUS - b, MODULUS);
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return mulmod(a, b, MODULUS);
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return mul(a, inv(b));
    }

    function inv(uint256 a) internal pure returns (uint256) {
        require(a != 0, "cannot invert zero");
        return invOrZero(a);
    }

    function eq(uint256 a, uint256 b) internal pure returns (bool) {
        return a == b;
    }

    function invOrZero(uint256 a) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        require(a < MODULUS, "a >= MODULUS");

        int256 t = 0;
        int256 r = int256(MODULUS);
        int256 newt = 1;
        int256 newr = int256(a);
        while (newr != 0) {
            int256 q = r / newr;
            (t, newt) = (newt, t - q * newt);
            (r, newr) = (newr, r - q * newr);
        }

        if (t < 0) {
            t += int256(MODULUS);
        }

        return uint256(t);
    }

    function square(uint256 a) internal pure returns (uint256) {
        return mul(a, a);
    }

    function pow(uint256 base, uint256 exp) internal view returns (uint256) {
        // EIP-198 args are <length_of_BASE> <length_of_EXPONENT> <length_of_MODULUS> <BASE> <EXPONENT> <MODULUS>
        bytes memory args = abi.encodePacked(
            uint256(32),
            uint256(32),
            uint256(32),
            base,
            exp,
            MODULUS
        );
        (bool success, bytes memory response) = address(0x05).staticcall(args);
        require(success, "EIP-198 precompile call failed");
        return uint256(bytes32(response));
    }

    function legendreSymbol(uint256 lhs) internal view returns (uint256) {
        return pow(lhs, (MODULUS - 1) / 2);
    }

    // reverts if sqrt DNE
    function sqrt(uint256 a) internal view returns (uint256) {
        uint256 legendre = legendreSymbol(a);
        require(legendre != MODULUS - 1, "sqrt DNE");
        if (legendre == 0) {
            return 0;
        }

        uint256 m = TWO_ADICITY;
        uint256 c = pow(NON_QR, TWO_ADIC_SUBGROUP_COFACTOR);
        uint256 t = pow(a, TWO_ADIC_SUBGROUP_COFACTOR);
        uint256 r = pow(a, (TWO_ADIC_SUBGROUP_COFACTOR + 1) / 2);

        while (true) {
            if (t == 0) {
                return 0;
            }
            if (t == 1) {
                return r;
            }

            uint256 i = 0;
            uint256 curr = t;
            while (curr != 1) {
                curr = square(curr);
                i++;
            }

            require(i < m, "unreachable: i >= m");

            uint256 b = pow(c, pow(2, sub(sub(m, i), 1)));
            m = i;
            c = square(b);
            t = mul(t, c);
            r = mul(r, b);
        }

        // hack
        // compiler is too stupid to see that the function will always return from the loop if it doesn't revert
        revert("unreachable");
    }

    // reverts if c is not a valid compressed point
    function decompressPoint(
        uint256 c
    ) internal view returns (uint256 x, uint256 y) {
        require(
            c <= (MODULUS - 1) | COMPRESSED_POINT_SIGN_MASK,
            "invalid compressed point"
        );
        uint256 sign = c & COMPRESSED_POINT_SIGN_MASK;
        y = c & (COMPRESSED_POINT_SIGN_MASK - 1);
        require(y < MODULUS, "invalid compressed point");

        uint256 ySquared = square(y);
        uint256 xSquared = div(
            sub(1, ySquared),
            sub(CURVE_A, mul(CURVE_D, ySquared))
        );

        x = sqrt(xSquared);

        require(x != 0 || sign == 0, "invalid compressed point");

        if (x > P_MINUS_1_OVER_2 != (sign != 0)) {
            x = neg(x);
        }

        return (x, y);
    }
}
