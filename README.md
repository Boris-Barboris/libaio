# libaio
Dynamic binding to Linux libaio library for D programming language.
* http://lse.sourceforge.net/io/aio.html
* https://www.fsl.cs.sunysb.edu/~vass/linux-aio.txt
* https://manpages.ubuntu.com/manpages/precise/man3/io.3.html
* https://pagure.io/libaio/blob/master/f/man/io.3

# Example

```d
import std.conv: octal;
import std.exception: enforce, errnoEnforce;
import std.experimental.allocator.mallocator: AlignedMallocator;
import std.string: toStringz, fromStringz;
import std.stdio: write, writeln;

import core.sys.posix.unistd;
import core.sys.posix.fcntl;

import libaio;
import libaio.loader;


enum string DEVICE = "/dev/zvol/rootpool1/testvolume1";
enum O_DIRECT = octal!40000;


void main()
{
    write("Loading libaio... ");
    DerelictLibaio.load();
    writeln("ok");

    auto blockDevice = open(DEVICE.toStringz, O_RDWR | O_DIRECT | O_EXCL);
    if (blockDevice < 0)
    {
        writeln("Error while opening block device: ", blockDevice);
        return;
    }
    scope(exit) close(blockDevice);
    void[] rawData = AlignedMallocator.instance.alignedAllocate(4096, 4096);
    rawData[0..11] = cast(void[]) "test string";
    writeln("data pointer: ", rawData.ptr,
            ", page-aligned: ", (cast(ulong) rawData.ptr % 4096) == 0);

    int err;
    // prepare libaio context
    io_context_t ctx;
    err = io_queue_init(32, &ctx);
    errnoEnforce(err == 0);
    scope(exit) io_destroy(ctx);

    iocb io;
    // initiate write. 512 -> 4096 change may be required for your disk.
    io.io_prep_pwrite(blockDevice, rawData.ptr, 512, 0);
    iocb* ioarr = &io;
    err = ctx.io_submit(1, &ioarr);
    errnoEnforce(err == 1);

    io_event[1] events;
    // wait for write completion
    // in prod code don't forget about EINTR.
    err = ctx.io_getevents(1, 1, events.ptr, null);
    errnoEnforce(err == 1);
    enforce(events[0].data is null);
    enforce(events[0].obj == &io);
    err = ctx.io_getevents(0, 1, events.ptr, null);
    errnoEnforce(err == 0);

    // initiate read
    void[] readData = AlignedMallocator.instance.alignedAllocate(4096, 4096);
    io.io_prep_pread(blockDevice, readData.ptr, 512, 0);
    err = ctx.io_submit(1, &ioarr);
    errnoEnforce(err == 1);

    // wait for read completion
    events[0] = io_event.init;
    err = ctx.io_getevents(1, 1, events.ptr, null);
    errnoEnforce(err == 1);
    enforce(events[0].data is null);
    enforce(events[0].obj == &io);

    enforce(rawData == readData);
    writeln("test succeeded");
}
```