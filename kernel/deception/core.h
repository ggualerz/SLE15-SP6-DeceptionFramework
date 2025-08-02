#ifndef _DECEPTION_CORE_H
#define _DECEPTION_CORE_H

#include <linux/list.h>
#include <linux/spinlock.h>
#include <linux/atomic.h>
#include <linux/cgroup.h>
#include <linux/utsname.h>

/* Deception rule entry */
struct syscall_hook_entry {
	int syscall_number;           /* Syscall number (e.g., __NR_uname) */
	char *pattern;                /* Match pattern (regex support) */
	char *replacement;            /* New value/path */
	struct cgroup *target_container; /* Target container cgroup (NULL = all) */
	pid_t target_pid;             /* Specific PID (0 = all) */
	unsigned long flags;          /* Behavior flags */
	struct list_head list;        /* Linked list */
	int rule_id;                  /* Unique rule ID */
};

/* Deception table structure */
struct deception_table {
	struct list_head entries;     /* List of substitution rules */
	spinlock_t lock;              /* Protects the table */
	atomic_t refcount;            /* Reference counting */
	atomic_t next_rule_id;        /* Next rule ID */
};

/* Function declarations */
int deception_init(void);
void deception_exit(void);

/* Table operations */
int deception_table_add_rule(struct syscall_hook_entry *entry);
int deception_table_remove_rule(int rule_id);
int deception_table_clear(void);
struct syscall_hook_entry *deception_table_find_match(int syscall, const char *arg, struct cgroup *container);

/* Container operations */
struct cgroup *get_current_container(void);
bool container_matches(struct cgroup *task_container, struct cgroup *target_container);

/* Hook operations */
int deception_hook_syscall(int syscall_number, void *original_func, void *hook_func);
void deception_unhook_syscall(int syscall_number);

/* Procfs operations */
int deception_proc_init(void);
void deception_proc_exit(void);

#endif /* _DECEPTION_CORE_H */ 