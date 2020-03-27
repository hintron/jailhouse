#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include "include/workloads.h"

#define GB 1073741824
#define MB 1048576
#define MAX_SIZE (1 * GB)

const char *help_string =
"Usage:\n"
"    prng <size> <seed>\n\n"

"Create pseudo-random data from a seed and output it as hex.\n"
"    <size>: The size of the data to create, in bytes. Limited to 1 GB.\n"
"    <seed>: The seed, in the form of a positive integer.\n\n"

"Note that this program is stateless. If you want a different pseudo-random \n"
"number, you need to supply a different seed.\n"
;

int main(int argc, char const *argv[])
{
	int rc = 0;
	char *p;
	char *buffer = NULL;
	unsigned long long buffer_len = 0;
	unsigned long long seed = 0;

	// TODO: Add an additional optional argument that is the output file
	// path instead of printing hex to stdout.
	if (argc != 3) {
		printf("%s", help_string);
		return 1;
	}

	errno = 0;
	buffer_len = strtoull(argv[1], &p, 10);
	if (errno != 0) {
		printf("ERROR: strtoull() failed to convert <size>\n");
		return errno;
	}

	if (buffer_len > MAX_SIZE) {
		printf("ERROR: <size> is larger than the max size (%u bytes)\n",
		       MAX_SIZE);
		return 1;
	}

 	buffer = (char *)malloc(buffer_len);

	errno = 0;
	seed = (unsigned long)strtoull(argv[2], &p, 10);
	if (errno != 0) {
		printf("ERROR: strtoull() failed to convert <seed>\n");
		return errno;
	}

	rc = prng_mgh((unsigned int *)buffer, buffer_len, seed);
	if (rc != 0) {
		printf("prng failed with return code %d\n", rc);
	} else {
		for (int i = 0; i < buffer_len; ++i) {
			printf("%02hhx", buffer[i]);
		}
		printf("\n");
	}

	free(buffer);
	return rc;
}
