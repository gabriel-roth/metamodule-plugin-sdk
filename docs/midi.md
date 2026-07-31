# MIDI

Native modules can receive and send MIDI messages directly, without going
through the MIDI-to-CV modules in the patch.

See [midi/midi_in.hh](../core-interface/midi/midi_in.hh),
[midi/midi_out.hh](../core-interface/midi/midi_out.hh), and
[midi/midi_message.hh](../core-interface/midi/midi_message.hh)

Namespace: `MetaModule`

> **Note:** `MidiInput` and `MidiOutput` are not usable in a plugin as of SDK
> v2.3: `midi_in.hh`/`midi_out.hh` include `midi/midi_router.hh` and
> `midi/midi_queue.hh`, which are not shipped in the SDK, and the
> `MidiRouter::subscribe_*()` symbols they call are not in `api-symbols.txt`.
> Until that's fixed, use the VCV Rack adaptor's `rack::midi::InputQueue` (see
> [rack-adaptor.md](./rack-adaptor.md)). The rest of this document describes
> the intended API. `Midi::toPrettyString()` below is exported and works today.

## MidiInput

```c++
struct MidiInput {
    std::optional<MidiMessage> pop_message();
    bool pop_message(MidiMessage *message);
};
```

Creating a `MidiInput` subscribes it to the stream of all incoming MIDI
messages: everything arriving on the MIDI jack and on USB (from an attached
controller, or from a computer the module is plugged into). Active Sensing
(0xFE) is filtered out before it reaches you. Messages are queued as they
arrive, and the queue holds 128 messages. Destroying the object unsubscribes it.

Keep it as a member of your module so that its lifetime matches the module's:
constructing one per `update()` call would drop messages and allocate.

Drain the queue on every `update()`. The queue overwrites its oldest entry when
it's full, so a module that pops only one message per sample silently loses the
start of dense passages (a chord, or a controller sweep). Both `pop_message()`
overloads return nothing/false once the queue is empty:

```c++
#include "midi/midi_in.hh"
using namespace MetaModule;

struct MyModule : CoreProcessor {
    MidiInput midi;
    float note_cv = 0.f;
    float gate = 0.f;

    void update() override {
        while (auto msg = midi.pop_message()) {
            if (msg->is_noteon()) {
                note_cv = (float(msg->note()) - 60.f) / 12.f; // 1V/oct, middle C = 0V
                gate = 10.f;
            } else if (msg->is_noteoff()) {
                gate = 0.f;
            }
        }
    }
    //...
};
```

The other overload avoids `std::optional` if you prefer:

```c++
MidiMessage msg;
while (midi.pop_message(&msg)) {
    // ...
}
```

Every module with a `MidiInput` gets its own copy of every message: subscribing
does not consume messages, so several modules (and the patch's own MIDI
modules) can all listen at once.

## MidiOutput

```c++
struct MidiOutput {
    void push_message(MidiMessage msg);
    bool is_queue_full() const;
};
```

Creating a `MidiOutput` subscribes it to the outgoing MIDI stream; messages
pushed to it are sent out the MIDI jack and USB. As with `MidiInput`, keep it
as a member of your module.

The queue holds 128 messages, and the audio engine pops one message from it per
audio block to hand to the hardware. Pushing to a full queue overwrites the
oldest message that hasn't been sent yet, so check `is_queue_full()` first if
losing messages would be a problem. Note that messages generated while nothing
is connected to MIDI are discarded rather than held.

```c++
#include "midi/midi_out.hh"
using namespace MetaModule;

struct MyModule : CoreProcessor {
    MidiOutput midi;

    void update() override {
        if (gate_just_went_high && !midi.is_queue_full()) {
            // Note On, channel 1, note 60, velocity 100
            midi.push_message(MidiMessage{0x90, 60, 100});
        }
    }
    //...
};
```

## MidiMessage

A `MidiMessage` is a single MIDI message of up to three bytes, plus the one-byte
USB-MIDI header that says which cable (port) it came from or is going to:

```c++
struct MidiMessage {
    MidiStatusByte status;    // .command (MidiCommand) and .channel (0-15)
    MidiDataBytes data;       // .byte[0], .byte[1]
    UsbCableCodeByte usb_hdr; // .cable_num (0-15) and .cin (code index number)

    constexpr MidiMessage() = default;
    constexpr MidiMessage(uint8_t status_byte, uint8_t data_byte0 = 0, uint8_t data_byte1 = 0);
    constexpr MidiMessage(uint8_t usb_header, uint8_t status_byte, uint8_t data_byte0, uint8_t data_byte1);
};
```

