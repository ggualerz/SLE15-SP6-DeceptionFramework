#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/string.h>
#include "core.h"

/**
 * deception_create_rule - Create a new rule entry
 */
struct syscall_hook_entry *deception_create_rule(int syscall_number, const char *pattern, 
                                                const char *replacement, struct cgroup *container, 
                                                pid_t target_pid, unsigned long flags)
{
	struct syscall_hook_entry *entry;

	entry = kzalloc(sizeof(struct syscall_hook_entry), GFP_KERNEL);
	if (!entry)
		return NULL;

	entry->syscall_number = syscall_number;
	entry->target_container = container;
	entry->target_pid = target_pid;
	entry->flags = flags;

	/* Copy pattern */
	if (pattern) {
		entry->pattern = kstrdup(pattern, GFP_KERNEL);
		if (!entry->pattern) {
			kfree(entry);
			return NULL;
		}
	}

	/* Copy replacement */
	if (replacement) {
		entry->replacement = kstrdup(replacement, GFP_KERNEL);
		if (!entry->replacement) {
			kfree(entry->pattern);
			kfree(entry);
			return NULL;
		}
	}

	INIT_LIST_HEAD(&entry->list);
	return entry;
}

/**
 * deception_destroy_rule - Destroy a rule entry
 */
void deception_destroy_rule(struct syscall_hook_entry *entry)
{
	if (!entry)
		return;

	kfree(entry->pattern);
	kfree(entry->replacement);
	kfree(entry);
} 