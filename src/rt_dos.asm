; Disk files on the SD card, through esxDOS: the DragonDOS statements
; SAVE, LOAD, MERGE, RUN "name", DIR, KILL and RENAME, and CSAVE/CLOAD as
; their cassette-named twins.
;
; This code lives in bank 5, so it is mapped while the ROM is paged in for
; an esxDOS call; every buffer esxDOS reads or writes is in bank 5 too.
;
; Files are stored as DragonDOS stores them: a BASIC program is a 9-byte
; header ($55, type 1, load address $1E01, length, exec address, $AA)
; followed by the tokenised program with its links as they would be at
; $1E01. "SAVE name,A" writes the program as text instead (CR LF line
; ends); LOAD and MERGE take either kind, and text files with CR, LF or
; CR LF line ends.

DBUFSZ          EQU 512

; Call esxDOS function L. A, BC, DE, IX are passed through; on return
; carry set means an error, with the esxDOS code in A.
dos_call:
        push af
        ld a, l
        ld (.op), a
        pop af
        di
        nextreg $50, $FF                ; ROM in, so RST $08 reaches esxDOS
        nextreg $51, $FF
        rst $08
.op:    db 0
        nextreg $50, CORE_PAGE
        nextreg $51, CORE_PAGE + 1
        ei
        ret

; Report esxDOS error A as a BASIC error.
doserr: ld hl, .map
.lp:    ld e, (hl)
        inc hl
        bit 7, e
        jr nz, .err
        cp e
        ld e, (hl)
        inc hl
        jr nz, .lp
.err:   ld a, e
        and $7F
        ld e, a
        jp error
.map:   db 5, ERR_NE                    ; no such file
        db 17, ERR_NE                   ; no such directory
        db 18, ERR_FE                   ; already exists
        db 9, ERR_DF                    ; disk full
        db 8, ERR_PT                    ; access denied
        db 24, ERR_PT                   ; read-only
        db 7, ERR_FS                    ; bad name
        db $80 | ERR_IO                 ; anything else

fserr:  ld e, ERR_FS
        jp error
fmerr:  ld e, ERR_FM
        jp error

; Close the open file, if any, and stop reading or writing it. Called at
; READY, so an error or BREAK never leaves a file open.
dos_abort:
        xor a
        ld (filein), a
        ld (ldrun), a
        ld a, (fmode)               ; a data file being written: keep
        push af                     ; what is buffered
        xor a
        ld (fmode), a
        pop af
        cp 2
        call z, dflush
        ld a, (dosfh)
        inc a
        ret z
        dec a
        push af
        ld a, $FF
        ld (dosfh), a
        pop af
        ld l, F_CLOSE
        jp dos_call                     ; an error closing is ignored

; Close the open file, reporting any error.
dclose: ld a, (dosfh)
        push af
        ld a, $FF
        ld (dosfh), a
        pop af
        ld l, F_CLOSE
        call dos_call
        jp c, doserr
        ret

; Open FNAME with mode B. Errors are reported; ?AO ERROR if a file is
; already open.
dopen:  ld a, (dosfh)
        inc a
        ld e, ERR_AO
        jp nz, error
        ld a, '*'
        ld ix, fname
        ld l, F_OPEN
        call dos_call
        jp c, doserr
        ld (dosfh), a
        ld hl, dosbuf
        ld (dbufp), hl
        ld hl, 0
        ld (dbufn), hl
        ret

; Next byte of the open file in A; carry set at the end of the file.
; Preserves BC, DE, HL, IX.
dget:   push hl
        ld hl, (dbufn)
        ld a, h
        or l
        jr nz, .have
        push bc
        push de
        push ix
        ld a, (dosfh)
        ld ix, dosbuf
        ld bc, DBUFSZ
        ld l, F_READ
        call dos_call
        jp c, doserr
        pop ix
        pop de
        ld h, b
        ld l, c
        pop bc
        ld a, h
        or l
        jr nz, .fill
        pop hl
        scf
        ret
.fill:  push hl
        ld hl, dosbuf
        ld (dbufp), hl
        pop hl
