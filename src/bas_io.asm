; Console input and output: CHROUT, the line editor (INLIN), printing
; helpers and the device parameters PRINT uses for commas and TAB.

CBLVAL          EQU 25              ; cursor blink period in frames

; Send A to the current output device. Preserves all registers.
chrout:
        push af
        ld a, (devnum)
        dec a                       ; 1: the open disk file
        jr z, .file
        dec a                       ; 2: the printer (there is none)
        jr z, .none
        pop af
        jp scrout
.none:  pop af
        ret
.file:  pop af
        jp dos_putc

crdo:   ld a, 13
        jr chrout
outspc: ld a, ' '
        jr chrout
outqst: ld a, '?'
        jr chrout

; Start a new line unless already at the left margin.
condcr:
        call devprm
        ld a, (devpos)
        or a
        ret z
        jr crdo

; Set DEVPOS, DEVWID, DEVLCF, DEVCFW for the current device (the screen).
; Z clear (the screen has a finite width). Preserves BC, DE, HL.
devprm:
        ld a, (curadr)
        and $1F
        ld (devpos), a
        ld a, 16
        ld (devcfw), a
        ld (devlcf), a
        xor a
        ld (spcio), a
        ld a, 32
        ld (devwid), a
        or a
        ret

; Print the zero-terminated string at HL.
strout:
        ld a, (hl)
        or a
        ret z
        call chrout
        inc hl
        jr strout

; Print " IN " and the line number in HL.
inprt:
        push hl
        ld hl, msg_in
        call strout
        pop hl
; Print HL as an unsigned decimal number, no padding.
linprt:
        push bc
        push de
        ld b, 0                     ; digits printed so far
        ld de, 10000
        call .dig
        ld de, 1000
        call .dig
        ld de, 100
        call .dig
        ld de, 10
        call .dig
        ld a, l
        add a, '0'
        call chrout
        pop de
        pop bc
        ret
.dig:   ld a, '0' - 1
.sub:   inc a
        or a
        sbc hl, de
        jr nc, .sub
        add hl, de
        cp '0'
        jr nz, .out
        inc b
        dec b
        ret z                       ; suppress leading zeros
.out:   inc b
        jp chrout

; ---- input -----------------------------------------------------------------

; Read a character from the current input device into A (7 bits).
inchr:
        call chrinp
        and $7F
        ret
chrinp:
        xor a
        ld (eofflg), a
        ld a, (filein)              ; loading a program from a file?
        or a
        jp nz, dos_getc
; Keyboard: blink the cursor until a key arrives.
keyinp:
    IF TESTMODE
        jp test_inchr
    ELSE
        push hl
.wait:  call cblink
        call polcat
        jr z, .wait
        ld hl, (curadr)             ; take the cursor off
        ld (hl), INVSP
        call render_hl
        pop hl
        ret
    ENDIF

; Wait a frame; every CBLVAL frames invert the cell at the cursor.
cblink:
        push af
        push hl
        halt
        ld hl, cblcnt
        dec (hl)
        jr nz, .x
        ld (hl), CBLVAL
        ld hl, (curadr)
        ld a, (hl)
        xor $40
        ld (hl), a
        call render_hl
.x:     pop hl
        pop af
        ret

; INLIN: read a line into BUF with editing. Returns HL = BUF-1 (ready for
; CRUNCH), carry set if BREAK was pressed.
inlcls: call grnchr
inlin:
        xor a
        ld (inkchr), a
        ld hl, BUF
        ld b, 1                     ; characters + 1
.next:  call inchr
        ld c, a
        ld a, (eofflg)
        or a
        jr nz, .done
        ld a, (filein)
        or a
        ld a, c
        jr nz, .noedit
        cp $0C                      ; CLEAR: clear the screen, start again
        jr z, inlcls
        cp 8                        ; delete a character
        jr nz, .notdel
        dec b
        jr z, inlin
        dec hl
        jr .echo
.notdel:
        cp $15                      ; delete the line
        jr nz, .notld
.rub:   dec b
        jr z, inlin
        ld a, 8
        call chrout
        jr .rub
.notld: cp 3                        ; BREAK
        scf
        jr z, .fin
.noedit:
        cp 13
        jr nz, .notcr
.done:  or a
.fin:   push af
        ld a, 13
        call .echo1
        ld (hl), 0
        ld hl, BUF - 1
        pop af
        ret
.notcr: cp ' '
        jr c, .next
        cp 'z' + 1
        jr nc, .next
        ld c, a
        ld a, b
        cp BUFLEN
        ld a, c
        jr nc, .next
        ld (hl), a
        inc hl
        inc b
.echo:  call .echo1
        jr .next
.echo1: push af                     ; no echo when reading a file
        ld a, (filein)
        or a
        jr nz, .noec
        pop af
        jp chrout
.noec:  pop af
        ret
