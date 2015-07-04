;
; File:
;                          console.asm
; Description:
;                      Console device driver
;
;                       Copyright (c) 1998
;                       Pasquale J. Villani
;                       All Rights Reserved
;
; This file is part of DOS-C.
;
; DOS-C is free software; you can redistribute it and/or
; modify it under the terms of the GNU General Public License
; as published by the Free Software Foundation; either version
; 2, or (at your option) any later version.
;
; DOS-C is distributed in the hope that it will be useful, but
; WITHOUT ANY WARRANTY; without even the implied warranty of
; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See
; the GNU General Public License for more details.
;
; You should have received a copy of the GNU General Public
; License along with DOS-C; see the file COPYING.  If not,
; write to the Free Software Foundation, 675 Mass Ave,
; Cambridge, MA 02139, USA.
;
; $Header: /cvsroot/freedos/kernel/kernel/console.asm,v 1.17 2004/05/23 22:04:42 bartoldeman Exp $
;

                %include "io.inc"


segment	_IO_FIXED_DATA

                global  ConTable
ConTable        db      0Ah
                dw      _IOExit		; 00h init
                dw      _IOExit		; 01h
                dw      _IOExit		; 02h
                dw      _IOCommandError	; 03h ioctl input
                dw      ConRead		; 04h input
                dw      CommonNdRdExit	; 05h nondestructive input, no wait
                dw      ConInStat	; 06h input status
                dw      ConInpFlush	; 07h input flush
                dw      ConWrite	; 08h output
                dw      ConWrite	; 09h output with verify
                dw      _IOExit		; 0ah output status

segment	_LOWTEXT

conin_buf	times 16 db 0
conin_buf_cnt	db	0	; 0=empty, 1~=index+1

; in: ax (ah=keycode, al=keydata)
; out: al
cnv_conin:
		push	bx
		push	cx
		push	dx
		push	bp
		push	ds
		mov	bx, DGROUP
		mov	ds, bx
		xor	bx, bx
	.loop1:
		mov	dx, [bx + _cnvkey_src]
		or	dx, dx
		jz	.no_cnv
		cmp	ax, dx
		je	.cnv
		inc	bx
		inc	bx
		jmp	short .loop1
	.cnv:
		mov	cl, 3
		shl	bx, cl
		mov	dl, [bx + _cnvkey_dest]
		or	dl, dl
		jz	.no_cnv
		mov	al, dl
		mov	bp, conin_buf
		mov	cx, 15
	.loop2:
		mov	dl, [bx + _cnvkey_dest + 1]
		mov	[cs:bp], dl
		inc	bx
		inc	bp
		loop	.loop2
		jmp	short .done

	.no_cnv:
		or	al, al
		jnz	.end
		xchg	ah, al
		mov	[cs:conin_buf], ax	; ah, 0
		xchg	ah, al
	.done:
		inc	byte [cs:conin_buf_cnt]
	.end:
		pop	ds
		pop	bp
		pop	dx
		pop	cx
		pop	bx
		ret

; push_conin
; push keydata to conin_buf
; in: al (keydata)
push_conin:
		push bx
		push cx
		mov cx, 15
		mov bx, conin_buf
	.loc_lp:
		cmp byte [cs:bx], 0
		je .loc_append
		inc bx
		loop .loc_lp
		jmp short .loc_exit
	.loc_append:
		mov byte [cs:bx], al
		mov byte [cs:bx+1], 0
		mov byte [cs:conin_buf_cnt], 1
	.loc_exit:
		pop cx
		pop bx
		ret

; VOID FAR ASMCFUNC flush_conin(void)
	global _flush_conin
_flush_conin:
		mov byte [cs:conin_buf], 0
		mov byte [cs:conin_buf_cnt], 0
		retf

; VOID FAR ASMCFUNC push_key_to_conin(UBYTE c)
	global _push_key_to_conin
_push_key_to_conin:
		push bp
		mov bp, sp
		mov al, [bp + 6]	; +0:bp +2:ret-off +4:ret-seg +6:arg
		call push_conin
		pop bp
		retf

; 04h input
		global	ConRead
