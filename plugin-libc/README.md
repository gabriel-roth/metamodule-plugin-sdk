## plugin-libc

Here are the libc, libstdc++, newlib, etc libraries your plugin will be linked with.

Normally when you compile with arm-none-eabi-g++ or gcc, the compiler links
against the standard library archives (.a files) that are distibuted with the
toolchain.

We cannot use these standard libraries achives because they were not compiled
in a way that they can be relocated. That is, they were not compiled with the
-fPIC flag so they can't be linked against your plugin which MUST be compiled
with -fPIC. We need this flag because we need to have relocations generated for
all symbols (which a basic requirement for a shared object that gets loaded as
a plugin).

The libraries are pre-compiled and can be found in `plugin-libc/lib/*.a`.

If you want to re-build them, use the scripts/build-plugin-libc-autotools.sh script.
This downloads the newlib and gcc sources and builds all required libraries
with the -fPIC flag so that dynamic loading will work.


