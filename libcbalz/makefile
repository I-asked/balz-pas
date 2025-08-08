FPC ?= fpc
INSTALL ?= install

FPCFLAGS ?= -O3

ifeq ($(VERBOSE),1)
V =
else
V = @
endif

FPCFLAGS += -Fu..

PREFIX ?= /usr/local

libcbalz.so: cbalz.pp
	@echo FPC.LINK  $@
	$(V)$(FPC) -Xe -Xc -k-soname=$@ -o$@ $(FPCFLAGS) $^

.PHONY: clean install

clean:
	@echo CLEAN
	$(V)$(RM) *.o *.ppu

install:
	@echo INSTALL cbalz.h → $(PREFIX)/include/cbalz.h
	$(V)$(INSTALL) -m 644 cbalz.h $(PREFIX)/include/cbalz.h
	@echo INSTALL libcbalz.so → $(PREFIX)/include/libcbalz.so
	$(V)$(INSTALL) -m 644 libcbalz.so $(PREFIX)/lib/libcbalz.so