ConRead:
		jcxz	.end
	.loop:
		cmp	byte [cs:conin_buf_cnt], 0
		je	.read_key

		xor	bh, bh
		mov	bl, [cs:conin_buf_cnt]
		inc	byte [cs:conin_buf_cnt]
		mov	al, [cs:bx + (conin_buf - 1)]
		or	al, al
		jnz	.set_data
		mov	byte [cs:conin_buf_cnt], 0
	.read_key:
		xor	ah, ah	; read key buf (wait)
		int	18h
		call	cnv_conin
	.set_data:
		stosb
		loop	.loop
	.end:
		jmp	_IOExit

; 05h nondestructive input, no wait
		global	CommonNdRdExit
CommonNdRdExit:
		cmp	byte [cs:conin_buf_cnt], 0
		je	.read_key

		xor	bh, bh
		mov	bl, [cs:conin_buf_cnt]
		mov	al, [cs:bx + (conin_buf - 1)]
		or	al, al
		jnz	.set_data
	.read_key:
		mov	ah, 1	; sense key buf (no wait)
		int	18h
		or	bh, bh
		jz	.no_data
		call	cnv_conin
		mov	byte [cs:conin_buf_cnt], 0
	.set_data:
		lds	bx, [cs:_ReqPktPtr]
		mov	[bx + 0dh], al
		jmp	_IOExit

	.no_data:
		jmp	_IODone

; 06h input status
		global	ConInStat
ConInStat:
		cmp	byte [cs:conin_buf_cnt], 0
		je	.read_key

		xor	bh, bh
		mov	bl, [cs:conin_buf_cnt]
		mov	al, [cs:bx + (conin_buf - 1)]
		or	al, al
		jnz	.end
	.read_key:
		mov	ah, 1	; sense key buf (no wait)
		int	18h
		or	bh, bh
		jz	.no_data
		call	cnv_conin
		mov	byte [cs:conin_buf_cnt], 0
	.end:
		jmp	_IOExit

	.no_data:
		jmp	_IODone

; 07h input flush
		global	ConInpFlush
ConInpFlush:
		mov byte [cs:conin_buf_cnt], 0
		mov byte [cs:conin_buf], 0

	.loc_loop:
		mov ah, 1
		int 18h
		or bh, bh
		jz .loc_end
		xor ah, ah
		int 18h
		jmp short .loc_loop
	.loc_end
		jmp	_IOExit

; 08h output
; 09h output with verify
		global	ConWrite
ConWrite:
		jcxz	.end
	.loop:
		mov	al, [es:di]
		inc	di
		int	29h
		loop	.loop
	.end:
		jmp	_IOExit


; for int29

CRT_STS_FLAG	equ	053ch

	extern	_scroll_bottom
	extern	_cursor_view
	extern	_cursor_x
	extern	_cursor_y
	extern	_clear_char
	extern	_clear_attr
	extern	_put_attr
;	extern	_int29_handler
	extern	reloc_call_int29_handler

segment INIT_TEXT

		global	init_crt
init_crt:
		mov	ah, 11h	; view cursor
		int	18h

		pushf
		cli
	.loop1:
		in	al, 60h
		test	al, 04h
		jz	.loop1

		mov	dx, 62h
		mov	al, 0e0h
		out	dx, al	; CSRR

	.loop2:
		in	al, 60h
		test	al, 01h
		jz	.loop2

		in	al, dx	; low addr
		mov	cl, al
		in	al, dx	; high addr
		mov	ch, al
		in	al, dx	; skip
		in	al, dx	; skip
		in	al, dx	; skip
		popf

		mov	ax, 60h
		mov	ds, ax
		mov	ax, cx
		mov	dl, 80
		div	dl
		mov	[_cursor_y], al
		mov	[_cursor_x], ah

		mov	bx, .init_str
	.loop3:
		mov	al, [cs:bx]
		test	al, al
		jz	.end
		pushf
;		call	far _int29_handler
		call	far reloc_call_int29_handler
		inc	bx
		jmp	short .loop3
	.end:
		ret

.init_str	db	1bh, '[>1l', 0

segment HMA_TEXT

; VOID ASMCFUNC set_curpos(UBYTE x, UBYTE y)
		global	_set_curpos
