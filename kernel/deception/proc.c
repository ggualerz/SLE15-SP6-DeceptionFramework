#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/proc_fs.h>
#include <linux/seq_file.h>
#include <linux/uaccess.h>
#include <linux/slab.h>
#include <linux/string.h>
#include "core.h"

static struct proc_dir_entry *deception_proc_dir = NULL;
static struct proc_dir_entry *deception_rules_file = NULL;

/**
 * deception_proc_show - Show rules in procfs
 */
static int deception_proc_show(struct seq_file *m, void *v)
{
	struct syscall_hook_entry *entry;
	int count = 0;

	seq_printf(m, "Deception Framework Rules:\n");
	seq_printf(m, "========================\n");

	/* TODO: Implement rule listing */
	seq_printf(m, "No rules configured yet.\n");

	return 0;
}

/**
 * deception_proc_open - Open procfs file
 */
static int deception_proc_open(struct inode *inode, struct file *file)
{
	return single_open(file, deception_proc_show, NULL);
}

/**
 * deception_proc_write - Write to procfs file
 */
static ssize_t deception_proc_write(struct file *file, const char __user *buffer,
                                   size_t count, loff_t *ppos)
{
	char *data;
	char *cmd, *syscall, *pattern, *replacement, *container;
	struct syscall_hook_entry *entry;
	int ret = count;

	/* Allocate buffer */
	data = kzalloc(count + 1, GFP_KERNEL);
	if (!data)
		return -ENOMEM;

	/* Copy from userspace */
	if (copy_from_user(data, buffer, count)) {
		kfree(data);
		return -EFAULT;
	}

	/* Parse command */
	cmd = strsep(&data, ":");
	if (!cmd) {
		kfree(data);
		return -EINVAL;
	}

	if (strcmp(cmd, "add") == 0) {
		/* Parse: add:syscall:pattern:replacement:container */
		syscall = strsep(&data, ":");
		pattern = strsep(&data, ":");
		replacement = strsep(&data, ":");
		container = strsep(&data, ":");

		if (!syscall) {
			pr_err("Deception Framework: Invalid add command format\n");
			kfree(data);
			return -EINVAL;
		}

		/* Create rule */
		entry = deception_create_rule(__NR_uname, pattern, replacement, NULL, 0, 0);
		if (!entry) {
			pr_err("Deception Framework: Failed to create rule\n");
			kfree(data);
			return -ENOMEM;
		}

		/* Add to table */
		if (deception_table_add_rule(entry) < 0) {
			pr_err("Deception Framework: Failed to add rule\n");
			deception_destroy_rule(entry);
			kfree(data);
			return -EINVAL;
		}

		pr_info("Deception Framework: Added rule via procfs\n");

	} else if (strcmp(cmd, "clear") == 0) {
		deception_table_clear();
		pr_info("Deception Framework: Cleared all rules via procfs\n");

	} else {
		pr_err("Deception Framework: Unknown command: %s\n", cmd);
		ret = -EINVAL;
	}

	kfree(data);
	return ret;
}

static const struct proc_ops deception_proc_ops = {
	.proc_open = deception_proc_open,
	.proc_read = seq_read,
	.proc_write = deception_proc_write,
	.proc_lseek = seq_lseek,
	.proc_release = single_release,
};

/**
 * deception_proc_init - Initialize procfs interface
 */
int deception_proc_init(void)
{
	pr_info("Deception Framework: Initializing procfs interface...\n");

	/* Create proc directory */
	deception_proc_dir = proc_mkdir("deception", NULL);
	if (!deception_proc_dir) {
		pr_err("Deception Framework: Failed to create proc directory\n");
		return -ENOMEM;
	}

	/* Create rules file */
	deception_rules_file = proc_create("rules", 0644, deception_proc_dir, &deception_proc_ops);
	if (!deception_rules_file) {
		pr_err("Deception Framework: Failed to create rules file\n");
		remove_proc_entry("deception", NULL);
		return -ENOMEM;
	}

	pr_info("Deception Framework: Procfs interface initialized\n");
	return 0;
}

/**
 * deception_proc_exit - Cleanup procfs interface
 */
void deception_proc_exit(void)
{
	pr_info("Deception Framework: Cleaning up procfs interface...\n");

	if (deception_rules_file) {
		remove_proc_entry("rules", deception_proc_dir);
		deception_rules_file = NULL;
	}

	if (deception_proc_dir) {
		remove_proc_entry("deception", NULL);
		deception_proc_dir = NULL;
	}

	pr_info("Deception Framework: Procfs interface cleaned up\n");
} 