The three-argument constructor deduces the USB header's code index number from
the status byte, so constructing a message from raw MIDI bytes is enough for
sending.

`status.command` is a `MidiCommand`: `NoteOff` (0x8), `NoteOn` (0x9),
`PolyKeyPressure` (0xA), `ControlChange` (0xB), `ProgramChange` (0xC),
`ChannelPressure` (0xD), `PitchBend` (0xE), `Sys` (0xF), or `None`.
`status.channel` is the MIDI channel, 0-15 (that is, one less than the channel
number shown in most MIDI software).

### Reading a message

Rather than decoding `data.byte[]` yourself, use the accessors, which name the
data bytes according to the message type:

| Function            | Returns                                                    |
|---------------------|------------------------------------------------------------|
| `note()`            | note number (Note On/Off, Poly Key Pressure)                |
| `velocity()`        | velocity (Note On/Off)                                      |
| `aftertouch()`      | pressure value (Poly Key Pressure)                          |
| `chan_pressure()`   | pressure value (Channel Pressure)                           |
| `ccnum()`           | controller number (Control Change)                          |
| `ccval()`           | controller value (Control Change)                           |
| `pcval()`           | program number (Program Change)                             |
| `bend()`            | pitch bend as an `int16_t`, -8192 to 8191, centered at 0    |
| `raw()`             | all four bytes packed into a `uint32_t`                     |
| `message_size()`    | how many bytes this message actually occupies (1, 2, or 3)  |

And to test what kind of message it is:

- `is_noteon()` / `is_noteoff()`: these handle the usual convention that a Note
  On with velocity 0 means Note Off, so prefer them over comparing the command
  yourself.
- `is_command<MidiCommand::ControlChange>()` (and the other `MidiCommand`
  values): matches the command nibble, any channel.
- `is_system_common<SongPositionPtr>()`, `is_system_realtime<TimingClock>()`:
  match a specific system message. The values are `TimeCodeQuarterFrame`,
  `SongPositionPtr`, `SongSelect`, `TuneRequest`, `EndExclusive`, and
  `TimingClock`, `Start`, `Continue`, `Stop`, `ActiveSending`, `SystemReset`.
- `is_timing_transport()`: true for Timing Clock, Start, Stop, or Continue.
- `is_sysex()` / `has_sysex_end()`: SysEx is delivered as a series of messages;
  `is_sysex()` is true for each of them, and `has_sysex_end()` marks the one
  carrying the 0xF7 terminator.

`MidiMessage::note_name(uint8_t)` returns a note number as a string such as
`"C3"` or `"F#4"`, using the same octave numbering as the rest of the
MetaModule UI. It allocates a `std::string`, so don't call it from `update()`.

### Filtering by source

`usb_hdr.cable_num` is the USB-MIDI cable number the message arrived on, which
identifies which port of a multi-port USB device sent it. Use
[`System::get_usb_midi_rx_cable()`](./system-api.md#usb) to find out what those
ports are called, then match on `cable_num` to listen to just one:

```c++
auto status = System::get_usb_connection_status();

for (unsigned c = 0; c < status.num_midi_rx_cables; c++) {
    auto cable = System::get_usb_midi_rx_cable(c);
    // cable.name is the port name, e.g. "Kontrol DAW"
}

if (auto msg = midi.pop_message()) {
    if (msg->usb_hdr.cable_num == my_port)
        process(*msg);
}
```

"rx" means cables the device sends to us -- the direction these messages are
travelling. Note this is *not* the same as the device's MIDI IN jacks: see
[system-api.md](./system-api.md#usb) for why. When the MetaModule is plugged
into a computer rather than acting as a host, it presents a single MIDI port, so
`cable_num` is always 0.

## Midi::toPrettyString()

```c++
namespace MetaModule::Midi {
    std::string toPrettyString(std::span<uint8_t, 3> bytes);
    std::string toPrettyMultilineString(std::span<uint8_t, 3> bytes);
}
```

Formats three raw MIDI bytes for display: `toPrettyString()` gives a single
line, `toPrettyMultilineString()` breaks it across lines to fit a narrow
display. Both allocate a `std::string`, so call them from
`get_display_text()` or another non-audio context, not from `update()`.

```c++
#include "midi/midi_message.hh"
using namespace MetaModule;

std::array<uint8_t, 3> bytes{msg.status, msg.data.byte[0], msg.data.byte[1]};
std::string text = Midi::toPrettyString(bytes);
```
