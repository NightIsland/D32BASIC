; ===========================================================================
; Settings: the settings screen (the GRAPH key) and D32BASIC.CFG.
;
; D32BASIC.CFG lives in the folder D32BASIC.NEX was started from. It is plain
; text, one setting a line, so it can be edited on a PC too:
;
;   FOLDER=C:/DRAGON/       the folder for programs and data files
;                           (empty: the start-up folder)
;   UNSUPPORTED=ERROR       or IGNORE: skip unsupported statements
;   SPEED=28                CPU speed in MHz: 3.5, 7, 14 or 28
;
; The folder is made the esxDOS current folder, so every file command
; (SAVE, LOAD, DIR, OPEN ...) uses it with no change of its own.
; ===========================================================================

F_GETCWD        EQU $A8
F_CHDIR         EQU $A9

; At start-up: remember the start-up folder, read the settings, apply them.
set_init:
        xor a
        ld (setign), a
        ld (setfld), a
        ld (startdir), a
        ld a, 3
        ld (setspd), a
        ld a, '*'
        ld ix, startdir
        ld l, F_GETCWD
        call dos_call
        jr nc, .cfg
        xor a                           ; not known: stay where we are
        ld (startdir), a
.cfg:   call cfgread
        jp setapply

; Read D32BASIC.CFG from the current (start-up) folder, if it is there.
cfgread:
        ld a, '*'
        ld ix, cfgnam
        ld b, FA_READ
        ld l, F_OPEN
        call dos_call
        ret c                           ; no file: the defaults
        push af
        ld ix, cfgbuf
        ld bc, 255
        ld l, F_READ
        call dos_call
        jr nc, .got
        ld bc, 0
.got:   pop af
        push bc
        ld l, F_CLOSE
        call dos_call
        pop bc
        ld hl, cfgbuf                   ; end the text, and each line, with 0
        add hl, bc
        ld (hl), 0
        ld hl, cfgbuf
.term:  ld a, (hl)
        or a
        jr z, .parse
        cp 13
        jr z, .z
        cp 10
        jr nz, .nx
.z:     ld (hl), 0
.nx:    inc hl
        jr .term
.parse: ld hl, cfgbuf
        add hl, bc
        ex de, hl                       ; DE = the end of the text
        ld hl, cfgbuf
.line:  push de
        or a
        push hl
        sbc hl, de
        pop hl
        jr nc, .endp
        call setkey
.skip:  ld a, (hl)                      ; on to the next line
        inc hl
        or a
        jr nz, .skip
        pop de
        jr .line
.endp:  pop de
        ret

; One line at HL: act on it if it is a setting. Preserves HL.
setkey: push hl
        ld de, k_folder
        call kmatch
        jr nz, .ign
        ld de, setfld
        ld b, 63
.cp:    ld a, (hl)
        or a
        jr z, .cpe
        ld (de), a
        inc hl
        inc de
        djnz .cp
.cpe:   xor a
        ld (de), a
        jr .done
.ign:   pop hl
        push hl
        ld de, k_unsup
        call kmatch
        jr nz, .spd
        ld a, (hl)
        and $DF
        cp 'I'
        ld a, 0
        jr nz, .setig
        inc a
.setig: ld (setign), a
        jr .done
.spd:   pop hl
        push hl
        ld de, k_speed
        call kmatch
        jr nz, .done
        ld a, (hl)
        ld b, 3
        cp '2'                          ; 28
        jr z, .sets
        dec b
        cp '1'                          ; 14
        jr z, .sets
        dec b
        cp '7'
        jr z, .sets
        dec b
        cp '3'                          ; 3.5
        jr nz, .done
.sets:  ld a, b
        ld (setspd), a
.done:  pop hl
        ret

; Does the text at HL start with the key at DE (either case)? Z if so,
; with HL just past it.
kmatch: ld a, (de)
        or a
        ret z
        ld c, a
        ld a, (hl)
        cp 'a'
        jr c, .uc
        cp 'z' + 1
        jr nc, .uc
        and $DF
.uc:    cp c
        ret nz
        inc hl
        inc de
        jr kmatch

