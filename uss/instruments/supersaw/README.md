# supersaw (ChucK)
Emory's first-week ChucK piece (9/18/2025), `CHomework1`. The same voices and numbers: 7 detuned SawOsc with per-saw pan plus two
chord-tone saws each, the 165 bpm square arp over five chords with the -12..0 bend at both ends of every chord, then the
15-measure drum section (kick, snare, noise hats, sine/triangle/square slide and blip gestures at probability 0.4, the saw bass).
The original is one unrolled score that stops; this plays the same score on a loop, rewritten with arrays.

| param | does |
|---|---|
| density | gesture probability (0.4 base) and hat probability (0.5 base) x 2^((d-.5)*3) |
| tone | below 0.5 lowpass 20 kHz down to 400 Hz; above 0.5 widens the saw detune up to 2.5x. 0.5 = as written |
| length | chord-section length x 2^((l-.5)*2) (0.5x..2x); also the stab's decay |
| space | reverb send (JCRev), 0 = dry as written |
| intensity | master level x 2^((i-.5)*2) |
| pitch + trig | trig fires a chord stab (the piece's own saw stack, +4/+14 intervals); pitch picks root among the five chord roots over 3 octaves |

Kept on purpose: every saw Pan2 is wired to dac four times in the original (+12 dB), reproduced as a x4 gain (levels match the
original within a few percent); chord sections use the up5 intervals throughout; hats are centred.
Added: master gain, filter, reverb send, limiter (thresh 0.6, transparent below). Original clips; this does not.
