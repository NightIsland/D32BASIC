; Instant SCREEN changes for the text screen and PMODE 0-4.
;
; On a Dragon, SCREEN only tells the video chip which memory to show, so
; the picture changes at once. Here the text screen and PMODE 0-4 are drawn
; into Layer 2, which takes a moment, so there are two Layer 2 pictures:
; banks 9-11 and 19-21. Every write goes to the one NextREG $13 names
; (L2CUR), which is also the one on show (NextREG $12), so a change to the
; screen on show appears at once. A whole redraw (SCREEN, or the text
; coming back) is drawn into the other one, out of sight, which is then
; shown.

L2_BANK2        EQU 19              ; the second picture: banks 19-21

; Point writes at the picture not on show.
l2back: ld a, (l2cur)
        xor L2_BANK ^ L2_BANK2
        ld (l2cur), a
        nextreg $13, a
        ret

; Show the picture writes go to, with Y scroll A.
l2show: push af
        ld a, (l2cur)
        nextreg $12, a
        pop af
        nextreg $17, a
        ret
