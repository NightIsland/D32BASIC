; System variables, buffers and the text screen, all in bank 5 ($4000-$4FFF).
; The names follow the Dragon's own where there is an equivalent, so the
; ROM documentation can be read alongside this code. Multi-byte values that
; BASIC programs can see (line numbers, links, floats, string descriptors)
; are big-endian, as on the 6809. Pointers private to the interpreter are
; little-endian Z80 words.

; ---- constants -----------------------------------------------------------
BUFLEN          EQU 250             ; line input buffer size
NUMLEV          EQU 29              ; stack levels REASON keeps free
NUMTMP          EQU 8               ; string temporaries
STRSIZ          EQU 5               ; bytes per string descriptor
STRSPC          EQU 200             ; default string space
FBUFLN          EQU 16              ; number output buffer

        MMU 2 3, 10, $4000          ; bank 5 at $4000-$7FFF

; ---- text screen: 32x16 cells laid out like Dragon video RAM -------------
SCRADR:         ds 512
SCREND          EQU SCRADR + 512

; ---- hardware / runtime state --------------------------------------------
curadr:         dw 0                ; cursor address in SCRADR
l2_scroll:      db 0                ; Layer 2 Y offset (multiple of 12)
cblcnt:         db 0                ; cursor blink counter
allock:         db 0                ; alpha lock: nonzero = upper case
ticker:         dw 0                ; 50 Hz tick counter (TIMER)
frames:         db 0                ; frame counter for blink
kb_state:       ds 8                ; last matrix state, one byte per half-row
kb_buf:         ds 16               ; key ring buffer
kb_head:        db 0
kb_tail:        db 0
kb_last:        db 0                ; key held, for auto-repeat
kb_rpt:         db 0                ; repeat countdown
inkchr:         db 0                ; key saved by BREAK check for INKEY$
at_ptr:         dw 0                ; TESTMODE: next AUTOTYPE byte
at_end:         dw 0                ; TESTMODE: end of AUTOTYPE data
dbg_on:         db 0                ; TESTMODE: echo screen output once input starts
rc_y:           db 0                ; renderer scratch
rc_x:           db 0
rc_pat:         ds 12