; Apply the settings: CPU speed, unsupported statements (read where they
; are met) and the folder. Carry set if the folder could not be entered.
setapply:
        ld a, (setspd)
        nextreg $07, a
        ld ix, setfld
        ld a, (ix)
        or a
        jr nz, .cd
        ld ix, startdir
        ld a, (ix)
        or a
        ret z                           ; start-up folder not known
.cd:    ld a, '*'
        ld l, F_CHDIR
        jp dos_call

; Write D32BASIC.CFG in the start-up folder. Carry set on an error.
cfgwrite:
        ld a, (startdir)
        or a
        jr z, .here
        ld a, '*'
        ld ix, startdir
        ld l, F_CHDIR
        call dos_call
        ret c
.here:  ld de, cfgbuf                   ; build the text
        ld hl, k_folder
        call setcpy
        ld hl, setfld
        call setcpy
        call setnl
        ld hl, k_unsup
        call setcpy
        call unsnam
        call setcpy
        call setnl
        ld hl, k_speed
        call setcpy
        call spdnam
        call setcpy
        call setnl
        push de
        ld a, '*'
        ld ix, cfgnam
        ld b, FA_WRITE | FA_CREATE_AL
        ld l, F_OPEN
        call dos_call
        pop de
        jr c, .back
        push af
        ex de, hl                       ; the length
        ld de, cfgbuf
        or a
        sbc hl, de
        ld b, h
        ld c, l
        ld ix, cfgbuf
        ld l, F_WRITE
        call dos_call
        pop bc                          ; B = the handle
        push af                         ; the write's carry
        ld a, b
        ld l, F_CLOSE
        call dos_call
        pop af
.back:  push af                         ; back to the files folder
        call setapply
        pop af
        ret

setcpy: ld a, (hl)
        or a
        ret z
        ld (de), a
        inc hl
        inc de
        jr setcpy
setnl:  ld a, 13
        ld (de), a
        inc de
        ld a, 10
        ld (de), a
        inc de
        ret

; HL = the name of the unsupported-statements setting.
unsnam: ld hl, m_error
        ld a, (setign)
        or a
        ret z
        ld hl, m_ignore
        ret
; HL = the CPU speed, as text.
spdnam: ld a, (setspd)
        add a, a
        ld l, a
        ld h, 0
        push de
        ld de, spdtab
        add hl, de
        pop de
        ld a, (hl)
        inc hl
        ld h, (hl)
        ld l, a
        ret

cfgnam:   db "D32BASIC.CFG", 0
k_folder: db "FOLDER=", 0
k_unsup:  db "UNSUPPORTED=", 0
k_speed:  db "SPEED=", 0
m_error:  db "ERROR", 0
m_ignore: db "IGNORE", 0
spdtab:   dw m_s0, m_s1, m_s2, m_s3
m_s0:     db "3.5", 0
m_s1:     db "7", 0
m_s2:     db "14", 0
m_s3:     db "28", 0

; ---- the settings screen -----------------------------------------------------
; GRAPH opens it at any time (POLCAT sees KEY_SETUP): at the OK prompt,
; while typing, or while a program runs. The text screen, cursor and
; display are saved and put back afterwards, so a program carries on as if
; nothing happened.
setovl: ld a, (insetup)
        or a
        ret nz                          ; already open
        inc a
        ld (insetup), a
        push bc
        push de
        push hl
        push ix
        ld hl, SCRADR                   ; save the text screen
        ld de, scrsav
        ld bc, 512
        ldir
        ld hl, (curadr)
        push hl
        ld a, (devpos)
        ld h, a
        ld a, (devnum)
        ld l, a
        push hl
        ld a, (filein)
        ld h, a
        ld a, (inkchr)
        ld l, a
        push hl
        ld a, (dspon)
        ld b, a
        ld a, (piacss)
        ld c, a
        push bc
        xor a
        ld (devnum), a                  ; the screen and keyboard
        ld (filein), a
        call samalp                     ; show the text screen
        call setscr
        pop bc                          ; B = display on, C = colour set
        push bc
        ld hl, scrsav                   ; put the screen back
        ld de, SCRADR
        ld bc, 512
        ldir
        pop bc
        ld a, c
        ld (piacss), a
        xor a
        ld (l2_scroll), a
        nextreg $17, a
        ld a, b
        ld (dspon), a
        or a
        jr z, .txt
        call grall
        jr .rest
