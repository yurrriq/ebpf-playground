// +build ignore

#include <linux/bpf.h>

#include <bpf/bpf_helpers.h>

SEC("tracepoint/syscalls/sys_enter_execve")
int hello(void *ctx) {
  bpf_printk("Hello, eBPF World!\n");
  return 0;
}

char LICENSE[] SEC("license") = "Dual MIT/GPL";
