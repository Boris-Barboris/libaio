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
module libaio.loader;

public import derelict.util.exception;
import derelict.util.loader;

import libaio;


private enum libNames = "libaio.so.1,libaio.so";


class DerelictLibaioLoader: SharedLibLoader
{
    protected
    {
        this()
        {
            super(libNames);
        }

        override void loadSymbols()
        {
            bindFunc(cast(void**)&io_queue_init, "io_queue_init");
            bindFunc(cast(void**)&io_queue_release, "io_queue_release");
            bindFunc(cast(void**)&io_queue_run, "io_queue_run");
            bindFunc(cast(void**)&io_setup, "io_setup");
            bindFunc(cast(void**)&io_destroy, "io_destroy");
            bindFunc(cast(void**)&io_submit, "io_submit");
            bindFunc(cast(void**)&io_cancel, "io_cancel");
            bindFunc(cast(void**)&io_getevents, "io_getevents");
            bindFunc(cast(void**)&io_pgetevents, "io_pgetevents");
        }
    }
}


__gshared DerelictLibaioLoader DerelictLibaio;

shared static this()
{
    DerelictLibaio = new DerelictLibaioLoader();
}