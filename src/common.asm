include '../../toolchain/src/include/ti84pceg.inc'

section .text

; Out of the unusual combination of laziness and a desire to save space,
; I'm using a string format where, if bit 7 of each byte is set, it should
; be preceded by a $BB byte.
; This will surely come back to byte me later.
macro reformat_string str, len
	local b
	local extra_padding
	extra_padding = 0
	repeat lengthof str
		b = (str shr (8 * (% - 1))) and $ff
		if 'a' <= b & b <= 'k'
			db	ti.tLa + b - 'a'
		else if 'l' <= b & b <= 'z'
			db	ti.tLl + b - 'l'
		else if b = 'Ω' shr 8
			db	ti.tLcapOmega
		else if b = 'Ω' and $ff
			extra_padding = extra_padding + 1
		else if b = '°' shr 8
			db	ti.tFromDeg
		else if b = '°' and $ff
			extra_padding = extra_padding + 1
		else if b = 'μ' shr 8
			db	ti.tLmu
		else if b = 'μ' and $ff
			extra_padding = extra_padding + 1
		else
			db	b
		end if
	end repeat
	rb	len - lengthof str + extra_padding
end macro

num_base_units = 0
macro base_unit name
	element	base_units.name:num_base_units
	reformat_string	`name, 3
	num_base_units = num_base_units + 1
end macro

public	base_units
base_units:
	base_unit	m
	base_unit	kg
	base_unit	s
	base_unit	A
	base_unit	K
	base_unit	mol
	base_unit	cd

macro unit symbol, mantissa, exp, dims
	local	dims_v
	dims_v = $f0f0f0f0f0f0f0
	reformat_string	`symbol, 3
	db	$0c
	db	$80 + exp
	db	mantissa bswap 7
	db	$0c,$80
repeat	elementsof (dims)
	dims_v = dims_v or ((((dims) scale %) and $f) shl (8 * ((dims) metadata %)))
end repeat
	emit	num_base_units,dims_v
end macro

sizeof_unit = 21

public _metric_units
_metric_units:
namespace base_units
	unit	g,      $10000000000000, -3, kg
	unit	L,      $10000000000000, -3, m*3
iterate	symbol, m, s, A, K, mol, cd
	unit	symbol, $10000000000000, 0, symbol
end iterate
 	unit	Hz,     $10000000000000, 0, -s
 	unit	N,      $10000000000000, 0, kg+m-2*s
 	unit	Pa,     $10000000000000, 0, kg-m-2*s
 	unit	J,      $10000000000000, 0, kg+2*m-2*s
 	unit	W,      $10000000000000, 0, kg+2*m-3*s
 	unit	C,      $10000000000000, 0, s+A
 	unit	V,      $10000000000000, 0, kg+2*m-3*s-A
 	unit	F,      $10000000000000, 0, -kg-2*m+4*s+2*A
 	unit	Ω,      $10000000000000, 0, kg+2*m-3*s-2*A
 	unit	ohm,    $10000000000000, 0, kg+2*m-3*s-2*A
 	unit	S,      $10000000000000, 0, -kg-2*m+3*s+2*A
 	unit	Wb,     $10000000000000, 0, kg+2*m-2*s-A
 	unit	T,      $10000000000000, 0, kg-2*s-A
 	unit	H,      $10000000000000, 0, kg+2*m-2*s-2*A
 	unit	lx,     $10000000000000, 0, cd-2*m
 	unit	Bq,     $10000000000000, 0, -s
 	unit	Gy,     $10000000000000, 0, 2*m-2*s
 	unit	Sv,     $10000000000000, 0, 2*m-2*s
 	unit	kat,    $10000000000000, 0, -s+mol
 	unit	h,      $60000000000000, 1, s
 	unit	d,      $86400000000000, 4, s
 	unit	au,     $14959787070000, 11, m
 	unit	t,      $10000000000000, 3, kg
 	unit	Da,     $16605390402000, -27, kg
 	unit	eV,     $16021766340000, -19, kg+2*m-2*s
end namespace
num_metric_units = ($ - _metric_units) / sizeof_unit

si_prefixes:
	reformat_string	'yzafpnμm kMGTPEZY',17

public format_united

; inputs: op1/op2 = united quantity, iy = address of self
; outputs: token string in $D0033A, null terminated, de = end of string
format_united:

	lea	ix,iy
	ld	bc,_metric_units-format_united - sizeof_unit
	add	ix,bc

	ld	bc,num_metric_units shl 8