.have:  dec hl
        ld (dbufn), hl
        ld hl, (dbufp)
        ld a, (hl)
        inc hl
        ld (dbufp), hl
        pop hl
        or a
        ret

; Give back the byte DGET just returned.
dunget: push hl
        ld hl, (dbufp)
        dec hl
        ld (dbufp), hl
        ld hl, (dbufn)
        inc hl
        ld (dbufn), hl
        pop hl
        ret

; Next byte of the file, which must be there (else ?FM ERROR).
dgetm:  call dget
        ret nc
        jp fmerr

; Write A to the open file (buffered). Preserves all registers.
dput:   push hl
        push de
        ld hl, (dbufp)
        ld (hl), a
        inc hl
        ld (dbufp), hl
        ld de, dosbuf + DBUFSZ
        or a
        sbc hl, de
        call z, dflush
        pop de
        pop hl
        ret

; Write out what DPUT has buffered. Preserves all registers.
dflush: push af
        push bc
        push de
        push hl
        push ix
        ld hl, (dbufp)
        ld de, dosbuf
        or a
        sbc hl, de
        jr z, .x
        ld b, h
        ld c, l
        ld a, (dosfh)
        ld ix, dosbuf
        ld l, F_WRITE
        call dos_call
        jp c, doserr
        ld hl, dosbuf
        ld (dbufp), hl
.x:     pop ix
        pop hl
        pop de
        pop bc
        pop af
        ret

; CHROUT to the file: CR is written as CR LF.
dos_putc:
        push af                     ; nothing goes to a file being read
        ld a, (fmode)
        dec a
        jr nz, .w
        pop af
        ret
.w:     pop af
        call dput
        cp 13
        ret nz
        push af
        ld a, 10
        call dput
        pop af
        ret

; INLIN's input from the file: LF counts as CR; at the end of the file,
; EOFFLG is set and A = CR.
dos_getc:
        call dget
        jr c, .eof
        cp 10
        ret nz
        ld a, 13
        ret
.eof:   ld a, 1
        ld (eofflg), a
        ld a, 13
        ret

; Evaluate a file name into FNAME. DE = an extension (".BAS") to add when
; the name has none, or 0. A DragonDOS drive suffix (":1") is dropped.
getnam: push de
        call frmevl
        pop de
getnmf: push de                         ; (the name already in the FAC)
        call frestr                     ; HL = text, B = length
        ld a, b
        or a
        jp z, fserr
        cp 50
        jp nc, fserr
        ld de, fname
        ld c, 0                         ; 1 once there is a '.'
.lp:    ld a, (hl)
        cp ':'
        jr z, .end
        cp '.'
        jr nz, .nodot
        ld c, 1
.nodot: ld (de), a
        inc hl
        inc de
        djnz .lp
.end:   pop hl
        ld a, e
        cp fname & $FF
        jp z, fserr                     ; nothing before the ':'
        ld a, c
        or a
        jr nz, .term
        ld a, h
        or l
        jr z, .term
.ext:   ld a, (hl)
        ld (de), a
        inc hl
        inc de
        or a
        jr nz, .ext
        ret
.term:  xor a
        ld (de), a
        ret

ext_bas: db ".BAS", 0

; An optional ",letter" at the end of the statement: carry set if it is
; there (it must be the letter in B), else ?SN ERROR.
optlet: call chrgot
        jr nz, .some
        or a                            ; none: carry clear
        ret
.some:  call chkcom
        cp b
        jp nz, snerr
        call chrget
        jp nz, snerr
        scf
        ret

; ---- SAVE / CSAVE -----------------------------------------------------------
st_csave:
        cp 'M'
        jp z, snerr                     ; CSAVEM: no machine code files
