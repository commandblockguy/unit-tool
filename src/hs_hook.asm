include 'capnhook.inc'
include '../../toolchain/src/include/ti84pceg.inc'

section	.text,"ax",@progbits
public _hs_hook

_hs_hook:
	db	$83
ix_val:
	set	0,(iy-flag_continue)
	or	a,a
	ret	nz

	ld	a,(ti.OP1)
	and	a,$3f
	cp	a,ti.CplxObj
	ret	nz

	ld	a,(ti.OP2+2)
	cp	a,$f0
	ret	c

	;push	hl
	;scf
	;sbc	hl,hl
	;ld	(hl),2
	;pop	hl

	call	format_united

	ld	hl,$D0033A
	ld	a,1
	ld	iy,ti.flags
	call	$21890

	res	0,(iy-flag_continue)
	res	ti.donePrgm,(iy+ti.doneFlags)

	xor	a,a
	inc	a

	ret

hook_size = $ - _hs_hook

extern format_united
