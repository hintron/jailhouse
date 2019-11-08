#include <stdio.h>
#include <sys/types.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdlib.h>
#include "include/sha3_mgh.h"

#define MAX_INPUT_PRINT 50

static int _count_set_bits(unsigned char *input, int input_len, int mode)
{
	int print = 0;

	if (input_len <= MAX_INPUT_PRINT) {
		print = 1;
		printf("Input Bytes:\n");
	} else {
		printf("Input is too large to print out (> %d bytes)\n",
		       MAX_INPUT_PRINT);
	}

	// Loop through each byte
	for (int i = 0; i < input_len; ++i) {
		if (print)
			printf("0x%0x\n", input[i]);
	}

	return count_set_bits_mgh(input, input_len, mode);

}

static int count_set_bits_0(unsigned char *input, int input_len)
{
	printf("%s\n", __func__);
	return _count_set_bits(input, input_len, 0);
}

static int count_set_bits_1(unsigned char *input, int input_len)
{
	printf("%s\n", __func__);
	return _count_set_bits(input, input_len, 1);
}

static int count_set_bits_2(unsigned char *input, int input_len)
{
	printf("%s\n", __func__);
	return _count_set_bits(input, input_len, 2);
}

int main(int argc, char const *argv[])
{
	int fd;
	struct stat file_info;
	int input_len = 0;
	void *input_buffer = NULL;
	int result0 = 0;
	int result1 = 0;
	int result2 = 0;

	if (argc != 2) {
		printf("Usage:\n");
		printf("    count-bits <input-file>\n");
		printf("    \n");
		printf("This program counts how many 1s there are in the input file's binary data.\n");
		return 1;
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
	if (input_len == 1) {
		printf("Input file is 1 byte\n");
	} else {
		printf("Input file is %d bytes\n", input_len);
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

	// Count the number of 1's in the input_buffer's binary data and return
	result0 = count_set_bits_0(input_buffer, input_len);
	result1 = count_set_bits_1(input_buffer, input_len);
	result2 = count_set_bits_2(input_buffer, input_len);

	if (result0 != result1 || result0 != result2) {
		printf("ERROR: result0 (%d), result1 (%d), and result2 (%d) differ\n",
		       result0, result1, result2);
		return 1;
	} else {
		printf("result0, result1, and result2 all match\n");
	}

	if (result0 == 1) {
		printf("There is 1 set bit in the input file\n");
	} else {
		printf("There are %d set bits in the input file\n", result0);
	}

	// Success
	return 0;
}
