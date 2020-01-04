#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "include/workloads.h"

int strncmp(const char *s1, const char *s2, size_t n);

const char *help_string =
"Usage:\n"
"    random-access-hash <input-file> [verbose]\n\n"

"A workload that takes a random input and randomly accesses it according to\n"
"the input. If the input isn't random, the access pattern won't be random.\n\n"

"    <input-file>: Required. The input file to use. Must be random, since\n"
"                  the access pattern is derived from the contents.\n\n"

"    verbose: Optional. If specified, additional information is printed to\n"
"             stdout.\n\n"
;

int main(int argc, char const *argv[])
{
	int fd;
	struct stat file_info;
	int input_len = 0;
	void *input_buffer = NULL;
	int verbose = 0;
	unsigned long long result = 0;

	if (argc <= 1 || argc > 3) {
		printf("%s", help_string);
		return 1;
	}

	if (argc > 2) {
		if (strncmp(argv[2], "verbose", 7) == 0) {
			verbose = 1;
		}
	}

	fd = open(argv[1], O_RDONLY);
	if (fd == -1) {
		printf("ERROR: Could not open input file\n");
		return 1;
	}

	if (fstat(fd, &file_info)) {
		printf("ERROR: Could not stat input file\n");
		return 1;
	}

	// Count how many bytes are in the file
	input_len = (int)file_info.st_size;
	if (verbose) {
		if (input_len == 1) {
			printf("Input file is 1 byte\n");
		} else {
			printf("Input file is %d bytes\n", input_len);
		}
	}

	// Malloc count bytes of memory to hold the contents
	input_buffer = (unsigned char *)malloc(input_len);
	if (!input_buffer) {
		printf("ERROR: Could not malloc input_buffer\n");
		return 1;
	}

	if (read(fd, input_buffer, input_len) == -1) {
		printf("ERROR: Could not read input file into input_buffer\n");
		return 1;
	}

	result = random_access_mgh(input_buffer, input_len);

	if (verbose) {
		printf("Result = %llu\n", result);
	} else {
		printf("%llu\n", result);
	}

	return 0;
}
