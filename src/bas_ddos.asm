; DragonDOS BASIC extras that are not about disks: error trapping, SWAP.
; Behaviour follows DragonDOS 1.0 (checked against its ROM in the oracle).

; ERROR GOTO line. ERROR GOTO 0 (or no line) turns trapping off.
st_error:
        cp TK_GO
        jp nz, snerr
        call chrget
        cp TK_TO
        jp nz, snerr
        call chrget
        call linget
        ld hl, (linnum)
        ld (traplin), hl
        ret

; Called by ERROR with the error code in (errnum), the stack reset. Records
; ERR and ERL; if a trap is set and a program is running, goes to the trap
; line and does not return.
errtrap:
        call rfclos                     ; a random file left open
        xor a
        ld (autofl), a
        ld hl, (curlin)
        ld (errlin), hl
        ld a, (errnum)
        cp ERR_NE                       ; DragonDOS's disk errors have
        jr c, .code                     ; codes from 128
        push hl
        sub ERR_NE
        rrca
        ld e, a
        ld d, 0
        ld hl, .dosc
        add hl, de
        ld a, (hl)
        pop hl
.code:  ld (errcod), a
        ld a, h
        and l
        inc a
        ret z                           ; direct mode: never trapped
        ld hl, (traplin)
        ld a, h
        or l
        ret z
        ld (linnum), hl
        call fndlin
        jr c, .gone
        pop af                          ; not returning to ERROR
        call crdo                       ; DragonDOS starts a new line
        call dexptr
        jp newstt
.gone:  ld hl, 0                        ; no such line: DragonDOS loops
        ld (traplin), hl                ; forever; we report ?UL instead
        ld a, ERR_UL
        ld (errnum), a
        ret

.dosc:  db 160, 148, 150, 152, 158, 154, 162 ; NE DF FS PT FE FE TF

; RUN clears ERR, ERL and the trap, and the random files' read pointers.
errclr: call rfclr
        ld hl, 0
        ld (traplin), hl
        ld (errlin), hl
        xor a
        ld (errcod), a
        ret

; ERR: the code of the last error (twice its number in the error table).
fn_err: ld a, (errcod)
        ld e, a
        jp sngflt
; ERL: the line of the last error, -1 in direct mode.
fn_erl: ld de, (errlin)
        jp givabf

; SWAP var, var: exchange two variables or array elements of one type.
st_swap:
        call ptrget
        push hl
        ld a, (valtyp)
        push af
        call chkcom
        ld hl, (arytab)
        push hl
        call ptrget
        ex de, hl                       ; DE = second
        pop bc                          ; BC = ARYTAB before
        pop af
        pop hl                          ; HL = first
        push de
        push af
        push hl
        ld hl, (arytab)                 ; a new simple variable moves the
        or a                            ; arrays up, and the first with
        sbc hl, bc                      ; them if it is an array element
        ex de, hl                       ; (DragonDOS 1.0 swaps with the
        pop hl                          ; old place and corrupts the
        push hl                         ; array)
        or a
        sbc hl, bc
        pop hl
        jr c, .simp
        add hl, de
.simp:  pop af
        ex (sp), hl                     ; (SP) = first, HL = second
        ld b, a
        ld a, (valtyp)
        cp b
        jp nz, tmerr
        pop de                          ; DE = first, HL = second
        ld b, 5
.swp:   ld a, (de)
        ld c, (hl)
        ld (hl), a
        ld a, c
        ld (de), a
        inc hl
        inc de
        djnz .swp
        ret

; AUTO [start[,step]]: number the lines as they are typed, from 100 in
; steps of 10. Each prompt is put in the line as if typed; a line with
; nothing after the number ends AUTO, as does BREAK or an error. Direct
; mode only (?FC in a program).
st_auto:
        push af
        ld hl, (curlin)
        ld a, h
        and l
        inc a
        jp nz, fcerr
        pop af
        ld de, 100
        ld bc, 10
        jr z, .set
        jp nc, snerr                    ; a line number must come next
        call linget
        ld de, (linnum)
        ld bc, 10
        call chrgot
        jr z, .set
        push de
        call chkcom
        jp nc, snerr
        call linget
        ld bc, (linnum)
        ld a, b
        or c
        jp z, snerr
        pop de
