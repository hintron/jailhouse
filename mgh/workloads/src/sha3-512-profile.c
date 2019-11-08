#include "include/workloads.h"
#include <stdio.h>

// This silences compiler warnings over of #include <string.h>
char *strcpy(char *dest, const char *src);
size_t strlen(const char *s);

// A 512-bit hash is really 64 bytes x 8 bits/byte
#define MD_LENGTH 64
#define ITERATIONS 1000
#define ITERATIONS_REAL ((ITERATIONS-2)/2)
int main(int argc, char const *argv[])
{
	char buffer_a[MD_LENGTH] = {0};
	char buffer_b[MD_LENGTH] = {0};

	// Copy the initial input seed string
	strcpy(buffer_a, "testing");

	(void) sha3_mgh(buffer_a, strlen(buffer_a), &buffer_b, MD_LENGTH);
	for (int i = 0; i < ITERATIONS_REAL; ++i) {
		(void) sha3_mgh(buffer_b, MD_LENGTH, &buffer_a, MD_LENGTH);
		(void) sha3_mgh(buffer_a, MD_LENGTH, &buffer_b, MD_LENGTH);
	}
	(void) sha3_mgh(buffer_b, MD_LENGTH, &buffer_a, MD_LENGTH);

	for (int i = 0; i < MD_LENGTH; ++i) {
		printf("%02hhx", buffer_a[i]);
	}
	printf("\n");

	return 0;
}
