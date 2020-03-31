#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>

#include "inmate.h"

#define GB 1073741824
#define MB 1048576
#define MAX_SIZE (1 * GB)

const char *help_string =
"Usage:\n"
"    prng <size> <seed> [<output_file>]\n\n"

"Create pseudo-random data from a seed. If <output_file> is specified, then \n"
"write the data to that file in binary format. If not, print the data to \n"
"stdout as a hex string.\n"
"    <size>: The size of the data to create, in bytes. Limited to 1 GB.\n"
"    <seed>: The seed, in the form of a positive integer.\n"
"    [<output_file>]: Output file to write the data to (in binary format).\n\n"

"Returns 0 if data generation and output action was successful. If \n"
"unsuccessful, prints the error to stdout and returns 1.\n\n"

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

	if (argc != 3 && argc != 4) {
		printf("%s", help_string);
		return 1;
	}

	errno = 0;
	buffer_len = strtoull(argv[1], &p, 10);
	if (errno != 0) {
		printf("ERROR: %d: strtoull() failed to convert <size>\n",
		       errno);
		return errno;
	}

	if (buffer_len > MAX_SIZE) {
		printf("ERROR: %d: <size> is larger than the max size (%u bytes)\n",
		       errno, MAX_SIZE);
		return 1;
	}

 	buffer = (char *)malloc(buffer_len);

	errno = 0;
	seed = (unsigned long)strtoull(argv[2], &p, 10);
	if (errno != 0) {
		printf("ERROR: strtoull() failed to convert <seed>\n");
		free(buffer);
		return errno;
	}

	rc = prng_mgh((unsigned int *)buffer, buffer_len, seed);
	if (rc != 0) {
		printf("ERROR: %d: ", rc);
		switch (rc) {
		case 1:
			printf("Local buffer size must be divisible by 4\n\n");
			printf("%s", help_string);
			break;
		case 2:
			printf("Seed sanity check error\n");
			break;
		default:
			printf("Unknown error\n");
			break;

		}
		free(buffer);
		return rc;
	}

	if (argv[3]) {
		int fd = open(argv[3], O_WRONLY | O_CREAT | O_TRUNC,
		              S_IRUSR | S_IWUSR | S_IRGRP | S_IWGRP | S_IROTH);
		if (fd == -1) {
			printf("ERROR: Failed to open file to write to\n");
			free(buffer);
			return 1;
		}
		if (write(fd, buffer, buffer_len) == -1) {
			printf("ERROR: Failed to write file\n");
			free(buffer);
			return 1;
		}
		if (close(fd) == -1) {
			printf("ERROR: Failed to close file\n");
		}
	} else {
		for (int i = 0; i < buffer_len; ++i) {
			printf("%02hhx", buffer[i]);
		}
		printf("\n");
	}

	free(buffer);
	return 0;
}
