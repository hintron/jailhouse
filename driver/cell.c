/*
 * Jailhouse, a Linux-based partitioning hypervisor
 *
 * Copyright (c) Siemens AG, 2013-2016
 *
 * Authors:
 *  Jan Kiszka <jan.kiszka@siemens.com>
 *
 * This work is licensed under the terms of the GNU GPL, version 2.  See
 * the COPYING file in the top-level directory.
 */

#include <linux/cpu.h>
#include <linux/mm.h>
#include <linux/slab.h>
#include <linux/vmalloc.h>
#include <asm/cacheflush.h>

#include "cell.h"
#include "main.h"
#include "pci.h"
#include "sysfs.h"

#include <jailhouse/hypercall.h>

struct cell *root_cell;

static LIST_HEAD(cells);
static cpumask_t offlined_cpus;

void jailhouse_cell_kobj_release(struct kobject *kobj)
{
	struct cell *cell = container_of(kobj, struct cell, kobj);

	jailhouse_pci_cell_cleanup(cell);
	vfree(cell->memory_regions);
	kfree(cell);
}

static struct cell *cell_create(const struct jailhouse_cell_desc *cell_desc)
{
	struct cell *cell;
	unsigned int id;
	int err;

	printk("MGH: GOT HERE!!!!!!!!!!!!!\n");
	if (cell_desc->num_memory_regions >=
	    ULONG_MAX / sizeof(struct jailhouse_memory)) {
		printk("MGH: ERROR EINVAL: cell_desc->num_memory_regions >= ULONG_MAX / sizeof(struct jailhouse_memory)\n");
		return ERR_PTR(-EINVAL);
	}

	/* determine cell id */
	id = 0;
retry:
	list_for_each_entry(cell, &cells, entry)
		if (cell->id == id) {
			id++;
			goto retry;
		}

	cell = kzalloc(sizeof(*cell), GFP_KERNEL);
	if (!cell) {
		printk("MGH: ERROR ENOMEM 2: cell_create())\n");
		return ERR_PTR(-ENOMEM);
	}

	printk("MGH: GOT HERE 2!!!!!!!!!!!!!\n");
	INIT_LIST_HEAD(&cell->entry);

	cell->id = id;

	printk("MGH: GOT HERE 5!!!!!!!!!!!!!\n");
	bitmap_copy(cpumask_bits(&cell->cpus_assigned),
		    jailhouse_cell_cpu_set(cell_desc),
		    min((unsigned int)nr_cpumask_bits,
		        cell_desc->cpu_set_size * 8));

	printk("MGH: GOT HERE 6!!!!!!!!!!!!!\n");
	cell->num_memory_regions = cell_desc->num_memory_regions;
	cell->memory_regions = vmalloc(sizeof(struct jailhouse_memory) *
				       cell->num_memory_regions);
	if (!cell->memory_regions) {
		kfree(cell);
		printk("MGH: ERROR ENOMEM 2: cell_create())\n");
		return ERR_PTR(-ENOMEM);
	}

	printk("MGH: GOT HERE 7!!!!!!!!!!!!!\n");
	memcpy(cell->name, cell_desc->name, JAILHOUSE_CELL_ID_NAMELEN);
	cell->name[JAILHOUSE_CELL_ID_NAMELEN] = 0;

	memcpy(cell->memory_regions, jailhouse_cell_mem_regions(cell_desc),
	       sizeof(struct jailhouse_memory) * cell->num_memory_regions);

	printk("MGH: GOT HERE 8!!!!!!!!!!!!!\n");
	err = jailhouse_pci_cell_setup(cell, cell_desc);
	if (err) {
		vfree(cell->memory_regions);
		kfree(cell);
		printk("MGH: ERROR: jailhouse_pci_cell_setup())\n");
		return ERR_PTR(err);
	}

	printk("MGH: GOT HERE 9!!!!!!!!!!!!!\n");
	err = jailhouse_sysfs_cell_create(cell);
	if (err) {
		/* cleanup done by jailhouse_sysfs_cell_create */
		printk("MGH: ERROR: jailhouse_sysfs_cell_create())\n");
		return ERR_PTR(err);
	}

	printk("MGH: Returning cell %s\n", cell->name);
	return cell;
}

static void cell_register(struct cell *cell)
{
	list_add_tail(&cell->entry, &cells);
	jailhouse_sysfs_cell_register(cell);
}

static struct cell *find_cell(struct jailhouse_cell_id *cell_id)
{
	struct cell *cell;

