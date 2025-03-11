#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
#include <linux/skbuff.h>

char msg_start[] = "[dpimod started] Drop IP packets with options set (RFC 1108):\n  130/0x82	SEC	Security (RIPSO)\n"
             "  133/0x85	E-SEC	Extended Security (RIPSO)";

char msg_finish[] = "[dpimod finished]";

int init_module(void)
{
    pr_info("%s\n", msg_start);
    return 0;
}

void cleanup_module(void)
{
    pr_alert("%s Good buy, world!\n", msg_finish);
}

MODULE_LICENSE("GPL");
