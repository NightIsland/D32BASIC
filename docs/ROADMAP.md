# Roadmap

1. **Foundations** *(done)*: repo, toolchain, `.NEX` build, the oracle
   and test harness, and specs for tokens, floating point and the memory map.
2. **Core language** *(done)*: line editor, tokeniser and `LIST`; expressions,
   variables, strings and arrays (with garbage collection); control flow;
   `PRINT`/`INPUT`; maths and string functions; the 32x16 text screen and
   keyboard. Also `PRINT USING`, `DEF FN`, `RENUM` and `DEL`.
3. **Finish the MVP** *(done: version 1.0, checked on a KS3 Next)*: SD file
   commands (`SAVE`, `LOAD`, `MERGE`, `DIR`, `KILL`, `RENAME`) and data files
   (`OPEN`, `CLOSE`, `PRINT #`, `INPUT #`, `EOF`); PMODE graphics (`PCLS`,
   `PSET`, `LINE`, `CIRCLE`, `PAINT`, `DRAW`, `GET`/`PUT`, `PCOPY`); `PLAY`
   and `SOUND` on the AY chip; the text-screen block graphics (`SET`,
   `RESET`, `POINT`), `EDIT`, `LINE INPUT`, `JOYSTK`; checks on a real Next;
   a release `.NEX`; the settings screen on the GRAPH key.
3b. **DragonDOS extras** *(next)*: the DragonDOS BASIC commands that make
   sense on an SD card: `ERROR GOTO`, `ERR`, `ERL`, `SWAP`, `AUTO`, `BEEP`,
   `WAIT`, `CHAIN`, `FREE`, `HIMEM`, random-access files and `COPY`. They are
   checked against the real DragonDOS 1.0 ROM where no disk is needed.
4. **Next extensions**, in small phases, each using only values a Dragon
   refuses so no Dragon program changes: `PMODE 5` (256x192 in 256 colours),
   `PLAY` with three voices, a mouse through `JOYSTK`, `PALETTE`, `PMODE 6`
   and `7` (320x256 and 640x256), hardware sprites, and `WIDTH 40`/`80`.