	list_for_each_entry(cell, &cells, entry)
		if (cell_id->id == cell->id ||
		    (cell_id->id == JAILHOUSE_CELL_ID_UNUSED &&
		     strcmp(cell->name, cell_id->name) == 0))
			return cell;
	return NULL;
}

static void cell_delete(struct cell *cell)
{
	list_del(&cell->entry);
	jailhouse_sysfs_cell_delete(cell);
}

int jailhouse_cell_prepare_root(const struct jailhouse_cell_desc *cell_desc)
{
	root_cell = cell_create(cell_desc);
	if (IS_ERR(root_cell))
		return PTR_ERR(root_cell);

	cpumask_and(&root_cell->cpus_assigned, &root_cell->cpus_assigned,
		    cpu_online_mask);

	return 0;
}

void jailhouse_cell_register_root(void)
{
	root_cell->id = 0;
	cell_register(root_cell);
}

void jailhouse_cell_delete_root(void)
{
	cell_delete(root_cell);
	root_cell = NULL;
}

int jailhouse_cmd_cell_create(struct jailhouse_cell_create __user *arg)
{
	struct jailhouse_cell_create cell_params;
	struct jailhouse_cell_desc *config;
	struct jailhouse_cell_id cell_id;
	void __user *user_config;
	struct cell *cell;
	unsigned int cpu;
	int err = 0;

	printk("MGH: driver/cell.c#jailhouse_cmd_cell_create()");
	if (copy_from_user(&cell_params, arg, sizeof(cell_params)))
		return -EFAULT;

	config = kmalloc(cell_params.config_size, GFP_USER | __GFP_NOWARN);
	if (!config)
		return -ENOMEM;

	user_config = (void __user *)(unsigned long)cell_params.config_address;
	if (copy_from_user(config, user_config, cell_params.config_size)) {
		err = -EFAULT;
		goto kfree_config_out;
	}

	if (cell_params.config_size < sizeof(*config) ||
	    memcmp(config->signature, JAILHOUSE_CELL_DESC_SIGNATURE,
		   sizeof(config->signature)) != 0) {
		printk("jailhouse: ERROR EINVAL: Not a cell configuration\n");
		err = -EINVAL;
		goto kfree_config_out;
	}
	if (config->revision != JAILHOUSE_CONFIG_REVISION) {
		printk("jailhouse: ERROR EINVAL: Configuration revision mismatch\n");
		err = -EINVAL;
		goto kfree_config_out;
	}

	config->name[JAILHOUSE_CELL_NAME_MAXLEN] = 0;

	/* CONSOLE_ACTIVE implies CONSOLE_PERMITTED for non-root cells */
	if (CELL_FLAGS_VIRTUAL_CONSOLE_ACTIVE(config->flags))
		config->flags |= JAILHOUSE_CELL_VIRTUAL_CONSOLE_PERMITTED;

	if (mutex_lock_interruptible(&jailhouse_lock) != 0) {
		err = -EINTR;
		goto kfree_config_out;
	}

	if (!jailhouse_enabled) {
		printk("MGH: ERROR EINVAL: jailhouse: !jailhouse_enabled\n");
		err = -EINVAL;
		goto unlock_out;
	}

	cell_id.id = JAILHOUSE_CELL_ID_UNUSED;
	memcpy(cell_id.name, config->name, sizeof(cell_id.name));
	if (find_cell(&cell_id) != NULL) {
		err = -EEXIST;
		goto unlock_out;
	}

	cell = cell_create(config);
	if (IS_ERR(cell)) {
		err = PTR_ERR(cell);
		printk("MGH: ERROR IS_ERR(cell)\n");
		goto unlock_out;
	}

	config->id = cell->id;

	if (!cpumask_subset(&cell->cpus_assigned, &root_cell->cpus_assigned)) {
		err = -EBUSY;
		goto error_cell_delete;
	}

	printk("MGH: GOT HERE 11\n");
	/* Off-line each CPU assigned to the new cell and remove it from the
	 * root cell's set. */
	for_each_cpu(cpu, &cell->cpus_assigned) {
#ifdef CONFIG_X86
		if (cpu == 0) {
			/*
			 * On x86, Linux only parks CPU 0 when offlining it and
			 * expects to be able to get it back by sending an IPI.
			 * This is not support by Jailhouse wich destroys the
			 * CPU state across non-root assignments.
			 */
			printk("Cannot assign CPU 0 to other cells\n");
			err = -EINVAL;
			goto error_cpu_online;
		}
#endif
		if (cpu_online(cpu)) {
			err = cpu_down(cpu);
			if (err) {
				printk("MGH: ERROR cpu_down(cpu)\n");
				goto error_cpu_online;
			}
			cpumask_set_cpu(cpu, &offlined_cpus);
		}
		cpumask_clear_cpu(cpu, &root_cell->cpus_assigned);
	}

	printk("MGH: GOT HERE 12\n");
	jailhouse_pci_do_all_devices(cell, JAILHOUSE_PCI_TYPE_DEVICE,
	                             JAILHOUSE_PCI_ACTION_CLAIM);

	printk("MGH: GOT HERE 13\n");
	err = jailhouse_call_arg1(JAILHOUSE_HC_CELL_CREATE, __pa(config));
	printk("MGH: GOT HERE 14\n");
	if (err < 0) {
		printk("MGH: ERROR jailhouse_call_arg1(JAILHOUSE_HC_CELL_CREATE): err = %d\n", err);
		goto error_cpu_online;
	}
	printk("MGH: GOT HERE 15\n");

	cell_register(cell);

	pr_info("Created Jailhouse cell \"%s\"\n", config->name);

unlock_out:
	mutex_unlock(&jailhouse_lock);

kfree_config_out:
	kfree(config);

	return err;

error_cpu_online:
	for_each_cpu(cpu, &cell->cpus_assigned) {
		if (!cpu_online(cpu) && cpu_up(cpu) == 0)
			cpumask_clear_cpu(cpu, &offlined_cpus);
		cpumask_set_cpu(cpu, &root_cell->cpus_assigned);
	}

error_cell_delete:
	cell_delete(cell);
	goto unlock_out;
}

