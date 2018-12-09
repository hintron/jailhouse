# JH= "tools/jailhouse"
VERSION=$(./tools/jailhouse --version)

echo "MGH: Starting $VERSION in QEMU"
./tools/jailhouse enable configs/x86/qemu-x86.cell
echo "MGH: Starting Bazooka cell"
./tools/jailhouse cell create configs/x86/bazooka-demo.cell
./tools/jailhouse cell load bazooka-demo inmates/demos/x86/bazooka-demo.bin
./tools/jailhouse cell start bazooka-demo