# Floating point

Dragon BASIC has one numeric type: a 5-byte Microsoft binary float. Matching
it bit for bit is what makes our output identical to a real Dragon's, down to
oddities like `PRINT 2^3^2` giving `64.0000001`. So D32BASIC reimplements the
same format and the same algorithms. It does not invent its own maths.

## Packed format (5 bytes, how variables are stored)

| Byte | Meaning |
|---|---|
| 0 | Exponent, biased by 128 (`$81` means 2^1). `0` means the number is zero, whatever the other bytes hold. |
| 1 | Mantissa, most significant byte. Bit 7 is the **sign** (1 = negative). Because the mantissa is always normalised, its real top bit is always 1, so the sign bit takes its place. |
| 2-4 | Rest of the mantissa, most significant first. |

The value is `(-1)^sign * 0.1mmmm...(binary) * 2^(exp-128)`. So 1.0 is
`81 00 00 00 00`, 0.5 is `80 00 00 00 00`, -1.0 is `81 80 00 00 00` and 10.0 is
`84 20 00 00 00`.

Range: about 2.9E-39 to 1.7E+38. Precision: 32-bit mantissa, about 9.6
decimal digits. PRINT shows at most 9 significant digits.

## Unpacked accumulators (how the arithmetic works)

The ROM does its arithmetic in two unpacked registers in the direct page:

* **FAC** (floating accumulator): exponent, 4 mantissa bytes with the top bit
  restored, and a separate sign byte (`$00` or `$FF`).
* **ARG**: the second operand, in the same layout.
* **FACOV**: an extra low "overflow" byte that holds bits shifted off the
  bottom of the mantissa during adds and normalisation. ROUND uses it, so
  results round the way the ROM rounds and not the way a naive 32-bit
  implementation would.
* **ARISGN**: the sign of the result of an add or multiply (FAC sign XOR ARG sign).

Our Z80 implementation keeps the same register set (FAC, ARG, FACOV, ARISGN)
in its own fixed workspace, so each routine can be checked against the ROM's
routine of the same name.

## Routines that must match exactly

These decide every printed digit, so each one is reimplemented from the
algorithm in the source listing, with the same constants and the same order
of operations:

| Routine | Job | Notes |
|---|---|---|
| `FADD` / `FSUB` | add, subtract | Align exponents by shifting the smaller operand right into FACOV, then add or subtract mantissas, then NORMAL, then ROUND. |
| `NORMAL` | normalise | Shift left until the top bit is set, decrementing the exponent; underflow gives zero. |
| `ROUND` | round | Uses FACOV bit 7; carry out of the mantissa bumps the exponent (overflow gives `?OV ERROR`). |
| `FMULT` | multiply | 32x32 shift-and-add multiply into a 40-bit result (low byte becomes FACOV). |
| `FDIV` | divide | Restoring division, 33 quotient bits; divide by zero gives `?/0 ERROR`. |
| `FIN` | text to number | Reads digits into FAC, multiplying by 10 each time, then applies the decimal exponent with repeated `*10` / `/10`. |
| `FOUT` | number to text | Scales into the range 99999999.9 to 999999999, adds 0.5, extracts digits by repeated subtraction of powers of ten, then decides between fixed and `E` notation. |
| `INT`, `QINT` | integer part | `INT` floors (towards minus infinity); `FIX` truncates. |
| `POLYX`, `POLY` | polynomial series | Used by `LOG`, `EXP`, `SIN`, `ATN`. Same coefficient tables as the ROM. |
| `SQR` | square root | Implemented as `X^0.5`, i.e. `EXP(LOG(X)*0.5)`, exactly as the ROM does, which is why `SQR(2)` prints `1.41421356`. |
| `^` | power | `EXP(LOG(X)*Y)`, with the ROM's special cases for 0 and negative bases. |
| `RND` | random numbers | Same generator and seed (`RNDX`), so `RND` sequences match a freshly reset Dragon. |

## Integers

There is no integer type. Where BASIC needs an integer (array subscripts,
`PEEK`, `AND`, `OR`, `NOT`, line numbers) the ROM converts with `INTCNV`, which
allows -32768 to 32767 and otherwise raises `?FC ERROR`. `AND`, `OR` and `NOT`
work on those 16-bit two's complement values, which is why `NOT 255` is `-256`.
