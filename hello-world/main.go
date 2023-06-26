// Hello, eBPF World!
package main

import (
	"log"
	"os"
	"os/signal"
	"syscall"

	"github.com/cilium/ebpf/link"
	"github.com/cilium/ebpf/rlimit"
)

//go:generate bpf2go bpf hello.bpf.c

func main() {
	stopChan := make(chan os.Signal, 1)
	signal.Notify(stopChan, os.Interrupt, syscall.SIGTERM, syscall.SIGINT)

	// Name of the kernel function to trace.
	fn := "sys_enter_execve"

	// Allow the current process to lock memory for eBPF resources.
	if err := rlimit.RemoveMemlock(); err != nil {
		log.Fatal(err)
	}

	// Load pre-compiled programs and maps into the kernel.
	objs := bpfObjects{}
	if err := loadBpfObjects(&objs, nil); err != nil {
		log.Fatalf("loading objects: %v", err)
	}
	defer objs.Close()

	// Attach the eBPF program to the tracepoint.
	tp, err := link.Tracepoint("syscalls", fn, objs.Hello, nil)
	if err != nil {
		log.Fatalf("opening tracepoint: %s", err)
	}
	defer tp.Close()

	// Remind me how to follow along.
	log.Printf("sudo cat /sys/kernel/debug/tracing/trace_pipe")

	// Wait until interrupted.
	<-stopChan
	log.Println("Exiting...")
}