_set_curpos:
		push	bp
		mov	bp, sp
		push	ds
		mov	ax, 60h
		mov	ds, ax

		xor	ah, ah
		mov	al, [bp + 6]	; y
		mov	byte [_cursor_y], al
		mov	dl, 80
		mul	dl
		xor	dh, dh
		mov	dl, [bp + 4]	; x
		mov	byte [_cursor_x], dl
		add	dx, ax
		shl	dx, 1
		mov	ah, 13h
		int	18h

%if 1
    mov ah, 12h
    cmp byte [_cursor_view], 0
    je .upd_csr_view
    mov ah, 11h
  .upd_csr_view:
    int 18h
%endif

		pop	ds
		pop	bp
		ret


; VOID ASMCFUNC crt_scroll_up(VOID)
		global	_crt_scroll_up
_crt_scroll_up:
		cld
		push	bp
		push	si
		push	di
		push	ds
		push	es

		call	_get_crt_height
		mov	dx, ax
		call	_get_crt_width
		mov	bx, ax

		mov	ax, 60h
		mov	ds, ax
		mov	al, [_clear_char]
		mov	ah, [_clear_attr]
		mov	bp, ax

		mov	si, bx
		shl	si, 1	; width * 2
		xor	di, di
		mov	al, bl
		dec	dl
		mul	dl
		mov	cx, ax	; witdh * (height - 1)
		push	si
		push	di
		push	cx
		mov	ax, 0a000h
		mov	ds, ax
		mov	es, ax
		rep	movsw
		mov	cx, bx	; witdh
		mov	ax, bp
		xor	ah, ah
		rep	stosw

		pop	cx
		pop	di
		pop	si
		mov	ax, 0a200h
		mov	ds, ax
		mov	es, ax
		rep	movsw
		mov	cx, bx	; witdh
		mov	ax, bp
		mov	al, ah
		xor	ah, ah
		rep	stosw

		pop	es
		pop	ds
		pop	di
		pop	si
		pop	bp
		ret


%if 0
; VOID ASMCFUNC crt_scroll_down(VOID)
		global	_crt_scroll_down
_crt_scroll_down:
%endif


; UBYTE ASMCFUNC get_crt_width(VOID)
		global	_get_crt_width
_get_crt_width:
		push	ds
		xor	ax, ax
		mov	ds, ax

		xor	ah, ah
		mov	al, [CRT_STS_FLAG]
		test	al, 2
		jz	.w80
		mov	al, 40
		jmp	short .end
	.w80:
		mov	al, 80
	.end:
		pop	ds
		ret


; UBYTE ASMCFUNC get_crt_height(VOID)
		global	_get_crt_height
_get_crt_height:
		push	ds
		mov	ax, 60h
		mov	ds, ax

		xor	ah, ah
		mov	al, [_scroll_bottom]
		inc	al

		pop	ds
		ret


; VOID ASMCFUNC put_crt(UBYTE x, UBYTE y, UWORD c)
		global	_put_crt
_put_crt:
		push	bp
		mov	bp, sp
		push	ds

		mov	ax, 0a000h
		mov	ds, ax
		call	_get_crt_width
		mul	byte [bp + 6]	; y * width
		xor	bh, bh
		mov	bl, [bp + 4]	; x
		add	bx, ax		; y * width + x
		shl	bx, 1		; (y * width + x) * 2
		mov	ax, [bp + 8]	; char
		mov	[bx], ax

		mov	ax, 60h
		mov	ds, ax
		mov	dl, [_put_attr]
		mov	ax, 0a200h
		mov	ds, ax
		mov	[bx], dl

		pop	ds
		pop	bp
		ret

; VOID ASMCFUNC put_crt_wattr(UBYTE x, UBYTE y, UWORD c, UBYTE a)
		global	_put_crt_wattr
_put_crt_wattr:
		push	bp
		mov	bp, sp
		push	ds

		mov	ax, 0a000h
		mov	ds, ax
		call	_get_crt_width
		mul	byte [bp + 6]	; y * width
		xor	bh, bh
		mov	bl, [bp + 4]	; x
		add	bx, ax		; y * width + x
		shl	bx, 1		; (y * width + x) * 2
		mov	ax, [bp + 8]	; char
		mov	[bx], ax

		mov	ax, 60h
		mov	ds, ax
		mov	dl, [_put_attr]
		mov	dh, [bp + 0ah]	; attr
		mov	ax, 0a200h
		mov	ds, ax
		mov	[bx], dl
		or	[bx], dh

		pop	ds
		pop	bp
		ret