static int cell_management_prologue(struct jailhouse_cell_id *cell_id,
				    struct cell **cell_ptr)
{
	cell_id->name[JAILHOUSE_CELL_ID_NAMELEN] = 0;

	if (mutex_lock_interruptible(&jailhouse_lock) != 0)
		return -EINTR;

	if (!jailhouse_enabled) {
		mutex_unlock(&jailhouse_lock);
		return -EINVAL;
	}

	*cell_ptr = find_cell(cell_id);
	if (*cell_ptr == NULL) {
		mutex_unlock(&jailhouse_lock);
		return -ENOENT;
	}
	return 0;
}

#define MEM_REQ_FLAGS	(JAILHOUSE_MEM_WRITE | JAILHOUSE_MEM_LOADABLE)

static int load_image(struct cell *cell,
		      struct jailhouse_preload_image __user *uimage)
{
	struct jailhouse_preload_image image;
	const struct jailhouse_memory *mem;
	unsigned int regions, page_offs;
	u64 image_offset, phys_start;
	void *image_mem;
	int err = 0;

	printk("MGH: Inside load_image");
	if (copy_from_user(&image, uimage, sizeof(image)))
		return -EFAULT;

	printk("MGH: cell.c --> load_image(): Trying to load image of size %lld (0x%llx)",
       image.size, image.size);
	if (image.size == 0)
		return 0;

	mem = cell->memory_regions;
	for (regions = cell->num_memory_regions; regions > 0; regions--) {
		image_offset = image.target_address - mem->virt_start;
		if (image.target_address >= mem->virt_start &&
		    image_offset < mem->size) {
			if (image.size > mem->size - image_offset) {
				printk("MGH: ERROR EINVAL: image.size (%lld) > mem->size (%lld) - image_offset (%lld)",
				       image.size, mem->size, image_offset);
				return -EINVAL;
			} else if ((mem->flags & MEM_REQ_FLAGS)
				   != MEM_REQ_FLAGS) {
				printk("MGH: ERROR EINVAL: mem->flags & MEM_REQ_FLAGS (%lld) != MEM_REQ_FLAGS (%d)",
				       mem->flags & MEM_REQ_FLAGS,
				       MEM_REQ_FLAGS);
				return -EINVAL;
			}
			break;
		} else {
			printk("MGH: Warning: image.target_address (0x%llx) < mem->virt_start (0x%llx) || image_offset (0x%llx) >= mem->size (0x%llx). Check next mem region...",
			       image.target_address, mem->virt_start,
			       image_offset, mem->size);
		}
		mem++;
	}
	if (regions == 0) {
		printk("MGH: ERROR EINVAL: regions == 0 (no region was suitable to load the image in)");
		return -EINVAL;
	} else {
		printk("MGH: The image was loaded into memory region %d!",
		       regions);
	}

	phys_start = (mem->phys_start + image_offset) & PAGE_MASK;
	printk("MGH: offset_in_page()");
	page_offs = offset_in_page(image_offset);
	printk("MGH: jailhouse_ioremap()");
	image_mem = jailhouse_ioremap(phys_start, 0,
				      PAGE_ALIGN(image.size + page_offs));