.set:   ld (autonx), de
        ld (autoinc), bc
        ld a, 1
        ld (autofl), a
        ret

; Read a line, with the next AUTO number already in it.
autoin: ld a, (autofl)
        or a
        jp z, inlin
        ld hl, (autonx)
        ld de, 64000
        or a
        sbc hl, de
        add hl, de
        jr c, .ok
        xor a
        ld (autofl), a
        jp inlin
.ok:    push hl
        ld de, (autoinc)
        add hl, de
        jr nc, .st
        ld hl, $FFFF
.st:    ld (autonx), hl
        pop hl
        xor a
        ld (inkchr), a
        ld de, BUF
        ld ix, .pow
.dig:   ld c, (ix)
        ld b, (ix + 1)
        ld a, '0' - 1
.sub:   inc a
        or a
        sbc hl, bc
        jr nc, .sub
        add hl, bc
        cp '0'                          ; leading zeros are left out,
        jr nz, .put                     ; but not the units
        push hl
        ld hl, BUF
        or a
        sbc hl, de
        pop hl
        jr nz, .put
        dec bc
        ld a, b
        or c
        ld a, '0'
        jr nz, .skip
.put:   ld (de), a
        inc de
.skip:  inc ix
        inc ix
        ld a, (ix)
        or (ix + 1)
        jr nz, .dig
        ld a, ' '
        ld (de), a
        inc de
        ld hl, BUF
.echo:  ld a, (hl)
        call chrout
        inc hl
        or a
        sbc hl, de
        add hl, de
        jr nz, .echo
        ex de, hl                       ; HL = the end of the line so far
        ld a, l
        sub BUF & $FF
        inc a
        ld b, a                         ; characters + 1
        jp inlinp
.pow:   dw 10000, 1000, 100, 10, 1, 0

; After the line number of a typed line (Z: nothing follows it): an AUTO
; line left empty ends AUTO and keeps any line of that number.
autend: ret nz
        ld a, (autofl)
        or a
        ret z
        xor a
        ld (autofl), a
        pop af
        call crdo
        jp main

; BEEP [n]: n short beeps (1-255).
st_beep:
        ld e, 1
        jr z, .go
        call gnzbyt
.go:    ld a, e
.lp:    push af
        ld hl, 112                      ; AY period for about 1 kHz
        ld d, 15
        call snd_tone
        ld b, 3
        call snd_wait
        call snd_off
        pop af
        dec a
        ret z
        push af
        ld b, 15
        call snd_wait
        call iscntc
        pop af
        jr .lp

; WAIT n: pause for n milliseconds (0-65535), to the nearest frame.
st_wait:
        ret z                           ; WAIT alone does nothing
        call evladr
        ex de, hl
.lp:    ld de, 10
        or a
        sbc hl, de
        ret c
        push hl
        ld b, 1
        call snd_wait
        call iscntc
        pop hl
        ld de, 10
        or a
        sbc hl, de
        ret c
        jr .lp

; HIMEM: the top of BASIC's memory, as a Dragon address where it has one
; (so that CLEAR n,HIMEM+1 leaves it where it is).
fn_himem:
        ld hl, (memsiz)
        ld de, $FA00
        or a
        sbc hl, de
        add hl, de
        jr nc, .next
        ld de, -$7A00
        add hl, de
.next:  ex de, hl
        jp givuns

; FRE$: free string space, after collecting the garbage.
fn_fres:
        call garbag
        ld hl, (fretop)
        ld de, (stktop)
        or a
        sbc hl, de
        ex de, hl
        jp givuns

