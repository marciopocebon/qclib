# Copyright IBM Corp. 2013, 2015

# Versioning scheme: major.minor.bugfix
#     major : Backwards compatible changes to the API
#     minor : Additions leaving the API unmodified
#     bugfix: Bugfixes only
VERSION = 1.0.0
CFLAGS  = -g -Wall -O2
CFILES  = query_capacity_data.c query_capacity.c query_capacity_sthyi.c query_capacity_sysinfo.c query_capacity_hypfs.c
OBJECTS = $(patsubst %.c,%.o,$(CFILES))
.SUFFIXES: .o .c

ifneq ("${V}","1")
        MAKEFLAGS += --quiet
	cmd=echo $1$2;
else
	cmd=;
endif
CC	= $(call cmd,"  CC    ",$@)gcc
LINK	= $(call cmd,"  LINK  ",$@)gcc
AR	= $(call cmd,"  AR    ",$@)ar
DOC	= $(call cmd,"  DOC   ",$@)doxygen
TAR	= $(call cmd,"  TAR   ",$@)tar
GEN	= $(call cmd,"  GEN   ",$@)grep

all: libqc.a libqc.so.$(VERSION) qc_test qc_test-sh

hcpinfbk_qclib.h: hcpinfbk.h
	$(GEN) -ve "^#pragma " $< > $@	# strip off z/VM specific pragmas

%.o: %.c query_capacity.h query_capacity_int.h query_capacity_data.h hcpinfbk_qclib.h
	$(CC) $(CFLAGS) -fpic -c $< -o $@

libqc.a: $(OBJECTS)
	$(AR) rcs $@ $^

libqc.so.$(VERSION): $(OBJECTS)
	$(LINK) -shared $^ -o $@

qc_test: qc_test.c libqc.a
	$(CC) $(CFLAGS) -static $< -L. -lqc -o $@

qc_test-sh: qc_test.c libqc.so.$(VERSION)
	$(CC) $(CFLAGS) -L. -l:libqc.so.$(VERSION) $< -o $@

test: qc_test
	./$<

test-sh: qc_test-sh
	LD_LIBRARY_PATH=. ./$<



doc:
	@if [ "`which doxygen 2>/dev/null`" != "" ]; then \
		$(DOC) config.doxygen 2>&1 | sed 's/^/    /'; \
	else \
		echo "Error: 'doxygen' not installed"; \
	fi