; VOID ASMCFUNC clear_crt(UBYTE x, UBYTE y)
		global	_clear_crt
_clear_crt:
		push	bp
		mov	bp, sp
		push	ds

		mov	ax, 60h
		mov	ds, ax
		xor	dh, dh
		mov	dl, [_clear_char]
		mov	cl, [_clear_attr]

		mov	ax, 0a000h
		mov	ds, ax
		call	_get_crt_width
		mul	byte [bp + 6]	; y * width
		xor	bh, bh
		mov	bl, [bp + 4]	; x
		add	bx, ax		; y * width + x
		shl	bx, 1		; (y * width + x) * 2
		mov	[bx], dx

		mov	ax, 0a200h
		mov	ds, ax
		mov	[bx], cl

		pop	ds
		pop	bp
		ret

; VOID ASMCFUNC clear_crt_all(VOID)
		global	_clear_crt_all
_clear_crt_all:
		cld
		push	di
		push	es

		mov	ax, 60h
		mov	es, ax
		mov	bl, [es:_clear_char]
		mov	bh, [es:_clear_attr]

		mov	ax, 0a000h
		mov	es, ax
		xor	di, di
		mov	cx, 1000h / 2
		xor	ah, ah
		mov	al, bl
		rep	stosw

		mov	ax, 0a200h
		mov	es, ax
		xor	di, di
		mov	cx, 1000h / 2
		xor	ah, ah
		mov	al, bh
		rep	stosw

		pop	es
		pop	di
		ret

; VOID ASMCFUNC show_cursor(VOID)
		global	_show_cursor
_show_cursor:
		push	ds
		mov	ax, 60h
		mov	ds, ax
		cmp	byte [_cursor_view], 0
		jne	.end
		mov	ah, 11h
		int	18h
		mov	byte [_cursor_view], 1
	.end:
		pop	ds
		ret

; VOID ASMCFUNC hide_cursor(VOID)
		global	_hide_cursor
_hide_cursor:
		push	ds
		mov	ax, 60h
		mov	ds, ax
		cmp	byte [_cursor_view], 0
		je	.end
		mov	ah, 12h
		int	18h
		mov	byte [_cursor_view], 0
	.end:
		pop	ds
		ret

segment	_DATA

		global	_programmable_keys
_programmable_keys:
		db	(..@programmable_key_end - _programmable_key) / 4
		global	_programmable_key
_programmable_key:
		dw	.00, 20 * 16 + 11 * 6

		dw	.01, 16
		dw	.02, 16
		dw	.03, 16
		dw	.04, 16
		dw	.05, 16
		dw	.06, 16
		dw	.07, 16
		dw	.08, 16
		dw	.09, 16
		dw	.0a, 16

		dw	.0b, 16
		dw	.0c, 16
		dw	.0d, 16
		dw	.0e, 16
		dw	.0f, 16
		dw	.10, 16
		dw	.11, 16
		dw	.12, 16
		dw	.13, 16
		dw	.14, 16

		dw	.15, 6
		dw	.16, 6
		dw	.17, 6
		dw	.18, 6
		dw	.19, 6
		dw	.1a, 6
		dw	.1b, 6
		dw	.1c, 6
		dw	.1d, 6
		dw	.1e, 6
		dw	.1f, 6

		dw	.20, 16
		dw	.21, 16
		dw	.22, 16
		dw	.23, 16
		dw	.24, 16

		dw	.25, 16
		dw	.26, 16
		dw	.27, 16
		dw	.28, 16
		dw	.29, 16

		dw	.2a, 16
		dw	.2b, 16
		dw	.2c, 16
		dw	.2d, 16
		dw	.2e, 16
		dw	.2f, 16
		dw	.30, 16
		dw	.31, 16
		dw	.32, 16
		dw	.33, 16

		dw	.34, 16
		dw	.35, 16
		dw	.36, 16
		dw	.37, 16
		dw	.38, 16

		dw	.39, 16
