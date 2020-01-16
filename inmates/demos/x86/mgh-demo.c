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

/*
 * This is the frequency the TSC is guaranteed to tick at, as well as the CPU's
 * advertised frequency.
 * From Wiki: "the TSC ticks at the processor's nominal frequency, regardless of
 * the actual CPU clock frequency due to turbo or power saving states."
 */
static unsigned long tsc_freq = 0;
static u64 max_freq = 0;

/* See Intel SDM Vol. 4: Model-Specific Registers */
#define MSR_IA32_MPERF		0xe7
#define MSR_IA32_APERF		0xe8
#define MSR_PLATFORM_INFO	0xce

#define EXPECTED_CPU_CACHE_LINE_SIZE 64
static unsigned long cpu_cache_line_size = 64;

/* NOTE: The stack size is the same size as a page (4 kb) */

static char str[32] = "Hello From MGH      ";

/*
 * The number of nanoseconds before toggling the throttle mechanism on or off.
 * Currently set to 15 seconds = 15 * 10^9
 */
#define ALTERNATING_PERIOD 15000000000
/* Delay 1 ms between each poll of the workload input */
#define POLL_DELAY_US 1000
typedef enum {
	ALTERNATING = 0,
	DEADLINE = 1,
	ITERATION = 2,
	DISABLED = 3,
} throttle_mode_t;

typedef enum {
	CLOCK = 0,
	SPIN = 1,
	PAUSE = 2, // Not yet implemented
} throttle_t;

typedef enum {
	SHA3 = 0,
	CACHE_ANALYSIS = 1,
	COUNT_SET_BITS = 2,
	RANDOM_ACCESS = 3,
	INMATE_DEBUG = 4,
} workload_t;

typedef enum {
	SLOW = 0, // right shift each bit of a byte into mask 0x1
	FASTER = 1, // AND each bit of a byte with separate dedicated mask
	FASTEST = 2, // Look-up table
} csb_mode_t;

#define DEFAULT_DEBUG_MODE		false
#define DEFAULT_LOCAL_BUFFER		false
#define DEFAULT_THROTTLE_MODE		ALTERNATING
#define DEFAULT_THROTTLE_MECHANISM	SPIN
#define DEFAULT_WORKLOAD_MODE		COUNT_SET_BITS
#define DEFAULT_COUNT_SET_BITS_MODE	FASTEST
#define DEFAULT_THROTTLE_ITERATIONS	5

#define CACHE_ANALYSIS_SIZE_MB 20
#define CACHE_ANALYSIS_USE_INPUT false

/* Change to false to disable print statements during regular operation. */
static bool MGH_DEBUG_MODE = DEFAULT_DEBUG_MODE;
static csb_mode_t COUNT_SET_BITS_MODE = DEFAULT_COUNT_SET_BITS_MODE;
static bool CACHE_ANALYSIS_POLLUTE_CACHE = false;

// # of bytes for the sha3-512 message digest output
#define MD_LENGTH 	64
#define MB		(1 << 20) // 2^20 = 1048576 = 1 MB

// Map out shared memory (define the sizes)
#define SYNC_SIZE 	1
#define RESERVED_SIZE	3
#define LEN_SIZE	4
// The entire IVSHMEM region is 40 MB. Data gets the rest of the space.
#define DATA_SIZE	((40 * MB) - (SYNC_SIZE + RESERVED_SIZE + LEN_SIZE))

#define MGH_HEAP_BASE	0x00200000
#define MGH_HEAP_SIZE	(35 * MB)

#define OFFSET_SYNC 	0
#define OFFSET_RESERVED	(OFFSET_SYNC + SYNC_SIZE)
#define OFFSET_LEN	(OFFSET_RESERVED + RESERVED_SIZE)
#define OFFSET_DATA	(OFFSET_LEN + LEN_SIZE)

// NOTE: The "heap" is really just another stack.
extern unsigned long heap_pos;

static void *alloc_heap(unsigned long size)
{
	return alloc(size, PAGE_SIZE);
}

/*
 * Effectively "free" all memory allocated via alloc_heap() by resetting the
 * heap position.
 */
