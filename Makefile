MEM := 64G
CPUS := 1
QEMU := /mydata/qemu_main/qemu/build/qemu-system-x86_64

FILE := tinfoilcvm
CONFIG := config.yml
EXTERNAL_CONFIG := external.yml
PORT := 8444

CMD := "readonly=on console=ttyS0 earlyprintk=serial root=/dev/sda2 tinfoil-debug=on tinfoil-config-hash=$(shell sha256sum $(CONFIG) | cut -d ' ' -f 1)"

all: clean build

build:
	mkosi

clean:
	rm -rf tinfoilcvm.*
	rm -rf vllm_source

run:
	stty intr ^]
	sudo $(QEMU) \
		-enable-kvm \
		-cpu EPYC-v4 \
		-machine q35 -smp $(CPUS),maxcpus=$(CPUS) \
		-m $(MEM) \
		-no-reboot \
		-bios ./OVMF.fd \
		-kernel $(FILE).vmlinuz \
		-initrd $(FILE).initrd \
		-append $(CMD) \
		-drive file=$(FILE).raw,if=none,id=disk0,format=raw,readonly=on \
		-device virtio-scsi-pci,id=scsi0,disable-legacy=on,iommu_platform=true \
		-device scsi-hd,drive=disk0 \
		-drive file=$(CONFIG),if=none,id=disk1,format=raw,readonly=on \
		-drive file=$(EXTERNAL_CONFIG),if=none,id=disk2,format=raw,readonly=on \
		-device virtio-scsi-pci,id=scsi1,disable-legacy=on,iommu_platform=true \
		-device scsi-hd,drive=disk1 \
		-machine memory-encryption=sev0,vmport=off \
		-object memory-backend-memfd,id=ram1,size=$(MEM),share=true,prealloc=false \
		-machine memory-backend=ram1 -object sev-snp-guest,id=sev0,policy=0x30000,cbitpos=51,reduced-phys-bits=5,kernel-hashes=on \
		-net nic,model=e1000 -net user,hostfwd=tcp::$(PORT)-:443 \
		-nographic -monitor pty -monitor unix:monitor,server,nowait
	stty intr ^c
