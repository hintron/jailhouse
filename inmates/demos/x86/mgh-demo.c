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

static char str[32] = "Hello From MGH      ";
static int ndevices = 0;
static int irq_counter;

// # of bytes for the sha3-512 message digest output
#define MD_LENGTH (512/8)

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

static void send_irq(struct ivshmem_dev_data *d)
{
	printk("MGH DEMO: %02x:%02x.%x sending IRQ; Shared: %s\n",
	       d->bdf >> 8, (d->bdf >> 3) & 0x1f, d->bdf & 0x3, (char *)d->shmem);
	// Write to the doorbell register (3 * u32 = 12 bytes)
	mmio_write32(d->registers + 3, 1);
}

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
	printk("MGH DEMO: got interrupt ... %d\n", irq_counter++);
}

void inmate_main(void)
{
	int bdf = 0;
	unsigned int class_rev;
	struct ivshmem_dev_data *d;
	volatile char *shmem;
	u8 length_u8 = 0;

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
		ndevices++;
		d = devs + ndevices - 1;
		d->bdf = bdf;
		map_shmem_and_bars(d);
		printk("MGH DEMO: mapped the bars got position %d\n",
			get_ivpos(d));

		memcpy(d->shmem, str, 32);

		int_set_handler(IRQ_VECTOR + ndevices - 1, irq_handler);
		pci_msix_set_vector(bdf, IRQ_VECTOR + ndevices - 1, 0);
		bdf++;
	}

	if (ndevices <= 0) {
		printk("MGH DEMO: No PCI devices found .. nothing to do.\n");
		goto out;
	}

	if (ndevices > 1) {
		printk("MGH DEMO: Too many PCI devices found!\n");
		goto out;
	}

	shmem = devs[0].shmem;
	// Indicate the we are up and running
	shmem[0] = 1;
	while (1) {
		// Poll until byte 0 is 2 (meaning that the root has placed
		// data for us in shmem to compute)
		while (shmem[0] != 2) {
			printk("Waiting for root cell to signal us...\n");
			// Delay a second
			delay_us(1000*1000);
		}

		// Indicate that we are now working on sha3
		shmem[0] = 3;

		// Cast signed length byte to unsigned
		length_u8 = shmem[1];

		calculate_sha3((char *)&shmem[2], (int)length_u8,
			       (char *)&shmem[258]);

		// Indicate that we are done
		shmem[0] = 1;
		// Tell the root cell that we are ready to calculate sha3
		send_irq(&devs[0]);
	}
out:
	halt();
}


// References:
// https://wiki.sei.cmu.edu/confluence/display/c/STR34-C.+Cast+characters+to+unsigned+char+before+converting+to+larger+integer+sizes
//