; FAC = unsigned 32-bit BCDE times 2^(A - $A0).
giv32:  ld (facexp), a
        ld a, b
        ld (facho), a
        ld a, c
        ld (facmoh), a
        ld a, d
        ld (facmo), a
        ld a, e
        ld (faclo), a
        xor a
        ld (facov), a
        ld (facsgn), a
        ld (valtyp), a
        jp normal

; CHAIN: copy every string whose text is in the program (A$="X") into
; string space, so the variables outlive the program. ?OS ERROR if there
; is not room for them.
chnstr: push ix
        ld hl, 0
        ld (chnneed), hl
        ld hl, .count
        ld (walkfn), hl
        call strwlk
        call garbag
        ld hl, (fretop)
        ld de, (stktop)
        or a
        sbc hl, de
        ld de, (chnneed)
        or a
        sbc hl, de
        ld e, ERR_OS
        jp c, error
        ld hl, .copy
        ld (walkfn), hl
        call strwlk
        pop ix
        ret
.count: call .chk
        ret c
        ld hl, (chnneed)
        add hl, bc
        ld (chnneed), hl
        ret
.copy:  call .chk
        ret c
        push hl
        ld hl, (fretop)
        or a
        sbc hl, bc
        ld (fretop), hl
        ex de, hl                       ; DE = its new place
        pop hl
        ld (ix + 2), d
        ld (ix + 3), e
        ldir
        ret
; Carry clear if the string at IX is in the program: HL = it, BC = length.
.chk:   ld a, (ix + 0)
        or a
        scf
        ret z
        ld c, a
        ld b, 0
        ld h, (ix + 2)
        ld l, (ix + 3)
        ld de, (txttab)
        or a
        sbc hl, de
        add hl, de
        ret c                           ; below the program
        ld de, (vartab)
        or a
        sbc hl, de
        add hl, de
        ccf                             ; at or above its end: carry
        ret

; ---- random-access files ----------------------------------------------------
; FREAD, FLREAD and FWRITE name a file (".DAT" if no extension) and work at
; a byte position: FROM, or for reading the file's read pointer, or for
; writing the end of the file. Each opens the file, does its work and
; closes it again, so nothing is lost if the program stops; only the read
; pointers (of up to RFMAX files) are kept, until CLOSE or RUN.

; Forget every read pointer (CLOSE, RUN).
rfclr:  ld hl, rftab
        ld de, rftab + 1
        ld bc, RFMAX * RFSIZ - 1
        ld (hl), 0
        ldir
        ret

; "name"[,FROM n][,FOR n]: the name into FNAME, FROM into RFPOS/RFFROM,
; FOR into RFFOR. A = the next character.
rfhead: ld de, ext_dat
        call getnam
        xor a
        ld (rffrom), a
        ld h, a
        ld l, a
        ld (rffor), hl
.opt:   call chrgot
        cp ','
        ret nz
        call chrget
        cp TK_FROM
        jr nz, .for
        call chrget
        call frmnum
        call get32
        ld a, 1
        ld (rffrom), a
        jr .opt
.for:   cp TK_FOR
        jp nz, snerr
        call chrget
        call evladr
        ld a, d
        or e
        jp z, fcerr
        ld (rffor), de
        jr .opt

; Find FNAME's entry, or make one (pointer 0): RFENT. ?TF ERROR if all are
; in use. Keeps A and the flags.
rffind: push af
        call rflook
        jr nc, .got
        ld hl, rftab
        ld b, RFMAX
.free:  ld a, (hl)
        or a
        jr z, .new
        ld de, RFSIZ
        add hl, de
        djnz .free
        ld e, ERR_TF
        jp error
.new:   push hl
        ex de, hl
        ld hl, fname
        ld bc, 64
        ldir
        xor a
        ld b, 4
.zero:  ld (de), a
        inc de
        djnz .zero
        pop hl
