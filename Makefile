# Tools
CC = gcc
LD = ld
OBJCOPY = objcopy
EMU = qemu-system-x86_64

# Directories
SRC_DIR = src
OBJ_DIR = obj
BIN_DIR = bin
GNU_EFI_DIR = gnu-efi

# EFI code file for emulator
# Ensure to modify this as needed, OVMF is utilized by default
# https://github.com/tianocore/tianocore.github.io/wiki/OVMF
EFI_EMU_CODE = /usr/share/OVMF/x64/OVMF_CODE.4m.fd

# Device to flash image to with the "flash" target
FLASH_DEV = /dev/sda

# Output EFI binary and bootable image
OUT_BIN = $(BIN_DIR)/BootX64.efi
OUT_IMG = $(BIN_DIR)/boot.img

# C compiler parameters
CCFLAGS = -I$(GNU_EFI_DIR)/inc -fpic -ffreestanding -fno-stack-protector \
	-fno-stack-check -fshort-wchar -mno-red-zone -maccumulate-outgoing-args -c

# Linker parameters
LDFLAGS = -shared -Bsymbolic -L$(GNU_EFI_DIR)/x86_64/lib -L$(GNU_EFI_DIR)/x86_64/gnuefi \
	  -T$(GNU_EFI_DIR)/gnuefi/elf_x86_64_efi.lds $(GNU_EFI_DIR)/x86_64/gnuefi/crt0-efi-x86_64.o \
	  -lgnuefi -lefi

# Objcopy parameters
OBJCOPYFLAGS = -j ".text" -j ".sdata" -j ".data" -j ".rodata" -j ".dynamic" -j ".dynsym" -j ".rel" -j ".rela" -j ".rel.*" -j ".rela.*" -j ".reloc" --target efi-app-x86_64 --subsystem=10

# Emulator paramerers
EMUFLAGS = -drive if=pflash,format=raw,file=$(EFI_EMU_CODE) -drive format=raw,file=$(OUT_IMG) -m 256M

# PHONY targets
.PHONY: all gnuefi help run flash clean


# By default, build the output EFI binary
all: $(OUT_BIN)

# Help menu about this Makefile
help:
	@echo "Usage: make <target>"
	@echo " "
	@echo "Targets:"
	@echo "    <NO OPTIONS>	- same as $(OUT_BIN)"
	@echo "    help		- Display this help menu"
	@echo "    gnuefi		- If not already present, download source and compile GNU EFI"
	@echo "    $(OUT_BIN)	- Compile the EFI binary"
	@echo "    $(OUT_IMG)	- Create a bootable image"
	@echo "    run			- Build the image and run it in an emulator (QEMU by default, ensure your emulator has proper EFI firmware)"
	@echo "    flash		- flash the image to a storage medium (currently $(FLASH_DEV))"
	@echo "    clean		- Remove build files"
	@echo " "

# Download source and compile GNU EFI if not present
ifeq ($(wildcard $(GNU_EFI_DIR)),)
gnuefi:
	git clone --depth 1 https://git.code.sf.net/p/gnu-efi/code $(GNU_EFI_DIR)
	cd $(GNU_EFI_DIR) && make -j $(shell nproc)
endif

# Compile the output EFI binary
$(OUT_BIN): gnuefi
	mkdir -p $(OBJ_DIR) $(BIN_DIR)

	$(CC) $(CCFLAGS) $(SRC_DIR)/main.c -o $(OBJ_DIR)/main.o
	$(LD) $(LDFLAGS) $(OBJ_DIR)/main.o -o $(OBJ_DIR)/main.so
	$(OBJCOPY) $(OBJCOPYFLAGS) $(OBJ_DIR)/main.so $(OUT_BIN)

# Build the output bootable image
$(OUT_IMG): $(OUT_BIN)
	dd if=/dev/zero of=$(OUT_IMG) bs=1M count=64
	mkfs.vfat -F 32 $(OUT_IMG)

	mmd -i $(OUT_IMG) ::/EFI
	mmd -i $(OUT_IMG) ::/EFI/Boot
	mcopy -i $(OUT_IMG) $(OUT_BIN) ::/EFI/Boot/

# Run the image in the emulator
run: $(OUT_IMG)
	$(EMU) $(EMUFLAGS)

# Flash the image to FLASH_DEV
flash: $(OUT_IMG)
	dd if=$(OUT_IMG) of=$(FLASH_DEV) status=progress oflag=sync
	sync
	eject $(FLASH_DEV)

	@echo -e "\n$(OUT_IMG) successfully flashed to $(FLASH_DEV)!"
	@echo "You may now safely remove your device"

# Delete build files
clean:
	rm -rf $(OBJ_DIR) $(BIN_DIR) $(GNU_EFI_DIR)