..@programmable_key_end:

	.00

	.01	db	0feh, ' C1  ', 1bh, 53h	; f1
							times 16 - ($ - .01) db 0
	.02	db	0feh, ' CU  ', 1bh, 54h	; f2
							times 16 - ($ - .02) db 0
	.03	db	0feh, ' CA  ', 1bh, 55h	; f3
							times 16 - ($ - .03) db 0
	.04	db	0feh, ' S1  ', 1bh, 56h	; f4
							times 16 - ($ - .04) db 0
	.05	db	0feh, ' SU  ', 1bh, 57h	; f5
							times 16 - ($ - .05) db 0
	.06	db	0feh, 'VOID ', 1bh, 45h	; f6
							times 16 - ($ - .06) db 0
	.07	db	0feh, 'NWL  ', 1bh, 4ah	; f7
							times 16 - ($ - .07) db 0
	.08	db	0feh, 'INS  ', 1bh, 50h	; f8
							times 16 - ($ - .08) db 0
	.09	db	0feh, 'REP  ', 1bh, 51h	; f9
							times 16 - ($ - .09) db 0
	.0a	db	0feh, ' ^Z  ', 1bh, 5ah	; f10
							times 16 - ($ - .0a) db 0

	.0b	db	'dir a:', 0dh		; shift+f1
							times 16 - ($ - .0b) db 0
	.0c	db	'dir b:', 0dh		; shift+f2
							times 16 - ($ - .0c) db 0
	.0d	db	'copy '			; shift+f3
							times 16 - ($ - .0d) db 0
	.0e	db	'del ',			; shift+f4
							times 16 - ($ - .0e) db 0
	.0f	db	'ren ',			; shift+f5
							times 16 - ($ - .0f) db 0
	.10	db	'chkdsk a:', 0dh	; shift+f6
							times 16 - ($ - .10) db 0
	.11	db	'chkdsk b:', 0dh	; shift+f7
							times 16 - ($ - .11) db 0
	.12	db	'type '			; shift+f8
							times 16 - ($ - .12) db 0
	.13	db	'date', 0dh		; shift+f9
							times 16 - ($ - .13) db 0
	.14	db	'time', 0dh		; shift+f10
							times 16 - ($ - .14) db 0

	.15					; roll up
							times 6 - ($ - .15) db 0
	.16					; roll down
							times 6 - ($ - .16) db 0
	.17	db	1bh, 50h		; ins
							times 6 - ($ - .17) db 0
	.18	db	1bh, 44h		; del
							times 6 - ($ - .18) db 0
	.19	db	0bh			; Å™
							times 6 - ($ - .19) db 0
	.1a	db	08h			; Å©
							times 6 - ($ - .1a) db 0
	.1b	db	0ch			; Å®
							times 6 - ($ - .1b) db 0
	.1c	db	0ah			; Å´
							times 6 - ($ - .1c) db 0
	.1d	db	1ah			; home/clr
							times 6 - ($ - .1d) db 0
	.1e					; help
							times 6 - ($ - .1e) db 0
	.1f	db	1eh			; shift+home/clr
							times 6 - ($ - .1f) db 0

	.20	times 16 db 0			; vf1
	.21	times 16 db 0			; vf2
	.22	times 16 db 0			; vf3
	.23	times 16 db 0			; vf4
	.24	times 16 db 0			; vf5

	.25	times 16 db 0			; shift+vf1
	.26	times 16 db 0			; shift+vf2
	.27	times 16 db 0			; shift+vf3
	.28	times 16 db 0			; shift+vf4
	.29	times 16 db 0			; shift+vf5

	.2a	times 16 db 0			; ctrl+f1
	.2b	times 16 db 0			; ctrl+f2
	.2c	times 16 db 0			; ctrl+f3
	.2d	times 16 db 0			; ctrl+f4
	.2e	times 16 db 0			; ctrl+f5
	.2f	times 16 db 0			; ctrl+f6
	.30	times 16 db 0			; ctrl+f7
	.31	times 16 db 0			; ctrl+f8
	.32	times 16 db 0			; ctrl+f9
	.33	times 16 db 0			; ctrl+f10

	.34	times 16 db 0			; ctrl+vf1
	.35	times 16 db 0			; ctrl+vf2
	.36	times 16 db 0			; ctrl+vf3
	.37	times 16 db 0			; ctrl+vf4
	.38	times 16 db 0			; ctrl+vf5

	.39	times 16 db 0			; ctrl+xfer/nfer

		global	_cnvkey_src
