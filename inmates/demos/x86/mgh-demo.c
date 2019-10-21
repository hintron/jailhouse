/*
 * Jailhouse, a Linux-based partitioning hypervisor
 *
 * Copyright (c) Siemens AG, 2014-2016
 *
 * Authors:
 *  Henning Schild <henning.schild@siemens.com>
 *
 * This work is licensed under the terms of the GNU GPL, version 2.  See
 * the COPYING file in the top-level directory.
 */
#include <inmate.h>

#define VENDORID	0x1af4
#define DEVICEID	0x1110

#define IVSHMEM_CFG_SHMEM_PTR	0x40
#define IVSHMEM_CFG_SHMEM_SZ	0x48

#define JAILHOUSE_SHMEM_PROTO_UNDEFINED	0x0000

#define IRQ_VECTOR	32

#define MAX_NDEV	4
#define UART_BASE	0x3F8

//
// MGH Section
//

#define MGH_HEAP_BASE		0x00200000
#define MGH_HEAP_SiZE_MB	30
static unsigned long CPU_CACHE_LINE_SIZE = 64;

/* NOTE: The stack size is the same size as a page (4 kb) */

/*
 * If true, then the input data will be copied into a local buffer before
 * passing to the workload. Then, a local output buffer will also be passed into
 * the workload. This is important, since the input originates in
 * a shared memory region which could introduce interference from other CPUs
 * if accessed throughout the workload.
 * NOTE: For now, keep disabled, because it hurts performance rather than helps.
 */
#define LOCAL_BUFFER	false

static bool is_throttle_enabled = false;
static char str[32] = "Hello From MGH      ";

/*
 * The number of nanoseconds before toggling the throttle mechanism on or off.
 * Currently set to 15 seconds = 15 * 10^9
 */
#define ALTERNATING_PERIOD 15000000000
/* Delay 1 ms between each poll of the workload input */
#define POLL_DELAY_US 1000

typedef enum {
	ALTERNATING,
	DEADLINE,
} throttle_mode_t;

static throttle_mode_t THROTTLE_MODE = ALTERNATING;

typedef enum {
	SHA3,
	CACHE_ANALYSIS,
} workload_t;

static workload_t WORKLOAD_MODE = CACHE_ANALYSIS;

#define CACHE_ANALYSIS_SIZE_MB 20
#define CACHE_ANALYSIS_POLLUTE_CACHE false
#define CACHE_ANALYSIS_USE_INPUT false

/* Change to false to disable print statements during regular operation. */
#define MGH_DEBUG_MODE	true
// #define MGH_DEBUG_MODE	false

// # of bytes for the sha3-512 message digest output
#define MD_LENGTH 	64
#define MB		(1 << 20) // 2^20 = 1048576 = 1 MB
#define OUTPUT_BYTES 	MD_LENGTH

// Map out shared memory (define the sizes)
#define SYNC_SIZE 	1
#define RES_1_SIZE 	3
#define IN_LEN_SIZE 	4
#define OUT_SIZE 	64
#define RES_2_SIZE 	4032
// The entire IVSHMEM region is 1 MB. Input Data gets the rest of the space.
#define IN_SIZE 	(MB - (SYNC_SIZE + RES_1_SIZE + IN_LEN_SIZE + OUT_SIZE + RES_1_SIZE))

#define OFFSET_SYNC 	0
#define OFFSET_RES_1 	(OFFSET_SYNC + SYNC_SIZE)
#define OFFSET_IN_LEN 	(OFFSET_RES_1 + RES_1_SIZE)
#define OFFSET_OUT 	(OFFSET_IN_LEN + IN_LEN_SIZE)
#define OFFSET_RES_2 	(OFFSET_OUT + OUT_SIZE)
#define OFFSET_IN 	(OFFSET_RES_2 + RES_2_SIZE)

// /* See alloc.c and d54cbbcc7c38 */
// extern unsigned long heap_pos;

// TODO: Replace this with Jailhouse alloc with commit d54cbbcc7c38
// Adapted from inmates/lib/alloc.c
// NOTE: The "heap" is really just another stack at this point.

static unsigned long heap_pos = MGH_HEAP_BASE;

