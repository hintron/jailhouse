VERSION=$(../../tools/jailhouse --version)
echo "MGH: Starting $VERSION in QEMU"
sudo ../../tools/jailhouse enable ../../configs/x86/inspiron-root.cell