.txt:   call txtcol
        call render_all
.rest:  pop hl
        ld a, l
        ld (inkchr), a
        ld a, h
        ld (filein), a
        pop hl
        ld a, l
        ld (devnum), a
        ld a, h
        ld (devpos), a
        pop hl
        ld (curadr), hl
        pop ix
        pop hl
        pop de
        pop bc
        xor a
        ld (insetup), a
        ret

; The screen itself: show the settings, act on keys until ENTER or BREAK.
setscr: call grnchr
        ld hl, m_title
        call strout
        ld hl, setfld
        ld a, (hl)
        or a
        jr nz, .f
        ld hl, m_start
.f:     call strout
        ld hl, m_unsup
        call strout
        call unsnam
        call strout
        ld hl, m_speed
        call strout
        call spdnam
        call strout
        ld hl, m_mhz
        call strout
        ld hl, m_keys
        call strout
.key:   call setkin
        cp '1'
        jr z, .fold
        cp '2'
        jr z, .unsup
        cp '3'
        jr z, .speed
        cp 13
        jr z, .save
        cp 3
        jr nz, .key
        ret
.unsup: ld hl, setign
        ld a, (hl)
        xor 1
        ld (hl), a
        jr setscr
.speed: ld hl, setspd
        dec (hl)
        ld a, (hl)
        and 3
        ld (hl), a
        nextreg $07, a
        jr setscr
.save:  call cfgwrite
        ret nc
        ld hl, m_nosave
        jr .msg
.fold:  ld hl, m_ask
        call strout
        ld hl, setfld                   ; keep the old one
        ld de, setold
        ld bc, 64
        ldir
        call setlin                     ; the new one into SETFLD
        jp c, setscr                    ; BREAK: no change
        call setapply
        jp nc, setscr
        ld hl, setold                   ; not there: back to the old one
        ld de, setfld
        ld bc, 64
        ldir
        call setapply
        ld hl, m_nofold
.msg:   call strout
        call setkin
        jp setscr

; A key for the settings screen (waits, cursor blinking).
setkin: call keyinp
        and $7F
        ret

; Read a line of up to 63 characters into SETFLD. Carry set on BREAK.
; (Not INLIN: BUF may hold the line being typed, or running.)
setlin: ld hl, setfld
        ld b, 0
.k:     call setkin
        cp 3
        scf
        ret z
        cp 13
        jr z, .end
        cp 8
        jr nz, .ch
        ld a, b
        or a
        jr z, .k
        dec hl
        dec b
        ld a, 8
        call chrout
        jr .k
.ch:    cp ' '
        jr c, .k
        ld c, a
        ld a, b
        cp 63
        jr nc, .k
        ld a, c
        ld (hl), a
        inc hl
        inc b
        call chrout
        jr .k
.end:   ld (hl), 0
        call crdo
        or a
        ret

m_title:  db "D32BASIC SETTINGS", 13, 13
          db "1 FILES FOLDER:", 13, "  ", 0
m_start:  db "(START-UP FOLDER)", 0
m_unsup:  db 13, 13, "2 UNSUPPORTED COMMANDS: ", 0
m_speed:  db 13, 13, "3 CPU SPEED: ", 0
m_mhz:    db " MHZ", 13, 13, 0
m_keys:   db "PRESS 1, 2 OR 3 TO CHANGE.", 13
          db "ENTER SAVES THE SETTINGS,", 13
          db "BREAK LEAVES WITHOUT SAVING.", 13, 0
m_ask:    db 13, "NEW FOLDER (EMPTY FOR THE", 13
          db "START-UP FOLDER)?", 13, 0
m_nofold: db 13, "?NE ERROR: NO SUCH FOLDER", 13
          db "PRESS A KEY", 0
m_nosave: db 13, "?IO ERROR: COULD NOT SAVE", 13
          db "D32BASIC.CFG. PRESS A KEY", 0

; Buffers (bank 5, outside the system variables).
scrsav:   ds 512                        ; the text screen under the settings
cfgbuf:   ds 256                        ; D32BASIC.CFG being read or written
setold:   ds 64
insetup:  db 0
