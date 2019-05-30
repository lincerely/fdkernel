; this is a part of FreeDOS(98) kernel
; included from console.asm or kernel.asm

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

	.00:

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

	.15:					; roll up
							times 6 - ($ - .15) db 0
	.16:					; roll down
							times 6 - ($ - .16) db 0
	.17	db	1bh, 50h		; ins
							times 6 - ($ - .17) db 0
	.18	db	1bh, 44h		; del
							times 6 - ($ - .18) db 0
	.19	db	0bh			; up-arrow
							times 6 - ($ - .19) db 0
	.1a	db	08h			; left-arrow
							times 6 - ($ - .1a) db 0
	.1b	db	0ch			; right-arrow
							times 6 - ($ - .1b) db 0
	.1c	db	0ah			; down-allow
							times 6 - ($ - .1c) db 0
	.1d	db	1ah			; home/clr
							times 6 - ($ - .1d) db 0
	.1e:					; help
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
		dw	3a00h	; up-arrow
		dw	3b00h	; left-arrow
		dw	3c00h	; right-arrow
		dw	3d00h	; down-arrow
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

	.15:					; roll up
							times 16 - ($ - .15) db 0
	.16:					; roll down
							times 16 - ($ - .16) db 0
	.17	db	1bh, 50h		; ins
							times 16 - ($ - .17) db 0
	.18	db	1bh, 44h		; del
							times 16 - ($ - .18) db 0
	.19	db	0bh			; up-arrow
							times 16 - ($ - .19) db 0
	.1a	db	08h			; left-arrow
							times 16 - ($ - .1a) db 0
	.1b	db	0ch			; right-arrow
							times 16 - ($ - .1b) db 0
	.1c	db	0ah			; down-arrow
							times 16 - ($ - .1c) db 0
	.1d	db	1ah			; home/clr
							times 16 - ($ - .1d) db 0
	.1e:					; help
							times 16 - ($ - .1e) db 0
	.1f	db	1eh			; shift+home/clr
							times 16 - ($ - .1f) db 0

		times (39h + 1 + 32) * 16 - ($ - _cnvkey_dest) db 0