; ---- interpreter state ---------------------------------------------------
txtptr:         dw 0                ; CHRGET pointer
curlin:         dw 0                ; current line number ($FFFF = direct)
oldlin:         dw 0                ; line for CONT
oldtxt:         dw 0                ; text pointer for CONT
datlin:         dw 0                ; line of current DATA
datptr:         dw 0                ; READ pointer
txttab:         dw 0                ; start of program
vartab:         dw 0                ; start of simple variables
arytab:         dw 0                ; start of arrays
strend:         dw 0                ; end of arrays / start of free
fretop:         dw 0                ; bottom of used string space
memsiz:         dw 0                ; top of string space
endmem:         dw 0                ; top of usable RAM
stktop:         dw 0                ; top of the stack (bottom of strings)
frespc:         dw 0                ; new string pointer
temppt:         dw 0                ; next free string temporary
lastpt:         dw 0                ; last used string temporary
tempst:         ds STRSIZ * NUMTMP  ; string temporaries
tempend:
linnum:         dw 0                ; line number from LINGET
lowtr:          dw 0                ; block move scratch
lowds:          dw 0
hightr:         dw 0
highds:         dw 0
lstptr:         dw 0                ; LIST pointer
varnam:         dw 0                ; variable name being looked up
varpnt:         dw 0                ; pointer to variable value
forpnt:         dw 0                ; pointer to FOR/LET variable
fnpnt:          dw 0                ; DEF FN scratch
tmpptr:         dw 0                ; general scratch pointer
tmpptr2:        dw 0
stktmp:         dw 0
valtyp:         db 0                ; 0 = numeric, $FF = string
dimflg:         db 0                ; nonzero while DIMming
subflg:         db 0                ; nonzero to forbid subscripts
inpflg:         db 0                ; nonzero for READ, zero for INPUT
count:          db 0
trmchr:         db 0
charac:         db 0
endchr:         db 0
invnam:         db 0
indata:         db 0
funflg:         db 0
toknum:         db 0
relflg:         db 0
trcflg:         db 0                ; TRON
oprflag:        db 0
devnum:         db 0                ; 0 = screen/keyboard
devpos:         db 0
devwid:         db 0
devlcf:         db 0
devcfw:         db 0
spcio:          db 0
eofflg:         db 0
filein:         db 0                ; nonzero: INLIN reads the open file
ldrun:          db 0                ; nonzero: RUN once the load ends
dosfh:          db 0                ; esxDOS handle of the open file, $FF = none
dbufp:          dw 0                ; next byte in DOSBUF
dbufn:          dw 0                ; bytes left in DOSBUF (reading)
fname:          ds 64               ; file name for esxDOS, zero-terminated
fname2:         ds 64               ; RENAME's new name
brkflg:         db 0                ; bit 7: print BREAK
ifcnt:          db 0
errnum:         db 0                ; error code being reported                ; IFs skipped looking for ELSE
txtbeg:         dw 0                ; start of the current statement
opmask:         db 0                ; FRMEVL: relations seen (> 1, = 2, < 4)
opptr:          dw 0                ; FRMEVL: operator that ended an operand
domask:         db 0                ; relations being tested
relstr:         db 0                ; nonzero: comparing strings
evalflg:        db 0                ; nonzero: PTRGET called from EVAL
curtol:         dw 0                ; array size / offset accumulator
arypnt:         dw 0                ; array being built or scanned
indice:         dw 0                ; current array index
integr2:        dw 0                ; AND/OR left operand
dsctmp:         ds 5                ; descriptor being built
dscpnt:         dw 0                ; descriptor being worked on
strng1:         dw 0
strng2:         dw 0
grbpnt:         dw 0                ; garbage collection: best descriptor
grbtop:         dw 0                ; garbage collection: its address
garbfl:         db 0                ; nonzero once collected for this request
inpptr:         dw 0                ; INPUT/READ data pointer
vartxt:         dw 0                ; INPUT/READ variable list pointer
usdptr:         dw 0                ; PRINT USING: format string descriptor
usflg:          db 0                ; PRINT USING: a value was printed
pumask:         db 0                ; PRINT USING: field flags
fldwid:         db 0                ; PRINT USING: field width / leading digits
dpwid:          db 0                ; PRINT USING: point and fraction digits
usscnt:         db 0                ; PRINT USING: format characters left
tempx1:         dw 0
fdecpt:         dw 0                ; PRINT USING: where the point went
comcnt:         db 0                ; PRINT USING: digits to the next comma
puptr:          dw 0                ; PRINT USING: output pointer
rennew:         dw 0                ; RENUM: first new number
reninc:         dw 0                ; RENUM: step
renfst:         dw 0                ; RENUM: first old line to renumber
rfirst:         dw 0                ; RENUM: its number ($FFFF: none)
rencur:         dw 0                ; RENUM: line being scanned
renst:          dw 0                ; RENUM: reference text start
renend:         dw 0                ; RENUM: reference text end
rbuf:           ds 6                ; RENUM: new reference text

; ---- floating point accumulators -----------------------------------------
facexp:         db 0                ; FAC: exponent, 4 mantissa bytes, sign
facho:          db 0
facmoh:         db 0
facmo:          db 0
faclo:          db 0
facsgn:         db 0
sgnflg:         db 0
facov:          db 0                ; FAC overflow (rounding) byte
argexp:         db 0                ; ARG, same layout
argho:          db 0
argmoh:         db 0
argmo:          db 0
arglo:          db 0
argsgn:         db 0
arisgn:         db 0                ; sign of FAC*ARG
resho:          db 0                ; multiply/divide result
resmoh:         db 0
resmo:          db 0
reslo:          db 0
resov:          db 0                ; FDIV stores a fifth byte here
bits:           db 0                ; fill byte for shifts
deccnt:         db 0
dptflg:         db 0
tenexp:         db 0
expsgn:         db 0
integr:         db 0
degree:         db 0                ; polynomial evaluation
polypt:         dw 0
tansgn:         db 0
sinqd:          db 0
fbufpt:         dw 0
tempf1:         ds 5
tempf2:         ds 5
tempf3:         ds 5
rndx:           ds 5                ; RND seed (packed float)
rndtmp:         ds 4

; ---- buffers -------------------------------------------------------------
nzlink:         db 1                ; nonzero, so CHEAD sees a link
buflnm:         dw 0                ; line number goes here before BUF
bufmin:         db 0                ; INPUT stores a comma here
BUF:            ds BUFLEN + 2
fbuffr:         ds 40               ; number formatting

sysvars_end:
        ASSERT sysvars_end <= $5000
