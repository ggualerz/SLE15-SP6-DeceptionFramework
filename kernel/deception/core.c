#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/slab.h>
#include <linux/string.h>
#include <linux/cgroup.h>
#include <linux/sched.h>
#include <linux/utsname.h>
#include <linux/list.h>
#include "core.h"

/* Global deception table */
static struct deception_table *deception_table = NULL;

/* Original syscall functions - will be used in future hooking */
static void *original_syscalls[__NR_syscalls] __attribute__((unused)) = {NULL};

/* Hooked syscall functions - will be used in future hooking */
static void *hooked_syscalls[__NR_syscalls] __attribute__((unused)) = {NULL};

/* Module parameters */
bool deception_enabled = true;
EXPORT_SYMBOL_GPL(deception_enabled);
module_param(deception_enabled, bool, 0644);
MODULE_PARM_DESC(deception_enabled, "Enable/disable deception framework");

/**
 * deception_init - Initialize the deception framework
 */
int deception_init(void)
{
	pr_info("Deception Framework: Initializing...\n");

	/* Allocate deception table */
	deception_table = kzalloc(sizeof(struct deception_table), GFP_KERNEL);
	if (!deception_table) {
		pr_err("Deception Framework: Failed to allocate table\n");
		return -ENOMEM;
	}

	/* Initialize table */
	INIT_LIST_HEAD(&deception_table->entries);
	spin_lock_init(&deception_table->lock);
	atomic_set(&deception_table->refcount, 1);
	atomic_set(&deception_table->next_rule_id, 1);

	pr_info("Deception Framework: Initialized successfully\n");
	return 0;
}

/**
 * deception_exit - Cleanup the deception framework
 */
void deception_exit(void)
{
	pr_info("Deception Framework: Exiting...\n");

	if (deception_table) {
		/* Clear all rules */
		deception_table_clear();
		
		/* Free table */
		kfree(deception_table);
		deception_table = NULL;
	}

	pr_info("Deception Framework: Exited\n");
}

/**
 * get_current_container - Get current task's container cgroup
 */
struct cgroup *get_current_container(void)
{
	/* For now, return NULL to indicate no container filtering */
	/* TODO: Implement proper container detection when needed */
	return NULL;
}

/**
 * container_matches - Check if task belongs to target container
 */
bool container_matches(struct cgroup *task_container, struct cgroup *target_container)
{
	if (!target_container)
		return true; /* No target specified, match all */
	
	if (!task_container)
		return false; /* No task container, no match */
	
	return task_container == target_container;
}

/**
 * deception_table_add_rule - Add a new rule to the table
 */
int deception_table_add_rule(struct syscall_hook_entry *entry)
{
	if (!deception_table || !entry)
		return -EINVAL;

	spin_lock(&deception_table->lock);
	
	/* Assign unique rule ID */
	entry->rule_id = atomic_inc_return(&deception_table->next_rule_id);
	
	/* Add to list */
	list_add_tail(&entry->list, &deception_table->entries);
	
	spin_unlock(&deception_table->lock);
	
	pr_info("Deception Framework: Added rule %d for syscall %d\n", 
		entry->rule_id, entry->syscall_number);
	
	return entry->rule_id;
}

/**
 * deception_table_remove_rule - Remove a rule by ID
 */
int deception_table_remove_rule(int rule_id)
{
	struct syscall_hook_entry *entry, *tmp;
	int found = 0;

	if (!deception_table)
		return -EINVAL;

	spin_lock(&deception_table->lock);
	
	list_for_each_entry_safe(entry, tmp, &deception_table->entries, list) {
		if (entry->rule_id == rule_id) {
			list_del(&entry->list);
			kfree(entry->pattern);
			kfree(entry->replacement);
			kfree(entry);
			found = 1;
			break;
		}
	}
	
	spin_unlock(&deception_table->lock);
	
	if (found) {
		pr_info("Deception Framework: Removed rule %d\n", rule_id);
		return 0;
	}
	
	return -ENOENT;
}

/**
 * deception_table_clear - Clear all rules
 */
int deception_table_clear(void)
{
	struct syscall_hook_entry *entry, *tmp;

	if (!deception_table)
		return -EINVAL;

	spin_lock(&deception_table->lock);
	
	list_for_each_entry_safe(entry, tmp, &deception_table->entries, list) {
		list_del(&entry->list);
		kfree(entry->pattern);
		kfree(entry->replacement);
		kfree(entry);
	}
	
	spin_unlock(&deception_table->lock);
	
	pr_info("Deception Framework: Cleared all rules\n");
	return 0;
}

/**
 * deception_table_find_match - Find matching rule for syscall
 */
struct syscall_hook_entry *deception_table_find_match(int syscall, const char *arg, struct cgroup *container)
{
	struct syscall_hook_entry *entry;

	if (!deception_table || !deception_enabled)
		return NULL;

	spin_lock(&deception_table->lock);
	
	list_for_each_entry(entry, &deception_table->entries, list) {
		if (entry->syscall_number == syscall) {
			/* Check container match */
			if (container_matches(container, entry->target_container)) {
				/* Check PID match */
				if (entry->target_pid == 0 || entry->target_pid == current->pid) {
					/* For now, just return first match */
					/* TODO: Add pattern matching */
					spin_unlock(&deception_table->lock);
					return entry;
				}
			}
		}
	}
	
	spin_unlock(&deception_table->lock);
	return NULL;
}

/* Module initialization and cleanup */
static int __init deception_core_init(void)
{
	return deception_init();
}

static void __exit deception_core_exit(void)
{
	deception_exit();
}

module_init(deception_core_init);
module_exit(deception_core_exit);

MODULE_LICENSE("GPL");
MODULE_AUTHOR("Gregory Gualerzi");
MODULE_DESCRIPTION("Deception Framework Core"); 