.metric_loop:
	dec	b
	jr	z,.not_named_metric_tramp
	lea	ix,ix+sizeof_unit
	ld	de,ti.OP2+2
	lea	hl,ix+14
	ld	c,7
.cp_dim_loop:
	ld	a,(de)
	inc	de
	cpi
	jr	nz,.metric_loop
	ld	a,c
	or	a,a
	jr	nz,.cp_dim_loop

; ix = pointer to unit

	push	ix,iy
	ld	iy,ti.flags
	call	ti.PushOP1

	lea	hl,ix+3
	call	ti.Mov9ToOP2

	call	ti.FPDiv

	ld	c,' '

	ld	a,(ti.OP1 + 1)
	sub	a,$80-24
	jr	c,.skip_prefix
	cp	a,48+3
	jr	nc,.skip_prefix

	pop	iy
	push	iy

	lea	hl,iy
	ld	bc,si_prefixes-format_united
	add	hl,bc
.prefix_loop:
	cp	a,3
	jr	c,.prefix_found
	sub	a,3
	inc	hl
	jr	.prefix_loop
.prefix_found:
	add	a,$80
	ld	(ti.OP1 + 1),a
	ld	c,(hl)

.skip_prefix:

	push	bc

	ld	hl,ti.OP1
	ld	a,$80
	and	a,(hl)
	ld	(hl),a

	ld	a,20
	ld	iy,ti.flags
	call	ti.FormReal

	jr	.skip_tramp
.not_named_metric_tramp:
	jr	.not_named_metric
.skip_tramp:

	ld	hl,ti.OP3
	ld	de,$D0033A
	ldir
	push	de

	call	ti.PopOP1 ; op1/2: number to format

	pop	de ; ptr to current end of string
	pop	bc ; c = SI prefix
	pop	iy,ix

	ld	a,' '
	ld	(de),a
	inc	de

	cp	a,c
	jr	z,.no_prefix
	ld	a,c
	cp	a,$80
	jr	c,.prefix_uppercase
	ld	c,a
	ld	a,ti.t2ByteTok
	ld	(de),a
	inc	de
	ld	a,c
.prefix_uppercase:
	ld	a,c
	ld	(de),a
	inc	de

.no_prefix:

repeat 3
	ld	a,(ix+%-1)
	or	a,a
	jr	z,.metric_name_copied
	cp	a,$80
	jr	c,.metric_uppercase_#%
	ld	c,a
	ld	a,ti.t2ByteTok
	ld	(de),a
	inc	de
	ld	a,c
.metric_uppercase_#%:
	ld	(de),a
	inc	de
end repeat
.metric_name_copied:

	xor	a,a
	ld	(de),a
	ret


.not_named_metric:
	push	iy
	ld	iy,ti.flags
	call	ti.PushOP1

	ld	hl,ti.OP1
	ld	a,$80
	and	a,(hl)
	ld	(hl),a

	ld	a,20
	call	ti.FormReal

	ld	hl,ti.OP3
	ld	de,$D0033A
	ldir
	push	de

	call	ti.PopOP1 ; op1/2: number to format

	pop	de ; ptr to current end of string

	pop	iy
	ld	bc,base_units-format_united
	add	iy,bc

	ld	b,num_base_units
	ld	hl,ti.OP2 + 2
.base_unit_loop:
	ld	a,(hl)
	and	a,$0F
	jr	z,.next

	; todo: use tDotIcon on all subsequent iterations?
	ld	a,' '
	ld	(de),a
	inc	de

repeat 3
	ld	a,(iy+%-1)
	or	a,a
	jr	z,.name_copied
	cp	a,$80
	jr	c,.uppercase_#%
	ld	c,a
	ld	a,ti.t2ByteTok
	ld	(de),a
	inc	de
	ld	a,c
.uppercase_#%:
	ld	(de),a
	inc	de
end repeat
.name_copied:

	ld	a,(hl)
	cp	a,$F1
; don't display an exponent of 1
	jr	z,.next

	ld	a,ti.tPower
	ld	(de),a
	inc	de

	ld	a,(hl)
	bit	3,a
	jr	z,.positive

	ld	a,ti.tChs
	ld	(de),a
	inc	de

	ld	a,(hl)
	neg

.positive:
	and	a,$0f
	add	a,ti.t0
	ld	(de),a
	inc	de

.next:
	inc	hl
	lea	iy,iy+3
	djnz	.base_unit_loop


	xor	a,a
	ld	(de),a
	ret
