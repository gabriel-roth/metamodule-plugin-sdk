## Limitations

If you are porting from a VCV Rack plugin, there are the following limitations:

  - No expander modules. That is, modules cannot communicate with one another.
    Modules that use an expander will always act as if the expander is not
    present.

  - SVGs are not loaded or rendered. You must convert to PNGs. Loading
    dynamically is not supported, the only way to display a PNG image (besides
    the faceplate) is to create an SvgWidget in the ModuleWidget constructor
    and use `addChild()`.

  - Param, Jack, and Light widgets are drawn with the MetaModule engine, not
    with nanovg. Children of these widgets are ignored.

Note: As of SDK v2.2.1, C++ exceptions and streams (stringstream, fstream,
iostream, etc.) are now **fully supported**. Plugins link against the SDK's own
libc/libstdc++ archive (see `plugin-libc/`), so throw/try/catch, stringstreams,
and file streams (using the paths described in [Filesystem
Calls](filesystem-syscalls.md)) all work. The `tests/exceptions-test`
plugin demonstrates this support. If you added `#ifdef METAMODULE` workarounds
for the old no-exceptions/no-streams limitations, they can be removed.

