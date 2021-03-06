/*
 * Michael Hinton
 *
 */

#include <inmate.h>


#define PRINT_INTERVAL_DEFAULT 100000000

// #define POLLUTE_CACHE_SIZE	(512 * 1024)

// #define APIC_TIMER_VECTOR	32

// static unsigned long expected_time;
// static unsigned long min = -1, max;

// static void irq_handler(void)
// {
// 	unsigned long delta;

// 	delta = tsc_read() - expected_time;
// 	if (delta < min)
// 		min = delta;
// 	if (delta > max)
// 		max = delta;
// 	printk("MGH: Timer fired, jitter: %6ld ns, min: %6ld ns, max: %6ld ns\n",
// 	       delta, min, max);

// 	expected_time += 100 * NS_PER_MSEC;
// 	apic_timer_set(expected_time - tsc_read());
// }

// static void init_apic(void)
// {
// 	unsigned long apic_freq_khz;

// 	int_init();
// 	int_set_handler(APIC_TIMER_VECTOR, irq_handler);

// 	apic_freq_khz = apic_timer_init(APIC_TIMER_VECTOR);
// 	printk("MGH: Calibrated APIC frequency: %lu kHz\n", apic_freq_khz);

// 	expected_time = tsc_read() + NS_PER_MSEC;
// 	apic_timer_set(NS_PER_MSEC);

// 	asm volatile("sti");
// }

// static void pollute_cache(char *mem)
// {
// 	unsigned long cpu_cache_line_size, ebx;
// 	unsigned long n;

// 	asm volatile("cpuid" : "=b" (ebx) : "a" (1)
// 		: "rcx", "rdx", "memory");
// 	cpu_cache_line_size = (ebx & 0xff00) >> 5;

// 	for (n = 0; n < POLLUTE_CACHE_SIZE; n += cpu_cache_line_size)
// 		mem[n] ^= 0xAA;
// }

void inmate_main(void)
{
	bool terminate = false;
	int i = 0;
	int count = 1;
	bool cache_pollution;
	bool verbose;
	long long interval;

	// bool allow_terminate = false;
	// unsigned long tsc_freq;
	// char *mem;

	comm_region->cell_state = JAILHOUSE_CELL_RUNNING_LOCKED;

	printk("**************************\n");
	printk("MGH: Cell stats\n");
	printk("**************************\n");
	printk("Input Command-line string: %s\n", cmdline);
	printk("CPU ID: %u\n", cpu_id());

	cache_pollution = cmdline_parse_bool("pollute-cache", false);
	verbose = cmdline_parse_bool("verbose", false);
	interval = cmdline_parse_int("interval", PRINT_INTERVAL_DEFAULT);

	if (cache_pollution) {
	// 	mem = alloc(PAGE_SIZE, PAGE_SIZE);
		printk("Cache pollution enabled (doesn't do anything)\n");
	}

	if (verbose) {
		printk("Verbose mode enabled\n");
	}
	printk("Print interval: %lld (0x%llx)\n", interval, interval);
	printk("**************************\n");


	// printk("MGH: Before tsc_init");
	// tsc_freq = tsc_init();
	// printk("Calibrated TSC frequency: %lu.%03u kHz\n", tsc_freq / 1000,
	//        tsc_freq % 1000);

	// printk("MGH: Before init_apic");
	// init_apic();

	printk("MGH: Before while loop\n");
	while (!terminate) {
		if (verbose && i > interval)
			printk("MGH:(%d) Start of loop\n", count);
		/*
		 * Halt the CPU until the next external interrupt is fired.
		 * The HLT instruction is executed by the operating system when
		 * there is no immediate work to be done, and the system enters
		 * its idle state.
		 */
		// TODO: If no interrupt is configured, then infinite stall!
		// asm volatile("hlt");
		// if (i > interval)
		// 	printk("MGH: After hlt: some interrupt received!\n");

		// if (cache_pollution)
		// 	pollute_cache(mem);

		switch (comm_region->msg_to_cell) {
		case JAILHOUSE_MSG_SHUTDOWN_REQUEST:
			// if (!allow_terminate) {
			// 	printk("Rejecting first shutdown request - "
			// 	       "try again!\n");
			// 	jailhouse_send_reply_from_cell(comm_region,
			// 			JAILHOUSE_MSG_REQUEST_DENIED);
			// 	allow_terminate = true;
			// } else
			printk("MGH:(%d:i=%d) "
			       "Shutting down bazooka-demo cell\n", count, i);
			terminate = true;
			break;
		default:
			if (verbose && i > interval)
				printk("MGH:(%d) Sending reply\n", count);
			jailhouse_send_reply_from_cell(comm_region,
					JAILHOUSE_MSG_UNKNOWN);
			break;
		}
		if (i > interval) {
			i = 0;
			count++;
		}
		else
			i++;
	}

	printk("MGH: Stopped Bazooka cell demo\n");
	comm_region->cell_state = JAILHOUSE_CELL_SHUT_DOWN;
}