static void *_alloc(unsigned long size, unsigned long align)
{
	if (MGH_DEBUG_MODE)
		printk("MGH DEBUG: heap_pos before: 0x%lx\n", heap_pos);

	unsigned long base = (heap_pos + align - 1) & ~(align - 1);
	heap_pos = base + size;

	if (MGH_DEBUG_MODE)
		printk("MGH DEBUG: heap_pos after: 0x%lx\n", heap_pos);

	return (void *)base;
}

static void *alloc_heap(unsigned long size)
{
	return _alloc(size, PAGE_SIZE);
}

/*
 * Effectively "free" all memory allocated via alloc_heap() by resetting the
 * heap position.
 */
static void free_heap_all(void)
{
	heap_pos = MGH_HEAP_BASE;
}

struct ivshmem_dev_data {
	u16 bdf;
	u32 *registers;
	void *shmem;
	u32 *msix_table;
	u64 shmemsz;
	u64 bar2sz;
};

static u64 pci_cfg_read64(u16 bdf, unsigned int addr)
{
	u64 bar;

	bar = ((u64)pci_read_config(bdf, addr + 4, 4) << 32) |
	      pci_read_config(bdf, addr, 4);
	return bar;
}

static void pci_cfg_write64(u16 bdf, unsigned int addr, u64 val)
{
	pci_write_config(bdf, addr + 4, (u32)(val >> 32), 4);
	pci_write_config(bdf, addr, (u32)val, 4);
}

static u64 get_bar_sz(u16 bdf, u8 barn)
{
	u64 bar, tmp;
	u64 barsz;

	bar = pci_cfg_read64(bdf, PCI_CFG_BAR + (8 * barn));
	pci_cfg_write64(bdf, PCI_CFG_BAR + (8 * barn), 0xffffffffffffffffULL);
	tmp = pci_cfg_read64(bdf, PCI_CFG_BAR + (8 * barn));
	barsz = ~(tmp & ~(0xf)) + 1;
	pci_cfg_write64(bdf, PCI_CFG_BAR + (8 * barn), bar);

	return barsz;
}

static void map_shmem_and_bars(struct ivshmem_dev_data *d)
{
	int cap = pci_find_cap(d->bdf, PCI_CAP_MSIX);

	if (cap < 0) {
		printk("MGH DEMO ERROR: device is not MSI-X capable\n");
		return;
	}

	d->shmemsz = pci_cfg_read64(d->bdf, IVSHMEM_CFG_SHMEM_SZ);
	d->shmem = (void *)pci_cfg_read64(d->bdf, IVSHMEM_CFG_SHMEM_PTR);

	if (MGH_DEBUG_MODE)
		printk("MGH DEMO: shmem is at %p\n", d->shmem);

	d->registers = (u32 *)((u64)(d->shmem + d->shmemsz + PAGE_SIZE - 1)
		& PAGE_MASK);
	pci_cfg_write64(d->bdf, PCI_CFG_BAR, (u64)d->registers);

	if (MGH_DEBUG_MODE)
		printk("MGH DEMO: bar0 is at %p\n", d->registers);

	d->bar2sz = get_bar_sz(d->bdf, 2);
	d->msix_table = (u32 *)((u64)d->registers + PAGE_SIZE);
	pci_cfg_write64(d->bdf, PCI_CFG_BAR + 16, (u64)d->msix_table);

	if (MGH_DEBUG_MODE)
		printk("MGH DEMO: bar2 is at %p\n", d->msix_table);

	pci_write_config(d->bdf, PCI_CFG_COMMAND,
			 (PCI_CMD_MEM | PCI_CMD_MASTER), 2);
	map_range(d->shmem, d->shmemsz + PAGE_SIZE + d->bar2sz, MAP_UNCACHED);
}

static int get_ivpos(struct ivshmem_dev_data *d)
{
	// Read from the ivpos register
	// IVPosition Register: if the device is not configured for interrupts,
	// this is zero. Else, it is the device's ID (between 0 and 65535).
	return mmio_read32(d->registers + 2);
}

// TODO: Get this working? Do I need this?
// static void send_irq(struct ivshmem_dev_data *d)
// {
// 	printk("MGH DEMO: %02x:%02x.%x sending IRQ; Shared: %s\n",
// 	       d->bdf >> 8, (d->bdf >> 3) & 0x1f, d->bdf & 0x3, (char *)d->shmem);
// 	// Write to the doorbell register (3 * u32 = 12 bytes)
// 	mmio_write32(d->registers + 3, 1);
// }