st_save:
        ld de, ext_bas
        call getnam
        ld b, 'A'
        call optlet
        push af
        ld b, FA_WRITE | FA_CREATE_AL
        call dopen
        pop af
        jr c, .ascii
        ld a, $55                       ; the DragonDOS header
        call dput
        ld a, 1
        call dput
        ld a, $1E
        call dput
        ld a, $01
        call dput
        ld hl, (vartab)
        ld de, (txttab)
        or a
        sbc hl, de
        ld a, h
        call dput
        ld a, l
        call dput
        ld a, $8B
        call dput
        ld a, $8D
        call dput
        ld a, $AA
        call dput
        ld hl, (txttab)
.line:  ld d, (hl)                      ; DE = this line's link
        inc hl
        ld e, (hl)
        inc hl
        ld a, d
        or e
        jr z, .end
        push hl
        push de
        ex de, hl                       ; the link as it would be at $1E01
        ld de, (txttab)
        or a
        sbc hl, de
        ld de, $1E01
        add hl, de
        ld a, h
        call dput
        ld a, l
        call dput
        pop de
        pop hl
.byte:  ld a, (hl)                      ; then the rest, up to the next line
        call dput
        inc hl
        ld a, l
        cp e
        jr nz, .byte
        ld a, h
        cp d
        jr nz, .byte
        jr .line
.end:   xor a                           ; the zero link that ends it
        call dput
        call dput
.close: call dflush
        jp dclose

; SAVE ...,A: the program as text, as LIST shows it.
.ascii: ld a, 1
        ld (devnum), a
        ld hl, (txttab)
.aline: ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .aend
        push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        ex de, hl
        call linprt
        call outspc
        pop hl
        push hl
        call dcrnch
        ld hl, BUF
        call strout
        call crdo
        pop hl
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .aline
.aend:  xor a
        ld (devnum), a
        call dflush
        call dclose
        ld hl, (curlin)                 ; direct: BUF, which held this
        ld a, h                         ; statement, is used up
        and l
        inc a
        jp z, ready
        ret

; ---- LOAD / CLOAD / RUN "name" / MERGE ----------------------------------------
st_cload:
        cp 'M'
        jp z, snerr                     ; CLOADM: no machine code files
st_load:
        ld de, ext_bas
        call getnam
        ld b, 'R'
        call optlet
        ld a, 0
        rla
        jr load1
st_runf:                                ; RUN "name"[,R]
        ld de, ext_bas
        call getnam
        ld b, 'R'
        call optlet
        ld a, 1
load1:  ld (ldrun), a
        ld b, FA_READ
        call dopen
        call dget
        jr c, .empty
        cp $55
        jr nz, .text
        call dhead                      ; DE = length
        ld hl, (txttab)                 ; room for it and two more zeros?
        add hl, de
        jp c, omerr
        inc hl
        inc hl
        push de
        call reason
        pop bc
        ld hl, (txttab)
.rd:    ld a, b
        or c
        jr z, .rdend
        call dgetm
        ld (hl), a
        inc hl
        dec bc
        jr .rd
.rdend: xor a                           ; in case the file was cut short
        ld (hl), a
        inc hl
        ld (hl), a
        call dclose
        call cheada
        ld hl, (txttab)                 ; VARTAB = after the zero link
.fend:  ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .found
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .fend
.found: inc hl
        inc hl
        ld (vartab), hl
        call runc
        ld a, (ldrun)
        or a
        jp z, ready
        xor a
        ld (ldrun), a
        call xrrun
        jp newstt
; A text file: NEW, then take its lines as if they were typed.
.text:  call dunget
.empty: call scrtch
textin: ld a, 1
        ld (filein), a
        jp main

; End of a text file being loaded or merged (from MAIN).
dos_ldend:
        xor a
        ld (filein), a
        call dclose
        ld a, (ldrun)
        or a
        jp z, ready
        xor a
        ld (ldrun), a
        call xrrun
        call runc
        jp newstt

; Read the rest of a DragonDOS header (the $55 is read). DE = the length.
dhead:  call dgetm
        cp 1                            ; a BASIC program?
        jp nz, fmerr
        call dgetm                      ; load address
        call dgetm
        call dgetm
        ld d, a
        call dgetm
        ld e, a
        call dgetm                      ; exec address
        call dgetm
        call dgetm
        cp $AA
        jp nz, fmerr
        ret

