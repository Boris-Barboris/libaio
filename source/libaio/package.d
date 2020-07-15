/*
Copyright 2020 Boris-Barboris

Boost Software License - Version 1.0 - August 17th, 2003

Permission is hereby granted, free of charge, to any person or organization
obtaining a copy of the software and accompanying documentation covered by
this license (the "Software") to use, reproduce, display, distribute,
execute, and transmit the Software, and to prepare derivative works of the
Software, and to permit third-parties to whom the Software is furnished to
do so, all subject to the following:

The copyright notices in the Software and this entire statement, including
the above license grant, this restriction and the following disclaimer,
must be included in all copies of the Software, in whole or in part, and
all derivative works of the Software, unless such copies or derivative
works are solely in the form of machine-executable object code generated by
a source language processor.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE, TITLE AND NON-INFRINGEMENT. IN NO EVENT
SHALL THE COPYRIGHT HOLDERS OR ANYONE DISTRIBUTING THE SOFTWARE BE LIABLE
FOR ANY DAMAGES OR OTHER LIABILITY, WHETHER IN CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.
*/
module libaio;

import core.stdc.config;
import core.sys.posix.time: timespec;
import core.sys.posix.signal: sigset_t;
import core.sys.posix.sys.uio: iovec;
import core.sys.linux.sys.socket: sockaddr;


// Online examples:
// https://www.fsl.cs.sunysb.edu/~vass/linux-aio.txt
// https://manpages.ubuntu.com/manpages/precise/man3/io.3.html
// https://pagure.io/libaio/blob/master/f/man/io.3


@nogc nothrow:

alias io_context_t = void*;

enum io_iocb_cmd: short
{
    IO_CMD_PREAD = 0,
    IO_CMD_PWRITE = 1,

    IO_CMD_FSYNC = 2,
    IO_CMD_FDSYNC = 3,

    IO_CMD_POLL = 5,
    IO_CMD_NOOP = 6,
    IO_CMD_PREADV = 7,
    IO_CMD_PWRITEV = 8,
};

// from /usr/include/linux/aio_abi.h
enum io_iocb_flags: uint
{
    IOCB_FLAG_RESFD = (1 << 0),
    IOCB_FLAG_IOPRIO = (1 << 1)
}

align(8) struct io_iocb_poll
{
    int events;
};

static assert (io_iocb_poll.sizeof == 8);

struct io_iocb_sockaddr
{
    sockaddr* addr;
    int len;
};

struct io_iocb_common
{
    align(8):
        void* buf;
        c_ulong nbytes;
        long offset;
        long __pad3;
    align(4):
        uint flags;
        uint resfd;
};

static assert (io_iocb_common.sizeof == 40);

struct io_iocb_vector
{
    iovec* vec;
    int nr;
    long offset;
};

static assert (io_iocb_vector.sizeof == 8 + 4 + 8 + 4);

struct iocb
{
    align(8):
        void *data;
        private uint key;   // used by kernel
    align(4):
        uint aio_rw_flags;  // RWF_ flags from /usr/include/linux/fs
    align:
        io_iocb_cmd aio_lio_opcode;
        short aio_reqprio;
        int aio_fildes;

        union {
            io_iocb_common c;
            io_iocb_vector v;
            io_iocb_poll poll;
            io_iocb_sockaddr saddr;
        };
};

static assert (iocb.sizeof == 8 + 4 + 4 + 2 * 2 + 4 + io_iocb_common.sizeof);

struct io_event
{
    align(8):
        void* data;
        iocb* obj;
        c_ulong res;
        c_ulong res2;
}

static assert (io_event.sizeof == 32);



alias io_callback_t = extern(C) nothrow @nogc void function(
    io_context_t ctx, iocb* iocb, c_long res, c_long res2);

alias da_io_queue_init = extern(C) nothrow @nogc int function(
    int maxevents, io_context_t* ctxp);

alias da_io_queue_release = extern(C) nothrow @nogc int function(
    io_context_t ctx);

alias da_io_queue_run = extern(C) nothrow @nogc int function(
    io_context_t ctx);

alias da_io_setup = extern(C) nothrow @nogc int function(
    int maxevents, io_context_t* ctxp);

alias da_io_destroy = extern(C) nothrow @nogc int function(
    io_context_t ctx);

alias da_io_submit = extern(C) nothrow @nogc int function(
    io_context_t ctx, c_long nr, iocb** ios);

alias da_io_cancel = extern(C) nothrow @nogc int function(
    io_context_t ctx, iocb *iocb, io_event* evt);

