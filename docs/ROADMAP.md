# Roadmap

1. **Foundations** *(done)*: repo, toolchain, `.NEX` build, the oracle
   and test harness, and specs for tokens, floating point and the memory map.
2. **Core language** *(done)*: line editor, tokeniser and `LIST`; expressions,
   variables, strings and arrays (with garbage collection); control flow;
   `PRINT`/`INPUT`; maths and string functions; the 32x16 text screen and
   keyboard. Also `PRINT USING`, `DEF FN`, `RENUM` and `DEL`.
3. **Finish the MVP** *(code done; real-Next checks to come)*: SD file
   commands (`SAVE`, `LOAD`, `MERGE`, `DIR`, `KILL`, `RENAME`) and data files
   (`OPEN`, `CLOSE`, `PRINT #`, `INPUT #`, `EOF`); PMODE graphics (`PCLS`,
   `PSET`, `LINE`, `CIRCLE`, `PAINT`, `DRAW`, `GET`/`PUT`, `PCOPY`); `PLAY`
   and `SOUND` on the AY chip; the text-screen block graphics (`SET`,
   `RESET`, `POINT`), `EDIT`, `LINE INPUT`, `JOYSTK`; checks on a real Next;
   a release `.NEX`. DragonDOS-only commands (`CHAIN`, `FREAD`, `AUTO` and so
   on) are tokenised but not yet implemented.
4. **Next extensions**: new PMODEs for Next hardware, planned once the MVP is done.
