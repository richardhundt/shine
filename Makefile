
LIBDIR =./lib
CURDIR = $(shell pwd)
DEPDIR = ${CURDIR}/deps
TVMDIR = ${DEPDIR}/tvmjit/src

export PREFIX = /usr/local

export LUADIR=${TVMDIR}
export PATH:=${TVMDIR}:${PATH}
export BUILD= ${CURDIR}/build
export DEPDIR

export LUA_PATH = ${TVMDIR}/?.lua;;
export TVM_PATH = ${TVMDIR}/?.lua;${CURDIR}/boot/src/?.raw;;
export TVM_CPATH = ${CURDIR}/boot/lib/?.so;;

export DEBUG=
#export DEBUG=-g

TJ = ${TVMDIR}/tvmjit
TJC = ${TJ} -b ${DEBUG}
SHC = boot/bin/shinec ${DEBUG}

VERSION=0.1

CFLAGS=-O2 -Wall
SOFLAGS=-O2 -Wall

LDPRE=
LDPOST=
LDCONFIG=
LPTHREAD=-lpthread

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

ifeq (${OS_NAME}, Darwin)
LPEG_BUILD=macosx
LIBEXT=dylib
LDPRE+=-Wl,-all_load
SOFLAGS+=-dynamic -bundle -undefined dynamic_lookup
ifeq (${MH_NAME}, x86_64)
CFLAGS+=-pagezero_size 10000 -image_base 100000000
endif
else
ifneq (,$(findstring MINGW,$(OS_NAME)))
LPTHREAD :=
endif
LPEG_BUILD=linux
LIBEXT=so
LDPRE+=-Wl,--whole-archive
LDPOST+=-Wl,--no-whole-archive -Wl,-E -lrt -lanl
SOFLAGS+=-shared -fPIC
LDCONFIG+=ldconfig -n ${PREFIX}/lib
LPTHREAD=-pthread
endif

LDFLAGS=-lm -ldl ${LPTHREAD}

export SOFLAGS
export LDFLAGS
export LDPRE
export LDPOST
export LPTHREAD

LPEG := ${DEPDIR}/lpeg/lpeg.so

EXEC := ${BUILD}/shine

NGAC := ${BUILD}/shinec

NDEPS = ${BUILD}/deps/liblpeg.a \
	${BUILD}/deps/libtvmjit.a

XDEPS = ${NDEPS} \
	${BUILD}/lang.a \
	${BUILD}/core.a \
	${BUILD}/shine.o \
	${BUILD}/shinec.o

CDEPS = ${NDEPS} \
	${BUILD}/lang.a \
	${BUILD}/core.a \
	${BUILD}/shinec.o

all: dirs ${TJ} ${LPEG} ${LIBS} ${EXEC} ${NGAC} libs

dirs:
	mkdir -p ${BUILD}/deps
	mkdir -p ${BUILD}/lang
	mkdir -p ${BUILD}/core
	mkdir -p ${BUILD}/libs

libs:
	git submodule update --init ${DEPDIR}/upoll
	git submodule update --init ${DEPDIR}/uthread
	git submodule update --init ${DEPDIR}/nanomsg
	make -C ./lib

${BUILD}/shine: ${TJ} ${XDEPS}
	${CC} ${CFLAGS} -I${TVMDIR} -L${TVMDIR} -o ${BUILD}/shine src/shine.c ${LDPRE} ${XDEPS} ${LDPOST} ${LDFLAGS}

${BUILD}/shinec: ${TJ} ${CDEPS}
	${CC} ${CFLAGS} -I${TVMDIR} -L${TVMDIR} -o ${BUILD}/shinec src/shinec.c ${LDPRE} ${CDEPS} ${LDPOST} ${LDFLAGS}