static void free_heap_all(void)
{
	heap_pos = MGH_HEAP_BASE;
}

static u64 query_max_freq_ratio(void)
{
	u64 plat_info = read_msr(MSR_PLATFORM_INFO);
	u64 max_ratio = (plat_info & 0xff00) >> 8;
	return max_ratio;
}

/*
 * Return the Maximum Non-Turbo Frequency in Hz
 *
 * “Maximum Non-Turbo Ratio (R/O) This is the ratio of the frequency that
 * invariant TSC runs at. Frequency = ratio * 100 MHz.” See Intel SDM Vol. 4
 * Section 2.17 and tables 2-20, 2-25, and 2-29.
 *
 * Get bits 8-15 of MSR_PLATFORM_INFO
 */
static u64 query_max_freq(void)
{
	u64 max_ratio = query_max_freq_ratio();
	u64 max_freq = max_ratio * 100000000;
	printk("MGH: Maximum Non-Turbo Ratio: %llu\n", max_ratio);
	printk("MGH: Maximum Non-Turbo Frequency: %llu\n", max_freq);
	return max_freq;
}

static void clear_freq_counters(void)
{
	// TODO: How to avoid preemption-timer interrupt between the following
	// msr instructions? Needs to be successive, or readings will be off.

	// Reset the frequency counters
	write_msr(MSR_IA32_MPERF, 0);
	write_msr(MSR_IA32_APERF, 0);
}
/*
 * Calculate the CPU's current frequency. Must call hardware_init() beforehand!
 *
 * See the Intel SDM, Vol 3B, Section 14.2
 *
 * We should probably query the frequency multiple times to get an accurate
 * reading (in case both counters are 0 or really low, etc.)
 * max frequency is the same as tsc_freq. Right?
 * See https://stackoverflow.com/questions/65095/assembly-cpu-frequency-measuring-algorithm
 */
static u64 query_freq(void)
{
	static u64 counter = 0;
	u64 freq;

	if (tsc_freq == 0) {
		printk("MGH: ERROR: tsc_freq is uninitialized\n");
		return 0;
	}

	if (max_freq == 0) {
		printk("MGH: ERROR: max_freq is uninitialized\n");
		return 0;
	}

	// TODO: How to avoid preemption-timer interrupt between the following
	// msr instructions? Needs to be successive, or readings will be off.
	u64 mperf = read_msr(MSR_IA32_MPERF);
	u64 aperf = read_msr(MSR_IA32_APERF);

	// Reset freq counters
	clear_freq_counters();

	// NOTE: Beware of order of operations so integer division does not
	// prematurely floor the ratio to 0!
	// freq = (tsc_freq * aperf) / mperf;
	freq = (max_freq * aperf) / mperf;

	if (MGH_DEBUG_MODE)
		printk("MGHFREQ:%llu,%llu,%llu,%llu,%llu\n",
		       counter, freq, max_freq, aperf, mperf);

	if (MGH_DEBUG_MODE && freq < max_freq) {
		printk("MGH: WARNING: %6llu: Actual CPU frequency less than max!\n",
		       counter);
	}

	counter++;

	return freq;
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
		printk("MGH: ERROR: device is not MSI-X capable\n");
		return;
	}

	d->shmemsz = pci_cfg_read64(d->bdf, IVSHMEM_CFG_SHMEM_SZ);
	d->shmem = (void *)pci_cfg_read64(d->bdf, IVSHMEM_CFG_SHMEM_PTR);

	if (MGH_DEBUG_MODE)
		printk("MGH: shmem is at %p\n", d->shmem);

	d->registers = (u32 *)((u64)(d->shmem + d->shmemsz + PAGE_SIZE - 1)
		& PAGE_MASK);
	pci_cfg_write64(d->bdf, PCI_CFG_BAR, (u64)d->registers);

	if (MGH_DEBUG_MODE)
		printk("MGH: bar0 is at %p\n", d->registers);

	d->bar2sz = get_bar_sz(d->bdf, 2);
	d->msix_table = (u32 *)((u64)d->registers + PAGE_SIZE);
	pci_cfg_write64(d->bdf, PCI_CFG_BAR + 16, (u64)d->msix_table);

	if (MGH_DEBUG_MODE)
		printk("MGH: bar2 is at %p\n", d->msix_table);

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
// 	printk("MGH: %02x:%02x.%x sending IRQ; Shared: %s\n",
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
		printk("MGH: WARNING: Could not convert '%d' to hex\n", in);
	}
	return out;
}

