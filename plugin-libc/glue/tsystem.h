/* Stub replacing gcc/tsystem.h (which is not part of the libgcc source dir),
   so that libgcc's unwinder sources can be compiled outside of the libgcc
   build system. The real tsystem.h declares the small set of libc functions
   the target libraries use; since we build against newlib headers, just
   include them. */
#ifndef GCC_TSYSTEM_H
#define GCC_TSYSTEM_H

#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#endif
