# Example Makefile

~~~makefile
CROSS   ?= aarch64-none-elf-
CC      := $(CROSS)gcc
CFLAGS  := -Icommon -ffreestanding -Wall

TESTS := ppi/ppi_basic_group1ns spi/spi_basic_group1ns sgi/sgi_basic_group1ns \
         lpi/lpi_basic vlpi/vlpi_basic vsgi/vsgi_basic

all: $(TESTS:=.o)

%.o: %.S common/gic_common.S common/gic_its.S
	$(CC) $(CFLAGS) $< -Icommon -o $@
# LPI/vLPI/vSGI tests also need gic_its.o:
# $(LD) test.o gic_common.o gic_its.o -o test.axf
	$(CC) $(CFLAGS) -c $< -o $@

# Override SoC bases / INTIDs on the command line, e.g.:
#   make CFLAGS='-Icommon -DGICD_BASE=0x... -DGICR_RD_BASE=0x... -DPPI_INTID=29'
clean:
	rm -f *.o */*.o
~~~

Notes:
- Tests are preprocessed assembly (.S); gcc -c runs cpp then as.
- Link against your bare-metal framework that provides end_test,
  core_synchronisation, exec_pe_var, and the exception vector table
  (curr_el_spx_irq_vector / curr_el_spx_fiq_vector).
