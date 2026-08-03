# Tips

## Memory Allocation Exceptions

Starting in SDK v2.3, c++ exceptions are supported in plugins. The most common
exception is due to running out of memory, so I suggest all plugins try to catch
a `std::bad_alloc` exception whenever allocating.

Example:

```c++
std::vector<float> sample_data;

try {
    sample_data.resize(sample_size); 
    sample_loaded = true;
} catch (std::bad_alloc &) {
    Gui::notify_user("Could not allocate memory for the sample. Choose a smaller file.", 2000);
    sample_loaded = false;
}
```

If your plugin has non-dynamic data members that use a lot of memory, then if
there is not enough memory available, the firmware itself will catch the bad 
allocation exception, so you do not need to handle this case. Example:

```c++
// Big buffer, might not have enough memory for it:
std::array<float, 12000000> large_buffer;

MyModule() {
    // If there is not enough memory for large_buffer, the plugin loader in 
    // firmware will catch the exception, so you don't need to do anything
    // special in your plugin.

    config(NUM_PARAMS, NUM_INPUTS, NUM_OUTPUTS, NUM_LIGHTS);
    // ... etc ...
}


```




## Memory Allocations in Audio Process

The MetaModule has hard real-time requirements in order to acheive low-latency
audio. 

There is an audio "thread" which has the highest priority of any task. The
audio thread calls your module's `process()` or `update()` function for each
sample frame. Therefore any code in the `process()` function must be optimized
for efficient execution.
 
You cannot make any memory allocations in the `process()` function
(or any other function that's called by `process()`. This includes:

- Do not create, destroy, or re-size a `std::string`. Writing characters to an
  already allocated string is OK, as long as it does not change length.

- Do not `push_back` or `emplace_back` or otherwise change the length of a
  std::vector (or any std container such as list, deque, etc...) You can
  read/write data in a vector, but don't change the capacity of the vector. If
  you need a dynamically-sized vector in the audio thread, one useful
  technique is to use `reserve()` when you construct your module. Then you can
  safely call `push_back` in the audio thread as long as you are 100% certain
  you will not push more items than you reserved.

### Workarounds for VCV Rack plugins

I've seen a few examples of VCV Rack plugins that allocate memory in the audio
thread. The most common example is allocating channels when a cable is patched
into a jack. Often, the number of polyphonic channels is read from the port and
then a vector of some data structure is allocated to accomodate that many poly
channels. This is not allowed in the MetaModule. I suspect it's OK in VCV Rack
because typically Rack is run on modern computers which can handle spikes in
CPU usage coming from allocations. But the MetaModule will behave erratically,
sometimes doing OK and sometimes failing when you patch a cable.

In order to address this pattern in several VCV Rack modules, the MetaModule
runs `process()` at least once for each module when it first loads the patch,
before the audio context starts. Often, this triggers all allocations and then
the module runs fine once the audio context starts.

To have your module follow this pattern, make allocations in the first call 
to `process()`, e.g. like this:

```c++
std::vector<float> data;

void process(const ProcessArgs& args) override {
    static bool first_run = true;
    if (first_run) {
        // Allocate on first run of process() only
        data.resize(12'000'000);
        first_run = false;
    }
    //...
```

Another approach is to do all allocations in the constructor. Use `reserve()` 
if you still need dynamic re-sizing. If you are using the VCV adaptor layer,
there is one downside to this approach: in the case that your modules allocates
a large amount of memory (say, > 32MB), the situation can come up where users
are unable to load your plugin without freeing up some memory, even if they don't
want to use the module that has a high memory footprint. The reason is that
with VCV Rack adaptor layer plugins, the MetaModule constructs each module in
the plugin in order to scan the widget tree. So if there's < 32MB free in this
example, then it won't be able to construct the module that allocates 32MB, 
and the entire plugin will fail to load. In this case I would suggest using the
previous method of allocating in the first run of `process()`. Note that
"native" plugins do not have this issue since they don't have a widget tree and
therefore aren't constructed when the plugin is loaded.

Another way I've seen it done is to allocate when the number of poly channnels
changes. While this sometimes works, if the number of polyphonic channals
changes during audio playback, we will get a CPU spike when it re-allocates
(i.e. if the user patches a new cable, or changes the poly count of the
upstream module). I don't recommend this technique, but it's common, so be
aware if you see it in existing code (and don't copy it).


## Memory

The MetaModule has about 300MB of RAM dedicated for plugins to use. This includes
the plugin code (but not data such as PNG files), and any memory individual modules
in the patch will use. Be mindful that this is a shared resource, so try to 
keep the memory footprint low if your module deals with large buffers (several MB or more)
or is able to load files of arbitrary sizes. Remember that users will often want
duplicates of a module in a patch.

## Disk Access

File system access is permitted on the MetaModule. However, it is much slower than
on a desktop computer. Also keep in mind that file paths differ on the computer
than they do on the MetaModule.
Use the helper function `translate_path_to_local()` to convert a computer
path to a MetaModule path (see [Filesystem Calls](./filesystem-syscalls.md)


## Block sizes

The minimum block size the MetaModule supports is 16 frames. So if you are
optimizing your module to process in blocks, this would be the ideal size to
use. 

Using a larger size would mean the CPU usage would spike, which can be
upsetting and confusing to users.

## UnInitialized data

Make sure any variables you use are initialized to a valid value. I do not
have hard data to back this up, but my experience has been that often a desktop
OS will return zero-intialized memory when you request an allocation, perhaps as a 
security feature. In any case, the MetaModule does not do this (and basic coding
practices tell us to always initialize a variable before reading it).

Bugs that result from using uninitialized data might not show themselves until
you port to the MetaModule.

For example:

```c++
class MyModule : rack::Module {
    float increment;

    void process() {
        int index = std::floor(increment);
        float output = wavetable[index];


```

Clearly, if `increment` is some value greater than the size of the wavetable,
the module might crash. On desktop system, you are more likely to get a value
of 0 for `increment`, therefore the bug will not show itself.

## MetaModule platform vs. Computer (VCV Rack) platform

The MetaModule runs without an operating system, and so has some different
requirements than code written to be run on a desktop computer for VCV Rack.
Also, subtle bugs or or less-than-ideal practices might rarely cause a problem
on a fast computer with GB of RAM, but might cause frequent issues with the
MetaModule's constrained resources. So, the process of porting can bring to
light these issue.