.got:   ld (rfent), hl
        pop af
        ret

; FNAME's entry: carry clear and HL = it, or carry set.
rflook: ld hl, rftab
        ld b, RFMAX
.lp:    push hl
        ld de, fname
.cmp:   ld a, (de)
        cp (hl)
        jr nz, .no
        inc hl
        inc de
        or a
        jr nz, .cmp
        pop hl
        ret
.no:    pop hl
        ld de, RFSIZ
        add hl, de
        djnz .lp
        scf
        ret

; FAC (0 up to 2^32-1) into RFPOS, low byte first.
get32:  ld a, (facsgn)
        or a
        jp m, fcerr
        ld a, (facexp)
        cp $A1
        jp nc, fcerr
        call qint
        ld hl, faclo
        ld de, rfpos
        ld b, 4
.cp:    ld a, (hl)
        ld (de), a
        dec hl
        inc de
        djnz .cp
        ret

; HL = the entry's read pointer (4 bytes after the name).
rfptr:  ld hl, (rfent)
        ld de, 64
        add hl, de
        ret

; Open FNAME with mode B, into RFH; nothing buffered, RFCNT 0.
rfopen: ld a, '*'
        ld ix, fname
        ld l, F_OPEN
        call dos_call
        jp c, doserr
        ld (rfh), a
        ld a, 1
        ld (rfopn), a
        ld hl, 0
        ld (rbn), hl
        ld (rfcnt), hl
        ld hl, rfbuf
        ld (rbp), hl
        ret

; Seek RFH to RFPOS.
rfseek: ld hl, rfpos
        ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ld c, (hl)
        inc hl
        ld b, (hl)
        ld a, (rfh)
        ld ix, 0                        ; from the start
        ld l, F_SEEK
        call dos_call
        ret nc
; An esxDOS error with the file open: close it, then report it.
rferr:  push af
        call rfclos
        pop af
        jp doserr

; The file's length into RFSTAT+7 (4 bytes, low first).
rfsize: ld a, (rfh)
        ld ix, rfstat
        ld l, F_FSTAT
        call dos_call
        jr c, rferr
        ret

; Close the file, if it is open (also after an error).
rfclos: ld a, (rfopn)
        or a
        ret z
        xor a
        ld (rfopn), a
        ld a, (rfh)
        ld l, F_CLOSE
        jp dos_call

; Next byte of the file in A; carry set at its end, or at the end of the
; FOR record. Counts RFCNT.
rget:   push hl
        push bc
        push de
        ld hl, (rffor)
        ld a, h
        or l
        jr z, .any
        ex de, hl
        ld hl, (rfcnt)
        or a
        sbc hl, de
        ccf
        jr c, .out                      ; the record is used up
.any:   ld hl, (rbn)
        ld a, h
        or l
        jr nz, .have
        ld a, (rfh)
        ld ix, rfbuf
        ld bc, 256
        ld l, F_READ
        call dos_call
        jr c, rferr
        ld h, b
        ld l, c
        ld de, rfbuf
        ld (rbp), de
        ld a, h
        or l
        scf
        jr z, .out
.have:  dec hl
        ld (rbn), hl
        ld hl, (rfcnt)
        inc hl
        ld (rfcnt), hl
        ld hl, (rbp)
        ld a, (hl)
        inc hl
        ld (rbp), hl
        or a
.out:   pop de
        pop bc
        pop hl
        ret

