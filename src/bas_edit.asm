; Program editing commands: DEL, RENUM, EDIT.

; DEL line, DEL from-to, DEL -to, DEL from-
st_del: jp z, fcerr
        call linget
        call fndlin
        ld (tmpptr), hl             ; first line to delete
        call chrgot
        jr z, .src
        cp TK_MINUS
        ret nz                      ; NEWSTT gives the ?SN ERROR
        call chrget
        jr z, .toend
        call linget
        call chrgot
        jp nz, snerr
        jr .src
.toend: ld a, $FF
        ld (linnum + 1), a
.src:   ld hl, (tmpptr)
.lp:    ld a, (hl)                  ; end of program?
        inc hl
        or (hl)
        dec hl
        jr z, .dor
        push hl
        inc hl
        inc hl
        ld d, (hl)
        inc hl
        ld e, (hl)
        ld hl, (linnum)
        or a
        sbc hl, de                  ; carry: this line is beyond the range
        pop hl
        jr c, .dor
        ld a, (hl)
        inc hl
        ld l, (hl)
        ld h, a
        jr .lp
.dor:   ex de, hl                   ; DE = first line kept
        ld hl, (vartab)
        or a
        sbc hl, de
        ld b, h
        ld c, l
        inc bc                      ; (never zero)
        ex de, hl
        ld de, (tmpptr)
        ldir
        dec de
        ld (vartab), de
        call runc
        ld hl, (tmpptr)
        call chead
        jp ready

st_renum:
st_edit:
st_exec:
prtusg:
        jp st_unimpl

fn_usr:
fn_unimpl:
        jp fcerr