; CHAIN "name"[,line]: load a program and run it (from the line, if given)
; keeping the variables. Only a tokenised (DragonDOS) file can be chained:
; a text file gives ?FM ERROR.
st_chain:
        ld de, ext_bas
        call getnam
        ld hl, 0
        ld (chnlin), hl
        call chrgot
        jr z, .open
        call chkcom
        jp nc, snerr                    ; a line number must follow
        call linget
        ld hl, (linnum)
        ld (chnlin), hl
        call chrgot
        jp nz, snerr
.open:  ld b, FA_READ
        call dopen
        call dget
        jp c, fmerr
        cp $55
        jp nz, fmerr
        call dhead                      ; DE = length
        ld (chnlen), de
        call chnstr                     ; strings out of the old program
        ld hl, (strend)
        ld de, (vartab)
        or a
        sbc hl, de
        ld (chnvsz), hl                 ; the variables' size
        ld hl, -64                      ; park them below the stack
        add hl, sp
        ld de, (chnvsz)
        or a
        sbc hl, de
        jp c, omerr
        ld (chndst), hl
        ld hl, (txttab)                 ; the new program must end below
        ld de, (chnlen)
        add hl, de
        jp c, omerr
        inc hl
        inc hl
        ex de, hl
        ld hl, (chndst)
        or a
        sbc hl, de
        jp c, omerr
        ld hl, (vartab)
        ld de, (chndst)
        ld bc, (chnvsz)
        call memmov
        ld hl, (txttab)
        ld bc, (chnlen)
.rd:    ld a, b
        or c
        jr z, .rdend
        call dgetm
        ld (hl), a
        inc hl
        dec bc
        jr .rd
.rdend: xor a
        ld (hl), a
        inc hl
        ld (hl), a
        call dclose
        call cheada
        ld hl, (txttab)                 ; DE = after the zero link
.fend:  ld a, (hl)
        inc hl
        or (hl)
        dec hl
        jr z, .found
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .fend
.found: inc hl
        inc hl
        push hl
        ld de, (vartab)                 ; ARYTAB and STREND move with them
        or a
        sbc hl, de                      ; HL = new - old
        ex de, hl
        ld hl, (arytab)
        add hl, de
        ld (arytab), hl
        ld hl, (strend)
        add hl, de
        ld (strend), hl
        pop de
        ld (vartab), de
        ld hl, (chndst)
        ld bc, (chnvsz)
        call memmov
        call restor
        call stkini
        ld hl, (chnlin)
        ld a, h
        or l
        jr z, .top
        ld (linnum), hl
        call fndlin
        jp c, ulerr
        call dexptr
        jp newstt
.top:   ld hl, (txttab)
        dec hl
        ld (txtptr), hl
        jp newstt

; Move BC bytes from HL to DE; the two may overlap.
memmov: ld a, b
        or c
        ret z
        push hl
        or a
        sbc hl, de
        pop hl
        jr c, .up
        ldir
        ret
.up:    add hl, bc
        dec hl
        ex de, hl
        add hl, bc
        dec hl
        ex de, hl
        lddr
        ret

st_merge:
        ld de, ext_bas
        call getnam
        ld b, 'R'
        call optlet
        ld a, 0
        rla
        ld (ldrun), a
        ld b, FA_READ
        call dopen
        call dget
        jp c, textin
        cp $55
        jr z, .bin
        call dunget
        jp textin
; A tokenised program: insert its lines one by one.
.bin:   call dhead
.line:  call dget                       ; the link: zero at the end
        jr c, .end
        ld d, a
        call dgetm
        or d
        jr z, .end
        call dgetm
        ld (buflnm), a
        ld h, a
        call dgetm
        ld (buflnm + 1), a
        ld l, a
        ld (linnum), hl
        ld hl, BUF - 1
        ld b, 4
.txt:   call dgetm
        ld (hl), a
        inc hl
        inc b
        jp z, fmerr                     ; no end in sight
        or a
        jr nz, .txt
        ld a, b
        cp BUFLEN
        jp nc, fmerr
        call insln
        call cheada
        jr .line