_cnvkey_src:
		dw	6200h, 6300h, 6400h, 6500h, 6600h, 6700h, 6800h, 6900h, 6a00h, 6b00h	; f1~f10
		dw	8200h, 8300h, 8400h, 8500h, 8600h, 8700h, 8800h, 8900h, 8a00h, 8b00h	; shift+f1~shift+f10
		dw	3600h	; roll up
		dw	3700h	; roll down
		dw	3800h	; ins
		dw	3900h	; del
		dw	3a00h	; Å™
		dw	3b00h	; Å©
		dw	3c00h	; Å®
		dw	3d00h	; Å´
		dw	3e00h	; home/clr
		dw	3f00h	; help
		dw	0ae00h	; shift+home/clr
		dw	5200h, 5300h, 5400h, 5500h, 5600h	; vf1~vf5
		dw	0c200h, 0c300h, 0c400h, 0c500h, 0c600h	; shift+vf1~shift+vf5
		dw	9200h, 9300h, 9400h, 9500h, 9600h, 9700h, 9800h, 9900h, 9a00h, 9b00h	; ctrl+f1~ctrl+f10
		dw	0d200h, 0d300h, 0d400h, 0d500h, 0d600h	; ctrl+vf1~ctrl+vf5
		dw	0b500h	; ctrl+xfer

		dw	5100h	; nfer

		times 32 dw 0

		global	_cnvkey_dest
_cnvkey_dest:
	.01	db	1bh, 53h	; f1
							times 16 - ($ - .01) db 0
	.02	db	1bh, 54h	; f2
							times 16 - ($ - .02) db 0
	.03	db	1bh, 55h	; f3
							times 16 - ($ - .03) db 0
	.04	db	1bh, 56h	; f4
							times 16 - ($ - .04) db 0
	.05	db	1bh, 57h	; f5
							times 16 - ($ - .05) db 0
	.06	db	1bh, 45h	; f6
							times 16 - ($ - .06) db 0
	.07	db	1bh, 4ah	; f7
							times 16 - ($ - .07) db 0
	.08	db	1bh, 50h	; f8
							times 16 - ($ - .08) db 0
	.09	db	1bh, 51h	; f9
							times 16 - ($ - .09) db 0
	.0a	db	1bh, 5ah	; f10
							times 16 - ($ - .0a) db 0

	.0b	db	'dir a:', 0dh		; shift+f1
							times 16 - ($ - .0b) db 0
	.0c	db	'dir b:', 0dh		; shift+f2
							times 16 - ($ - .0c) db 0
	.0d	db	'copy '			; shift+f3
							times 16 - ($ - .0d) db 0
	.0e	db	'del ',			; shift+f4
							times 16 - ($ - .0e) db 0
	.0f	db	'ren ',			; shift+f5
							times 16 - ($ - .0f) db 0
	.10	db	'chkdsk a:', 0dh	; shift+f6
							times 16 - ($ - .10) db 0
	.11	db	'chkdsk b:', 0dh	; shift+f7
							times 16 - ($ - .11) db 0
	.12	db	'type '			; shift+f8
							times 16 - ($ - .12) db 0
	.13	db	'date', 0dh		; shift+f9
							times 16 - ($ - .13) db 0
	.14	db	'time', 0dh		; shift+f10
							times 16 - ($ - .14) db 0

	.15					; roll up
							times 16 - ($ - .15) db 0
	.16					; roll down
							times 16 - ($ - .16) db 0
	.17	db	1bh, 50h		; ins
							times 16 - ($ - .17) db 0
	.18	db	1bh, 44h		; del
							times 16 - ($ - .18) db 0
	.19	db	0bh			; Å™
							times 16 - ($ - .19) db 0
	.1a	db	08h			; Å©
							times 16 - ($ - .1a) db 0
	.1b	db	0ch			; Å®
							times 16 - ($ - .1b) db 0
	.1c	db	0ah			; Å´
							times 16 - ($ - .1c) db 0
	.1d	db	1ah			; home/clr
							times 16 - ($ - .1d) db 0
	.1e					; help
							times 16 - ($ - .1e) db 0
	.1f	db	1eh			; shift+home/clr
							times 16 - ($ - .1f) db 0

		times (39h + 1 + 32) * 16 - ($ - _cnvkey_dest) db 0