static char _get_hex_from_upper_nibble(char in)
{
	return _get_hex_from_lower_nibble(in >> 4);
}

static void init_cache_line_size(void)
{
	unsigned long ebx;

	asm volatile("cpuid" : "=b" (ebx) : "a" (1)
		: "rcx", "rdx", "memory");
	cpu_cache_line_size = (ebx & 0xff00) >> 5;

	if (MGH_DEBUG_MODE)
		printk("MGH: cache_line_size = %lu\n",
		       cpu_cache_line_size);

	/* The cache line size should always be 64 B on Intel x86-64 */
	if (cpu_cache_line_size != EXPECTED_CPU_CACHE_LINE_SIZE)
		printk("MGH: ERROR: Actual cache line size is %lu B\n",
		       cpu_cache_line_size);
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
	for (unsigned long n = 0; n < size; n += cpu_cache_line_size) {
		mem[n] ^= 0xAA;
	}
}

/* Calculate sha3 of input and store in output */
static void calculate_sha3(char *input, unsigned long input_len, char *output,
			   unsigned long *output_len)
{
	*output_len = MD_LENGTH;
	if (!sha3_mgh(input, (int)input_len, output, MD_LENGTH)) {
		printk("ERROR: SHA3 failed!\n");
		return;
	}
}

// TODO: Actually make this useful?
static void cache_analysis(char *input, unsigned long input_len, char *output,
			   unsigned long *output_len)
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

	// Allocate 20 MB of memory to play with
	buffer = (unsigned char *)alloc_heap(buffer_size);

	// Force entire buffer into cache
	if (CACHE_ANALYSIS_POLLUTE_CACHE)
		pollute_cache((char *)buffer, buffer_size);

	// n stores
	for (unsigned long i = 0; i < buffer_size; ++i) {
		buffer[i] = i;
	}

	// n stores
	for (unsigned long i = 0; i < buffer_size-1; ++i) {
		buffer[i] = buffer[i] + buffer[i+1];
	}
	buffer[buffer_size-1] = (2 * buffer[buffer_size-1]) + 1;

	free_heap_all();
}

static void count_set_bits(char *input, unsigned long input_len, char *output,
			   unsigned long *output_len)
{
	int result = 0;
	int *output_int = (int *)output;

	result = count_set_bits_mgh((unsigned char *)input, (int)input_len,
				    COUNT_SET_BITS_MODE);

	// Copy int to output (assume little-endian order)
	*output_int = result;

	// Store # of bytes of result
	*output_len = sizeof(result);
}

static void random_access(char *input, unsigned long input_len, char *output,
			  unsigned long *output_len)
{
	u64 result = 0;
	u64 *output_int = (u64 *)output;

	result = random_access_mgh((unsigned char *)input, (int)input_len);

	// Copy int to output (assume little-endian order)
	*output_int = result;

	// Store # of bytes of result
	*output_len = sizeof(result);
}

static void irq_handler(void)
{
	static int irq_counter = 0;
	printk("MGH: got interrupt ... %d\n", irq_counter++);
}

