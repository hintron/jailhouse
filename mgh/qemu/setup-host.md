# Make sure `kvm_intel.nested=1` on kernel cmdline

If you get these warnings:

    qemu-system-x86_64: warning: host doesn't support requested feature: CPUID.01H:ECX.vmx [bit 5]

It means that you need to let the kernel allow nested VM stuff in QEMU.

To do this ad-hoc, without restarting, do:

    cat /sys/module/kvm_intel/parameters/nested
    sudo rmmod kvm_intel
    sudo modprobe kvm_intel nested=1
    cat /sys/module/kvm_intel/parameters/nested

The nested param should have changed from N to Y.

To make this *permanent*, so you don't need to do the above on each fresh boot,
edit the Linux commandline parameters passed to the kernel on boot.

To do this, edit _/etc/default/grub_ and append
`kvm_intel.nested=1` to `GRUB_CMDLINE_LINUX_DEFAULT`. Then run
`sudo update-grub` and roboot.

On reboot, check to make sure the commandline parameters have changed:

    cat /proc/cmdline

Also check that the nested param is now Y instead of N:

    cat /sys/module/kvm_intel/parameters/nested
