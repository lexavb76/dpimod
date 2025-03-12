#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
//#include <linux/skbuff.h> // skb_network_header()
//#include <linux/ip.h>
//#include <net/inet_sock.h> // struct ip_options
//#include <net/ip.h> //  ip_options_get()

//#define action NF_DROP
#define action NF_ACCEPT

char msg_start[] = "[dpimod started] Drop IP packets with options set (RFC 1108):\n  130/0x82	SEC	Security (RIPSO)\n"
             "  133/0x85	E-SEC	Extended Security (RIPSO)";

char msg_finish[] = "[dpimod finished]";

unsigned int dpi_hook_handler(void *priv, struct sk_buff *skb, const struct nf_hook_state *state);

//.hooknum = NF_INET_PRE_ROUTING: for received packages.
//.hooknum = NF_INET_LOCAL_OUT: for sent packages.
struct nf_hook_ops dpi_opts = {.hook = dpi_hook_handler,
                          .pf = NFPROTO_INET,
                          .hook_ops_type = NF_HOOK_OP_NF_TABLES,
                          .hooknum = NF_INET_PRE_ROUTING,
                          .priority = NF_IP_PRI_FIRST};

int init_module(void)
{
    pr_info("%s\n Action: %d\n", msg_start, action);
    nf_register_net_hook(&init_net, &dpi_opts); // init_net: default network namespace
    dpi_opts.hooknum = NF_INET_LOCAL_OUT;
    nf_register_net_hook(&init_net, &dpi_opts); // The same for output packets
    return 0;
}

void cleanup_module(void)
{
    nf_unregister_net_hook(&init_net, &dpi_opts);
    dpi_opts.hooknum = NF_INET_PRE_ROUTING; // Unregister in revers order (just for convinience)
    nf_unregister_net_hook(&init_net, &dpi_opts);
    pr_alert("%s Good buy, world!\n", msg_finish);
}

unsigned int dpi_hook_handler(void *priv, struct sk_buff *skb, const struct nf_hook_state *state)
{
    pr_info("[dpimod] RCVD IP packet");
    return action;
}
MODULE_LICENSE("GPL");