static char _get_hex_from_lower_nibble(char in)
{
	// Init with bogus value
	char out = 'G';
	in = in & 0x0F;
	if (in <= 9) {
		out = in + '0';
	} else if (in > 9 && in <= 15) {
		out = in + 'a' - 10;
	} else {
		printk("MGH DEMO: Warning: Could not convert '%d' to hex\n", in);
	}
	return out;
}

static char _get_hex_from_upper_nibble(char in)
{
	return _get_hex_from_lower_nibble(in >> 4);
}

static unsigned long get_cache_line_size(void)
{
	unsigned long cache_line_size = 0;
	unsigned long ebx;

	asm volatile("cpuid" : "=b" (ebx) : "a" (1)
		: "rcx", "rdx", "memory");
	cache_line_size = (ebx & 0xff00) >> 5;

	if (MGH_DEBUG_MODE)
		printk("MGH DEBUG: cache_line_size = %lu\n", cache_line_size);

	/* The cache line size should always be 64 B on Intel x86-64 */
	if (cache_line_size != 64)
		printk("MGH DEBUG: Error: Actual cache line size is %lu B\n",
		       cache_line_size);

	return cache_line_size;
}

/*
 * Write to the first byte of each cache line at a given memory location. This
 * will force the CPU to load data from the memory location into the cache.
 *
 * mem		(IN/OUT) A pointer to the memory location.
 * size		(IN) How much of the memory to disturb.
 *
 * Adapted from apic-demo.c
 */
static void pollute_cache(char *mem, unsigned long size)
{
	for (unsigned long n = 0; n < size; n += CPU_CACHE_LINE_SIZE) {
		mem[n] ^= 0xAA;
	}
}

/* Calculate sha3 of input and store in output */
static void calculate_sha3(char *input, unsigned long input_length,
			   char *output)
{
	int i;

	// Add a null char to end of input for printing convenience
	input[input_length] = '\0';

	if (!sha3_mgh(input, (int)input_length, output, MD_LENGTH)) {
		printk("sha3 failed for string `%s`\n", input);
		return;
	}

	// Return early if not in debug mode
	if (!MGH_DEBUG_MODE)
		return;

	// Print out the calculated SHA3
	for (i = 0; i < MD_LENGTH; ++i) {
		char upper = _get_hex_from_upper_nibble(output[i]);
		char lower = _get_hex_from_lower_nibble(output[i]);
		printk("%c", upper);
		printk("%c", lower);
	}
	printk("\n");
}


static void cache_analysis(char *input, unsigned long input_len, char *output)
{
	unsigned char *buffer = NULL;
	unsigned long buffer_size = CACHE_ANALYSIS_SIZE_MB*MB;
	unsigned char input_hash = 0;

	if (CACHE_ANALYSIS_USE_INPUT) {
		// Create a simple 1-byte hash from the input
		for (unsigned long i = 0; i < input_len; ++i) {
			// Implicit cast of signed char to unsigned
			input_hash += input[i];
		}
	} else {
		input_hash = CACHE_ANALYSIS_SIZE_MB;
	}
	if (MGH_DEBUG_MODE) {
		printk("MGH DEBUG: input_hash: %u\n", input_hash);
		printk("MGH DEBUG: buffer_size: 0x%lx\n", buffer_size);
	}

	// Allocate 20 MB of memory to play with
	buffer = (unsigned char *)alloc_heap(buffer_size);

	if (MGH_DEBUG_MODE) {
		printk("MGH DEBUG: buffer: %p\n", buffer);
		printk("MGH DEBUG: buffer_end: %p\n", &buffer[buffer_size-1]);
	}

	// Force entire buffer into cache
	if (CACHE_ANALYSIS_POLLUTE_CACHE)
		pollute_cache((char *)buffer, buffer_size);

	// n stores
	for (unsigned long i = 0; i < buffer_size; ++i) {
		buffer[i] = i;
		if (MGH_DEBUG_MODE && (i % MB == 0))
			printk("MGH DEBUG: i==0x%lx\n", i);
	}

	// n stores
	for (unsigned long i = 0; i < buffer_size-1; ++i) {
		buffer[i] = buffer[i] + buffer[i+1];
	}
	buffer[buffer_size-1] = (2 * buffer[buffer_size-1]) + 1;

	free_heap_all();
}

static void irq_handler(void)
{
	static int irq_counter = 0;
	printk("MGH DEMO: got interrupt ... %d\n", irq_counter++);
}


