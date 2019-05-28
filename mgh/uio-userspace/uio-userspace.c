#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <sys/mman.h>
#include <sys/types.h>
#include <fcntl.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include <errno.h>

static const char *UIO_FILE = "/dev/uio0";
static const char *RES_0_FILE = "/sys/class/uio/uio0/device/resource0";
static const char *CONFIG_FILE = "/sys/class/uio/uio0/device/config";

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
    unsigned int j = 0;
    long PAGESIZE = 0;
    int uio0_fd = 0;
    int res0_fd = 0;
    int config_fd = 0;
    int err = 0;
    unsigned char command_high = 0;
    uint16_t vendor = 0;
    uint16_t device = 0;

    if (argc != 1) {
        printf("uio-userspace v0.1\n");
        printf("Usage:\n");
        printf("    uio-userspace [help]\n");
        printf("    \n");
        printf("    This program will try to interact with a Jailhouse inmate over a virtual PCI ivshmem device through shared memory.\n");
        exit(0);
    }

    // Get the page size of the system (usually 4096)
    PAGESIZE = sysconf(_SC_PAGESIZE);

    // Open the files
    uio0_fd = open(UIO_FILE, O_RDWR);
    res0_fd = open(RES_0_FILE, O_RDWR);
    // You can't mmap this config file. You can only [p]read/[p]write it
    config_fd = open(CONFIG_FILE, O_RDWR);

    printf("MGH: uio0_fd = %d\n", uio0_fd);
    printf("MGH: res0_fd = %d\n", res0_fd);
    printf("MGH: config_fd = %d\n", config_fd);

    if (uio0_fd == -1) {
        printf("open(%s) failed\n", UIO_FILE);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        exit(-1);
    }
    if (res0_fd == -1) {
        printf("open(%s) failed\n", RES_0_FILE);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        exit(-1);
    }
    if (config_fd == -1) {
        printf("open(%s) failed\n", CONFIG_FILE);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        exit(-1);
    }

    // This call succeeds on Inspiron, but not in QEMU Jailhouse Image
    printf("Trying to mmap registers from %s\n", UIO_FILE);
    registers = (unsigned int *) mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, uio0_fd, PAGESIZE*0);
    if (registers == (void *) -1) {
        printf("registers mmap failed for %s (%p)\n", UIO_FILE, registers);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));

        // This call succeeds in QEMU Jailhouse Image, but not on Inspiron
        printf("Trying to mmap registers from %s\n", RES_0_FILE);
        // Try again, but this time use the resource 0 version
        registers = (unsigned int *) mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, res0_fd, PAGESIZE*0);
        if (registers == (void *) -1) {
            printf("registers mmap failed for %s (%p)\n", RES_0_FILE, registers);
            printf("MGH: ERR %d: %s\n", errno, strerror(errno));
            exit(-1);
        }
    }
    printf("registers mmap succeeded! Address:%p\n", registers);

    // Get the shared memory at +PAGESIZE offset of /dev/uio0
    shmem = (unsigned int *) mmap(NULL, PAGESIZE, PROT_READ|PROT_WRITE, MAP_SHARED, uio0_fd, PAGESIZE*1);
    if (shmem == (void *) -1) {
        printf("shmem mmap failed (%p)\n", shmem);
        printf("MGH: ERR %d: %s\n", errno, strerror(errno));
        exit(-1);
    }
    printf("shmem mmap succeeded! Address:%p\n", shmem);


    // Sanity check: read device and vendor id
    err = pread(config_fd, &vendor, 2, 0);
    if (err == -1) {
        printf("MGH: Error reading PCI vendor: (%d) %s\n", errno, strerror(errno));
        exit(-1);
    }
    printf("Vendor: %x\n", vendor);

    err = pread(config_fd, &device, 2, 2);
    if (err == -1) {
        printf("MGH: Error reading PCI device: (%d) %s\n", errno, strerror(errno));
        exit(-1);
    }
    printf("device: %x\n", device);

    // Wait for interrupts to come in from the real-time inmate
    while (1) {
        int buf = 0;

        // See uio-howto.rst
        /* Read and cache command value */
        err = pread(config_fd, &command_high, 1, 5);
        if (err == -1) {
            printf("MGH: command config read ERR %d: %s\n", errno, strerror(errno));
            exit(-1);
        }
        printf("MGH: command_high: %x\n", command_high);
        command_high &= ~0x4;
        printf("MGH: command_high &= ~0x4: %x\n", command_high);

        // Is this needed? See uio-howto.rst
        /* Re-enable interrupts. */
        err = pwrite(config_fd, &command_high, 1, 5);
        if (err == -1) {
            perror("config write:");
            break;
        }

        // Wait for next interrupt from inmate
        // 4 is the only valid read count for /dev/uioX
        err = read(uio0_fd, &buf, 4);
        if (err == -1) {
            printf("MGH: Error reading %s: (%d) %s\n", UIO_FILE, errno, strerror(errno));
            continue;
        }
        if (err != 4) {
            printf("MGH: Error: did not read in 4 bytes!\n");
        }

        printf("MGH: Received interrupt! buf is %d\n", buf);
        printf("MGH: Swap and increment shmem\n");
        temp = ++shmem[0];
        shmem[0] = shmem[1];
        shmem[1] = temp;

        printf("MGH: intrmask: %d\n", registers[intrmask]);
        // This seems to crash things
        // printf("MGH: intrstatus: %d\n", registers[intrstatus]);
        /*
         * There is no good way for software to find out whether the device is
         * configured for interrupts. A positive IVPosition means interrupts,
         * but zero could mean either.
         */
        printf("MGH: ivposition: %d\n", registers[ivposition]);
        if (registers[ivposition] > 0) {
            printf("MGH: interrupts are configured!\n");
        }
        printf("MGH: doorbell: %d\n", registers[doorbell]);
        printf("MGH: lstate: %d\n", registers[lstate]);
        printf("MGH: rstate: %d\n", registers[rstate]);
        // printf("MGH: writing to lstate...\n");
        // printf("MGH: lstate: %d\n", registers[lstate]);

        // Try all the different commands to see what happens
        for (i = 0; i < 32; ++i) {
            for (j = 0; j < 32; ++j) {
                write_to_doorbell(registers, i, j);
            }
        }

        // Try writing to the doorbell register
        registers[lstate] = 1;
    }

    // This doesn't matter if we are exiting (only for valgrind)
    // close(uio0_fd);
    // close(res0_fd);
    // close(config_fd);
    // munmap(shmem, 4096);
    // munmap(registers, 4096);
    exit(0);
}
