# See https://askubuntu.com/questions/760671/could-not-load-vboxdrv-after-upgrade-to-ubuntu-16-04-and-i-want-to-keep-secur/768310#768310

# cd  ~/code/jailhouse/mgh/scripts
# openssl req -new -x509 -newkey rsa:2048 -keyout MOK.priv -outform DER -out MOK.der -nodes -days 36500 -subj "/CN=MGH Custom Driver Key (for Jailhouse)/"

# Before signing these drivers, the keys need to be accepted by mokutil

sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der ../../driver/jailhouse.ko
modinfo ../../driver/jailhouse.ko
sudo /usr/src/linux-headers-$(uname -r)/scripts/sign-file sha256 ./MOK.priv ./MOK.der ../uio-kernel-module/uio_ivshmem.ko
modinfo ../uio-kernel-module/uio_ivshmem.ko
