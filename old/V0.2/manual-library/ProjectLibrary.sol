// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

/// @notice Arithmetic library with operations for fixed-point numbers.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/FixedPointMathLib.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/FixedPointMathLib.sol)
library FixedPointMathLib {
    /// @dev The full precision multiply-divide operation failed, either due
    /// to the result being larger than 256 bits, or a division by a zero.
    error FullMulDivFailed();

    /// @dev Calculates `floor(a * b / d)` with full precision.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Remco Bloemen under MIT license: https://2π.com/21/muldiv
    function fullMulDiv(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        /// @solidity memory-safe-assembly
        assembly {
            // forgefmt: disable-next-item
            for {} 1 {} {
                // 512-bit multiply `[prod1 prod0] = x * y`.
                // Compute the product mod `2**256` and mod `2**256 - 1`
                // then use the Chinese Remainder Theorem to reconstruct
                // the 512 bit result. The result is stored in two 256
                // variables such that `product = prod1 * 2**256 + prod0`.

                // Least significant 256 bits of the product.
                let prod0 := mul(x, y)
                let mm := mulmod(x, y, not(0))
                // Most significant 256 bits of the product.
                let prod1 := sub(mm, add(prod0, lt(mm, prod0)))

                // Handle non-overflow cases, 256 by 256 division.
                if iszero(prod1) {
                    if iszero(d) {
                        // Store the function selector of `FullMulDivFailed()`.
                        mstore(0x00, 0xae47f702)
                        // Revert with (offset, size).
                        revert(0x1c, 0x04)
                    }
                    result := div(prod0, d)
                    break       
                }

                // Make sure the result is less than `2**256`.
                // Also prevents `d == 0`.
                if iszero(gt(d, prod1)) {
                    // Store the function selector of `FullMulDivFailed()`.
                    mstore(0x00, 0xae47f702)
                    // Revert with (offset, size).
                    revert(0x1c, 0x04)
                }

                ///////////////////////////////////////////////
                // 512 by 256 division.
                ///////////////////////////////////////////////

                // Make division exact by subtracting the remainder from `[prod1 prod0]`.
                // Compute remainder using mulmod.
                let remainder := mulmod(x, y, d)
                // Subtract 256 bit number from 512 bit number.
                prod1 := sub(prod1, gt(remainder, prod0))
                prod0 := sub(prod0, remainder)
                // Factor powers of two out of `d`.
                // Compute largest power of two divisor of `d`.
                // Always greater or equal to 1.
                let twos := and(d, sub(0, d))
                // Divide d by power of two.
                d := div(d, twos)
                // Divide [prod1 prod0] by the factors of two.
                prod0 := div(prod0, twos)
                // Shift in bits from `prod1` into `prod0`. For this we need
                // to flip `twos` such that it is `2**256 / twos`.
                // If `twos` is zero, then it becomes one.
                prod0 := or(prod0, mul(prod1, add(div(sub(0, twos), twos), 1)))
                // Invert `d mod 2**256`
                // Now that `d` is an odd number, it has an inverse
                // modulo `2**256` such that `d * inv = 1 mod 2**256`.
                // Compute the inverse by starting with a seed that is correct
                // correct for four bits. That is, `d * inv = 1 mod 2**4`.
                let inv := xor(mul(3, d), 2)
                // Now use Newton-Raphson iteration to improve the precision.
                // Thanks to Hensel's lifting lemma, this also works in modular
                // arithmetic, doubling the correct bits in each step.
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**8
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**16
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**32
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**64
                inv := mul(inv, sub(2, mul(d, inv))) // inverse mod 2**128
                result := mul(prod0, mul(inv, sub(2, mul(d, inv)))) // inverse mod 2**256
                break
            }
        }
    }

    /// @dev Calculates `floor(x * y / d)` with full precision, rounded up.
    /// Throws if result overflows a uint256 or when `d` is zero.
    /// Credit to Uniswap-v3-core under MIT license:
    /// https://github.com/Uniswap/v3-core/blob/contracts/libraries/FullMath.sol
    function fullMulDivUp(uint256 x, uint256 y, uint256 d) internal pure returns (uint256 result) {
        result = fullMulDiv(x, y, d);
        /// @solidity memory-safe-assembly
        assembly {
            if mulmod(x, y, d) {
                if iszero(add(result, 1)) {
                    // Store the function selector of `FullMulDivFailed()`.
                    mstore(0x00, 0xae47f702)
                    // Revert with (offset, size).
                    revert(0x1c, 0x04)
                }
                result := add(result, 1)
            }
        }
    }
}

pragma solidity ^0.8.4;

/// @notice Library for converting numbers into strings and other string operations.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/LibString.sol)
/// @author Modified from Solmate (https://github.com/transmissions11/solmate/blob/main/src/utils/LibString.sol)
library LibString {
    /// @dev Returns the base 10 decimal representation of `value`.
    function toString(uint256 value) internal pure returns (string memory str) {
        /// @solidity memory-safe-assembly
        assembly {
            // The maximum value of a uint256 contains 78 digits (1 byte per digit), but
            // we allocate 0xa0 bytes to keep the free memory pointer 32-byte word aligned.
            // We will need 1 word for the trailing zeros padding, 1 word for the length,
            // and 3 words for a maximum of 78 digits.
            str := add(mload(0x40), 0x80)
            // Update the free memory pointer to allocate.
            mstore(0x40, add(str, 0x20))
            // Zeroize the slot after the string.
            mstore(str, 0)

            // Cache the end of the memory to calculate the length later.
            let end := str

            let w := not(0) // Tsk.
            // We write the string from rightmost digit to leftmost digit.
            // The following is essentially a do-while loop that also handles the zero case.
            for { let temp := value } 1 {} {
                str := add(str, w) // `sub(str, 1)`.
                // Write the character to the pointer.
                // The ASCII index of the '0' character is 48.
                mstore8(str, add(48, mod(temp, 10)))
                // Keep dividing `temp` until zero.
                temp := div(temp, 10)
                if iszero(temp) { break }
            }

            let length := sub(end, str)
            // Move the pointer 32 bytes leftwards to make room for the length.
            str := sub(str, 0x20)
            // Store the length.
            mstore(str, length)
        }
    }
}

pragma solidity ^0.8.4;

/// @notice Safe integer casting library that reverts on overflow.
/// @author Solady (https://github.com/vectorized/solady/blob/main/src/utils/SafeCastLib.sol)
/// @author Modified from OpenZeppelin (https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeCast.sol)
library SafeCastLib {
    error Overflow();

    function toInt64(int256 x) internal pure returns (int64) {
        int64 y = int64(x);
        if (x != y) _revertOverflow();
        return y;
    }

    function toInt256(uint256 x) internal pure returns (int256) {
        if (x >= 1 << 255) _revertOverflow();
        return int256(x);
    }

    function _revertOverflow() private pure {
        /// @solidity memory-safe-assembly
        assembly {
            // Store the function selector of `Overflow()`.
            mstore(0x00, 0x35278d12)
            // Revert with (offset, size).
            revert(0x1c, 0x04)
        }
    }
}