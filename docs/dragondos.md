# DragonDOS BASIC extras

D32BASIC has the DragonDOS 1.0 BASIC commands that make sense on an SD card.
Those that need no disk were checked against the real DragonDOS ROM in the
test oracle (`tests/dos/`); the disk commands follow the DragonDOS manual
("Introduction to DragonDOS"), with the SD card's files in place of a
DragonDOS disk.

## Checked against DragonDOS

* `ERROR GOTO line` traps errors in a running program; `ERROR GOTO 0` (or no
  line) turns it off. `ERR` is the error code (twice the error's number:
  `?/0` is 20) and `ERL` its line (-1 in direct mode, and printed signed, as
  DragonDOS does). Both are set by every error, and cleared by `RUN`.
  A trap resets the `FOR`/`GOSUB` stack, starts a new line first, and stays
  on, so an error in the handler is trapped again. Errors in direct mode and
  `STOP` are not trapped. Disk errors have DragonDOS's codes (128 up), for
  example `?NE` is 160.
* `SWAP a,b` exchanges two variables or array elements of the same type.
* `AUTO [start[,step]]` numbers lines from 100 in steps of 10. Pressing ENTER
  straight after a number ends it (and keeps any line of that number), as do
  BREAK and errors. In a program it gives `?FC ERROR`.
* `BEEP [n]` beeps n times (1-255); `WAIT n` pauses n milliseconds (0-65535,
  to the nearest 50th of a second; BREAK works).
* `HIMEM` is the top of BASIC's memory and `FRE$` the free string space
  (after a garbage collection). `CLEAR n,HIMEM+1` keeps the top where it is.
  HIMEM is a Dragon address after `CLEAR n,addr`; with the Next's larger
  memory, the start-up value is higher than a Dragon's 32766.

## From the manual

* `FREE`, `FREE drive` or `FREE(drive)`: free bytes on the current SD drive.
  Drives 1-4 all mean it; others give `?DN ERROR`.
* `CHAIN "name"[,line]` loads a program and runs it, from the line if given,
  keeping the variables. Only tokenised (normally `SAVE`d) programs can be
  chained; a text one (`SAVE "name",A`) gives `?FM ERROR`.
* `COPY "from" TO "to"` copies a file (give the extensions). `?FE ERROR` if
  the new one exists.
* `PROTECT ON|OFF "name"` and `VERIFY [ON|OFF]` are accepted and do nothing.
* Random-access files. Names get `.DAT` when they have no extension.
  * `CREATE "name"[,length]` makes a file of that many spaces.
  * `FWRITE "name"[,FROM pos][,FOR len];items` writes numbers and strings as
    `PRINT` shows them, with nothing between items (write `","` yourself to
    separate them), at the end of the file unless `FROM`. `FOR` pads the
    record with spaces or cuts it short. The file is made if need be.
  * `FREAD "name"[,FROM pos][,FOR len];variables` reads as `INPUT` does:
    commas, colons and line ends separate the items. It starts at the file's
    read pointer (0 at first) unless `FROM`, and moves the pointer past what
    it read. With `FOR`, it reads only that record (`FOR` bytes) and moves
    the pointer to the end of it. `FLREAD` reads a whole line into one string,
    commas included. Reading past the end gives `?FE ERROR` (code 154).
  * `LOF "name"` is the file's length and `LOC "name"` its read pointer, in
    bytes. `EOF("name")` is 1 before the end and 0 at it (the manual's
    values; `EOF(-1)` for a data file still gives -1 at the end).
  * `CLOSE` (or `CLOSE 1` to `4`) and `RUN` reset the read pointers. Up to
    10 files can have one; an 11th gives `?TF ERROR`.
  * Each statement opens the file, works and closes it again, so nothing is
    lost if the program stops or the Next is reset.

## Our own

* `CD "path"` changes the current folder; `"D:"` in front changes the drive
  too. `CD` alone prints the current drive and folder. It lasts for the
  session; the files folder in the settings doesn't change.
* `MKDIR "path"` makes a folder (`?FE ERROR` if it exists).

## Not included

`DRIVE`, `DSKINIT`, `BACKUP`, `BOOT`, `SREAD` and `SWRITE` work on disk
drives and sectors, which an SD card does not have. They give `?SN ERROR`,
or are skipped with the IGNORE setting.

## Differences from DragonDOS

* An `ERROR GOTO` to a line that doesn't exist gives `?UL ERROR` and turns
  trapping off. DragonDOS loops forever.
* `SWAP` of an array element with a variable used for the first time works.
  DragonDOS swaps with the element's old place and corrupts the array.