/*
 * Returns true if hardware setup was successful.
 */
static bool hardware_setup(void)
{
	unsigned long tsc_freq;

	// Set up the Time Stamp Counter (TSC)
	tsc_freq = tsc_init();
	if (tsc_freq == 0) {
		printk("MGH DEMO: TSC was not initialized successfully (frequency == 0).\n");
		return false;
	}

	if (MGH_DEBUG_MODE)
		printk("MGH DEMO: TSC frequency is %lu Hz.\n", tsc_freq);

	// Set the cache line size
	CPU_CACHE_LINE_SIZE = get_cache_line_size();

	return true;
}

/*
 * Returns true if device setup was successful.
 */
static bool device_setup(struct ivshmem_dev_data *devs)
{
	int bdf = 0;
	unsigned int class_rev;
	struct ivshmem_dev_data *dev;
	int ndevices = 0;

	// Set up interrupts
	int_init();

	while ((ndevices < MAX_NDEV) &&
	       (-1 != (bdf = pci_find_device(VENDORID, DEVICEID, bdf)))) {
	       	if (MGH_DEBUG_MODE)
			printk("MGH DEMO: Found %04x:%04x at %02x:%02x.%x\n",
			       pci_read_config(bdf, PCI_CFG_VENDOR_ID, 2),
			       pci_read_config(bdf, PCI_CFG_DEVICE_ID, 2),
			       bdf >> 8, (bdf >> 3) & 0x1f, bdf & 0x3);

		class_rev = pci_read_config(bdf, 0x8, 4);
		if (class_rev != (PCI_DEV_CLASS_OTHER << 24 |
				  JAILHOUSE_SHMEM_PROTO_UNDEFINED << 8)) {
			printk("MGH DEMO: class/revision %08x, not supported "
			       "skipping device\n", class_rev);
			bdf++;
			continue;
		}
		dev = &devs[ndevices];
		dev->bdf = bdf;
		map_shmem_and_bars(dev);
		if (MGH_DEBUG_MODE)
			printk("MGH DEMO: mapped the bars got position %d\n",
			       get_ivpos(dev));

		memcpy(dev->shmem, str, 32);

		int_set_handler(IRQ_VECTOR + ndevices, irq_handler);
		pci_msix_set_vector(bdf, IRQ_VECTOR + ndevices, 0);
		bdf++;
		ndevices++;
	}

	if (ndevices <= 0) {
		printk("MGH DEMO: No PCI devices found! Nothing to do\n");
		return false;
	}

	if (ndevices > 1) {
		printk("MGH DEMO: More than one PCI device found!\n");
	}

	return true;
}

static void enable_throttle(void)
{
	/* Communicate to the hypervisor via the Jailhouse
	 * communication region of this cell */
	jailhouse_send_msg_to_cell(comm_region,
			JAILHOUSE_MSG_START_THROTTLING);
	printk("MGH DEMO: Sent enable throttle request\n");
}

static void disable_throttle(void)
{
	jailhouse_send_msg_to_cell(comm_region,
			JAILHOUSE_MSG_STOP_THROTTLING);
	printk("MGH DEMO: Sent disable throttle request\n");
}

/*
 * Toggle the throttling mechanism on or off if it has been ALTERNATING_PERIOD
 * nanoseconds since the last throttle toggle. Run this check before every
 * workload. Use this throttle mode to measure the impact of throttling with a
 * sustained root userspace workload.
 */
static void check_alternating_throttle(void)
{
	static unsigned long start = 0;
	static bool throttled = false;
	unsigned long current, duration;

	/* If 0, it means we haven't initialized the timer yet */
	if (start == 0) {
		start = tsc_read_ns();
		return;
	}

	current = tsc_read_ns();
	if (current < start) {
		printk("MGH: ERROR: TSC underflow (current=%ld, start=%ld\n",
		       current, start);
		return;
	}

	duration = current - start;
	if (duration < ALTERNATING_PERIOD)
		return;

	/* Toggle the throttling mechanism on or off */
	if (throttled) {
		disable_throttle();
		throttled = false;
	} else {
		enable_throttle();
		throttled = true;
	}

	/* Reset timer */
	start = tsc_read_ns();
}

/*
 * Turn on throttling if deadlines were not met during the last workload. Run
 * this check before every workload.
 */
