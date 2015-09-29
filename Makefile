ASM		= nasm
ASMDIR		= boot/include/
GCC		= gcc
LD		= ld

BOOT_T		= boot/boot.bin
IMAGE_T   	= a.img
LOADER_T  	= boot/loader.bin
KERNEL_T	= kernel/kernel.o kernel/start.o
LIB_T		= lib/kliba.o lib/string.o
FINAL_T		= kernel/kernel.bin

.PHONY:	image clean build_img

image : ${BOOT_T} ${LOADER_T} ${KERNEL_T} ${LIB_T} ${FINAL_T} build_img

clean : 
	rm -f $(LOADER_T) ${BOOT_T} ${KERNEL_T} ${LIB_T} ${FINAL_T}

# loader : ${LOADER_
#  boot :	$(BOOT_T)

build_img:
	dd if=boot/boot.bin of=a.img bs=512 count=1 conv=notrunc
	sudo mount -o loop a.img /mnt/floppy/
	sudo cp -f boot/loader.bin /mnt/floppy/
	sudo cp -f kernel/kernel.bin /mnt/floppy/
	sudo umount /mnt/floppy/

boot/boot.bin : boot/boot.asm ${ASMDIR}load.inc ${ASMDIR}fat12hdr.inc
	$(ASM) -I ${ASMDIR}  -o $@ $<
boot/loader.bin: boot/loader.asm ${ASMDIR}fat12hdr.inc ${ASMDIR}load.inc ${ASMDIR}pm.inc
	$(ASM) -I ${ASMDIR} -o $@ $<
kernel/kernel.o: kernel/kernel.asm
	$(ASM) -f elf -o $@ $<
kernel/start.o: kernel/start.c include/type.h include/const.h include/protect.h
	$(GCC) -I include/ -c -fno-builtin -o $@ $<
lib/kliba.o: lib/kliba.asm
	$(ASM) -f elf -o $@ $<
lib/string.o: lib/string.asm
	$(ASM) -f elf -o $@ $<
kernel/kernel.bin: ${KERNEL_T} 
	${LD} -s -Ttext 0x30400 -o $@ ${KERNEL_T} ${LIB_T}
