INCLUDES := ./ ./include

SRCS := pio.asm i2c.asm keyboard.asm romdisk.asm mmu.asm interrupt_vect.asm

# If the UART is configured as the standard output, it shall be the first driver to initialize
ifdef CONFIG_TARGET_STDOUT_UART
	SRCS := uart.asm $(SRCS)
else
	SRCS += uart.asm
endif

# Same goes for the video driver
ifdef CONFIG_TARGET_STDOUT_VIDEO
	SRCS := video.asm $(SRCS)
else
	# Check if it was even activated in the menuconfig
	ifdef CONFIG_TARGET_ENABLE_VIDEO
		SRCS += video.asm
	endif
endif

# Load the video driver first, in order to get an output early on

	# Command to be executed before compiling the whole OS.
	# In our case, compile the programs that will be part of ROMDISK and create it.
	# After creation, get its size, thanks to `stat` command, and store it in a generated header file
	# named `romdisk_info_h.asm`
PRECMD := (cd $(PWD)/romdisk && make) && \
          SIZE=$$(stat -c %s $(PWD)/romdisk/disk.img) && \
          (echo -e "IFNDEF ROMDISK_H\nDEFINE ROMDISK_H\nDEFC ROMDISK_SIZE=$$SIZE\nENDIF" > $(PWD)/include/romdisk_info_h.asm) && \
		  unset SIZE

	# After compiling the whole OS, we need to remove the unecessary binaries:
	# In our case, it's the binary containing BSS addresses, so we only have to keep
	# the one containing the actual code. The filename comes from the linker's first
	# section name: RST_VECTORS
	# FULLBIN defines the expected final binary path/name.
	# After selecting the rigth binary, we have to truncate it to a size that will let us
	# easily concatenate the ROMDISK after it.
	# Of course, the final step is to concatenate the ROMDISK to the final binary after that.
POSTCMD := @echo "RAM used by kernel: $$(du -bs $(BINDIR)/*KERNEL_BSS*.bin | cut -f1) bytes" && \
	   rm $(BINDIR)/*KERNEL_BSS*.bin && mv $(BINDIR)/*RST_VECTORS*.bin $(FULLBIN) && \
	   echo "OS size: $$(du -bs $(FULLBIN) | cut -f1) bytes" && \
	   truncate -s $$(( $(CONFIG_ROMDISK_ADDRESS) - $(CONFIG_KERNEL_PHYS_ADDRESS) )) $(FULLBIN) && \
	   cat $(PWD)/romdisk/disk.img >> $(FULLBIN)