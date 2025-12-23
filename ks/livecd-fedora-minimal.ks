lang en_US.UTF-8
keyboard us
timezone US/Eastern
authselect --useshadow --passalgo=sha512
rootpw --iscrypted $6$IofbdE7LaRem0MPo$O/ZoYrgFxt/l9ToTkl7hJSIzZ3hSjNQo2TAYPPsKJaCzt/R6h7jsH1dcOEWuy46VkMw.eePYN7QDtAveV16Fx0
selinux --enforcing
firewall --enabled
clearpart --drives=sd*|hd*|vd* --all --initlabel --disklabel=gpt
part /boot/efi --fstype=efi --grow --maxsize=128 --size=20
part / --size 2048
bootloader --location=partition --append="iomem=relaxed nopti noibrs noibpb"

repo --name=fedora --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=fedora-$releasever&arch=$basearch
repo --name=fedora-updates --mirrorlist=http://mirrors.fedoraproject.org/mirrorlist?repo=updates-released-f$releasever&arch=$basearch


%packages --excludedocs
@Core
kernel
dracut-live
python3-pip
grub2-efi-x64
grub2-efi-x64-cdboot
shim-x64
wget
isomd5sum
dmidecode
pciutils-libs
libusb
libjaylink
libftdi
-libX*
-btrfs-progs
-snappy
-trousers
%end

%post
set -euxo pipefail
mkdir -p /root/workspace

# Mirror the HTTP tree into /root/workspace as flatly as possible
wget -r -np -nH --cut-dirs=0 --directory-prefix=/root/workspace http://127.0.0.1:8080/

# If wget still created a host directory (localhost or localhost:8080), flatten it
if [ -d /root/workspace/localhost ]; then
  mv /root/workspace/localhost/* /root/workspace/ || true
  rm -rf /root/workspace/localhost
fi
if [ -d /root/workspace/localhost:8080 ]; then
  mv /root/workspace/localhost:8080/* /root/workspace/ || true
  rm -rf /root/workspace/localhost:8080
fi

# Sanity check: fail early if expected content is not present
test -f /root/workspace/scripts/start.sh
test -d /root/workspace/flashrom
test -d /root/workspace/bios
ls -la /root/workspace/scripts

# Start the real work
cp -r /root/workspace/flashrom /root/flashrom
chmod +x /root/flashrom/flashrom
cp -r /root/workspace/bios /root/bios

pip3 install /root/workspace/chipsec/*.whl
mkdir -p /root/chipsec
ln -sf /usr/bin/chipsec_util /root/chipsec/chipsec_util.py
ln -sf /usr/bin/chipsec_main /root/chipsec/chipsec_main.py

cp /root/workspace/scripts/start.sh /root/start.sh
chmod +x /root/start.sh

rm -rf /root/workspace
find /root -type f -name "index.html" -delete

printf "\nif [ -f ~/start.sh ]; then\n\tchmod +x ~/start.sh\n\t~/start.sh\nfi\n\nexport updated=r3\n" >> /root/.bashrc

systemctl mask NetworkManager-wait-online.service
%end
