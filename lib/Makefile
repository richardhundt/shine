SHC = ../boot/bin/shnc ${DEBUG}

LIBS := ${BUILD}/libs/sys.so \
	${BUILD}/libs/async.so \
	${BUILD}/libs/data.so \
	${BUILD}/libs/net.so \
	${BUILD}/libs/codec.so \
	${BUILD}/libs/util.so

all: ${LIBS}

${BUILD}/libs/sys.so: ${BUILD}/libnanomsg.a ${BUILD}/uthread.o
	${SHC} -n "sys"           sys/init.shn      ${BUILD}/sys.o
	${SHC} -n "sys.unix"      sys/unix.shn      ${BUILD}/sys_unix.o
	${SHC} -n "sys.win32"     sys/win32.shn     ${BUILD}/sys_win32.o
	${SHC} -n "sys.ffi"       sys/ffi/init.shn  ${BUILD}/sys_ffi.o
	${SHC} -n "sys.ffi.posix" sys/ffi/posix.shn ${BUILD}/sys_ffi_posix.o
	${SHC} -n "sys.ffi.osx"   sys/ffi/osx.shn   ${BUILD}/sys_ffi_osx.o
	${SHC} -n "sys.ffi.bsd"   sys/ffi/bsd.shn   ${BUILD}/sys_ffi_bsd.o
	${SHC} -n "sys.ffi.linux" sys/ffi/linux.shn ${BUILD}/sys_ffi_linux.o
	${SHC} -n "sys.argparse"  sys/argparse.shn  ${BUILD}/sys_argparse.o
	${SHC} -n "sys.thread"    sys/thread.shn    ${BUILD}/sys_thread.o
	${SHC} -n "sys.nanomsg"   sys/nanomsg.shn   ${BUILD}/sys_nanomsg.o
	${CC} ${SOFLAGS} -o ${BUILD}/libs/sys.so ${LDFLAGS} \
	${BUILD}/sys.o ${BUILD}/sys_unix.o ${BUILD}/sys_win32.o \
	${BUILD}/sys_ffi.o ${BUILD}/sys_ffi_posix.o ${BUILD}/sys_ffi_osx.o \
	${BUILD}/sys_ffi_bsd.o ${BUILD}/sys_ffi_linux.o ${BUILD}/sys_argparse.o \
	${BUILD}/sys_nanomsg.o ${BUILD}/sys_thread.o \
	${LDPRE} ${BUILD}/libnanomsg.a ${LDPOST} ${BUILD}/uthread.o ${LPTHREAD}

${BUILD}/libs/async.so: ${BUILD}/upoll.o
	${SHC} -n "async"       async/init.shn  ${BUILD}/async.o
	${SHC} -n "async.fiber" async/fiber.shn ${BUILD}/async_fiber.o
	${SHC} -n "async.loop"  async/loop.shn  ${BUILD}/async_loop.o
	${SHC} -n "async.util"  async/util.shn  ${BUILD}/async_util.o
	${SHC} -n "async.io"    async/io.shn    ${BUILD}/async_io.o
	${CC} ${SOFLAGS} -o ${BUILD}/libs/async.so ${LDFLAGS} \
	${BUILD}/upoll.o ${BUILD}/async.o ${BUILD}/async_fiber.o \
	${BUILD}/async_loop.o ${BUILD}/async_util.o ${BUILD}/async_io.o

${BUILD}/libs/data.so:
	${SHC} -n "data.queue" data/queue.shn ${BUILD}/data_queue.o
	${SHC} -n "data.buffer" data/buffer.shn ${BUILD}/data_buffer.o
	${SHC} -n "data.uuid" data/uuid.shn  ${BUILD}/data_uuid.o
	${CC} ${SOFLAGS} -o ${BUILD}/libs/data.so ${LDFLAGS} \
	${BUILD}/data_queue.o ${BUILD}/data_buffer.o ${BUILD}/data_uuid.o

