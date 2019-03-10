// The MIT License (MIT)

// Copyright (c) 2015 Markku-Juhani O. Saarinen

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

// MGH:
// Code adapted from https://github.com/mjosaarinen/tiny_sha3/
// https://github.com/mjosaarinen/tiny_sha3/blob/master/sha3.c
// https://github.com/mjosaarinen/tiny_sha3/blob/master/sha3.h

// TODO: Replace this with what's needed from the outside world
// There is a lib.c and types.h from Jailhouse that could help
#include <stddef.h>
#include <stdint.h>

#define KECCAKF_ROUNDS 24
#define ROTL64(x, y) (((x) << (y)) | ((x) >> (64 - (y))))

// state context
typedef struct {
    union {                                 // state:
        uint8_t b[200];                     // 8-bit bytes
        uint64_t q[25];                     // 64-bit words
    } st;
    int pt, rsiz, mdlen;                    // these don't overflow
} sha3_ctx_t;

// #define shake128_init(c) _sha3_init(c, 16)
// #define shake256_init(c) _sha3_init(c, 32)
// #define shake_update _sha3_update





void sha3_keccakf(uint64_t st[25])
{
    // constants
    const uint64_t keccakf_rndc[24] = {
        0x0000000000000001, 0x0000000000008082, 0x800000000000808a,
        0x8000000080008000, 0x000000000000808b, 0x0000000080000001,
        0x8000000080008081, 0x8000000000008009, 0x000000000000008a,
        0x0000000000000088, 0x0000000080008009, 0x000000008000000a,
        0x000000008000808b, 0x800000000000008b, 0x8000000000008089,
        0x8000000000008003, 0x8000000000008002, 0x8000000000000080,
        0x000000000000800a, 0x800000008000000a, 0x8000000080008081,
        0x8000000000008080, 0x0000000080000001, 0x8000000080008008
    };
    const int keccakf_rotc[24] = {
        1,  3,  6,  10, 15, 21, 28, 36, 45, 55, 2,  14,
        27, 41, 56, 8,  25, 43, 62, 18, 39, 61, 20, 44
    };
    const int keccakf_piln[24] = {
        10, 7,  11, 17, 18, 3, 5,  16, 8,  21, 24, 4,
        15, 23, 19, 13, 12, 2, 20, 14, 22, 9,  6,  1
    };

    // variables
    int i, j, r;
    uint64_t t, bc[5];

#if __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
    uint8_t *v;

    // endianess conversion. this is redundant on little-endian targets
    for (i = 0; i < 25; i++) {
        v = (uint8_t *) &st[i];
        st[i] = ((uint64_t) v[0])     | (((uint64_t) v[1]) << 8) |
            (((uint64_t) v[2]) << 16) | (((uint64_t) v[3]) << 24) |
            (((uint64_t) v[4]) << 32) | (((uint64_t) v[5]) << 40) |
            (((uint64_t) v[6]) << 48) | (((uint64_t) v[7]) << 56);
    }
#endif

    // actual iteration
    for (r = 0; r < KECCAKF_ROUNDS; r++) {

        // Theta
        for (i = 0; i < 5; i++)
            bc[i] = st[i] ^ st[i + 5] ^ st[i + 10] ^ st[i + 15] ^ st[i + 20];

        for (i = 0; i < 5; i++) {
            t = bc[(i + 4) % 5] ^ ROTL64(bc[(i + 1) % 5], 1);
            for (j = 0; j < 25; j += 5)
                st[j + i] ^= t;
        }

        // Rho Pi
        t = st[1];
        for (i = 0; i < 24; i++) {
            j = keccakf_piln[i];
            bc[0] = st[j];
            st[j] = ROTL64(t, keccakf_rotc[i]);
            t = bc[0];
        }

        //  Chi
        for (j = 0; j < 25; j += 5) {
            for (i = 0; i < 5; i++)
                bc[i] = st[j + i];
            for (i = 0; i < 5; i++)
                st[j + i] ^= (~bc[(i + 1) % 5]) & bc[(i + 2) % 5];
        }

        //  Iota
        st[0] ^= keccakf_rndc[r];
    }

#if __BYTE_ORDER__ != __ORDER_LITTLE_ENDIAN__
    // endianess conversion. this is redundant on little-endian targets
    for (i = 0; i < 25; i++) {
        v = (uint8_t *) &st[i];
        t = st[i];
        v[0] = t & 0xFF;
        v[1] = (t >> 8) & 0xFF;
        v[2] = (t >> 16) & 0xFF;
        v[3] = (t >> 24) & 0xFF;
        v[4] = (t >> 32) & 0xFF;
        v[5] = (t >> 40) & 0xFF;
        v[6] = (t >> 48) & 0xFF;
        v[7] = (t >> 56) & 0xFF;
    }
#endif
}

