
LIBDIR=./lib

OS_NAME=$(shell uname -s)
MH_NAME=$(shell uname -m)

ifeq (${OS_NAME}, Darwin)
LPEG_BUILD=macosx
else
LPEG_BUILD=linux
endif


all: ${LIBDIR}/lpeg.so ${LIBDIR}/ray.so

${LIBDIR}/lpeg.so:
	make -C ${LIBDIR}/lpeg-0.12 ${LPEG_BUILD}
	cp ${LIBDIR}/lpeg-0.12/lpeg.so ${LIBDIR}

${LIBDIR}/ray.so:
	git submodule update --init ${LIBDIR}/ray
	make -C ${LIBDIR}/ray
	cp ${LIBDIR}/ray/ray.so ${LIBDIR}

clean:
	make -C ${LIBDIR}/lpeg-0.12 clean
	make -C ${LIBDIR}/ray clean
	rm -f ${LIBDIR}/ray.so
	rm -f ${LIBDIR}/lpeg.so
