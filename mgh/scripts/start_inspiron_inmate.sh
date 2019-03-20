cd "${BASH_SOURCE%/*}" || exit
../../tools/jailhouse cell create ../../configs/x86/inspiron-inmate.cell
../../tools/jailhouse cell load inspiron-inmate ../../inmates/demos/x86/mgh-demo.bin
../../tools/jailhouse cell start inspiron-inmate