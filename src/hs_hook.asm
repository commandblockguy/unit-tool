include 'capnhook.inc'
include '../../toolchain/src/include/ti84pceg.inc'

public _hs_hook
_hs_hook:
	db	$83
ix_val:
	set	0,(iy-flag_continue)
	or	a,a
	ret	nz

	push	hl
	scf
	sbc	hl,hl
	ld	(hl),2
	pop	hl

	ret

hook_size = $ - _hs_hook

public _hs_hook_size
_hs_hook_size:
	dl	hook_size