static void command_line_params(bool *local_buffer,
				throttle_mode_t *throttle_mode,
				workload_t *workload_mode,
				throttle_t *throttle_mechanism,
				int *throttle_iterations)
{
	*local_buffer = cmdline_parse_bool("lb",
					   DEFAULT_LOCAL_BUFFER);
	*throttle_mode = cmdline_parse_int("tmode",
					   DEFAULT_THROTTLE_MODE);
	*throttle_mechanism = cmdline_parse_int("tmech",
					   DEFAULT_THROTTLE_MECHANISM);
	*workload_mode = cmdline_parse_int("wm",
					   DEFAULT_WORKLOAD_MODE);
	MGH_DEBUG_MODE = cmdline_parse_bool("debug", DEFAULT_DEBUG_MODE);

	printk("MGH: local_buffer=%d\n", *local_buffer);
	printk("MGH: MGH_DEBUG_MODE=%d\n", MGH_DEBUG_MODE);
	switch (*throttle_mode) {
	case ALTERNATING:
		printk("MGH: throttle_mode=ALTERNATING\n");
		break;
	case DEADLINE:
		printk("MGH: throttle_mode=DEADLINE\n");
		break;
	case ITERATION:
		*throttle_iterations = cmdline_parse_int("throttleiter",
						DEFAULT_THROTTLE_ITERATIONS);
		printk("MGH: throttle_mode=ITERATION\n");
		printk("MGH: throttle_iterations=%d\n", *throttle_iterations);
		break;
	case DISABLED:
		printk("MGH: throttle_mode=DISABLED\n");
		break;
	default:
		printk("MGH: throttle_mode=?\n");
		break;
	}

	switch (*throttle_mechanism) {
	case CLOCK:
		printk("MGH: throttle_mechanism=CLOCK\n");
		break;
	case SPIN:
		printk("MGH: throttle_mechanism=SPIN\n");
		break;
	case PAUSE:
		printk("MGH: throttle_mechanism=PAUSE\n");
		break;
	default:
		printk("MGH: throttle_mechanism=?\n");
		break;
	}

	switch (*workload_mode) {
	case SHA3:
		printk("MGH: workload_mode=SHA3\n");
		break;
	case CACHE_ANALYSIS:
		printk("MGH: workload_mode=CACHE_ANALYSIS\n");
		break;
	case COUNT_SET_BITS:
		printk("MGH: workload_mode=COUNT_SET_BITS\n");
		break;
	case RANDOM_ACCESS:
		printk("MGH: workload_mode=RANDOM_ACCESS\n");
		break;
	case INMATE_DEBUG:
		printk("MGH: workload_mode=INMATE_DEBUG\n");
		break;
	default:
		printk("MGH: workload_mode=?\n");
		break;
	}

	if (*workload_mode == COUNT_SET_BITS) {
		COUNT_SET_BITS_MODE = cmdline_parse_int("csbm",
			DEFAULT_COUNT_SET_BITS_MODE);
		switch (COUNT_SET_BITS_MODE) {
		case SLOW:
			printk("MGH: COUNT_SET_BITS_MODE=SLOW\n");
			break;
		case FASTER:
			printk("MGH: COUNT_SET_BITS_MODE=FASTER\n");
			break;
		case FASTEST:
			printk("MGH: COUNT_SET_BITS_MODE=FASTEST\n");
			break;
		default:
			printk("MGH: COUNT_SET_BITS_MODE=?\n");
			break;
		}
	}

	if (*workload_mode == CACHE_ANALYSIS) {
		CACHE_ANALYSIS_POLLUTE_CACHE = cmdline_parse_bool("pc",
						CACHE_ANALYSIS_POLLUTE_CACHE);
		printk("MGH: CACHE_ANALYSIS_POLLUTE_CACHE=%d\n",
		       CACHE_ANALYSIS_POLLUTE_CACHE);
	}
}
/*
 * Returns true if hardware setup was successful.
 */
