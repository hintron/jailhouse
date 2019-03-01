cd "${BASH_SOURCE%/*}" || exit
../../tools/jailhouse cell create configs/x86/bazooka-demo.cell
../../tools/jailhouse cell load bazooka-demo inmates/demos/x86/bazooka-demo.bin
../../tools/jailhouse cell start bazooka-demo