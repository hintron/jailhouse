cd "${BASH_SOURCE%/*}" || exit
VERSION=$(./tools/jailhouse --version)
echo "MGH: Starting $VERSION in QEMU"
../../tools/jailhouse enable configs/x86/qemu-mgh.cell