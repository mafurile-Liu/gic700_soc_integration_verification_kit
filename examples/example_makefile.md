# Example Makefile

## Build flow

```
test.S  -->  [gcc -c]  -->  test.o  -----+
gic_common.S  -->  [gcc -c]  -->  gic_common.o  --+
gic_its.S  -->  [gcc -c]  -->  gic_its.o  --------+
user_handler.c  -->  [gcc -c]  -->  user_handler.o  --+
bootcode.s  -->  [as]  -->  bootcode.o  ----------+
vector.s  -->  [as]  -->  vector.o  -------------+
                                                   |
                                          [ld -T scatter.txt]
                                                   |
                                             test.axf
```

## Makefile

~~~makefile
CROSS   ?= aarch64-none-elf-
CC      := $(CROSS)gcc
AS      := $(CROSS)gcc
LD      := $(CROSS)ld
CFLAGS  := -Icommon -ffreestanding -Wall -O0
ASFLAGS := -Icommon
LDFLAGS := -T scatter.txt --entry=bootcode

# Common objects (linked into every test)
COMMON_OBJ := common/gic_common.o common/user_handler.o
# ITS objects (only needed for LPI/vLPI/vSGI tests)
ITS_OBJ    := common/gic_its.o
# Framework objects (provided by ARM delivery or your environment)
FRAMEWORK  := bootcode.o vector.o

# Test list
TESTS := ppi/ppi_basic_group1ns spi/spi_basic_group1ns sgi/sgi_basic_group1ns

# Rule: compile .S -> .o
%.o: %.S common/gic_common.h common/gic_reg.h common/gic_macros.h
	$(CC) $(ASFLAGS) -c $< -o $@

# Rule: compile .c -> .o
%.o: %.c
	$(CC) $(CFLAGS) -c $< -o $@

# Rule: link a basic test (SPI/PPI/SGI, no ITS needed)
%.axf: %.o $(COMMON_OBJ) $(FRAMEWORK)
	$(LD) $(LDFLAGS) $< $(COMMON_OBJ) $(FRAMEWORK) -o $@

# Rule: link an LPI/vLPI/vSGI test (needs gic_its.o)
lpi/%.axf vlpi/%.axf vsgi/%.axf: %.o $(COMMON_OBJ) $(ITS_OBJ) $(FRAMEWORK)
	$(LD) $(LDFLAGS) $< $(COMMON_OBJ) $(ITS_OBJ) $(FRAMEWORK) -o $@

# Override SoC bases on command line:
#   make CFLAGS='-Icommon -DGICD_BASE=0x... -DGICR_RD_BASE=0x...'

clean:
	rm -f *.o */*.o common/*.o
~~~

## How user_handler.c works

The assembly declares `gic_user_handler` as `.weak`:

~~~asm
.weak   gic_user_handler
...
bl      gic_user_handler     ! linker makes this NOP if undefined
~~~

The C file provides a weak default (does nothing):

~~~c
__attribute__((weak))
void gic_user_handler(unsigned int intid) {
    (void)intid;  // empty
}
~~~

**Three usage modes:**

1. **Default (no custom logic):** Link `user_handler.o` as-is. The weak C
   function is called but does nothing. Handler proceeds to default pass/fail.

2. **Custom logic (edit the file):** Edit `common/user_handler.c`, add your
   code, recompile. No other changes needed.

3. **Custom logic (separate file):** Create `my_handler.c` with a **strong**
   definition (no `__attribute__((weak))`). Exclude `user_handler.o` from the
   link. The linker picks your strong definition over the weak one.

~~~makefile
# Mode 3 example: replace user_handler.o with my_handler.o
COMMON_OBJ := common/gic_common.o my_handler.o
~~~

## Notes

- Tests are preprocessed assembly (.S); `gcc -c` runs cpp then as.
- `user_handler.c` is C; `gcc -c` compiles it. No libc needed (ffreestanding).
- The linker resolves `.weak gic_user_handler` to the C function if linked,
  or makes the `bl` a NOP if the symbol is absent.
- Link order doesn't matter for weak symbols; the linker handles it.
- `bootcode.o` and `vector.o` come from the ARM A720 delivery (bootcode.s,
  vector.s). They provide `end_test`, `core_synchronisation`, `test_start`
  entry, and the exception vector table.