${BUILD}/libs/util.so: ${BUILD}/trex.o
	${SHC} -n "util.time" util/time.shn  ${BUILD}/util_time.o
	${SHC} -n "util.regexp" util/regexp.shn  ${BUILD}/util_regexp.o
	${SHC} -n "util.random" util/random.shn  ${BUILD}/util_random.o
	${SHC} -n "util.guards" util/guards.shn  ${BUILD}/util_guards.o
	${CC} ${SOFLAGS} -o ${BUILD}/libs/util.so ${LDFLAGS} \
	${BUILD}/util_time.o ${BUILD}/util_regexp.o ${BUILD}/trex.o \
	${BUILD}/util_random.o ${BUILD}/util_guards.o

${BUILD}/libs/net.so:
	${SHC} -n "net.socket" net/socket.shn  ${BUILD}/net_socket.o
	${SHC} -n "net.http" net/http.shn  ${BUILD}/net_http.o
	${SHC} -n "net.uri" net/uri.shn  ${BUILD}/net_uri.o
	${CC} ${SOFLAGS} -o ${BUILD}/libs/net.so ${LDFLAGS} \
	${BUILD}/net_socket.o ${BUILD}/net_http.o ${BUILD}/net_uri.o

${BUILD}/libs/codec.so:
	${SHC} -n "codec.base64" codec/base64.shn  ${BUILD}/codec_base64.o
	${SHC} -n "codec.json" codec/json.shn  ${BUILD}/codec_json.o
	${SHC} -n "codec.tnetstrings" codec/tnetstrings.shn ${BUILD}/codec_tnets.o
	${SHC} -n "codec.serialize" codec/serialize.shn  ${BUILD}/codec_serialize.o
	${CC} ${SOFLAGS} -o ${BUILD}/libs/codec.so ${LDFLAGS} \
	${BUILD}/codec_base64.o ${BUILD}/codec_json.o ${BUILD}/codec_tnets.o \
	${BUILD}/codec_serialize.o

${BUILD}/upoll.o:
	${CC} -c -O3 -fPIC ${DEPDIR}/upoll/src/upoll.c -o ${BUILD}/upoll.o \
		-I${DEPDIR}/upoll/src/include -I${DEPDIR}/upoll/src

${BUILD}/uthread.o:
	${CC} -c -O2 -fPIC ${DEPDIR}/uthread/src/uthread.c \
	-o ${BUILD}/uthread.o -I${DEPDIR}/uthread/include

${BUILD}/trex.o:
	${CC} -c -O2 -fPIC -Wno-unused-value ${DEPDIR}/trex/trex.c \
	-o ${BUILD}/trex.o -I${DEPDIR}/trex

${DEPDIR}/nanomsg/Makefile:
	cd ${DEPDIR}/nanomsg && ./autogen.sh && ./configure --prefix=${BUILD}

${BUILD}/libnanomsg.a: ${DEPDIR}/nanomsg/Makefile
	cd ${DEPDIR}/nanomsg && make && make install
	cp ${DEPDIR}/nanomsg/.libs/libnanomsg.a ${BUILD}/libnanomsg.a

clean:
	rm -f ${BUILD}/upoll.o
	rm -f ${BUILD}/trex.o
	rm -f ${BUILD}/libs/*.so
	rm -f ${BUILD}/libnanomsg.a

install:
	install -m 0644 ${BUILD}/libs/sys.so ${PREFIX}/lib/shine/sys.so
	install -m 0644 ${BUILD}/libs/util.so ${PREFIX}/lib/shine/util.so
	install -m 0644 ${BUILD}/libs/net.so ${PREFIX}/lib/shine/net.so
	install -m 0644 ${BUILD}/libs/data.so ${PREFIX}/lib/shine/data.so
	install -m 0644 ${BUILD}/libs/async.so ${PREFIX}/lib/shine/async.so
	install -m 0644 ${BUILD}/libs/codec.so ${PREFIX}/lib/shine/codec.so

uninstall:
	rm -f ${PREFIX}/lib/shine/*.so