.end:   call clearc
        jp dos_ldend

; ---- DIR -----------------------------------------------------------------------
; DIR [drive]: the files in the current directory, with their sizes.
st_dir: jr z, .go
        call getbyt                     ; the drive number is ignored
.go:    ld a, '*'
        ld ix, .dot
        ld bc, $1000                    ; long names, unsorted
        ld l, F_OPENDIR
        call dos_call
        jp c, doserr
        ld (dosfh), a
.next:  call iscntc
        ld a, (dosfh)
        ld ix, dosbuf
        ld de, .dot
        ld l, F_READDIR
        call dos_call
        jp c, doserr
        or a
        jp z, dclose
        ld hl, dosbuf + 1
        ld a, (hl)
        cp '.'                          ; ".", ".." and hidden names
        jr z, .next
.name:  ld a, (hl)                      ; the whole name, in capitals:
        inc hl                          ; names are found in either case,
        or a                            ; and the Dragon has no lower case
        jr z, .endn
        cp 'a'
        jr c, .out
        cp 'z' + 1
        jr nc, .out
        and $DF
.out:   call chrout
        jr .name
.endn:  call devprm
        ld a, (devpos)                  ; a long name: the size goes on
        cp 21                           ; the next line
        jr c, .pad
        call crdo
.pad:   call devprm
        ld a, (devpos)
        cp 21
        jr nc, .size
        call outspc
        jr .pad
.size:  inc hl                          ; skip the time and date
        inc hl
        inc hl
        inc hl
        ld a, (dosbuf)
        and $10
        jr nz, .isdir
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ld a, (hl)
        inc hl
        or (hl)
        jr nz, .big
        ex de, hl
        call linprt
        jr .eol
.big:   ld e, d                         ; size / 1024, then "K"
        ld d, (hl)
        dec hl
        ld a, (hl)
        srl d
        rra
        rr e
        srl d
        rra
        rr e
        ld h, a
        ld l, e
        call linprt
        ld a, 'K'
        call chrout
        jr .eol
.isdir: ld hl, .dir
        call strout
.eol:   call crdo
        jp .next
.dot:   db ".", 0
.dir:   db "<DIR>", 0

; ---- KILL / RENAME -------------------------------------------------------------
; KILL "name.ext"
st_kill:
        ld de, 0
        call getnam
        ld a, '*'
        ld ix, fname
        ld l, F_UNLINK
        call dos_call
        jp c, doserr
        ret

; RENAME "old" TO "new"
st_rename:
        ld de, 0
        call getnam
        ld hl, fname
        ld de, fname2
        ld bc, 64
        ldir
        ld a, TK_TO
        call synchr
        ld de, 0
        call getnam
        ld a, '*'
        ld ix, fname2
        ld de, fname
        ld l, F_RENAME
        call dos_call
        jp c, doserr
        ret

; COPY "from" TO "to": copy a file. The new one must not exist (?FE).
st_copy:
        ld de, 0
        call getnam
        ld hl, fname
        ld de, fname2
        ld bc, 64
        ldir
        ld a, TK_TO
        call synchr
        ld de, 0
        call getnam
        call .swap                      ; the source, in DOSFH as for LOAD
        ld b, FA_READ
        call dopen
        call .swap
        ld a, '*'
        ld ix, fname
        ld b, FA_WRITE | FA_CREATE_NEW
        ld l, F_OPEN
        call dos_call
        jp c, doserr
        ld (cpdst), a
.lp:    ld a, (dosfh)
        ld ix, dosbuf
        ld bc, DBUFSZ
        ld l, F_READ
        call dos_call
        jr c, .err
        ld a, b
        or c
        jr z, .done
        ld a, (cpdst)
        ld ix, dosbuf
        ld l, F_WRITE
        call dos_call
        jr nc, .lp
.err:   push af
        call .shut
        pop af
        jp doserr
.done:  call .shut
        jp dclose
.shut:  ld a, (cpdst)
        ld l, F_CLOSE
        jp dos_call
