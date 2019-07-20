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


static bool is_throttle_enabled = false;
static char str[32] = "Hello From MGH      ";

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


struct ivshmem_dev_data {
	u16 bdf;
	u32 *registers;
	void *shmem;
	u32 *msix_table;
	u64 shmemsz;
	u64 bar2sz;
};

static struct ivshmem_dev_data devs[MAX_NDEV];

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

	printk("MGH DEMO: shmem is at %p\n", d->shmem);
	d->registers = (u32 *)((u64)(d->shmem + d->shmemsz + PAGE_SIZE - 1)
		& PAGE_MASK);
	pci_cfg_write64(d->bdf, PCI_CFG_BAR, (u64)d->registers);
	printk("MGH DEMO: bar0 is at %p\n", d->registers);
	d->bar2sz = get_bar_sz(d->bdf, 2);
	d->msix_table = (u32 *)((u64)d->registers + PAGE_SIZE);
	pci_cfg_write64(d->bdf, PCI_CFG_BAR + 16, (u64)d->msix_table);
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

static void calculate_sha3(char *input, int input_length, char *output)
{
	int i;

	// A null character should have been added right after end of input, so
	// that it can print properly.

	if (!sha3_mgh(input, input_length, output, MD_LENGTH)) {
		printk("sha3 failed for string `%s`\n", input);
		return;
	}
	printk("sha3 of '%s':\n", input);
	for (i = 0; i < MD_LENGTH; ++i) {
		char upper = _get_hex_from_upper_nibble(output[i]);
		char lower = _get_hex_from_lower_nibble(output[i]);
		printk("%c", upper);
		printk("%c", lower);
	}
	printk("\n");
}

static void irq_handler(void)
{
	static int irq_counter = 0;
	printk("MGH DEMO: got interrupt ... %d\n", irq_counter++);
}

/*
 * Returns true if there is an IVSHMEM PCI device that we can use
 */
static bool device_setup(void)
{
	int bdf = 0;
	unsigned int class_rev;
	struct ivshmem_dev_data *dev;
	int ndevices = 0;

	// Set up interrupts
	int_init();

	while ((ndevices < MAX_NDEV) &&
	       (-1 != (bdf = pci_find_device(VENDORID, DEVICEID, bdf)))) {
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
	// printk("MGH DEMO: (%d) Sent enable throttle request\n",
	//        count);
}

static void disable_throttle(void)
{
	jailhouse_send_msg_to_cell(comm_region,
			JAILHOUSE_MSG_STOP_THROTTLING);
	// printk("MGH DEMO: (%d) Sent disable throttle request\n",
	//        count);
}

/*
 * Request that the root throttle itself when deadlines
 * are getting close to being missed
 */
static void check_deadlines(void)
{
	static int now = 0;
	static int previous = 0;
	static int DEADLINE = 500;
	bool meeting_deadlines = false;

	// TODO: Have a timing mechanism that we can use to keep track of things
	// Look at apic demo for how to use timer

	if (now - previous < DEADLINE) { // this does nothing right now
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
		/* Note: For the inmate to get this message from root, remove
		 * JAILHOUSE_CELL_PASSIVE_COMMREG from the inmate config */
		if (is_throttle_enabled) {
			printk("MGH DEMO: Disabling root throttling\n");
			disable_throttle();
		}

		printk("MGH DEMO: Stopping inmate\n");
		comm_region->cell_state = JAILHOUSE_CELL_SHUT_DOWN;
		ret = true;
		break;
	case JAILHOUSE_MSG_NONE:
		break;
	default:
		jailhouse_send_reply_from_cell(comm_region,
					       JAILHOUSE_MSG_UNKNOWN);
		break;
	}
	return ret;
}

/*
 * Calculate the SHA3 of the next item
 */
static void workload(volatile char *shmem)
{
	u32 *len_ptr = (u32 *) &shmem[OFFSET_IN_LEN];
	u32 len = *len_ptr;

	printk("MGH DEMO: Input data length: %d\n", len);

	// Account for space needed to tack on NULL character
	if (len > IN_SIZE - 1) {
		printk("MGH DEMO: Input data max length exceeded (%d > %d)\n",
		       len, IN_SIZE - 1);
		return;
	}

	printk("MGH DEMO: Calculating SHA3 on incoming data!\n");

	// Add a null char in for printing convenience
	shmem[OFFSET_IN + len] = '\0';

	calculate_sha3((char *)&shmem[OFFSET_IN], (int) len,
		       (char *)&shmem[OFFSET_OUT]);
}

void inmate_main(void)
{
	volatile char *shmem;

	if (!device_setup())
		return;

	// Get the first PCI device, which should be the IVSHMEM device
	shmem = devs[0].shmem;

	// Indicate to userspace that we are up and running
	shmem[OFFSET_SYNC] = 1;

	// Continuously wait on userspace for a workload
	while (1) {
		// If lagging behind, try throttling the root cell
		check_deadlines();

		// If about to shutdown, disable throttling first
		if (check_shutdown())
			return;

		// Check if the root placed a workload in shmem. If not, delay
		if (shmem[OFFSET_SYNC] != 2) {
			// TODO: Delay by 1 ms instead of 1 s
			delay_us(1000*1000);
			continue;
		}

		// Indicate that we are now working on sha3
		shmem[OFFSET_SYNC] = 3;

		workload(shmem);

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