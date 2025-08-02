#include <linux/module.h>
#include <linux/init.h>
#include <linux/kernel.h>
#include <linux/utsname.h>
#include <linux/sched.h>
#include <linux/cgroup.h>
#include "core.h"

/* External declaration of original syscall */
extern asmlinkage long sys_newuname(struct new_utsname __user *name);

/**
 * deception_uname_hook - Hooked uname syscall
 */
asmlinkage long deception_uname_hook(struct new_utsname __user *name)
{
	struct syscall_hook_entry *rule;
	struct cgroup *container;
	struct new_utsname tmp;
	int ret;

	/* Get current container */
	container = get_current_container();

	/* Check for matching rule */
	rule = deception_table_find_match(__NR_uname, NULL, container);
	if (rule) {
		pr_info("Deception Framework: Intercepted uname syscall (rule %d)\n", rule->rule_id);
		
		/* For now, just modify the system name */
		down_read(&uts_sem);
		memcpy(&tmp, utsname(), sizeof(tmp));
		up_read(&uts_sem);
		
		/* Modify system name if replacement is provided */
		if (rule->replacement && strlen(rule->replacement) < __NEW_UTS_LEN) {
			strncpy(tmp.sysname, rule->replacement, __NEW_UTS_LEN - 1);
			tmp.sysname[__NEW_UTS_LEN - 1] = '\0';
		}
		
		if (copy_to_user(name, &tmp, sizeof(tmp)))
			return -EFAULT;
		
		if (override_release(name->release, sizeof(name->release)))
			return -EFAULT;
		if (override_architecture(name))
			return -EFAULT;
		
		return 0;
	}

	/* No rule matched, call original syscall */
	return sys_newuname(name);
}

/**
 * deception_hook_syscall - Hook a syscall
 */
int deception_hook_syscall(int syscall_number, void *original_func, void *hook_func)
{
	if (syscall_number < 0 || syscall_number >= __NR_syscall_max)
		return -EINVAL;

	original_syscalls[syscall_number] = original_func;
	hooked_syscalls[syscall_number] = hook_func;

	pr_info("Deception Framework: Hooked syscall %d\n", syscall_number);
	return 0;
}

/**
 * deception_unhook_syscall - Unhook a syscall
 */
void deception_unhook_syscall(int syscall_number)
{
	if (syscall_number < 0 || syscall_number >= __NR_syscall_max)
		return;

	original_syscalls[syscall_number] = NULL;
	hooked_syscalls[syscall_number] = NULL;

	pr_info("Deception Framework: Unhooked syscall %d\n", syscall_number);
}

/**
 * deception_hooks_init - Initialize syscall hooks
 */
int deception_hooks_init(void)
{
	pr_info("Deception Framework: Initializing hooks...\n");

	/* Hook uname syscall */
	deception_hook_syscall(__NR_uname, (void *)sys_newuname, (void *)deception_uname_hook);

	pr_info("Deception Framework: Hooks initialized\n");
	return 0;
}

/**
 * deception_hooks_exit - Cleanup syscall hooks
 */
void deception_hooks_exit(void)
{
	pr_info("Deception Framework: Cleaning up hooks...\n");

	/* Unhook uname syscall */
	deception_unhook_syscall(__NR_uname);

	pr_info("Deception Framework: Hooks cleaned up\n");
} 