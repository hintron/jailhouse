// The MIT License (MIT)

// Copyright (c) 2019 Michael Hinton

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
// For Linux debug only
// #include <stdio.h>
/*
 * Alternate sequentially and randomly accessing up to a 4-GiB random input.
 * Return an accumulated count of the value of each byte accessed in this way.
 */
extern u64 random_access_mgh(unsigned char *input, int input_len)
{
    u64 count = 0;
    // Loop through each byte
    // printf("input_len: %d\n", input_len);

    // Input is too small
    if (input_len <= 4)
        return count;

    for (int i = 0; i <= input_len - 4; ++i) {
        // printf("i: %d\n", i);
        // printf("input[i]: %d\n", input[i]);

        // Cast as a 4-byte value
        u32 *curr_rand = (u32 *)&input[i];
        // Make sure index does not exceed the length of the input
        u32 random_index = (*curr_rand) % input_len;
        // Conduct random access and accumulate value
        // printf("random_index: %u\n", random_index);
        count += input[random_index];
        // printf("count += %u = %lld\n", input[random_index], count);
    }
    // Who cares about touching the last 3 bytes
    return count;
}