; Read a line of the file into RLBUF (FREAD's INPUT, through FLINLN): CR
; or LF (or CR LF), or the end of the file, ends it. HL = RLBUF-1. ?FE ERROR
; (read past the end) if nothing is left.
rfline: ld hl, (rfcnt)
        ld (rfbase), hl
        ld hl, rlbuf
        ld b, 0
        call rget
        jr c, .past
.lp:    cp 10
        jr z, .end
        cp 13
        jr z, .cr
        ld (hl), a
        ld a, b
        cp BUFLEN
        jr nc, .full                    ; too long: the rest is lost
        inc hl
        inc b
.full:  call rget
        jr nc, .lp
        jr .end
.cr:    push hl                         ; a LF straight after goes with it
        ld hl, (rbn)
        ld a, h
        or l
        jr z, .crx
        ld hl, (rbp)
        ld a, (hl)
        cp 10
        call z, rget
.crx:   pop hl
.end:   ld (hl), 0
        ld hl, rlbuf - 1
        ret
.past:  call rfclos
        ld e, ERR_RE
        jp error

; FREAD "name"[,FROM n][,FOR n];variables: read as INPUT does, with
; commas, colons and line ends between the items.
st_fread:
        call rfread
        SYNCHK ';'
        ld a, 3                         ; FLINLN reads from RFH
        ld (devnum), a
        ld hl, rlbuf - 1
        call inpcon
        xor a
        ld (devnum), a
        ld hl, (inpptr)                 ; where the reading stopped
        ld a, (hl)
        or a
        ld hl, (rfcnt)
        jr z, rfdone                    ; at a line end: all of it is used
        ld hl, (inpptr)                 ; else up to its terminator
        ld de, rlbuf - 1
        or a
        sbc hl, de
        ld de, (rfbase)
        add hl, de
        jr rfdone

; FLREAD "name"[,FROM n][,FOR n];string: a whole line, commas included.
st_flread:
        call rfread
        SYNCHK ';'
        call ptrget
        ld (forpnt), hl
        call chkstr
        call rfline
        ld hl, rlbuf
        xor a
        ld (charac), a
        ld (endchr), a
        call strlit
        call inpcom
        ld hl, (rfcnt)
; HL bytes have been read: close the file and move the read pointer to
; RFPOS plus those (or plus FOR).
rfdone: ld de, (rffor)
        ld a, d
        or e
        jr z, .add
        ex de, hl
.add:   push hl
        call rfclos
        pop bc
        call rfptr
        ex de, hl
        ld hl, rfpos
        ld a, (hl)
        add a, c
        ld (de), a
        inc hl
        inc de
        ld a, (hl)
        adc a, b
        ld (de), a
        ld b, 2
.carry: inc hl
        inc de
        ld a, (hl)
        adc a, 0
        ld (de), a
        djnz .carry
        ret

; FREAD/FLREAD: parse, open, and seek to FROM or the read pointer.
rfread: call rfhead
        push af
        ld a, (rffrom)
        or a
        jr nz, .open
        call rflook                     ; the read pointer, 0 if none
        ld de, 64
        jr nc, .has
        ld hl, fn_loc.zero - 64
.has:   add hl, de
        ld de, rfpos
        ld bc, 4
        ldir
.open:  ld b, FA_READ
        call rfopen
        call rffind                     ; only once it opens
        call rfseek
        pop af
        ret

; FWRITE "name"[,FROM n][,FOR n];items: write numbers and strings as PRINT
; shows them, with nothing between the items. FOR pads the record with
; spaces or cuts it short. Writes at the end of the file unless FROM.
st_fwrite:
        call rfhead
        SYNCHK ';'
        push af
        ld b, FA_READ | FA_WRITE | FA_OPEN_AL
        call rfopen
        ld a, (rffrom)
        or a
        jr nz, .seek
        call rfsize
        ld hl, rfstat + 7
        ld de, rfpos
        ld bc, 4
        ldir
.seek:  call rfseek
        ld a, 3                         ; CHROUT writes to RFH
        ld (devnum), a
        pop af
.item:  jr z, rfend
        call frmevl
        ld a, (valtyp)
        or a
        jr nz, .str
        call fout
        call strout
        call outspc
        jr .sep
.str:   call strprt
.sep:   call chrgot
        jr z, rfend
        cp ','
        jr z, .next
        cp ';'
        jp nz, snerr
.next:  call chrget
        jr .item
; Pad to the FOR length, write what is left and close.
rfend:  ld de, (rffor)
.pad:   ld hl, (rfcnt)
        or a
        sbc hl, de
        jr nc, .done
        ld a, ' '
        call rfputc
        jr .pad
.done:  xor a
        ld (devnum), a
        call rfflsh
        jp rfclos

; CREATE "name"[,length]: a new file of that many spaces.
st_create:
        ld de, ext_dat
        call getnam
        ld de, 0
        call chrgot
        jr z, .go
        call chkcom
        call evladr
.go:    ld (rffor), de
        ld b, FA_WRITE | FA_CREATE_NEW
        call rfopen
        jr rfend

; Output to the file being written (CHROUT, device 3). Characters past a
; FOR length are dropped. Keeps every register.
rfputc: push hl
        push de
        push af
        ld hl, (rffor)
        ld a, h
        or l
        jr z, .put
        ex de, hl
        ld hl, (rfcnt)
        or a
        sbc hl, de
        jr nc, .skip
.put:   ld hl, (rfcnt)
        inc hl
        ld (rfcnt), hl
        pop af
        push af
        ld hl, (rbp)
        ld (hl), a
        inc hl
        ld (rbp), hl
        ld de, rfbuf + 256
        or a
        sbc hl, de
        call z, rfflsh
.skip:  pop af
        pop de
        pop hl
        ret

; Write out RFBUF. Keeps every register.
rfflsh: push af
        push bc
        push de
        push hl
        push ix
        ld hl, (rbp)
        ld de, rfbuf
        or a
        sbc hl, de
        ld b, h
        ld c, l
        ld a, h
        or l
        jr z, .x
        ld a, (rfh)
        ld ix, rfbuf
        ld l, F_WRITE
        call dos_call
        jp c, rferr
        ld hl, rfbuf
        ld (rbp), hl
.x:     pop ix
        pop hl
        pop de
        pop bc
        pop af
        ret

; The argument of LOF, LOC: "name" or ("name").
rfarg:  call chrgot
        ld de, ext_dat
        cp '('
        jp nz, getnam
        call chkopn
        ld de, ext_dat
        call getnam
        jp chkcls

; LOF "name": the file's length in bytes.
fn_lof: call rfarg
        ld b, FA_READ
        call rfopen
        call rfsize
        call rfclos
        ld hl, rfstat + 7
; FAC = the 4 bytes at HL (low first).
giv4:   ld e, (hl)
        inc hl
        ld d, (hl)
        inc hl
        ld c, (hl)
        inc hl
        ld b, (hl)
        ld a, $A0
        jp giv32

; LOC "name": the file's read pointer (0 if it has none).
fn_loc: call rfarg
        call rflook
        jr c, .none
        ld de, 64
        add hl, de
        jr giv4
.none:  ld hl, .zero
        jr giv4
.zero:  dd 0

; EOF("name"), from FN_EOF with the name in the FAC: 0 if the read pointer
; is at the end of the file, else 1 (as the DragonDOS manual has it).
rfeof:  ld de, ext_dat
        call getnmf
        call rflook
        ld de, 64
        jr nc, .has
        ld hl, fn_loc.zero - 64
.has:   add hl, de
   ld de, rfpos
        ld bc, 4
        ldir
        ld b, FA_READ
        call rfopen
        call rfsize
        call rfclos
        ld hl, rfstat + 7               ; length - pointer: <= 0 at the end
        ld de, rfpos
        ld b, 4
        ld c, 0                         ; OR of the result bytes
        or a
.sub:   ld a, (hl)
        ex de, hl
        sbc a, (hl)
        ex de, hl
        push af
        or c
        ld c, a
        pop af
        inc hl
        inc de
        djnz .sub
        ld e, 0
        jr c, .end                      ; past it
        ld a, c
        or a
        jr z, .end                      ; at it
        inc e
.end:   jp sngflt
