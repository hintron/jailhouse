#include <stdio.h>
#include <stdlib.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

enum ivshmem_registers {
    intrmask = 0 / sizeof(int),
    intrstatus = 4 / sizeof(int),
    ivposition = 8 / sizeof(int),
    doorbell = 12 / sizeof(int),
    lstate = 16 / sizeof(int),
    rstate = 20 / sizeof(int)
};


// https://stackoverflow.com/questions/12502552/can-i-check-if-two-file-or-file-descriptor-numbers-refer-to-the-same-file
int same_file(int fd1, int fd2) {
    struct stat stat1, stat2;
    if(fstat(fd1, &stat1) < 0) return -1;
    if(fstat(fd2, &stat2) < 0) return -1;
    return (stat1.st_dev == stat2.st_dev) && (stat1.st_ino == stat2.st_ino);
}


/*
 * Write to the doorbell register
 *
 * From ivshmem-spec.txt:
 *
 * Doorbell Register: writing this register requests to interrupt a peer.
 * The written value's high 16 bits are the ID of the peer to interrupt,
 * and its low 16 bits select an interrupt vector.
 *
 * If the device is not configured for interrupts, the write is ignored.
 *
 * If the interrupt hasn't completed setup, the write is ignored.  The
 * device is not capable to tell guest software whether setup is
 * complete.  Interrupts can regress to this state on migration.
 *
 * If the peer with the requested ID isn't connected, or it has fewer
 * interrupt vectors connected, the write is ignored.  The device is not
 * capable to tell guest software what peers are connected, or how many
 * interrupt vectors are connected
 */
void write_to_doorbell(unsigned int registers_ptr[], unsigned int dest, unsigned int cmd)
{
    int msg = ((dest & 0xffff) << 16) + (cmd & 0xffff);
    printf("MGH: writing to doorbell. msg = %u (dest:%u; cmd:%u)\n", msg, dest, cmd);
    registers_ptr[doorbell] = msg;
}



int main(int argc, char **argv) {
    unsigned int *shmem = NULL;
    unsigned int *registers = NULL;
    unsigned int temp = 0;
    unsigned int i = 0;

    // Get the page size of the system (usually 4096)
    long PAGESIZE = sysconf(_SC_PAGESIZE);

    // Open the files
    int uio0_fd = open("/dev/uio0", O_RDONLY);
    int res0_fd = open("/sys/class/uio/uio0/device/resource0", O_RDWR);
    // You can't mmap this config file. You can only [p]read/[p]write it
    int config_fd = open("/sys/class/uio/uio0/device/config", O_RDWR);

    printf("MGH: uio0_fd = %d\n", uio0_fd);
    printf("MGH: res0_fd = %d\n", res0_fd);
    printf("MGH: config_fd = %d\n", config_fd);

    // Check to make sure


    // Get the registers offset
    registers = (unsigned int *) mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, res0_fd, PAGESIZE*0);
    if (registers == (void *) -1) {
        printf("registers mmap failed (%p)\n", registers);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        close(res0_fd);
        exit(-1);
    }
    // TODO: Check to see if this still fails
    // if ((registers = mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, uio0_fd, PAGESIZE*0)) == (void *) -1){
    printf("registers mmap succeeded! Address:%p\n", registers);


    // Get the shared memory at +PAGESIZE offset of /dev/uio0
    shmem = (unsigned int *) mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, uio0_fd, PAGESIZE*1);
    if (shmem == (void *) -1) {
        printf("shmem mmap failed (%p)\n", shmem);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        close(uio0_fd);
        exit(-1);
    }
    printf("shmem mmap succeeded! Address:%p\n", shmem);

    // Wait for interrupts to come in from the real-time inmate
    while (1) {
        int buf = 0;
        // 4 is the only valid read count for /dev/uioX
        int rv = read(uio0_fd, &buf, 4);
        if (rv == -1) {
            printf("MGH: Error reading fd=%d\n", uio0_fd);
            continue;
        }

        printf("MGH: Received interrupt! buf is %d\n", buf);

        printf("MGH: Swap and increment shmem\n");
        temp = ++shmem[0];
        shmem[0] = shmem[1];
        shmem[1] = temp;

        printf("MGH: intrmask: %d\n", registers[intrmask]);
        printf("MGH: intrstatus: %d\n", registers[intrstatus]);
        printf("MGH: ivposition: %d\n", registers[ivposition]);
        /*
         * There is no good way for software to find out whether the device is
         * configured for interrupts. A positive IVPosition means interrupts,
         * but zero could mean either.
         */
        if (registers[ivposition] > 0) {
            printf("MGH: interrupts are configured!\n");
        }
        printf("MGH: doorbell: %d\n", registers[doorbell]);
        printf("MGH: lstate: %d\n", registers[lstate]);
        printf("MGH: rstate: %d\n", registers[rstate]);
        // printf("MGH: writing to lstate...\n");
        // printf("MGH: lstate: %d\n", registers[lstate]);

        // Try different things on different interrupts, to see what breaks
        switch(i) {
            default:
            // fall through
            case 0:
                write_to_doorbell(registers, 1, 16);
                break;
            case 1:
                write_to_doorbell(registers, 1, 1);
                break;
            case 2:
                write_to_doorbell(registers, 1, 2);
                break;
            case 3:
                write_to_doorbell(registers, 2, 1);
                break;
            case 4:
                write_to_doorbell(registers, 2, 16);
                break;
        }
        i++;
    }

    close(uio0_fd);
    close(res0_fd);
    close(config_fd);
    munmap(shmem, 4096);
    munmap(registers, 4096);
    exit(0);
}