	if (!image_mem) {
		pr_err("jailhouse: Unable to map cell RAM at %08llx "
		       "for image loading\n",
		       (unsigned long long)(mem->phys_start + image_offset));
		return -EBUSY;
	}

	printk("MGH: copy_from_user()");
	if (copy_from_user(image_mem + page_offs,
			   (void __user *)(unsigned long)image.source_address,
			   image.size))
		err = -EFAULT;
	/*
	 * ARMv7 and ARMv8 require to clean D-cache and invalidate I-cache for
	 * memory containing new instructions. On x86 this is a NOP.
	 */
	printk("MGH: flush_icache_range()");
	flush_icache_range((unsigned long)(image_mem + page_offs),
			   (unsigned long)(image_mem + page_offs) + image.size);
#ifdef CONFIG_ARM
	/*
	 * ARMv7 requires to flush the written code and data out of D-cache to
	 * allow the guest starting off with caches disabled.
	 */
	__cpuc_flush_dcache_area(image_mem + page_offs, image.size);
#endif

	printk("MGH: vunmap()");
	vunmap(image_mem);

	return err;
}

int jailhouse_cmd_cell_load(struct jailhouse_cell_load __user *arg)
{
	struct jailhouse_preload_image __user *image = arg->image;
	struct jailhouse_cell_load cell_load;
	struct cell *cell;
	unsigned int n;
	int err;

	printk("MGH: driver/cell.c --> jailhouse_cmd_cell_load()");
	if (copy_from_user(&cell_load, arg, sizeof(cell_load)))
		return -EFAULT;

	printk("MGH: cell_management_prologue()");
	err = cell_management_prologue(&cell_load.cell_id, &cell);
	if (err)
		return err;

	err = jailhouse_call_arg1(JAILHOUSE_HC_CELL_SET_LOADABLE, cell->id);
	if (err)
		goto unlock_out;

	for (n = cell_load.num_preload_images; n > 0; n--, image++) {
		printk("MGH: load_image()");
		err = load_image(cell, image);
		if (err)
			break;
	}

unlock_out:
	printk("MGH: unlock_out()");
	mutex_unlock(&jailhouse_lock);

	return err;
}

int jailhouse_cmd_cell_start(const char __user *arg)
{
	struct jailhouse_cell_id cell_id;
	struct cell *cell;
	int err;

	printk("MGH: driver/cell.c#jailhouse_cmd_cell_start()");
	if (copy_from_user(&cell_id, arg, sizeof(cell_id)))
		return -EFAULT;

	err = cell_management_prologue(&cell_id, &cell);
	if (err)
		return err;

	err = jailhouse_call_arg1(JAILHOUSE_HC_CELL_START, cell->id);

	mutex_unlock(&jailhouse_lock);

	return err;
}

static int cell_destroy(struct cell *cell)
{
	unsigned int cpu;
	int err;

	err = jailhouse_call_arg1(JAILHOUSE_HC_CELL_DESTROY, cell->id);
	if (err)
		return err;

	for_each_cpu(cpu, &cell->cpus_assigned) {
		if (cpumask_test_cpu(cpu, &offlined_cpus)) {
			if (cpu_up(cpu) != 0)
				pr_err("Jailhouse: failed to bring CPU %d "
				       "back online\n", cpu);
			cpumask_clear_cpu(cpu, &offlined_cpus);
		}
		cpumask_set_cpu(cpu, &root_cell->cpus_assigned);
	}

	jailhouse_pci_do_all_devices(cell, JAILHOUSE_PCI_TYPE_DEVICE,
	                             JAILHOUSE_PCI_ACTION_RELEASE);

	pr_info("Destroyed Jailhouse cell \"%s\"\n", cell->name);

	cell_delete(cell);

	return 0;
}

int jailhouse_cmd_cell_destroy(const char __user *arg)
{
	struct jailhouse_cell_id cell_id;
	struct cell *cell;
	int err;

	if (copy_from_user(&cell_id, arg, sizeof(cell_id)))
		return -EFAULT;

	err = cell_management_prologue(&cell_id, &cell);
	if (err)
		return err;

	err = cell_destroy(cell);

	mutex_unlock(&jailhouse_lock);

	return err;
}

int jailhouse_cmd_cell_destroy_non_root(void)
{
	struct cell *cell, *tmp;
	int err;

	list_for_each_entry_safe(cell, tmp, &cells, entry) {
		if (cell == root_cell)
			continue;
		err = cell_destroy(cell);
		if (err) {
			pr_err("Jailhouse: failed to destroy cell \"%s\"\n", cell->name);
			return err;
		}
	}

	return 0;
}
