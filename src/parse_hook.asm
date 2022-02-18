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
; A complex number with bit 5 of second type set
; Mantissa bytes: 4 bit exponents for s, kg, m, A, K, mol, cd, respectively
; First mantissa byte is or'd with $f0

public _parse_hook
_parse_hook:
	db	$83
ix_val:
	set	0,(iy-flag_continue)
	cp	a,1
	ret	nz

	;push	hl
	;scf
	;sbc	hl,hl
	;ld	(hl),2
	;pop	hl

; todo: special check for mult/div with string in OP1

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

	push	hl
	scf
	sbc	hl,hl
	ld	(hl),2
	pop	hl

	ld	de,2
	or	a,a
	sbc	hl,de
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

; swap OP2 and OP3
	call	ti.OP2ToOP5
	call	ti.OP3ToOP2
	call	ti.OP5ToOP3

	pop	af

iterate op, Mul, Div, Add, Sub
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
	jr	handleTail

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
	jr	handleTail

handleAdd:
	ld	iy,ti.flags
	jp	ti.ErrDataType

handleSub:
	ld	iy,ti.flags
	jp	ti.ErrDataType

handleTail:
	jr	nc,.dimensionless
	ld	a,ti.CplxObj
	ld	(ti.OP1),a
	call	ti.OP4ToOP2
.dimensionless:
	ld	hl,2
	ld	iy,ti.flags
	res	0,(iy-flag_continue)
	ld	a,1
	and	a,a
	ret

; parses the string in OP1, returns united value in OP1 and OP2 or throws a data type error
parse_string:
	ld	iy,ti.flags
	ret

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

hook_size = $ - _parse_hook

public _parse_hook_size
_parse_hook_size:
	dl	hook_size
