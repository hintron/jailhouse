#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "include/workloads.h"

int strncmp(const char *s1, const char *s2, size_t n);

#define MAX_INPUT_PRINT 50

const char *help_string =
"Usage:\n"
"    count-set-bits <input-file> [<mode=2>] [verbose]\n\n"

"Print to stdout the number of 1s in an input file's binary data.\n\n"
"    <input-file>: Required. The input file to use.\n\n"

"    <mode>: Optional. Defaults to 2. Specifies the algorithm used.\n"
"            Can be 0, 1, or 2. 0 is the slowest and 2 is the fastest.\n\n"

"    verbose: Optional. If specified, additional information is printed to\n"
"             stdout.\n\n"
;

static int _count_set_bits(unsigned char *input, int input_len, int mode,
			   int verbose)
{
	int print = 0;

	if (verbose) {
		if (input_len <= MAX_INPUT_PRINT) {
			print = 1;
			printf("Input Bytes:\n");
		} else {
			printf("Input is too large to print out (> %d bytes)\n",
			       MAX_INPUT_PRINT);
		}
	}

	// Loop through each byte
	if (print) {
		for (int i = 0; i < input_len; ++i) {
			printf("0x%0x\n", input[i]);
		}
	}

	return count_set_bits_mgh(input, input_len, mode);
}

int main(int argc, char const *argv[])
{
	int fd;
	struct stat file_info;
	int input_len = 0;
	void *input_buffer = NULL;
	int result = 0;
	int mode = 2;
	int verbose = 0;

	if (argc <= 1 || argc > 4) {
		printf("%s", help_string);
		return 1;
	}

	if (argc > 2) {
		if (strncmp(argv[2], "verbose", 7) == 0) {
			verbose = 1;
		} else {
			mode = atoi(argv[2]);
		}
	}

	if (argc > 3) {
		if (!verbose && (strncmp(argv[3], "verbose", 7) == 0)) {
			verbose = 1;
		} else {
			mode = atoi(argv[3]);
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

	switch(mode){
	default:
		if (verbose) {
			printf("ERROR: Mode could not be determined. Defaulting to 2.\n");
		}
		mode = 2;
		/* Fall through */
	case 0:
	case 1:
	case 2:
		if (verbose) {
			printf("Input mode=%d\n", mode);
		}
		// Count the number of 1's in the input_buffer's binary data and return
		result = _count_set_bits(input_buffer, input_len, mode,
					 verbose);
		break;
	}

	// Let outside tools compare the results of different modes, if wanted.

	if (verbose) {
		if (result == 1) {
			printf("There is 1 set bit in the input file\n");
		} else {
			printf("There are %d set bits in the input file\n", result);
		}
	} else {
		printf("%d\n", result);
	}

	return 0;
}