static void check_deadline_throttle(unsigned long ns_per_byte)
{
	// static int now = 0;
	// static int previous = 0;
	static int MAX_NS_PER_BYTE = 120;
	bool meeting_deadlines = false;

	/* If we haven't run yet, we don't know if we need to throttle or not */
	if (ns_per_byte == 0)
		return;

	if (ns_per_byte > MAX_NS_PER_BYTE) {
		// Throttle!
		meeting_deadlines = false;
	} else {
		meeting_deadlines = true;
	}

	// TODO: Add some smoothing if needed, so inmate isn't thrashing back
	// and forth between throttle and no throttle

	// If we are meeting deadlines, and we are throttling, stop throttling
	if (meeting_deadlines && is_throttle_enabled) {
		disable_throttle();
		is_throttle_enabled = false;
	} else if (!meeting_deadlines && !is_throttle_enabled) {
		enable_throttle();
		is_throttle_enabled = true;
	}

	// TODO: Have the root cell automatically throttle itself,
	// rather than wait for the root to request it (is there shared
	// read-only memory it could monitor?)
}

/*
 * If the root wants us to shut down, disable throttling beforehand, if needed.
 * Then, change the inmate's cell state and return true.
 * Else, return false.
 */
static bool check_shutdown(void)
{
	bool ret = false;
	switch (comm_region->msg_to_cell) {
	case JAILHOUSE_MSG_SHUTDOWN_REQUEST:
		printk("MGH DEMO: Allowing inmate to be shut down\n");
		comm_region->cell_state = JAILHOUSE_CELL_SHUT_DOWN;
		ret = true;
		break;
	default:
	case JAILHOUSE_MSG_NONE:
		break;
	// NOTE: We don't want to send an UNKNOWN message because that could
	// mess with the throttling messages we send
	// 	jailhouse_send_reply_from_cell(comm_region,
	// 				       JAILHOUSE_MSG_UNKNOWN);
	// 	break;
	}
	return ret;
}

static unsigned long get_input_length(volatile char *shmem)
{
	u32 *len_ptr = (u32 *)&shmem[OFFSET_IN_LEN];
	return (unsigned long)(*len_ptr);
}

static char *get_input(volatile char *shmem)
{
	return (char *)&shmem[OFFSET_IN];
}

static char *get_output(volatile char *shmem)
{
	return (char *)&shmem[OFFSET_OUT];
}


/*
 * Calculate the SHA3 of the next item
 */
static void workload(char *input, unsigned long len, char *output)
{
	if (MGH_DEBUG_MODE)
		printk("MGH DEBUG: Input data length: %lu\n", len);

	// Account for space needed to tack on NULL character
	if (len > IN_SIZE - 1) {
		printk("MGH DEMO: Input data max length exceeded (%lu > %u)\n",
		       len, IN_SIZE - 1);
		return;
	}

	switch (WORKLOAD_MODE) {
	case SHA3:
		calculate_sha3(input, len, output);
		break;
	case CACHE_ANALYSIS:
		cache_analysis(input, len, output);
		break;
	default:
		printk("MGH: Error: Unknown workload mode\n");
		break;
	}

}

/*
 * MGH: By default, x86 inmates only map the first 2 MB of virtual memory, even
 * when more memory is configured. So map configured memory pages behind the
 * virtual memory address MGH_HEAP_BASE. Without this, there is nothing behind
 * the virtual memory address and you'll get a page fault.
 */
static void expand_memory(void)
{
	map_range((char *)MGH_HEAP_BASE, MGH_HEAP_SiZE_MB*MB, MAP_UNCACHED);

	// TODO: Implement when merged with d54cbbcc7c38 */
	// /* Set heap_pos to point to MGH_HEAP_BASE, instead of right after the
	//  * inmate's stack, so alloc() can allocated more than 1 MB. */
	// heap_pos = (char *)MGH_HEAP_BASE;
	// char *input_buffer = alloc(5*MB, PAGE_SIZE);
	// char *output_buffer = alloc(5*MB, PAGE_SIZE);
}

