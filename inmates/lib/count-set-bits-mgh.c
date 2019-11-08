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

int lut [256] = {
    // Pattern for first 3 bits
    // Add 1 for all bits set in upper 5 bits

    // 00000000 -> 0 (first value in row)
    // 00000001
    // 00000010
    // 00000011
    // 00000100
    // 00000101
    // 00000110
    // 00000111
    0, 1, 1, 2, 1, 2, 2, 3,
    // 00001000 -> 1
    1, 2, 2, 3, 2, 3, 3, 4,
    // 00010000 -> 1
    1, 2, 2, 3, 2, 3, 3, 4,
    // 00011000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 00100000 -> 1
    1, 2, 2, 3, 2, 3, 3, 4,
    // 00101000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 00110000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 00111000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 01000000 -> 1
    1, 2, 2, 3, 2, 3, 3, 4,
    // 01001000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 01010000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 01011000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 01100000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 01101000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 01110000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 01111000 -> 4
    4, 5, 5, 6, 5, 6, 6, 7,
    // 10000000 -> 1
    1, 2, 2, 3, 2, 3, 3, 4,
    // 10001000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 10010000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 10011000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 10100000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 10101000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 10110000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 10111000 -> 4
    4, 5, 5, 6, 5, 6, 6, 7,
    // 11000000 -> 2
    2, 3, 3, 4, 3, 4, 4, 5,
    // 11001000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 11010000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 11011000 -> 4
    4, 5, 5, 6, 5, 6, 6, 7,
    // 11100000 -> 3
    3, 4, 4, 5, 4, 5, 5, 6,
    // 11101000 -> 4
    4, 5, 5, 6, 5, 6, 6, 7,
    // 11110000 -> 4
    4, 5, 5, 6, 5, 6, 6, 7,
    // 11111000 -> 5
    5, 6, 6, 7, 6, 7, 7, 8,
};

extern int count_set_bits_mgh(unsigned char *input, int input_len, int mode)
{
    unsigned char tmp = 0;
    int count = 0;
    // Loop through each byte
    for (int i = 0; i < input_len; ++i) {
        // Loop through each bit
        switch (mode) {
        default:
        case 0:
            // Fast
            tmp = input[i];
            for (int j = 0; j < 8; ++j) {
                if (0x1 & tmp)
                    count++;
                tmp >>= 1;
            }
            break;
        case 1:
            // Faster
            if (0x1 & input[i])
                count++;
            if (0x2 & input[i])
                count++;
            if (0x4 & input[i])
                count++;
            if (0x8 & input[i])
                count++;
            if (0x10 & input[i])
                count++;
            if (0x20 & input[i])
                count++;
            if (0x40 & input[i])
                count++;
            if (0x80 & input[i])
                count++;
            break;
        case 2:
            // Fastest
            count += lut[input[i]];
            break;
        }

    }
    return count;
}
