cd "${BASH_SOURCE%/*}" || exit
../../tools/jailhouse cell create configs/x86/ivshmem-demo.cell
../../tools/jailhouse cell load ivshmem-demo inmates/demos/x86/ivshmem-demo.bin
../../tools/jailhouse cell start ivshmem-demo