void inmate_main(void)
{
	volatile char *shmem;
	char *input_buffer;
	char *output_buffer;
	struct ivshmem_dev_data devs[MAX_NDEV];
	unsigned long workload_counter = 0;

	if (!hardware_setup())
		return;

	if (!device_setup(devs))
		return;

	/* Initialize better (?) exception reporting */
	if (MGH_DEBUG_MODE)
		excp_reporting_init();

	// Get the first PCI device, which should be the IVSHMEM device
	shmem = devs[0].shmem;

	if (MGH_DEBUG_MODE) {
		printk("MGH DEBUG: is_throttle_enabled addr: %p\n",
		       &is_throttle_enabled);
		printk("MGH DEBUG: str addr: %p\n", str);
		printk("MGH DEBUG: devs addr: %p\n", devs);
		printk("MGH DEBUG: workload_counter addr: %p\n",
		       &workload_counter);
		printk("MGH DEBUG: comm_region addr: %p\n", comm_region);
		printk("MGH DEBUG: shmem addr: %p\n", shmem);
	}

	/* Make sure MGH_HEAP address space is initialized */
	expand_memory();

	if (LOCAL_BUFFER) {
		input_buffer = (char *)MGH_HEAP_BASE;
		/* Separate the input and output by 5 MB */
		output_buffer = input_buffer + (5*MB);
		if (MGH_DEBUG_MODE) {
			printk("MGH DEBUG: input_buffer addr: %p\n",
				input_buffer);
			printk("MGH DEBUG: output_buffer addr: %p\n",
				output_buffer);
			input_buffer[0] = 'M';
			input_buffer[1] = 'G';
			input_buffer[2] = 'H';
			input_buffer[3] = '\0';
			printk("MGH DEBUG: input_buffer: %s\n", input_buffer);
		}
	}

	// Indicate to userspace that we are up and running
	shmem[OFFSET_SYNC] = 1;

	// Continuously wait on userspace for a workload
	while (1) {
		unsigned long start = 0;
		unsigned long end = 0;
		unsigned long input_len = 0;
		unsigned long copy_duration = 0;
		unsigned long workload_duration = 0;
		unsigned long total_duration = 0;
		unsigned long ns_per_byte = 0;

		char *input = NULL;
		char *output = NULL;

		// If about to shutdown, disable throttling first
		if (check_shutdown())
			return;

		switch (THROTTLE_MODE) {
		case ALTERNATING:
			check_alternating_throttle();
			break;
		case DEADLINE:
			check_deadline_throttle(ns_per_byte);
			break;
		default:
			printk("MGH: Error: unknown throttle mode\n");
			break;
		}

		// Check if the root placed a workload in shmem. If not, delay
		if (shmem[OFFSET_SYNC] != 2) {
			delay_us(POLL_DELAY_US);
			continue;
		}

		// Indicate that we are now working on sha3
		shmem[OFFSET_SYNC] = 3;
		input_len = get_input_length(shmem);
		input = get_input(shmem);
		output = get_output(shmem);

		/* Completely copy the input from shmem to a local buffer.
		 * We want to avoid constantly reading from shared memory during
		 * calculations, since that might slow things down. This may be
		 * why there was coupling between unrelated CPUs. */
		if (LOCAL_BUFFER) {
			start = tsc_read_ns();
			memcpy(input_buffer, input, input_len);
			/* Point workload input and output to local buffers */
			input = input_buffer;
			output = output_buffer;
			end = tsc_read_ns();
			copy_duration = end - start;
			if (MGH_DEBUG_MODE)
				printk("Input buffer copy took %lu ns\n",
				       copy_duration);
		}

		start = tsc_read_ns();
		workload(input, input_len, output);
		workload_counter++;
		end = tsc_read_ns();
		workload_duration = end - start;

		if (LOCAL_BUFFER) {
			start = tsc_read_ns();
			output = get_output(shmem);
			memcpy(output, output_buffer, MD_LENGTH);
			end = tsc_read_ns();
			copy_duration += (end - start);
			if (MGH_DEBUG_MODE)
				printk("Output buffer copy took %lu ns\n",
				       (end - start));
		}

		total_duration = copy_duration + workload_duration;
		ns_per_byte = total_duration / input_len;

		printk("MGHOUT:%ld|%ld,%ld(%ld+%ld),%lu\n", workload_counter,
		       input_len, total_duration, copy_duration,
		       workload_duration, ns_per_byte);

		// Indicate that we are done
		shmem[OFFSET_SYNC] = 1;

		// TODO: irq doesn't seem to work right now
		// // Tell the root cell that we are ready to calculate sha3
		// send_irq(&devs[0]);
	}
}


// References:
// https://wiki.sei.cmu.edu/confluence/display/c/STR34-C.+Cast+characters+to+unsigned+char+before+converting+to+larger+integer+sizes
//