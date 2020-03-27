// The MIT License (MIT)

// Copyright (c) 2020 Michael Hinton

// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:

// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.

// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

#include <inmate.h>

/*
 * Linear Congruential Generator
 *
 * Given a pre-allocated buffer x of size len, generate pseudo-random data
 * to fill up the buffer.
 *
 * x:          (out) A pointer to a pre-allocated buffer
 * len_char:   The size of the random data to generate. Must be a multiple of 4.
 * seed:       The seed for the prng.
 *
 * Returns 0 if successful, and > 0 if the prng failed.
 * 1 means that len_char was not divisible by 4.
 * 2 means the seed was too large (should be impossible).
 *
 * Recurrence relation: X[n + 1] = (a * X[n] + c) % m
 *
 * m, 0 < m : modulus
 * a, 0 < a < m : multiplier
 * c, 0 <= c < m : increment
 * X[0], 0 <= X[0] < m : seed
 *
 * Use the same multiplier, modulus, and increment that glibc uses.
 *
 * https://en.wikipedia.org/wiki/Linear_congruential_generator
 * https://www.geeksforgeeks.org/pseudo-random-number-generator-prng
 *
 */
extern int prng_mgh(u32 *x, int len_char, u32 seed)
{
	u32 m = 2147483648; // 2^31, or 0x80000000
	u32 a = 1103515245;
	u32 c = 12345;
	int len = len_char / 4;

	/* Local buffer size must be divisible by 4 */
	if (len_char % 4 != 0) {
		return 1;
	}

	/* Force seed to be within the proper bounds */
	seed = seed % m;

	/* Sanity check. Unsigned numbers can never be < 0 */
	if (seed >= m) {
		return 2;
	}

	/* Use the seed to generate the first value */
	x[0] = (a * seed + c) % m;

	for (int i = 1; i < len; ++i) {
		x[i] = (a * x[i - 1] + c) % m;
	}

	return 0;
}