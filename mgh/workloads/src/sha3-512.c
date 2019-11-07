#include "include/sha3_mgh.h"
#include <stdio.h>
#include <string.h>

// A 512-bit hash is really 64 bytes x 8 bits/byte
#define MD_LENGTH (512/8)
int main(int argc, char const *argv[])
{
	char output[MD_LENGTH] = {0};
	int i;

	if (argc != 2) {
		printf("mgh-sha3-512 test program v0.1\n");
		printf("Written by Michael Hinton.\n");
		printf("Usage:\n");
		printf("    mgh-sha3-512 \"input\"\n");
		printf("    \n");
		printf("    This program will take an input string and calculate the sha3 of the input\n");
		return 1;
	}

	if (!sha3_mgh(argv[1], strlen(argv[1]), &output, MD_LENGTH)) {
		printf("sha3 failed for string `%s`\n", argv[1]);
	}

	for (i = 0; i < MD_LENGTH; ++i) {
		printf("%02hhx", output[i]);
	}
	printf("\n");
	return 0;
}
