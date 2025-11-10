#include <linux/kernel.h>
#include <linux/module.h>
#include <linux/netfilter.h>
#include <linux/netfilter_ipv4.h>
//#include <linux/skbuff.h> // skb_network_header()
#include <linux/ip.h> // iphdr()
//#include <net/inet_sock.h> // struct ip_options
#include <net/ip.h> //  ip_options_compile()

#define BASE_IPHDR_LEN sizeof(struct iphdr)/4 // Base IP header length without options in 32-bit words

char msg_start[] = "[dpimod started] Drop IP packets with options set (RFC 1108):\n  130/0x82	SEC	Security (RIPSO)\n"
             "  133/0x85	E-SEC	Extended Security (RIPSO)";

char msg_finish[] = "[dpimod finished]";

unsigned int dpi_hook_handler(void *priv, struct sk_buff *skb, const struct nf_hook_state *state);
void check_ip_options(struct iphdr *iph, const struct nf_hook_state *state, int *action, int action_todo);

//.hooknum = NF_INET_PRE_ROUTING: for received packages.
//.hooknum = NF_INET_LOCAL_OUT: for sent packages.
struct nf_hook_ops dpi_opts = {.hook = dpi_hook_handler,
                          .pf = NFPROTO_INET,
                          .hook_ops_type = NF_HOOK_OP_NF_TABLES,
                          .hooknum = NF_INET_PRE_ROUTING,
                          .priority = NF_IP_PRI_FIRST};

int init_module(void)
{
    pr_info("%s\n", msg_start);
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
    int action = NF_ACCEPT;
    if (skb) {
        check_ip_options(ip_hdr(skb), state, &action, NF_DROP);
    }
    return action;
}

void check_ip_options(struct iphdr *iph, const struct nf_hook_state *state, int *action, int action_todo)
{
    unsigned char *opt;
    int optslen;
    opt = (unsigned char *) &iph[1]; // Points to the first byte after Base IP Header (struct iphdr)
    optslen = 4 * (iph->ihl - BASE_IPHDR_LEN);
    if (optslen > 0) { // ip_options present
        pr_info(
            "[dpimod] IP packet, hook %d, ip_hdr_len = %d, optlen = %x, default action: %d\n",
            state->hook,
            iph->ihl,
            optslen,
            *action);
        while (optslen > 0 && *opt != IPOPT_END) {
            if (*opt == IPOPT_NOOP) {
                pr_info("[dpimod] Option NOOP.\n");
                ++opt;
                --optslen;
                continue;
            }
            if (*opt == IPOPT_SEC
                || *opt == IPOPT_SEC + 3) { // Base and extended Security options (RFC 1108)
                *action = action_todo;
                pr_info("[dpimod] IP Security option (%d) is set. Drop (action: %d)...\n", *opt, *action);
                break;
            }
            pr_info("[dpimod] Option (%d) is set.\n", *opt);
            optslen -= (opt[1] > 0) ? opt[1] : optslen; // Stop if opt length is 0 (malformed option)
            opt += opt[1];
        }
    }
}

MODULE_LICENSE("GPL");
