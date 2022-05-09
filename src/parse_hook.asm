include 'capnhook.inc'
include '../../toolchain/src/include/ti84pceg.inc'

; Stuff this will need to do:
; When multiplying or dividing a number by a string, parse out a type
; When adding or subtracting two complex numbers, check if they are both united, have the same units, and then add them keeping the units the same
; When multiplying or dividing two complex numbers, check if they are both united, then bytewise add or subtract their units
; When taking the exponent or root of a complex number, check if it is united, and then multiply each byte by the exponent
; When displaying a value, if it's united, turn it back into a string
; For any other operations involving a complex number, check if it is united, and if so throw an error
; I don't even know how lists are going to work

; United number format:
; A complex number - real part is coefficient, complex part is units
; Mantissa bytes: 4 bit exponents for s, kg, m, A, K, mol, cd, respectively
; First mantissa byte is or'd with $f0

section	.text,"ax",@progbits
public _parse_hook

_parse_hook:
	db	$83
ix_val:
	set	0,(iy-flag_continue)
	cp	a,3
	jr	nz,.not_type3

	ld	a,b
	cp	a,$0f ; Output(
	ret	nz

; check if this actually a united quantity
	ld	a,(ti.OP1)
	and	a,$3f
	cp	a,ti.CplxObj
	ret	nz
	ld	a,(ti.OP2+2)
	and	a,$f0
	cp	a,$f0
	ret	nz

	lea	iy,ix
	ld	de,handleToString-ix_val
	add	iy,de
	push	hl
	call	ti._indcall
	pop	hl
	ld	b,$0f
	xor	a,a
	ret

.not_type3:
	cp	a,1
	ret	nz

	;push	hl
	;scf
	;sbc	hl,hl
	;ld	(hl),2
	;pop	hl

; check if mult/div with string as second arg
	ld	a,(ti.OP1)
	cp	a,ti.StrngObj
	jr	nz,.not_string
	ld	a,l
	cp	a,2
	jr	nz,.not_string
	ld	a,b
	sub	a,ti.tMul
	srl	a
	jr	nz,.not_string

	push	bc,ix
	call	ti.ChkFindSym
	jp	c,ti.ErrUndefined
	set	7,(hl) ; mark dirty - todo: check if not temporary?
	ex	de,hl

	ld	c,(hl)
	inc	hl
	ld	a,(hl)
	inc	hl
	or	a,a
	jp	nz,ti.ErrSyntax

	lea	iy,ix
	ld	de,parse_unit-ix_val
	add	iy,de

	push	hl,bc
	call	ti._indcall
	pop	bc,hl
	ld	a,0

	jr	nc,.parsed

	ld	a,(hl)
	inc	hl
	dec	c
	jp	z,ti.ErrSyntax
	cp	a,ti.t2ByteTok
	jr	nz,.not_2byte

	ld	a,(hl)
	inc	hl
	dec	c
	jp	z,ti.ErrSyntax
.not_2byte:

	push	af
	call	ti._indcall
	ld	iy,ti.flags
	jp	c,ti.ErrSyntax
	pop	af

	ld	b,num_prefixes
	ld	hl,si_prefixes_full
.prefix_loop:
	cp	a,(hl)
	inc	hl
	jr	z,.prefix_found
	inc	hl
	djnz	.prefix_loop
	jp	ti.ErrSyntax
.prefix_found:
	ld	a,(hl)

.parsed:
	lea	hl,ix+3
	call	ti.Mov9OP1OP2
	ld	hl,ti.OP1+1
	add	a,(hl)
	ld	(hl),a

.copied:
	pop	ix,bc	

	ld	hl,2

.not_string:

; todo: complex lists?

; check if this even contains a united value
	ld	iy,(ti.FPS)
	push	hl
	ld	a,(ti.OP1)
	and	a,$1f
	cp	a,ti.CplxObj
	jr	nz,.find_united_loop
	ld	a,(ti.OP2+2)
	cp	a,$f0
	jr	nc,.found
.find_united_loop:
	dec	l
	jr	z,.notfound
	lea	iy,iy-9
	ld	a,(iy)
	and	a,$1f
	cp	a,ti.CplxObj
	jr	nz,.find_united_loop
	lea	iy,iy-9
	ld	a,(iy+9+2)
	cp	a,$f0
	jr	nc,.found
	jr	.find_united_loop

.notfound:
	pop	hl
; continue flag is set at beginning - don't bother setting either it or the registers here
	ret

; united number was found - we need to do *something*
.found:
	pop	hl
	ld	iy,ti.flags

; b = operation
; 	recip:	0c
; 	square:	0d
; 	add:	70
; 	sub: 	71
;	frac:	81
; 	mul: 	82
; 	div: 	83
;	neg:	b0
; 	sqrt: 	bc
;	3root:	bd
; 	exp: 	f0
;	root:	f1
; implicit mul reuses mul

	;push	hl
	;scf
	;sbc	hl,hl
	;ld	(hl),2
	;pop	hl

	dec	l
	jr	nz,multi_arg

single_arg:
	ld	a,b
	cp	a,$A6
	ld	de,handleToString - ix_val
	jr	z,.call_handler
	cp	a,$A7
	ld	de,handleToString - ix_val
	jr	z,.call_handler

iterate op, Chs, Recip, Sqr, Sqrt, CubRt
	cp	a,ti.t#op
	ld	de,handle#op - ix_val
	jr	z,.call_handler
end iterate

	jp	ti.ErrDataType

.call_handler:
	lea	iy,ix
	add	iy,de
	call	ti._indcall
	ret

multi_arg:
	dec	l
	jp	nz,ti.ErrDataType

	push	bc
	call	ti.PopOP3

; check that neither arg is complex but not united
; convert any real numbers into united with no units
	ld	iy,ti.OP1
iterate n, 1, 3
	ld	a,(iy+ti.OP#n-ti.OP1)
	and	a,$7f
	cp	a,ti.CplxObj
	jr	z,.op#n#_complex
	or	a,a
	jr	z,.op#n#_real
	ld	iy,ti.flags
	jp	ti.ErrDataType
.op#n#_real:
	lea	hl,ix
	ld	de,.null_type - ix_val
	add	hl,de
	ld	de,ti.OP#n + 11
	call	ti.Mov9b
	jr	.op#n#_valid
.op#n#_complex:
	ld	a,(iy+ti.OP#n-ti.OP1+13)
	cp	a,$f0
	jp	c,ti.ErrDataType
.op#n#_valid:
end iterate

; (coeff2, unit2, coeff1, unit1) -> (coeff1, coeff2, unit2, unit1)
	call	ti.OP2ToOP5
	call	ti.OP1ToOP2
	call	ti.OP3ToOP1
	call	ti.OP5ToOP3

	pop	af

iterate op, Mul, Div, Add, Sub
	cp	a,ti.t#op
	ld	de,handle#op - ix_val
	jr	z,.call_handler
end iterate

	ld	iy,ti.flags
	jp	ti.ErrDataType

.call_handler:
	lea	iy,ix
	add	iy,de
	call	ti._indcall
	ret

.null_type:
	db	$0c,$80,$f0,$f0,$f0,$f0,$f0,$f0,$f0

handleMul:
	ld	de,ti.OP4+2
	ld	hl,ti.OP3+2
	ld	b,7
	ld	c,0
.loop:
	ld	a,(de)
	add	a,(hl)
	or	a,$f0
	ld	(de),a
	and	a,$0f
	jr	z,.zero
	ld	c,$ff
.zero:
	inc	hl
	inc	de
	djnz	.loop

	push	bc
	call	ti.FPMult
	pop	af
	jr	handle2ArgTail

handleDiv:
	ld	de,ti.OP4+2
	ld	hl,ti.OP3+2
	ld	b,7
	ld	c,0
.loop:
	ld	a,(de)
	sub	a,(hl)
	or	a,$f0
	ld	(de),a
	and	a,$0f
	jr	z,.zero
	ld	c,$ff
.zero:
	inc	hl
	inc	de
	djnz	.loop

	push	bc
	call	ti.FPDiv
	pop	af
	jr	handle2ArgTail

handleAdd:
	ld	iy,ti.flags
	call	ti.FPAdd
	jr	checkSameUnits

handleSub:
	ld	iy,ti.flags
	call	ti.FPSub
; fall through to checkSameUnits

checkSameUnits:
	ld	hl,ti.OP3 + 2
	ld	de,ti.OP4 + 2
	ld	bc,7
.loop:
	ld	a,(de)
	inc	de
	cpi
	jp	nz,ti.ErrDataType
; ugh why can't you jr po
	ld	a,c
	or	a,a
	jr	nz,.loop
	scf
; fall through to handle2ArgTail

handle2ArgTail:
	jr	nc,hookTail
	ld	a,ti.CplxObj
	ld	(ti.OP1),a
	call	ti.OP4ToOP2
hookTail:
	ld	iy,ti.flags
	res	0,(iy-flag_continue)
	ld	a,1
	and	a,a
	ret

handleChs:
	call	ti.InvOP1S
	jr	hookTail

handleRecip:
	call	ti.PushRealO2
	call	ti.FPRecip
	call	ti.PopRealO2
	ld	a,(ti.OP1)
	or	a,ti.CplxObj
	ld	(ti.OP1),a
	ld	hl,ti.OP2+2
	ld	b,7
.loop:
	ld	a,(hl)
	neg
	or	a,$f0
	ld	(hl),a
	inc	hl
	djnz	.loop
	jr	hookTail

handleSqr:
	call	ti.PushRealO2
	call	ti.FPSquare
	call	ti.PopRealO2
	ld	a,(ti.OP1)
	or	a,ti.CplxObj
	ld	(ti.OP1),a
	ld	hl,ti.OP2+2
	ld	b,7
.loop:
	ld	a,(hl)
	sla	a
	or	a,$f0
	ld	(hl),a
	inc	hl
	djnz	.loop
hookTailTramp:
	jr	hookTail

handleSqrt:
	ld	iy,ti.flags
	call	ti.PushRealO2
	call	ti.SqRoot
	call	ti.PopRealO2
	ld	a,(ti.OP1)
	or	a,ti.CplxObj
	ld	(ti.OP1),a
	ld	hl,ti.OP2+2
	ld	b,7
.loop:
	ld	a,(hl)
	ld	d,a
	and	a,$f8
	ld	e,a
	ld	a,d
	and	a,$0f
	srl	a
	jp	c,ti.ErrDataType
	or	a,e
	ld	(hl),a
	inc	hl
	djnz	.loop
	jr	hookTailTramp

handleCubRt:
	jp	ti.ErrDataType

handleToString:
	ld	bc,format_united-handleToString
	add	iy,bc
	call	ti._indcall
	ex	de,hl
	ld	de,$D0033A
	or	a,a
	sbc	hl,de

	call	ti.CreateTStrng
	inc	de
	inc	de
	ld	hl,$D0033A
.loop:
	ld	a,(hl)
; I'm not sure why MathPrint uses ' ' for space and tokens for everything else.
; I'm not sure I want to know.
	cp	a,' '
	jr	nz,.not_space
	ld	a,ti.tSpace
.not_space:
	ld	(de),a
	inc	hl
	inc	de
	dec	bc
	ld	a,b
	or	a,c
	jr	nz,.loop

	call	ti.OP4ToOP1

	jr	hookTailTramp

; hl = pointer to first token
; c = size
; iy = ptr to self
; destroys a,bc,de,hl
; returns ix = unit, or c if not found
parse_unit:
	lea	ix,iy
	ld	de,_metric_units-parse_unit
	add	ix,de
	push	hl
	ld	de,0
	ld	hl,ti.scrapMem
	ld	(hl),de
	ex	de,hl
	pop	hl
	ld	b,3
	inc	c
.preparse_loop:
	dec	c
	jr	z,.preparse_done
	ld	a,(hl)
	inc	hl
	cp	a,ti.t2ByteTok
	jr	nz,.not2byte

	dec	c
	jp	z,ti.ErrSyntax
	ld	a,(hl)
	inc	hl
.not2byte:
	ld	(de),a
	inc	de
	djnz	.preparse_loop
.preparse_done:

	ld	de,(ti.scrapMem)
	ld	b,num_metric_units
.unit_loop:
	ld	hl,(ix)
	or	a,a
	sbc	hl,de
	ret	z
	lea	ix,ix+sizeof_unit
	djnz	.unit_loop
	scf
	ret

hook_size = $ - _parse_hook

extern	_metric_units
extern	num_metric_units
extern	format_united
extern	sizeof_unit
extern	si_prefixes_full
extern	num_prefixes
