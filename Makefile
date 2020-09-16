# Copyright IBM Corp. 2013, 2017

# Versioning scheme: major.minor.bugfix
#     major : Backwards compatible changes to the API
#     minor : Additions leaving the API unmodified
#     bugfix: Bugfixes only
VERSION  = 2.2.0
VERM     = $(shell echo $(VERSION) | cut -d '.' -f 1)
CFLAGS  ?= -g -Wall -O2
LDFLAGS ?=
CFILES  = query_capacity.c query_capacity_data.c query_capacity_sysinfo.c \
          query_capacity_sysfs.c query_capacity_hypfs.c query_capacity_sthyi.c
OBJECTS = $(patsubst %.c,%.o,$(CFILES))
.SUFFIXES: .o .c
DOCDIR	?= /usr/share/doc/packages/

ifneq ("${V}","1")
        MAKEFLAGS += --quiet
	cmd = echo $1$2;
else
	cmd =
endif
CC	= $(call cmd,"  CC    ",$@)gcc
LINK	= $(call cmd,"  LINK  ",$@)gcc
AR	= $(call cmd,"  AR    ",$@)ar
DOC	= $(call cmd,"  DOC   ",$@)doxygen
TAR	= $(call cmd,"  TAR   ",$@)tar
GEN	= $(call cmd,"  GEN   ",$@)grep

INSTALL_FLAGS_BIN = -g $(GROUP) -o $(OWNER) -m755
INSTALL_FLAGS_MAN = -g $(GROUP) -o $(OWNER) -m644
INSTALL_FLAGS_LIB = -g $(GROUP) -o $(OWNER) -m755

all: libqc.a libqc.so.$(VERSION) qc_test qc_test-sh zname zhypinfo

hcpinfbk_qclib.h: hcpinfbk.h
	$(GEN) -ve "^#pragma " $< > $@	# strip off z/VM specific pragmas

%.o: %.c query_capacity.h query_capacity_int.h query_capacity_data.h hcpinfbk_qclib.h
	$(CC) $(CFLAGS) -fpic -c $< -o $@

libqc.a: $(OBJECTS)
	$(AR) rcs $@ $^

libqc.so.$(VERSION): $(OBJECTS)
	$(LINK) $(LDFLAGS) -Wl,-soname,libqc.so.$(VERM) -shared $^ -o $@
	-rm libqc.so.$(VERM) 2>/dev/null
	ln -s libqc.so.$(VERSION) libqc.so.$(VERM)

zname: zname.c zhypinfo.h libqc.so.$(VERSION)
	$(CC) $(CFLAGS) -L. $< -o $@ libqc.so.$(VERSION)

zhypinfo: zhypinfo.c zhypinfo.h libqc.so.$(VERSION)
	$(CC) $(CFLAGS) -L. $< -o $@ libqc.so.$(VERSION)

qc_test: qc_test.c libqc.a
	$(CC) $(CFLAGS) -static $< -L. -lqc -o $@

qc_test-sh: qc_test.c libqc.so.$(VERSION)
	$(CC) $(CFLAGS) -L. $< -o $@ libqc.so.$(VERSION)

test: qc_test
	./$<

test-sh: qc_test-sh
	LD_LIBRARY_PATH=. ./$<

doc: html

