/*
 * Jailhouse, a Linux-based partitioning hypervisor
 *
 * Authors:
 *  Michael Hinton
 *
 * This work is licensed under the terms of the GNU GPL, version 2.  See
 * the COPYING file in the top-level directory.
 */

#include <jailhouse/types.h>
#include <jailhouse/cell-config.h>

struct {
	struct jailhouse_cell_desc cell;
	__u64 cpus[1];
	// struct jailhouse_memory mem_regions[6];
	struct jailhouse_memory mem_regions[5];
	struct jailhouse_pio pio_regions[3];
	struct jailhouse_pci_device pci_devices[2];
	struct jailhouse_pci_capability pci_caps[5];
} __attribute__((packed)) config = {
	.cell = {
		.signature = JAILHOUSE_CELL_DESC_SIGNATURE,
		.revision = JAILHOUSE_CONFIG_REVISION,
		.name = "bazooka-inmate-linux",
		.flags = JAILHOUSE_CELL_VIRTUAL_CONSOLE_ACTIVE,
		/* MGH: Remove the JAILHOUSE_CELL_PASSIVE_COMMREG flag to make
		 * the hypervisor ask the inmate for permission before shutting
		 * it down (see apic-demo.c) */
		.cpu_set_size = sizeof(config.cpus),
		.num_memory_regions = ARRAY_SIZE(config.mem_regions),
		.num_irqchips = 0,
		.num_pio_regions = ARRAY_SIZE(config.pio_regions),
		.num_pci_devices = ARRAY_SIZE(config.pci_devices),
		.num_pci_caps = ARRAY_SIZE(config.pci_caps),

		// .console = {
		// 	.type = JAILHOUSE_CON_TYPE_8250,
		// 	.flags = JAILHOUSE_CON_ACCESS_PIO,
		// 	.address = 0x3f8,
		// },
		.console = {
			.type = JAILHOUSE_CON_TYPE_8250,
			.flags = JAILHOUSE_CON_ACCESS_MMIO,
			.address = 0xa3601000,
		},
	},

	.cpus = {
		0b0100,
	},

	.mem_regions = {
		/* Low RAM */
		{
			.phys_start = 0x3a600000,
			.virt_start = 0,
			// 1 MB of RAM for the inmate's program
			.size = 0x00100000,
			.flags = JAILHOUSE_MEM_READ | JAILHOUSE_MEM_WRITE |
				JAILHOUSE_MEM_EXECUTE | JAILHOUSE_MEM_DMA |
				JAILHOUSE_MEM_LOADABLE,
		},
		/* communication region */
		{
			/* MGH: This virtual memory region points to memory
			 * allocated by Jailhouse within its own hypervisor
			 * memory region for communication to each inmate.
			 * This is NOT pointing to anything in the 75 MB inmate
			 * memory region */
			.virt_start = 0x00100000,
			.size = 0x00001000,
			.flags = JAILHOUSE_MEM_READ | JAILHOUSE_MEM_COMM_REGION |
				/* MGH: Allow the inmate to write to the comm
				 * region, so it can send messages to root */
				JAILHOUSE_MEM_WRITE,
		},
		/* MGH: High RAM */
		{
			/* MGH: We have 36 MB of memory allocated to the inmate
			 * in the root config, but are only using 1 MB for the
			 * inmate's stack and program. So create an additional
			 * "heap" area with the other 35 MB to allow the program
			 * more memory to work with. */
			.phys_start = 0x3a700000,
			.virt_start = 0x00200000,
			// 74 MB (0x3a7 + 0x4a = 0x3ca)
			.size = 0x4a00000,
			.flags = JAILHOUSE_MEM_READ | JAILHOUSE_MEM_WRITE |
				JAILHOUSE_MEM_EXECUTE | JAILHOUSE_MEM_DMA |
				JAILHOUSE_MEM_LOADABLE,
		},
		/* MGH: IVSHMEM shared memory region */
		{
			/* MGH: Having the virtual address be the same as the
			 * the physical address is for convenience */
			.phys_start = 0x3f100000,
			.virt_start = 0x3f100000,
			.size = 0x100000, // 1 MB
			.flags = JAILHOUSE_MEM_READ | JAILHOUSE_MEM_WRITE |
				JAILHOUSE_MEM_ROOTSHARED,
		},
		/* MemRegion: a3601000-a3601007 : serial PCI adapter - ttyS4 */
		{
			.phys_start = 0xa3601000,
			.virt_start = 0xa3601000,
			.size = 0x1000,
			.flags = JAILHOUSE_MEM_READ | JAILHOUSE_MEM_WRITE,
		},
		// /* MemRegion: 3f200000-87f7cfff : System RAM */
		// {
		// 	.phys_start = 0x3f200000,
		// 	.virt_start = 0x3f200000,
		// 	.size = 0x48d7d000,
		// 	.flags = JAILHOUSE_MEM_READ | JAILHOUSE_MEM_WRITE |
		// 		JAILHOUSE_MEM_EXECUTE | JAILHOUSE_MEM_DMA,
		// },
	},

	.pio_regions = {
		PIO_RANGE(0x2f8, 8), /* serial 2 */
		PIO_RANGE(0x3f8, 8), /* serial 1 */
		PIO_RANGE(0xc00, 0xf300), /* HACK: PCI bus */
	},

	.pci_devices = {
		{
			.type = JAILHOUSE_PCI_TYPE_IVSHMEM,
			.domain = 0x0000,
			.bdf = 0x0f << 3,
			.bar_mask = {
				0xffffff00, 0xffffffff, 0x00000000,
				0x00000000, 0xffffffe0, 0xffffffff,
			},
			.num_msix_vectors = 1,
			.shmem_region = 3,
		},
		/* PCIDevice: 03:00.0 serial PCI adapter - ttyS4 */
		{
			.type = JAILHOUSE_PCI_TYPE_DEVICE,
			.iommu = 0,
			.domain = 0x0,
			.bdf = 0x300,
			.bar_mask = {
				0xffffc000, 0xffe00000, 0xffe00000,
				0x00000000, 0x00000000, 0x00000000,
			},
			.caps_start = 59,
			.num_caps = 5,
			.num_msi_vectors = 0,
			.msi_64bits = 0,
			.msi_maskable = 0,
			.num_msix_vectors = 16,
			.msix_region_size = 0x1000,
			.msix_address = 0xa35b3000,
		},
	},

	.pci_caps = {
		/* PCIDevice: 03:00.0 - serial PCI adapter - ttyS4*/
		{
			.id = PCI_CAP_ID_PM,
			.start = 0x40,
			.len = 0x8,
			.flags = JAILHOUSE_PCICAPS_WRITE,
		},
		{
			.id = PCI_CAP_ID_EXP,
			.start = 0x70,
			.len = 0x14,
			.flags = 0,
		},
		{
			.id = PCI_CAP_ID_MSIX,
			.start = 0xb0,
			.len = 0xc,
			.flags = JAILHOUSE_PCICAPS_WRITE,
		},
		{
			.id = PCI_EXT_CAP_ID_DSN | JAILHOUSE_PCI_EXT_CAP,
			.start = 0x100,
			.len = 0xc,
			.flags = 0,
		},
		{
			.id = PCI_EXT_CAP_ID_PWR | JAILHOUSE_PCI_EXT_CAP,
			.start = 0x110,
			.len = 0x10,
			.flags = 0,
		},
	},
};