${BUILD}/lang.a: ${TJ}
	mkdir -p ${BUILD}/lang
	${TJC} -n "shine.lang.re" src/lang/re.lua ${BUILD}/lang/re.o
	${TJC} -n "shine.lang.parser" src/lang/parser.lua ${BUILD}/lang/parser.o
	${TJC} -n "shine.lang.tree" src/lang/tree.lua ${BUILD}/lang/tree.o
	${TJC} -n "shine.lang.loader" src/lang/loader.lua ${BUILD}/lang/loader.o
	${TJC} -n "shine.lang.translator" src/lang/translator.lua ${BUILD}/lang/translator.o
	${TJC} -n "shine.lang.util" src/lang/util.lua ${BUILD}/lang/util.o
	${TJC} -n "jit.bc" ${TVMDIR}/jit/bc.lua ${BUILD}/lang/bc.o
	${TJC} -n "jit.vmdef" ${TVMDIR}/jit/vmdef.lua ${BUILD}/lang/jit_vmdef.o
	${TJC} -n "jit.bcsave" ${TVMDIR}/jit/bcsave.lua ${BUILD}/lang/jit_bcsave.o
	${TJC} -n "lunokhod" ${TVMDIR}/lua/lunokhod.lua ${BUILD}/lang/lunokhod.o
	ar rcus ${BUILD}/lang.a ${BUILD}/lang/*.o

${BUILD}/shine.o: ${BUILD}/shinec.o
	${TJC} -n "shine" src/shine.lua ${BUILD}/shine.o

${BUILD}/shinec.o:
	${TJC} -n "shinec" src/shinec.lua ${BUILD}/shinec.o

${BUILD}/core.a: ${BUILD}/core/init.o
	ar rcus ${BUILD}/core.a ${BUILD}/core/*.o

${BUILD}/core/init.o:
	${TJC} -n "core" src/core/init.lua ${BUILD}/core/init.o

${BUILD}/deps/liblpeg.a: ${LPEG}
	ar rcus ${BUILD}/deps/liblpeg.a ${DEPDIR}/lpeg/*.o

${BUILD}/deps/libtvmjit.a: ${TJ}
	cp ${TVMDIR}/libtvmjit.a ${BUILD}/deps/libtvmjit.a

${TJ}:
	git submodule update --init ${DEPDIR}/tvmjit
	${MAKE} PREFIX=${BUILD} TRAVIS=1 -C ${DEPDIR}/tvmjit

${LPEG}:
	make -C ${DEPDIR}/lpeg ${LPEG_BUILD}
	cp ${DEPDIR}/lpeg/lpeg.so boot/lib/

clean:
	make -C ./lib clean
	rm -rf ${BUILD}/core/*
	rm -rf ${BUILD}/lang/*
	rm -f ${BUILD}/*.a
	rm -f ${BUILD}/*.o
	rm -f ${BUILD}/shine
	rm -f ${BUILD}/shinec
	rm -f ${BUILD}/libs/*

install: all
	mkdir -p ${PREFIX}/lib/shine
	mkdir -p ${PREFIX}/lib/lua/5.1
	make -C ./lib install
	install -m 0755 ${BUILD}/shine ${PREFIX}/bin/shine
	install -m 0755 ${BUILD}/shinec ${PREFIX}/bin/shinec
	${LDCONFIG}

uninstall:
	make -C ./lib uninstall
	rm -f ${PREFIX}/bin/shine
	rm -f ${PREFIX}/bin/shinec
	${LDCONFIG}

realclean: clean
	make -C ./lib clean
	make -C ${DEPDIR}/tvmjit clean
	make -C ${DEPDIR}/lpeg clean
	stat ${DEPDIR}/nanomsg/Makefile && make -C ${DEPDIR}/nanomsg clean
	rm -rf ${BUILD}

bootstrap: ${TJ} ${LPEG}
	mkdir -p boot/bin
	mkdir -p boot/lib
	mkdir -p boot/src/shine/lang
	${TJC} src/shinec.lua           boot/src/shinec.raw
	${TJC} src/lang/re.lua          boot/src/shine/lang/re.raw
	${TJC} src/lang/parser.lua      boot/src/shine/lang/parser.raw
	${TJC} src/lang/tree.lua        boot/src/shine/lang/tree.raw
	${TJC} src/lang/loader.lua      boot/src/shine/lang/loader.raw
	${TJC} src/lang/translator.lua  boot/src/shine/lang/translator.raw
	${TJC} src/lang/util.lua        boot/src/shine/lang/util.raw

.PHONY: all libs dirs clean realclean bootstrap install uninstall