alias da_io_getevents = extern(C) nothrow @nogc int function(
    io_context_t ctx_id, c_long min_nr, c_long nr, io_event* events,
    timespec* timeout);

alias da_io_pgetevents = extern(C) nothrow @nogc int function(
    io_context_t ctx_id, c_long min_nr, c_long nr,
    io_event* events, timespec* timeout, sigset_t* sigmask);


__gshared
{
    da_io_queue_init io_queue_init;
    da_io_queue_release io_queue_release;
    da_io_queue_run io_queue_run;
    da_io_setup io_setup;
    da_io_destroy io_destroy;
    da_io_submit io_submit;
    da_io_cancel io_cancel;
    da_io_getevents io_getevents;
    da_io_pgetevents io_pgetevents;
}


// UFCS-optimized functions from libaio.h

pragma(inline) void io_set_callback(ref iocb iocb, io_callback_t cb)
{
    iocb.data = cast(void*) cb;
}

pragma(inline) void io_prep_pread(
    ref iocb iocb, int fd, void* buf, size_t count, long offset)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_PREAD;
    iocb.aio_reqprio = 0;
    iocb.c.buf = buf;
    iocb.c.nbytes = count;
    iocb.c.offset = offset;
}

pragma(inline) void io_prep_pwrite(
    ref iocb iocb, int fd, void* buf, size_t count, long offset)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_PWRITE;
    iocb.aio_reqprio = 0;
    iocb.c.buf = buf;
    iocb.c.nbytes = count;
    iocb.c.offset = offset;
}

pragma(inline) void io_prep_preadv(
    ref iocb iocb, int fd, iovec* iov, int iovcnt, long offset)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_PREADV;
    iocb.aio_reqprio = 0;
    iocb.c.buf = cast(void*) iov;
    iocb.c.nbytes = iovcnt;
    iocb.c.offset = offset;
}

pragma(inline) void io_prep_pwritev(
    ref iocb iocb, int fd, iovec* iov, int iovcnt, long offset)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_PWRITEV;
    iocb.aio_reqprio = 0;
    iocb.c.buf = cast(void*) iov;
    iocb.c.nbytes = iovcnt;
    iocb.c.offset = offset;
}

pragma(inline) void io_prep_preadv2(
    ref iocb iocb, int fd, iovec* iov, int iovcnt, long offset, int flags)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_PREADV;
    iocb.aio_reqprio = 0;
    iocb.aio_rw_flags = flags;
    iocb.c.buf = cast(void*) iov;
    iocb.c.nbytes = iovcnt;
    iocb.c.offset = offset;
}

pragma(inline) void io_prep_pwritev2(
    ref iocb iocb, int fd, iovec* iov, int iovcnt, long offset, int flags)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_PWRITEV;
    iocb.aio_reqprio = 0;
    iocb.aio_rw_flags = flags;
    iocb.c.buf = cast(void*) iov;
    iocb.c.nbytes = iovcnt;
    iocb.c.offset = offset;
}

pragma(inline) void io_prep_poll(ref iocb iocb, int fd, int events)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_POLL;
    iocb.aio_reqprio = 0;
    iocb.poll.events = events;
}

pragma(inline) int io_poll(
    io_context_t ctx, iocb* iocb, io_callback_t cb, int fd, int events)
{
    io_prep_poll(*iocb, fd, events);
    io_set_callback(*iocb, cb);
    return io_submit(ctx, 1, &iocb);
}

pragma(inline) void io_prep_fsync(ref iocb iocb, int fd)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_FSYNC;
    iocb.aio_reqprio = 0;
}

pragma(inline) int io_fsync(
    io_context_t ctx, iocb* iocb, io_callback_t cb, int fd)
{
    io_prep_fsync(*iocb, fd);
    io_set_callback(*iocb, cb);
    return io_submit(ctx, 1, &iocb);
}

pragma(inline) void io_prep_fdsync(ref iocb iocb, int fd)
{
    iocb = iocb.init;
    iocb.aio_fildes = fd;
    iocb.aio_lio_opcode = io_iocb_cmd.IO_CMD_FDSYNC;
    iocb.aio_reqprio = 0;
}

pragma(inline) int io_fdsync(
    io_context_t ctx, iocb* iocb, io_callback_t cb, int fd)
{
    io_prep_fdsync(*iocb, fd);
    io_set_callback(*iocb, cb);
    return io_submit(ctx, 1, &iocb);
}

pragma(inline) void io_set_eventfd(ref iocb iocb, int eventfd)
{
	iocb.c.flags |= io_iocb_flags.IOCB_FLAG_RESFD;
	iocb.c.resfd = eventfd;
}