; Exchange FNAME and FNAME2.
.swap:  ld hl, fname
        ld de, fname2
        ld b, 64
.sw:    ld a, (de)
        ld c, (hl)
        ld (hl), a
        ld a, c
        ld (de), a
        inc hl
        inc de
        djnz .sw
        ret

; PROTECT ON|OFF "name" and VERIFY [ON|OFF]: accepted, but do nothing.
st_protect:
        cp TK_ON
        jr z, .ok
        cp TK_OFF
        jp nz, snerr
.ok:    call chrget
        ld de, 0
        jp getnam
st_verify:
        ret z
        cp TK_ON
        jr z, .ok
        cp TK_OFF
        jp nz, snerr
.ok:    jp chrget

; ---- data files: OPEN, CLOSE, PRINT #, INPUT #, EOF -------------------------------
; The Dragon's cassette (device -1) is a file on the SD card here, named as
; given with ".DAT" added when there is no extension. Device -2, the
; printer, takes output and throws it away; device 0 is the screen and
; keyboard. DEVNUM holds 0, 1 (the file) or 2 (the printer).

; "#n" or "n": the device number into DEVNUM. ?DN ERROR unless 0, -1, -2.
getcdn: call chkcom
getdnm: cp '#'
        call z, chrget
        call frmnum
        call intcnv                 ; DE = a signed integer
        ld a, d
        or e
        jr z, .set                  ; 0: the screen
        ld a, d
        inc a
        jr nz, dnerr
        ld a, e
        cpl                         ; -1 gives 0, -2 gives 1
        cp 2
        jr nc, dnerr
        inc a
.set:   ld (devnum), a
        ret
dnerr:  ld e, ERR_DN
        jp error

; The device must be open for input (OPNICK) or output (OPNOCK).
opnick: ld a, (devnum)
        or a
        ret z
        cp 2
        jp z, fmerr2
        ld a, (fmode)
        or a
        jr z, noerr
        dec a
        ret z
        jp fmerr2
opnock: ld a, (devnum)
        dec a
        ret nz                      ; the screen or printer
        ld a, (fmode)
        or a
        jr z, noerr
        dec a
        ret nz
fmerr2: ld e, ERR_FM
        jp error
noerr:  ld e, ERR_NO
        jp error

; OPEN "I"|"O", #device, "name"
st_open:
        call frmevl
        call frestr                 ; the mode: its first character
        ld a, b
        or a
        jp z, fcerr
        ld a, (hl)
        push af
        call getcdn
        call chkcom
        ld de, ext_dat
        call getnam
        call chrgot
        jp nz, snerr
        ld a, (devnum)
        ld c, a
        xor a
        ld (devnum), a
        pop af
        cp 'I'
        jr z, .in
        cp 'O'
        jp nz, fmerr2
        ld a, c                     ; output: only the file needs opening
        dec a
        ret nz
        ld b, FA_WRITE | FA_CREATE_AL
        call dopen
        ld a, 2
        ld (fmode), a
        ret
.in:    ld a, c
        or a
        ret z                       ; the keyboard
        cp 2
        jp z, fmerr2                ; the printer
        ld b, FA_READ
        call dopen
        ld a, 1
        ld (fmode), a
        ret

ext_dat: db ".DAT", 0