static bool hardware_setup(void)
{
	// Set up the Time Stamp Counter (TSC)
	tsc_freq = tsc_init();
	if (tsc_freq == 0) {
		printk("MGH: TSC was not initialized successfully (frequency == 0).\n");
		return false;
	}

	if (MGH_DEBUG_MODE)
		printk("MGH: TSC frequency is %lu Hz.\n", tsc_freq);

	// Set the cache line size
	init_cache_line_size();

	// Clear the frequency counters to start with clean slate
	clear_freq_counters();

	// Architecture-dependent!
	// Get the max turbo frequency from Recent Intel architectures
	max_freq = query_max_freq();

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
			printk("MGH: Found %04x:%04x at %02x:%02x.%x\n",
			       pci_read_config(bdf, PCI_CFG_VENDOR_ID, 2),
			       pci_read_config(bdf, PCI_CFG_DEVICE_ID, 2),
			       bdf >> 8, (bdf >> 3) & 0x1f, bdf & 0x3);

		class_rev = pci_read_config(bdf, 0x8, 4);
		if (class_rev != (PCI_DEV_CLASS_OTHER << 24 |
				  JAILHOUSE_SHMEM_PROTO_UNDEFINED << 8)) {
			printk("MGH: class/revision %08x, not supported "
			       "skipping device\n", class_rev);
			bdf++;
			continue;
		}
		dev = &devs[ndevices];
		dev->bdf = bdf;
		map_shmem_and_bars(dev);
		if (MGH_DEBUG_MODE)
			printk("MGH: mapped the bars got position %d\n",
			       get_ivpos(dev));

		memcpy(dev->shmem, str, 32);

		int_set_handler(IRQ_VECTOR + ndevices, irq_handler);
		pci_msix_set_vector(bdf, IRQ_VECTOR + ndevices, 0);
		bdf++;
		ndevices++;
	}

	if (ndevices <= 0) {
		printk("MGH: No PCI devices found! Nothing to do\n");
		return false;
	}

	if (ndevices > 1) {
		printk("MGH: More than one PCI device found!\n");
	}

	return true;
}

static void enable_throttle(throttle_t throttle_mechanism)
{
	/* Communicate to the hypervisor via the Jailhouse
	 * communication region of this cell */
	switch (throttle_mechanism) {
	case PAUSE:
		printk("MGH: ERROR: PAUSE throttle mechanism not yet implemented. Defaulting to SPIN.\n");
		/* Fall through */
	case SPIN:
		jailhouse_send_msg_to_cell(comm_region,
						JAILHOUSE_MSG_THROTTLE_SPIN);
		printk("MGH: Sent enable throttle request (spin)\n");
		break;
	case CLOCK:
		jailhouse_send_msg_to_cell(comm_region,
						JAILHOUSE_MSG_THROTTLE_CLOCK);
		printk("MGH: Sent enable throttle request (clock)\n");
		break;
	default:
		printk("MGH: ERROR: Invalid throttle mechanism requested\n");
		break;
	}
}

static void disable_throttle(void)
{
	jailhouse_send_msg_to_cell(comm_region,
			JAILHOUSE_MSG_STOP_THROTTLING);
	printk("MGH: Sent disable throttle request\n");
}

/*
 * Toggle the throttling mechanism on or off if it has been ALTERNATING_PERIOD
 * nanoseconds since the last throttle toggle. Run this check before every
 * workload. Use this throttle mode to measure the impact of throttling with a
 * sustained root userspace workload.
 *
 * If the throttle is enabled, returns true. If it is disabled, returns false.
 */
static bool check_alternating_throttle(throttle_t throttle_mechanism)
{
	static unsigned long start = 0;
	static bool throttled = false;
	unsigned long current, duration;

	/* If 0, it means we haven't initialized the timer yet */
	if (start == 0) {
		start = tsc_read_ns();
		return throttled;
	}

	current = tsc_read_ns();
	if (current < start) {
		printk("MGH: ERROR: TSC underflow (current=%lu, start=%lu)\n",
		       current, start);
		return throttled;
	}

	duration = current - start;
	if (duration < ALTERNATING_PERIOD)
		return throttled;

	/* Toggle the throttling mechanism on or off */
	if (throttled) {
		disable_throttle();
		throttled = false;
	} else {
		enable_throttle(throttle_mechanism);
		throttled = true;
	}

	/* Reset timer */
	start = tsc_read_ns();
	return throttled;
}

/*
 * Toggle the throttling mechanism on or off if it has been ALTERNATING_PERIOD
 * nanoseconds since the last throttle toggle. Run this check before every
 * workload. Use this throttle mode to measure the impact of throttling with a
 * sustained root userspace workload.
 *
 * If the throttle is enabled, returns true. If it is disabled, returns false.
 */
