; Keyboard: the frame interrupt scans the Spectrum Next key matrix (the
; membrane and a PS/2 keyboard both appear in it) and queues Dragon key
; codes. CAPS SHIFT and SYMBOL SHIFT select the second and third tables.
;
; Dragon-specific keys: CAPS+SPACE = BREAK ($03), CAPS+0 or CAPS+5 = left
; arrow / delete ($08), CAPS+8 = right arrow ($09), CAPS+6 = down ($0A),
; CAPS+7 = up arrow ($5E, which is also the ^ character), CAPS+1 = CLEAR
; ($0C), CAPS+2 = toggle lower case (the Dragon's SHIFT+0).

KEY_TOGGLE      EQU $FF             ; internal: alpha lock toggle
RPT_DELAY       EQU 25              ; frames before auto-repeat
RPT_RATE        EQU 4               ; frames between repeats

; Called from the frame interrupt. Uses AF, BC, DE, HL.
kb_scan:
        ld hl, kb_state
        ld d, $FE                   ; half-row select (A8-A15)
        ld e, 0                     ; matrix index of row start
.row:   ld a, d
        in a, ($FE)
        cpl
        and $1F                     ; 1 = pressed
        ld c, a
        ld a, e                     ; mask out the two shift keys
        or a
        jr nz, .r7
        res 0, c                    ; CAPS SHIFT
.r7:    cp 35
        jr nz, .new
        res 1, c                    ; SYMBOL SHIFT
.new:   ld a, (hl)                  ; newly pressed = now AND NOT before
        cpl
        and c
        ld (hl), c
        jr z, .next
        ld b, e                     ; find the first new bit
.bit:   rrca
        jr c, .found
        inc b
        jr .bit
.found: ld a, b
        ld (kb_last), a
        ld a, RPT_DELAY
        ld (kb_rpt), a
        ld a, b
        push hl
        call kb_queue_index
        pop hl
        ; carry on scanning so the state table stays current
.next:  inc hl
        ld a, e
        add a, 5
        ld e, a
        rlc d
        jr c, .row
        ; auto-repeat of the held key
        ld a, (kb_last)
        cp $FF
        ret z
        call kb_is_down
        jr nz, .held
        ld a, $FF
        ld (kb_last), a
        ret
.held:  ld hl, kb_rpt
        dec (hl)
        ret nz
        ld (hl), RPT_RATE
        ld a, (kb_last)
        jp kb_queue_index

; Z clear if matrix key A is currently down.
kb_is_down:
        ld b, 0
.d:     sub 5
        jr c, .got
        inc b
        jr .d
.got:   add a, 5                    ; A = bit, B = row
        ld c, a
        ld hl, kb_state
        ld a, l
        add a, b
        ld l, a
        adc a, h
        sub l
        ld h, a
        ld a, (hl)
        inc c
.sh:    dec c
        jr z, .t
        rrca
        jr .sh
.t:     and 1
        ret

; Translate matrix index A with the current shift state and queue it.
; Uses AF, BC, HL.
kb_queue_index:
        push de
        ld c, a
        ld b, 0
        ld e, 0                     ; E = 1 unless the plain table
        ld hl, kb_plain
        ld a, $FE                   ; CAPS SHIFT is row $FE bit 0
        in a, ($FE)
        rrca
        jr c, .nocaps
        ld hl, kb_caps
        inc e
        jr .look
.nocaps:
        ld a, $7F                   ; SYMBOL SHIFT is row $7F bit 1
        in a, ($FE)
        bit 1, a
        jr nz, .look
        ld hl, kb_sym
        inc e
.look:  add hl, bc
        ld a, (hl)
        or a
        jr z, .done
        cp KEY_TOGGLE
        jr nz, .notog
        ld a, (allock)
        cpl
        ld (allock), a
        jr .done
.notog: ld d, a                     ; plain letters follow the alpha lock
        dec e
        jr z, .q
        cp 'A'
        jr c, .q
        cp 'Z' + 1
        jr nc, .q
        ld a, (allock)
        or a
        jr nz, .q
        set 5, d
.q:     ld a, d
        call kb_put
.done:  pop de
        ret

; Put key A into the ring buffer (dropped if full).
kb_put:
        push hl
        push bc
        ld c, a
        ld a, (kb_head)
        ld b, a
        inc a
        and 15
        ld hl, kb_tail
        cp (hl)
        jr z, .full
        ld (kb_head), a
        ld a, b
        ld hl, kb_buf
        add a, l
        ld l, a
        adc a, h
        sub l
        ld h, a
        ld (hl), c
.full:  pop bc
        pop hl
        ret

; POLCAT: A = next key and Z clear, or A = 0 and Z set if none.
; Preserves all other registers.
polcat:
        push hl
        ld a, (kb_tail)
        ld hl, kb_head
        cp (hl)
        jr z, .none
        ld l, a
        inc a
        and 15
        ld (kb_tail), a
        ld a, l
        ld hl, kb_buf
        add a, l
        ld l, a
        adc a, h
        sub l
        ld h, a
        ld a, (hl)
        pop hl
        or a
        ret
.none:  pop hl
        xor a
        ret

kb_plain:
        db 0,   'Z', 'X', 'C', 'V'
        db 'A', 'S', 'D', 'F', 'G'
        db 'Q', 'W', 'E', 'R', 'T'
        db '1', '2', '3', '4', '5'
        db '0', '9', '8', '7', '6'
        db 'P', 'O', 'I', 'U', 'Y'
        db 13,  'L', 'K', 'J', 'H'
        db ' ', 0,   'M', 'N', 'B'
kb_caps:
        db 0,   'Z', 'X', 'C', 'V'
        db 'A', 'S', 'D', 'F', 'G'
        db 'Q', 'W', 'E', 'R', 'T'
        db $0C, KEY_TOGGLE, 0, 0, 8
        db 8,   0,   9,   $5E, 10
        db 'P', 'O', 'I', 'U', 'Y'
        db 13,  'L', 'K', 'J', 'H'
        db 3,   0,   'M', 'N', 'B'
kb_sym:
        db 0,   ':', 0,   '?', '/'
        db 0,   0,   '\\', 0,  0
        db 0,   0,   0,   '<', '>'
        db '!', '@', '#', '$', '%'
        db '_', ')', '(', "'", '&'
        db '"', ';', 0,   ']', '['
        db 13,  '=', '+', '-', '^'
        db ' ', 0,   '.', ',', '*'

; ---- JOYSTK -------------------------------------------------------------------------
; The Dragon's joysticks are analogue (0-63 each way). The Next's are
; digital, so each axis reads 0, 31 (centred) or 63. JOYSTK(0) and (1) are
; the right joystick (Next port 1), (2) and (3) the left (port 2); as on the
; Dragon, only JOYSTK(0) reads the sticks and the others give the values it
; read.
fn_joystk:
        call conint
        ld a, e
        cp 4
        jp nc, fcerr
        or a
        call z, joyin
        ld d, 0
        ld hl, potval
        add hl, de
        ld e, (hl)
        jp sngflt

joyin:  ld hl, potval
        in a, ($1F)                 ; Kempston 1
        call .one
        in a, ($37)                 ; Kempston 2
.one:   ld c, a
        ld b, 2                     ; left / right bits
        call .axis
        ld a, c                     ; up / down bits
        rra
        rra
        ld c, a
        ld b, 2
.axis:  ld a, c
        and b
        ld a, 0
        jr nz, .st
        ld a, c
        srl b
        and b
        ld a, 63
        jr nz, .st
        ld a, 31
.st:    ld (hl), a
        inc hl
        ret

; Make both joystick ports Kempston (port 1 at $1F, port 2 at $37), keeping
; the video timing and scandoubler bits of register 5.
joyset: ld bc, $243B
        ld a, 5
        out (c), a
        inc b
        in a, (c)
        and $05
        or $42
        out (c), a
        ret
