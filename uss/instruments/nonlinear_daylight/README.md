# nonlinear daylight (Csound)
Emory's piece. `nonlinear_daylight.csd` is `1_nonlinear_daylight_ORIGINAL.csd` with the generative scheduler (instr 1), the FM
voice with phaser/flanger/chorus combs (instr 2) and the freeverb chain (instr 3) kept line for line. It plays by itself:
random-walk notes from a C-major-ish table, random key offset (-8..2 semitones, fractional) and tempo 40-65 per run.

| param | does |
|---|---|
| density | scheduler rate x 2^((d-.5)*3) (0.35x..2.8x); the 0.65 note chance is the original's |
| tone | FM modulation index x 2^((t-.5)*3), live |
| length | note length and all envelopes x 2^((l-.5)*3) (p3 10 s at default) |
| space | 0.75 = original (fully wet, no dry). Below: dry voices fade in. Above: bigger, darker room |
| intensity | level x 2^((i-.5)*2) |
| pitch + trig | trig edge fires one note: pitch picks a degree of the piece's scale over 3 octaves, in the run's key; ratio and index are drawn like any generated note |

Changes vs the original: ksmps 256 to 32 and sr 48000 (hook needs ksmps <= 64); 40-voice cap (CPU guard); an output soft limiter
(identity below 0.7, ceiling 0.95; the original peaks at 1.08 and clips); dead duplicate globals dropped; the weighted ratio/index
draws factored into two opcodes shared by the scheduler and the trigger. Macro `USS_SEED` makes a run repeatable (0 = time seed, default).
Run: `csound -d -+ignore_csopts=1 nonlinear_daylight.csd --omacro:DEMIURGE_PARAM_PORT=N --env:INCDIR=$DEMIURGE_RESOURCES` (the launcher does this).
