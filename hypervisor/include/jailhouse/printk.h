/*
 * Jailhouse, a Linux-based partitioning hypervisor
 *
 * Copyright (c) Siemens AG, 2013
 *
 * Authors:
 *  Jan Kiszka <jan.kiszka@siemens.com>
 *
 * This work is licensed under the terms of the GNU GPL, version 2.  See
 * the COPYING file in the top-level directory.
 */

#include <jailhouse/types.h>

void __attribute__((format(printf, 1, 2))) printk(const char *fmt, ...);

void __attribute__((format(printf, 1, 2))) panic_printk(const char *fmt, ...);

#ifdef CONFIG_TRACE_ERROR
#define trace_error(code) ({						  \
	printk("%s:%d: returning error %s\n", __FILE__, __LINE__, #code); \
	code;								  \
})
#else /* !CONFIG_TRACE_ERROR */
#define trace_error(code)	code
#endif /* !CONFIG_TRACE_ERROR */

void arch_dbg_write_init(void);
extern void (*arch_dbg_write)(const char *msg);

extern bool virtual_console;
extern volatile struct jailhouse_virt_console console;

// MGH: Add debug print macro if DEBUG is defined (pass in to compiler)
// #ifdef DEBUG
// #define MGH_DEBUG 1
// #else
// #define MGH_DEBUG 0
// #endif

#define MGH_DEBUG 0

#define printmgh(fmt, ...) \
    do { if (MGH_DEBUG) printk(fmt, ##__VA_ARGS__); } while (0)

// See https://stackoverflow.com/questions/1644868/define-macro-for-debug-printing-in-c
// https://stackoverflow.com/questions/18968070/error-when-defining-a-stringising-macro-with-va-args