static bool check_iteration_throttle(throttle_t throttle_mechanism,
				     unsigned long workload_counter,
				     int throttle_iterations)
{
	static bool throttled = false;
	static bool toggled = false;

	/* Do nothing on the first workload run */
	if (workload_counter == 0)
		return throttled;

	/* Toggle throttle once every throttle_iterations */
	if (workload_counter % throttle_iterations == 0) {
		if (!toggled) {
			/* Toggle the throttling mechanism on or off */
			if (throttled) {
				disable_throttle();
				throttled = false;
			} else {
				enable_throttle(throttle_mechanism);
				throttled = true;
			}

			/* Don't keep toggling */
			toggled = true;
		}
	} else {
		/* Reset toggle tracker */
		if (toggled)
			toggled = false;
	}
	return throttled;
}

/*
 * Turn on throttling if deadlines were not met during the last workload. Run
 * this check before every workload.
 *
 * If the throttle is enabled, returns true. If it is disabled, returns false.
 */
static bool check_deadline_throttle(unsigned long ns_per_byte,
				    throttle_t throttle_mechanism)
{
	static bool throttled = false;
	// static int now = 0;
	// static int previous = 0;
	static int MAX_NS_PER_BYTE = 120;
	bool meeting_deadlines = false;

	/* If we haven't run yet, we don't know if we need to throttle or not */
	if (ns_per_byte == 0)
		return throttled;

	if (ns_per_byte > MAX_NS_PER_BYTE) {
		// Throttle!
		meeting_deadlines = false;
	} else {
		meeting_deadlines = true;
	}

	// TODO: Add some smoothing if needed, so inmate isn't thrashing back
	// and forth between throttle and no throttle

	// If we are meeting deadlines, and we are throttling, stop throttling
	if (meeting_deadlines && throttled) {
		disable_throttle();
		throttled = false;
	} else if (!meeting_deadlines && !throttled) {
		enable_throttle(throttle_mechanism);
		throttled = true;
	}
	// TODO: Have the root cell automatically throttle itself,
	// rather than wait for the root to request it (is there shared
	// read-only memory it could monitor?)
	return throttled;
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
		printk("MGH: Allowing inmate to be shut down\n");
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

static unsigned long get_data_length(volatile char *shmem)
{
	u32 *len_ptr = (u32 *)&shmem[OFFSET_LEN];
	return (unsigned long)(*len_ptr);
}

static void set_data_length(volatile char *shmem, unsigned long len)
{
	u32 *len_ptr = (u32 *)&shmem[OFFSET_LEN];
	*len_ptr = (u32)(len);
}

static char *get_inout(volatile char *shmem)
{
	return (char *)&shmem[OFFSET_DATA];
}

/*
 * Do a workload on len bytes from input, and store result in output_len bytes
 * of output while also setting output_len.
 */
static void workload(char *input, unsigned long len, char *output,
		     unsigned long *output_len, workload_t workload_mode)
{
	// Account for space needed to tack on NULL character
	if (len > DATA_SIZE) {
		printk("MGH: ERROR: Input exceeded max length (%lu > %u)\n",
		       len, DATA_SIZE);
		return;
	}

	switch (workload_mode) {
	case SHA3:
		calculate_sha3(input, len, output, output_len);
		break;
	case CACHE_ANALYSIS:
		cache_analysis(input, len, output, output_len);
		break;
	case COUNT_SET_BITS:
		count_set_bits(input, len, output, output_len);
		break;
	case RANDOM_ACCESS:
		random_access(input, len, output, output_len);
		break;
	default:
		printk("MGH: ERROR: Unknown workload mode\n");
		break;
	}
}

/* Debug inmate code - use to debug some mechanics in the inmate */
static void inmate_debug(void)
{
	unsigned long start_tsc = 0;
	unsigned long end_tsc = 0;
	unsigned long cycles = 0;
	unsigned long start = 0;
	unsigned long end = 0;
	unsigned long delay_start_us = 1162000;
	unsigned long delay_step_us = 100000;
	unsigned long delay_max_us = 3000000;
	unsigned long delay_count = delay_start_us;
	unsigned long duration = 0;
	unsigned long prev_duration = 0;

	while (1) {
		// Check for shutdown request
		if (check_shutdown())
			return;

		start = tsc_read_ns();
		start_tsc = rdtsc();
		delay_us(delay_count);
		end_tsc = rdtsc();
		end = tsc_read_ns();

		delay_count += delay_step_us;

		duration = end - start;
		cycles = end_tsc - start_tsc;

		printk("MGH: delay_count (us): %lu start (ns): %lu; end (ns): %lu; duration (ns):%lu\n",
		       delay_count, start, end, duration);
		printk("MGH: delay_count (us): %lu start (tsc): %lu; end (tsc): %lu; cycles (tsc):%lu\n",
		       delay_count, start_tsc, end_tsc, cycles);

		if (duration < prev_duration) {
			printk("MGH: Duration is shorter than last run!\n");
		}

		if (end < start) {
			printk("MGH: Timer wrap-around!\n");
		}

		if (end_tsc < start_tsc) {
			printk("MGH: TSC wrap-around!\n");
		}

		// Quit after a certain amount of seconds
		if (delay_count > delay_max_us) {
			printk("MGH: Finish\n");
			break;
		}
		prev_duration = duration;
	}

	while (1) {
		// Wait for shutdown request
		if (check_shutdown())
			return;
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
	map_range((char *)MGH_HEAP_BASE, MGH_HEAP_SIZE, MAP_UNCACHED);

	/* Set heap_pos to point to MGH_HEAP_BASE, instead of right after the
	 * inmate's stack, so alloc() can allocate more than 1 MB. */
	heap_pos = MGH_HEAP_BASE;
}

static void print_hex(char *buffer, unsigned long buffer_len)
{
	for (int i = 0; i < buffer_len; ++i) {
		char upper = _get_hex_from_upper_nibble(buffer[i]);
		char lower = _get_hex_from_lower_nibble(buffer[i]);
		printk("%c", upper);
		printk("%c", lower);
	}
	printk("\n");
}

void inmate_main(void)
{
	volatile char *shmem;
	char *buffer;
	struct ivshmem_dev_data devs[MAX_NDEV];
	unsigned long workload_counter = 0;
	throttle_mode_t throttle_mode = DEFAULT_THROTTLE_MODE;
	throttle_t throttle_mechanism = DEFAULT_THROTTLE_MECHANISM;
	workload_t workload_mode = DEFAULT_WORKLOAD_MODE;
	int throttle_iterations = DEFAULT_THROTTLE_ITERATIONS;
	/*
	 * If true, then the input data will be copied into a local buffer
	 * before passing to the workload. Then, a local output buffer will also
	 * be passed into the workload. This is important, since the input
	 * originates in a shared memory region which could introduce
	 * interference from other CPUs if accessed throughout the workload.
	 * NOTE: For now, keep disabled, because it hurts performance rather
	 * than helps.
	 */
	bool local_buffer = DEFAULT_LOCAL_BUFFER;

	/* Process custom command line parameters for inmate */
	command_line_params(&local_buffer, &throttle_mode, &workload_mode,
			    &throttle_mechanism, &throttle_iterations);

	if (!hardware_setup())
		return;

	if (!device_setup(devs))
		return;

	if (workload_mode == INMATE_DEBUG) {
		inmate_debug();
		return;
	}

	// Print out column headers for the subsequent frequency data
	if (MGH_DEBUG_MODE)
		printk("MGHFREQ:counter,freq,max_freq,aperf,mperf\n");

	(void) query_freq();

	/* Initialize better (?) exception reporting */
	// excp_reporting_init();

	// Get the first PCI device, which should be the IVSHMEM device
	shmem = devs[0].shmem;

	/* Make sure MGH_HEAP address space is initialized */
	expand_memory();

	if (local_buffer) {
		buffer = (char *)MGH_HEAP_BASE;
	}

	// Indicate to userspace that we are up and running
	shmem[OFFSET_SYNC] = 1;

	(void) query_freq();

	// Print out column headers for the subsequent data
	printk("MGHOUT:is_throttled,workload_counter,input_len,workload_cycles,avg_freq\n");

	// Continuously wait on userspace for a workload
	while (1) {
		unsigned long start_tsc = 0;
		unsigned long end_tsc = 0;
		unsigned long workload_cycles = 0;
		unsigned long start = 0;
		unsigned long end = 0;
		unsigned long input_len = 0;
		unsigned long output_len = 0;
		unsigned long copy_duration = 0;
		unsigned long workload_duration = 0;
		unsigned long total_duration = 0;
		unsigned long ns_per_byte = 0;
		u64 freq1, freq2, freq3, freq4, avg_freq;
		bool is_throttled = false;

		char *inout = NULL;

		// If about to shutdown, disable throttling first
		if (check_shutdown())
			return;

		switch (throttle_mode) {
		case ALTERNATING:
			is_throttled = check_alternating_throttle(throttle_mechanism);
			break;
		case DEADLINE:
			is_throttled = check_deadline_throttle(ns_per_byte,
							       throttle_mechanism);
			break;
		case ITERATION:
			is_throttled = check_iteration_throttle(throttle_mechanism,
								workload_counter,
								throttle_iterations);
			break;
		case DISABLED:
			is_throttled = false;
			break;
		default:
			is_throttled = false;
			printk("MGH: ERROR: unknown throttle mode\n");
			break;
		}

		// Check if the root placed a workload in shmem. If not, delay
		if (shmem[OFFSET_SYNC] != 2) {
			delay_us(POLL_DELAY_US);
			continue;
		}

		// Indicate that we are now working on sha3
		shmem[OFFSET_SYNC] = 3;
		input_len = get_data_length(shmem);

		if (MGH_DEBUG_MODE)
			printk("MGH DEBUG: Input data length: %lu\n",
			       input_len);

		if (input_len == 0) {
			printk("MGH: ERROR: Inmate input is 0. Exiting...\n");
			return;
		}

		inout = get_inout(shmem);

		freq1 = query_freq();

		/* Don't exceed heap when copying input into local buffer */
		if (local_buffer && input_len > MGH_HEAP_SIZE) {
			printk("MGH: WARNING: Inmate input > %d B (heap size), so can't copy input into local buffer.\n", MGH_HEAP_SIZE);
			local_buffer = false;
		}

		/* Completely copy the input from shmem to a local buffer.
		 * We want to avoid constantly reading from shared memory during
		 * calculations, since that might slow things down. */
		if (local_buffer) {
			start = tsc_read_ns();
			memcpy(buffer, inout, input_len);
			/* Point workload input and output to local buffers */
			inout = buffer;
			end = tsc_read_ns();
			copy_duration = end - start;
			if (MGH_DEBUG_MODE)
				printk("Input buffer copy took %lu ns\n",
				       copy_duration);
		}

		freq2 = query_freq();

		start = tsc_read_ns();
		start_tsc = rdtsc();
		workload(inout, input_len, inout, &output_len, workload_mode);
		end_tsc = rdtsc();
		end = tsc_read_ns();

		if (MGH_DEBUG_MODE) {
			printk("workload output: 0x");
			print_hex(inout, output_len);
		}

		set_data_length(shmem, output_len);

		if (start > end)
			printk("MGH: Warning: Timer overflow during workload (start=%lu > end=%lu)\n",
			       start, end);

		if (start_tsc > end_tsc)
			printk("MGH: ERROR: start_tsc=%lu > end_tsc=%lu!\n",
			       start_tsc, end_tsc);

		workload_cycles = end_tsc - start_tsc;
		workload_duration = end - start;

		freq3 = query_freq();

		if (local_buffer) {
			start = tsc_read_ns();
			inout = get_inout(shmem);
			memcpy(inout, buffer, MD_LENGTH);
			end = tsc_read_ns();
			copy_duration += (end - start);
			if (MGH_DEBUG_MODE)
				printk("Output buffer copy took %lu ns\n",
				       (end - start));
		}

		freq4 = query_freq();
		avg_freq = (freq1 + freq2 + freq3 + freq4) / 4;

		total_duration = copy_duration + workload_duration;
		ns_per_byte = total_duration / input_len;

		printk("MGHOUT:%d,%lu,%lu,%lu,%llu\n", is_throttled,
		       workload_counter, input_len, workload_cycles, avg_freq);

		workload_counter++;

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