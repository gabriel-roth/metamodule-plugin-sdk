// Routes plugins' exception unwinder to the MetaModule firmware's unified
// exception-index (exidx) lookup.
//
// libgcc's unwinder declares __gnu_Unwind_Find_exidx as a weak symbol and
// when it is defined, calls it for every frame instead of the baked-in
// __exidx_start/__exidx_end fallback. Routing it to the host firmware
// lets an exception unwind across the plugin/host boundary.

typedef unsigned _uw;

extern _uw mm_host_find_exidx(_uw pc, int *nrec);

_uw __gnu_Unwind_Find_exidx(_uw pc, int *nrec) {
	return mm_host_find_exidx(pc, nrec);
}
