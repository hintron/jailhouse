#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>
#include "ivshmem.h"

enum ivshmem_registers {
    intrmask = 0 / sizeof(int),
    intrstatus = 4 / sizeof(int),
    ivposition = 8 / sizeof(int),
    doorbell = 12 / sizeof(int),
    lstate = 16 / sizeof(int),
    rstate = 20 / sizeof(int)
};

int main(int argc, char **argv) {
    void *memptr = NULL;
    void *configptr = NULL;
    unsigned int *mem_array = NULL;
    unsigned int *config_array = NULL;
    unsigned int temp = 0;
    int fd1 = 0;
    int fd2 = 0;
    char *file_1 = "/dev/uio0";
    char *file_2 = "/sys/class/uio/uio0/device/resource0";

    printf("opening file %s\n", file_1);
    fd1 = open(file_1, O_RDWR);
    printf("MGH: fd1 = %d\n", fd1);
    printf("opening file %s\n", file_2);
    fd2 = open(file_2, O_RDWR);
    printf("MGH: fd2 = %d\n", fd2);

    // Get the shared memory at +4096 offset of /dev/uio0
    if ((memptr = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, fd1, 4096)) == (void *) -1){
        printf("mmap failed (%p)\n", memptr);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        close(fd1);
        exit(-1);
    }
    printf("mmap succeeded! Address:%p\n", memptr);
    mem_array = (unsigned int *)memptr;

    printf("MGH: Swap and increment shmem\n");
    temp = ++mem_array[0];
    mem_array[0] = mem_array[1];
    mem_array[1] = temp;

    if ((configptr = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, fd2, 0)) == (void *) -1){
        printf("mmap failed (%p)\n", configptr);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        close(fd2);
        exit(-1);
    }
    printf("mmap succeeded! Address:%p\n", configptr);
    config_array = (char *)configptr;

    printf("MGH: lstate: %d\n", config_array[lstate]);
    printf("MGH: rstate: %d\n", config_array[rstate]);
    printf("MGH: writing to lstate...\n");
    config_array[lstate]++;
    printf("MGH: lstate: %d\n", config_array[lstate]);

    printf("MGH: doorbell: %d\n", config_array[doorbell]);
    printf("MGH: writing to doorbell...\n");
    config_array[doorbell] = 1;
    printf("MGH: doorbell: %d\n", config_array[doorbell]);

    close(fd1);
    close(fd2);
    munmap(memptr, 4096);
    munmap(configptr, 4096);
    exit(0)
}
