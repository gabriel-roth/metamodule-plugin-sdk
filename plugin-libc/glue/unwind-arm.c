/* Compiles libgcc's ARM EABI unwinder together with a definition of
 * __gnu_Unwind_Find_exidx in the same translation unit.
 *
 * unwind-arm-common.inc declares __gnu_Unwind_Find_exidx as a weak symbol
 * and tests its address at runtime. A weak undefined reference does not pull
 * members out of a static archive, so if the definition lived in its own
 * object file it would never be linked, and the plugin .so would carry a
 * dynamic GOT relocation against an undefined weak symbol -- which the
 * MetaModule dynamic loader treats as a missing-symbol error. Defining it in
 * the same translation unit as the unwinder guarantees it is present
 * whenever the unwinder is used at all.
 */

#include "../libgcc/config/arm/unwind-arm.c"

/* Each plugin carries its own unwinder and its own exception index table
 * (the linker defines __exidx_start/__exidx_end around the .so's own
 * .ARM.exidx section, and unwind-arm-common.inc declares them), so the
 * lookup returns the plugin's own table regardless of pc. Exceptions cannot
 * propagate into or through firmware frames.
 */
_Unwind_Ptr __gnu_Unwind_Find_exidx(_Unwind_Ptr pc, int *nrec) {
	(void)pc;
	*nrec = (int)(&__exidx_end - &__exidx_start);
	return (_Unwind_Ptr)&__exidx_start;
}