; CLOSE [#device[, #device...]]
st_close:
        jr z, .all                      ; no list: close everything
        cp '1'                          ; CLOSE drive (1-4), as DragonDOS
        jr c, .lp
        cp '5'
        jr nc, .lp
        call chrget
        jp nz, snerr
.all:   call rfclr                      ; the random files' pointers too
        jr closit
.lp:    call getdnm
        call closit
        call chrgot
        ret z
        call chkcom
        jr .lp
closit: xor a
        ld (devnum), a
        ld a, (fmode)
        or a
        ret z
        cp 2
        call z, dflush
        xor a
        ld (fmode), a
        jp dclose

; Read a line of the data file into BUF: CR, LF or CR LF ends it. HL =
; BUF-1. ?IE ERROR if the end of the file comes first.
flinln: ld a, (devnum)
        cp 3
        jp z, rfline                    ; FREAD
        ld hl, BUF
        ld b, 0
.lp:    call dget
        jr c, .eof
        cp 10
        jr z, .end
        cp 13
        jr z, .cr
        ld (hl), a
        ld a, b
        cp BUFLEN
        jr nc, .lp                  ; too long: the rest is lost
        inc hl
        inc b
        jr .lp
.cr:    call dget                   ; a LF after the CR goes with it
        jr c, .end
        cp 10
        call nz, dunget
.end:   ld (hl), 0
        ld hl, BUF - 1
        ret
.eof:   ld e, ERR_IE
        jp error

; EOF(device): -1 at the end of the data file, else 0.
fn_eof: ld a, (valtyp)
        or a
        jp nz, rfeof                    ; EOF("name"): a random file
        ld a, (devnum)
        push af
        call intcnv
        ld a, d                     ; (as GETDNM, from the FAC)
        or e
        jr z, .dev
        ld a, d
        inc a
        jp nz, dnerr
        ld a, e
        cpl
        cp 2
        jp nc, dnerr
        inc a
.dev:   ld (devnum), a
        call opnick
        ld de, 0
        ld a, (devnum)
        or a
        jr z, .fin
        call dget
        jr c, .end
        call dunget
        jr .fin
.end:   dec de
.fin:   pop af
        ld (devnum), a
        jp givabf

dosbuf: ds DBUFSZ

; FREE [(drive)]: free space on the SD card's current drive, in bytes.
; Drives 1-4 are a Dragon's; they all mean the current drive here.
fn_free:
        call chrgot
        cp '('
        jr nz, .cur
        call chkopn
        call getbyt
        call chkcls
        ld a, e
        dec a
        cp 4
        jr c, .cur
        ld e, ERR_DN
        jp error
.cur:   ld a, '*'
        ld l, F_GETFREE
        call dos_call
        jp c, doserr
        ld a, $A0 + 9                   ; 512-byte blocks
        jp giv32

; ---- folders: CD and MKDIR (D32BASIC's own) ------------------------------------
F_MKDIR         EQU $AA

; A path into FNAME, zero-terminated (1-63 characters).
getpth: call frmevl
        call frestr                     ; HL = text, B = length
        ld a, b
        or a
        jp z, fserr
        cp 64
        jp nc, fserr
        ld de, fname
        ld c, b
        ld b, 0
        ldir
        xor a
        ld (de), a
        ret

; CD "path": change the current folder; "X:" in front changes the current
; drive as well. CD alone prints the current drive and folder.
st_cd:  jr z, .show
        call getpth
        ld hl, (fname)                  ; L = the first character, H = the second
        ld a, h
        cp ':'
        jr nz, .dir
        ld a, l
        and $DF
        sub 'A'
        cp 16
        jp nc, nedir
        add a, a
        add a, a
        add a, a
        or 1
        ld l, M_GETSETDRV
        call dos_call
        jp c, nedir
        ld a, (fname + 2)
        or a
        ret z                           ; "D:" alone: just the drive
.dir:   ld a, '*'
        ld ix, fname
        ld l, F_CHDIR
        call dos_call
        jp c, doserr
        ret
.show:  ld a, '*'
        ld ix, fname
        ld l, F_GETCWD
        call dos_call
        jp c, doserr
        ld a, (fname + 1)               ; esxDOS may give the drive or not
        cp ':'
        jr z, .path
        xor a
        ld l, M_GETSETDRV
        call dos_call
        jp c, doserr
        rrca
        rrca
        rrca
        and $1F
        add a, 'A'
        call chrout
        ld a, ':'
        call chrout
.path:  ld hl, fname
        call strout
        jp crdo
nedir:  ld e, ERR_NE
        jp error

; MKDIR "path": make a folder. ?FE ERROR if it is there already.
st_mkdir:
        call getpth
        ld a, '*'
        ld ix, fname
        ld l, F_MKDIR
        call dos_call
        jp c, doserr
        ret
