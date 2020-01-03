#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "include/workloads.h"

// This silences compiler warnings over of #include <string.h>
size_t strlen(const char *s);
int strncmp(const char *s1, const char *s2, size_t n);
void *memcpy(void *dest, const void *src, size_t n);

// A 512-bit hash is really 64 bytes x 8 bits/byte
#define MD_LENGTH (512/8)
#define MAX_STR_LEN 10000

const char *help_string =
"Usage:\n"
"    sha3-512 [-f <input>] [-s <input>] [verbose]\n\n"

"Print to stderr the 512-bit sha3 of an input file or string.\n\n"
"    -f <input>: The input file to use.\n\n"

"    -s <input>: The input string to use.\n\n"

"    If no input is supplied, stdin is assumed. stdin is read until the EOF\n"
"    character is received. If interactive, send an EOF character with\n"
"    ctrl+d.\n\n"

"    verbose: Optional. If specified, additional information is printed to\n"
"             stdout.\n\n"
;

typedef enum {
	INPUT_FILE,
	INPUT_STRING,
	INPUT_STDIN,
} input_t;

int main(int argc, char const *argv[])
{
	char output[MD_LENGTH] = {0};
	struct stat file_info;
	void *input_buffer = NULL;
	int input_buffer_len = 0;
	input_t input_type = INPUT_STDIN;
	int verbose = 0;
	int fd = 0;
	unsigned char *tmp_buffer = NULL;
	int tmp_buffer_size = 1024;
	char c = 0;
	int i = 0;

	if (argc > 4) {
		printf("%s", help_string);
		return 1;
	}

	if (argc > 1) {
		if (strncmp(argv[1], "-f", 2) == 0) {
			input_type = INPUT_FILE;
		} else if (strncmp(argv[1], "-s", 2) == 0) {
			input_type = INPUT_STRING;
		} else if (strncmp(argv[1], "verbose", 7) == 0) {
			verbose = 1;
		} else {
			printf("%s", help_string);
			return 1;
		}
	}

	/* Catch the rest of the possible verbose flags */
	if (argc > 2 && input_type == INPUT_STDIN &&
	    strncmp(argv[2], "verbose", 7) == 0) {
		verbose = 1;
	} else if (argc > 3 && strncmp(argv[3], "verbose", 7) == 0) {
		verbose = 1;
	}


	switch (input_type) {
	case INPUT_STRING:
		input_buffer_len = strlen(argv[2]);
		if (input_buffer_len > MAX_STR_LEN) {
			printf("ERROR: String input is greater than %d - use the file input method instead\n",
			       MAX_STR_LEN);
			return 1;
		}
		input_buffer = (void *)argv[2];
		break;
	case INPUT_STDIN:
		/*
		 * Read binary data in from stdin into a malloced buffer one
		 * character at a time until EOF is reached. If the buffer
		 * is about to overflow, malloc a new buffer that is twice the
		 * size, copy the buffer over, and free the previous buffer.
		 * Once EOF is reached, record the # of characters received.
		 * That will be the size of the buffer for the workload.
		 * If the malloced buffer exceeds some very large value (like
		 * 1 GB), then abort with an error, because something likely
		 * went wrong (infinite loop?).
		 */
		tmp_buffer = (unsigned char *)malloc(tmp_buffer_size);
		/*
		 * Note: binary data can have EOFs anywhere. So this is not
		 * identical to -f <input-file> for non-text input in stdin.
		 */
		while ((c = fgetc(stdin)) != EOF) {
			/* Copy the character into the buffer */
			tmp_buffer[i] = c;
			i++;
			if (i >= tmp_buffer_size) {
				// TODO: Add a buffer growth limit?
				/* Double the size of the buffer */
				tmp_buffer_size *= 2;
				input_buffer = malloc(tmp_buffer_size);
				// copy tmp_buffer contents into input_buffer
				memcpy(input_buffer, tmp_buffer, i);
				free(tmp_buffer);
				tmp_buffer = (unsigned char *)input_buffer;
			}
		}
		input_buffer = (void *)tmp_buffer;
		input_buffer_len = i;
		break;
	default:
		/* Fall-through */
	case INPUT_FILE:
		fd = open(argv[2], O_RDONLY);
		if (fd == -1) {
			printf("ERROR: Could not open input file %s\n",
			       argv[2]);
			return 1;
		}
		if (fstat(fd, &file_info)) {
			printf("ERROR: Could not fstat input fd\n");
			return 1;
		}

		// Count how many bytes are in the file
		input_buffer_len = (int)file_info.st_size;

		// Malloc count bytes of memory to hold the contents
		input_buffer = (unsigned char *)malloc(input_buffer_len);
		if (!input_buffer) {
			printf("ERROR: Could not malloc input_buffer\n");
			return 1;
		}

		if (read(fd, input_buffer, input_buffer_len) == -1) {
			printf("ERROR: Could not read input file into input_buffer\n");
			free(input_buffer);
			return 1;
		}
		break;
	}

	if (verbose) {
		printf("Input is %d byte", input_buffer_len);
		if (input_buffer_len != 1) {
			printf("s");
		}
		printf("\n");
	}

	if (!sha3_mgh(input_buffer, input_buffer_len, &output, MD_LENGTH)) {
		printf("sha3 failed for string `%s`\n", argv[1]);
	}

	for (i = 0; i < MD_LENGTH; ++i) {
		printf("%02hhx", output[i]);
	}
	printf("\n");

	if (input_type == INPUT_FILE) {
		free(input_buffer);
	}
	return 0;
}