html: $(CFILES) query_capacity.h query_capacity_int.h query_capacity_data.h hcpinfbk_qclib.h
	@if [ "`which doxygen 2>/dev/null`" != "" ]; then \
		$(DOC) config.doxygen 2>&1 | sed 's/^/    /'; \
	else \
		echo "Error: 'doxygen' not installed"; \
	fi

		cppcheck query_capacity*.[ch] 2>&1 | sed 's/^/   /'; \
	else \
		echo "cppcheck not available"; \
	fi
	@echo;
	-@if which smatch >/dev/null 2>&1; then \
		echo "Running smatch"; \
		smatch query_capacity*.[ch] 2>&1 | sed 's/^/   /'; \
	else \
		echo "smatch not available"; \
	fi
	@echo;
	-@if which sparse >/dev/null 2>&1; then \
		echo "Running sparse"; \
		sparse -Wsparse-all query_capacity*.[ch] 2>&1 | sed 's/^/   /'; \
	else \
		echo "sparse not available"; \
	fi
	@echo;
	-@if which valgrind >/dev/null 2>&1; then \
		echo "Running valgrind: qc_test"; \
		LD_LIBRARY_PATH=. valgrind --leak-check=full --show-leak-kinds=all ./qc_test-sh `find regtest_data -maxdepth 1 -mindepth 1 -type d | \
			grep -ve "^regtest_data/extras_" | sort` 2>&1 | grep -A 100 "HEAP SUMMARY:" | sed 's/^/   /'; \
		echo; \
		echo "zname: Running valgrind: zname -a"; \
		QC_USE_DUMP=regtest_data/dump_r3545038 LD_LIBRARY_PATH=. valgrind --leak-check=full --show-leak-kinds=all ./zname -a | \
			grep -A 100 "HEAP SUMMARY:" | sed 's/^/   /'; \
		echo; \
		echo "zname: Running valgrind: zhypinfo"; \
		QC_USE_DUMP=regtest_data/dump_r3545038 LD_LIBRARY_PATH=. valgrind --leak-check=full --show-leak-kinds=all ./zhypinfo | \
			grep -A 100 "HEAP SUMMARY:" | sed 's/^/   /'; \
		echo; \
		echo "zname: Running valgrind: zhypinfo -L"; \
		QC_USE_DUMP=regtest_data/dump_r3545038 LD_LIBRARY_PATH=. valgrind --leak-check=full --show-leak-kinds=all ./zhypinfo -L | \
			grep -A 100 "HEAP SUMMARY:" | sed 's/^/   /'; \
		echo; \
		echo "Running callgrind: qctest"; \
		LD_LIBRARY_PATH=. valgrind --callgrind-out-file=/dev/null --tool=callgrind ./zhypinfo -l `find regtest_data -maxdepth 1 -mindepth 1 -type d | \
			grep -ve "^regtest_data/extras_" | sort` 2>&1 | grep "refs:" | sed 's/^/   /'; \
	else \
		echo "valgrind not available"; \
	fi
	@echo;

install: libqc.a libqc.so.$(VERSION)
	echo "  INSTALL"
	install -Dm 644 libqc.a $(DESTDIR)/usr/lib64/libqc.a
	install -Dm 755 libqc.so.$(VERSION) $(DESTDIR)/usr/lib64/libqc.so.$(VERSION)
	ln -sr $(DESTDIR)/usr/lib64/libqc.so.$(VERSION) $(DESTDIR)/usr/lib64/libqc.so.$(VERM)
	ln -sr $(DESTDIR)/usr/lib64/libqc.so.$(VERSION) $(DESTDIR)/usr/lib64/libqc.so
	install -Dm 755 zname $(DESTDIR)/usr/bin/zname
	install -Dm 755 zhypinfo $(DESTDIR)/usr/bin/zhypinfo
	install -Dm 644 zname.8 $(DESTDIR)/usr/share/man8/zname.8
	install -Dm 644 zhypinfo.8 $(DESTDIR)/usr/share/man8/zhypinfo.8
	install -Dm 644 query_capacity.h $(DESTDIR)/usr/include/query_capacity.h
	install -Dm 644 README $(DESTDIR)/$(DOCDIR)/qclib/README
	install -Dm 644 LICENSE $(DESTDIR)/$(DOCDIR)/qclib/LICENSE

installdoc: doc
	echo "  INSTALLDOC"
	install -dm 755 $(DESTDIR)/$(DOCDIR)/qclib/html
	cp -r html/* $(DESTDIR)/$(DOCDIR)/qclib/html
	chmod 644 $(DESTDIR)/$(DOCDIR)/qclib/html/search/*
	chmod 644 $(DESTDIR)/$(DOCDIR)/qclib/html/*
	chmod 755 $(DESTDIR)/$(DOCDIR)/qclib/html/search

clean:
	echo "  CLEAN"
	rm -f $(OBJECTS) libqc.a libqc.so.$(VERSION) qc_test qc_test-sh hcpinfbk_qclib.h
	rm -rf html libqc.so.$(VERM)
	rm -rf zname zhypinfo