// Initialize the context for SHA3

static void _sha3_init(sha3_ctx_t *c, int mdlen)
{
    int i;

    for (i = 0; i < 25; i++)
        c->st.q[i] = 0;
    c->mdlen = mdlen;
    c->rsiz = 200 - 2 * mdlen;
    c->pt = 0;
}

// update state with more data

static void _sha3_update(sha3_ctx_t *c, const void *data, int len)
{
    size_t i;
    int j;

    j = c->pt;
    for (i = 0; i < len; i++) {
        c->st.b[j++] ^= ((const uint8_t *) data)[i];
        if (j >= c->rsiz) {
            sha3_keccakf(c->st.q);
            j = 0;
        }
    }
    c->pt = j;
}

// finalize and output a hash

static void _sha3_final(void *md, sha3_ctx_t *c)
{
    int i;

    c->st.b[c->pt] ^= 0x06;
    c->st.b[c->rsiz - 1] ^= 0x80;
    sha3_keccakf(c->st.q);

    for (i = 0; i < c->mdlen; i++) {
        ((uint8_t *) md)[i] = c->st.b[i];
    }
}

// compute a SHA-3 hash (md) of given byte length from "in"

/**
 * Comput the SHA-3 HASH
 * @param  in    (IN) The input
 * @param  inlen (IN) The number of bytes to read from the input
 * @param  md    (OUT) A preallocated string of size mdlen to store the output
 *               message digest (hash)
 * @param  mdlen (IN) The length of the message digest (224, 256, 384, 512, custom)
 * @return       1 if successful, 0 if not
 */
int sha3(const void *in, int inlen, void *md, int mdlen)
{
    sha3_ctx_t sha3;

    if (!md || !in || !mdlen) {
        return 0;
    }

    _sha3_init(&sha3, mdlen);
    _sha3_update(&sha3, in, inlen);
    _sha3_final(md, &sha3);

    return 1;
}

// SHAKE128 and SHAKE256 extensible-output functionality

// void shake_xof(sha3_ctx_t *c)
// {
//     c->st.b[c->pt] ^= 0x1F;
//     c->st.b[c->rsiz - 1] ^= 0x80;
//     sha3_keccakf(c->st.q);
//     c->pt = 0;
// }

// void shake_out(sha3_ctx_t *c, void *out, size_t len)
// {
//     size_t i;
//     int j;

//     j = c->pt;
//     for (i = 0; i < len; i++) {
//         if (j >= c->rsiz) {
//             sha3_keccakf(c->st.q);
//             j = 0;
//         }
//         ((uint8_t *) out)[i] = c->st.b[j++];
//     }
//     c->pt = j;
// }


// // TODO: Get this compiled and working
// // TODO: Call this from inmate
// int main(int argc, char const *argv[])
// {
//         char *input = NULL;
//         int size = 0;

//         if (argc != 1) {
//                 printf("uio-userspace v0.1\n");
//                 printf("Usage:\n");
//                 printf("    uio-userspace [help]\n");
//                 printf("    \n");
//                 printf("    This program will try to interact with a Jailhouse inmate over a virtual PCI ivshmem device through shared memory.\n");
//                 exit(0);
//         }


//         memset(sha, 0, sizeof(sha));
//         memset(buf, 0, sizeof(buf));
//         memset(msg, 0, sizeof(msg));

//         msg_len = test_readhex(msg, testvec[i][0], sizeof(msg));
//         sha_len = test_readhex(sha, testvec[i][1], sizeof(sha));

//         // compute a SHA-3 hash (md) of given byte length from "in"
//         sha3(msg, msg_len, buf, sha_len);

//         if (memcmp(sha, buf, sha_len) != 0) {
//             fprintf(stderr, "[%d] SHA3-%d, len %d test FAILED.\n",
//                 i, sha_len * 8, msg_len);
//             fails++;
//         }

//         return 0;
// }
