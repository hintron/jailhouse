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
    IntrMask = 0,
    IntrStatus = 4,
    IVPosition = 8,
    Doorbell = 12,
    lstate = 16,
    rstate = 20
};

int main(int argc, char ** argv){

    void * memptr, *configptr;
    char *char_array, *config_array;
    unsigned int * map_array;
    int i, fd, fdc;
    int count;
    int msg, cmd, dest;
    char temp;

    if (argc != 5) {
        printf("USAGE: uio_ioctl <filename> <count> <cmd> <dest>\n");
        exit(-1);
    }

    fd=open(argv[1], O_RDWR);
    printf("[UIO] opening file %s\n", argv[1]);
    printf("MGH: fd = %d\n", fd);
    count = atol(argv[2]);
    cmd = (unsigned short) atoi(argv[3]);
    dest = (unsigned short) atoi(argv[4]);

    printf("[UIO] count is %d\n", count);

    //if ((memptr = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 0)) == (void *) -1){
    if ((memptr = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, fd, 4096)) == (void *) -1){
        printf("mmap failed (%p)\n", memptr);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
	close (fd);
        exit (-1);
    }
    printf("mmap succeeded! Address:%p\n", memptr);

    map_array = (unsigned int *)memptr;
    char_array = (char *)memptr;

    fdc = open("/sys/class/uio/uio0/device/resource0", O_RDWR);
    if ((configptr = mmap(NULL, 4096, PROT_READ|PROT_WRITE, MAP_SHARED, fdc, 0)) == (void *) -1){
        printf("mmap failed (%p)\n", configptr);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
	close (fdc);
        exit (-1);
    }


    printf("mmap succeeded! Address:%p\n", configptr);
    config_array = (char *)configptr;

    // TODO: This only reads a byte, but it's four bytes. Be careful
    printf("MGH: lstate: %d\n", config_array[lstate]);
    printf("MGH: rstate: %d\n", config_array[rstate]);
    printf("MGH: writing to lstate...\n");
    config_array[lstate]++;
    printf("MGH: lstate: %d\n", config_array[lstate]);
    printf("MGH: Doorbell: %d\n", config_array[Doorbell]);
    printf("MGH: writing to doorbell...\n");
    config_array[Doorbell]++;
    printf("MGH: Doorbell: %d\n", config_array[Doorbell]);

    //msg = ((dest & 0xffff) << 16) + (cmd & 0xffff);
//  //  msg = cmd;
    //printf("[UIO] writing %u\n", msg);

    //for (i = 0; i < count; i++) {
    //    printf("[UIO] ping #%d\n", i);
    //    map_array[Doorbell/sizeof(int)] = msg;
    //    sleep(1);
    //}


    for (i = 0; i < count; i++) {
        printf("MGH: Set shmem %d\n", i);
        temp = ++char_array[0];
        char_array[0] = char_array[1];
        char_array[1] = temp;
        sleep(1);
    }

    munmap(memptr, 4096);
    close(fd);

    printf("[UIO] Exiting...\n");
}
