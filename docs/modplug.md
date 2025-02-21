# ModPlug support

Panel Attack is capable of identifying and playing the following tracker module formats:

- .699
- .amf
- .ams
- .dbm
- .dmf
- .dsm
- .far
- .it
- .j2b
- .mdl
- .med
- .mod
- .mt2
- .mtm
- .okt
- .psm
- .s3m
- .stm
- .ult
- .umx
- .xm

There are some issues regarding playback of these formats so they will not work as expected under most circumstances


# Issues

With the available decoder ModPlug formats will decode with a brief but notable piece of silence at the start or end.

That means that any audio that has an end will not loop cleanly, even though it does in an editor like OpenMPT. Likewise all transitions from music_start to the looping part will have that piece of silence.

These issues derive from the love framework and likely at least partially libmodplug so there is no way to fix these issues for Panel Attack.


# Workaround

1. Define the loop within the track itself using jump markers from the final row back to the start of the loop
2. Don't use `_start` files for the intro; keep it integrated with the main audio.