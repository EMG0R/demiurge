# lockin (ChucK)
NEPTR Phase 4's built-in synth mode (`NEPTR_phase4/chuck/synthi.ck`, the "Mid-Air Thief" voice). **The note algorithm and the
voice are unchanged**: 5 rotating modes, Markov interval weights, harmonic-series boost, Levy-flight register, 4 detuned saws
with per-note random filter/vibrato/pitch decay.

| what | how |
|---|---|
| arcade (was ch1 CC68) | `trig` param, hard-mapped to the arcade button: press = one note; hold >= 5 s = toggle the sequencer |
| BPM (was ch16 CC119) | still from the transport: `MidiIn "Midi Through"`, unchanged. Not a param. `USS_NO_MIDI=1` skips it (offline checks) |
| density | NOTE_PROB = min(1, d x 1.2) (0.5 gives the original 0.6) |
| length | LOCKIN_LENGTH = length (0.5 = original) |
| tone | FILTER_OFFSET_SEMITONES = (t-.5) x 48 |
| pitch | LOCKIN_PITCH_SEMITONES = round((p-.5) x 24), a +-12 transpose |
| intensity | master volume 0.6 x 2^((i-.5)*2) |
| space | reverb send, 0 = dry as the original |

Differences: the sequencer boots ON (USS is generative by default; the original booted OFF); a limiter (transparent below 0.7).
Discrepancy to confirm: the original listened to CC68, which is Teensy button **b9**; the NEPTR arcade button is **b1** (CC60).
The hard map uses b1 like the other instruments; change `source` in `params/uss-lockin.json` if CC68 was really meant.
