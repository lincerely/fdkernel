; FreeDOS(98) FAT32 boot sector for NEC PC-98 series
; baseed on FreeDOS FAT32 boot sector (kernel/boot/boot.asm)

;	+--------+
;	|        |
;	|        |
;	|--------| 4000:0000
;	|        |
;	|  FAT   |
;	|        |
;	|--------| 2000:0000
;	|BOOT SEC|
;	|(NEC98) |
;	|--------| 1FE0:0000, 1FC0:0000 or 1F80:0000
;	|        |
;	|    ----| 1F00:0800 bottom of private stack
;	|        |
;	|        |
;	|        |
;	|        |
;	|        |
;	|        |
;	|        |
;	|        |
;	|        |
;	|--------|
;	|KERNEL  |
;	|LOADED  |
;	|--------| 0060:0000
;	|        |
;	+--------+

;%define MULTI_SEC_READ  1
;%define DO_INIT_ON_ERROR 1
%define PRIVATE_STACK 1

		CPU 8086

segment	.text

%define BASE            0

                org     BASE

Entry:          jmp     short real_start
		nop

%if 1
oemname		db	'MSWIN4.1'	; guess not required but safe
%else
oemname		db	'FDOS7.10'
%endif

%define bsOemName       0x03      ; OEM label
%define bsBytesPerSec   0x0b      ; bytes/sector
%define bsSecPerClust   0x0d      ; sectors/allocation unit
%define bsResSectors    0x0e      ; # reserved sectors
%define bsFATs          0x10      ; # of fats
%define bsRootDirEnts   0x11      ; # of root dir entries
%define bsSectors       0x13      ; # sectors total in image
%define bsMedia         0x15      ; media descrip: fd=2side9sec, etc...
%define sectPerFat      0x16      ; # sectors in a fat
%define sectPerTrack    0x18      ; # sectors/track
%define nHeads          0x1a      ; # heads
%define nHidden         0x1c      ; # hidden sectors
%define nSectorHuge     0x20      ; # sectors if > 65536
%define xsectPerFat     0x24      ; Sectors/Fat
%define xrootClst       0x2c      ; Starting cluster of root directory
%define drive           0x40      ; Drive number

		times	0x5a-$+$$ db 0

%define LOADSEG         0x0060
%define FATSEG          0x2000         

%define fat_sector      0x48         ; last accessed sector of the FAT

%define loadsegoff_60	loadseg_off-Entry ; FAR pointer = 60:0
%define loadseg_60	loadseg_seg-Entry

;%define fat_start       0x5a		; first FAT sector
;%define data_start      0x5e		; first data sector
;%define fat_secmask     0x62		; number of clusters in a FAT sector - 1
;%define fat_secshift    0x64		; fat_secmask+1 = 2^fat_secshift


DISK_BOOT	equ	0584h	; seg=0000h
BOOTPART_SCRATCHPAD	equ	03feh;


;-----------------------------------------------------------------------
;   ENTRY
;-----------------------------------------------------------------------

; offset +90 (5Ah)
; scratchpad for FD98 boot loader
fat_start	dd	0
data_start	dd	0
fat_secmask	dw	0
fat_secshift	dw	0
loadseg_off	dw	0
loadseg_seg	dw	LOADSEG


real_start:
;cont:
		push	si
		cld
%ifdef PRIVATE_STACK
		mov	ax, 1f00h
		mov	ss, ax
		mov	sp, 0800h
%endif
		xor	cx, cx		; clear cx for further use
		mov	ds, cx		; ensure ds=0 (may not be required)
		mov	word [BOOTPART_SCRATCHPAD], si
		mov	al, byte [DISK_BOOT]
		push	cs
		pop	ds

		mov	[drive], al     ; BIOS passes drive number in DL
		and	al, 7fh
		mov	[readDAUA], al	; LBA mode DAUA
		mov	ah, 8eh			; SASI/IDE HDD `half-height' mode
		int	1bh

		mov	ah, 0ch			; CRT start (TEXT)
		int	18h

;                call    print
;                db      "Loading ",0

;      Calc Params
;      Fat_Start
		mov	si, word [nHidden]
		mov	di, word [nHidden+2]
		add	si, word [bsResSectors]
		adc	di, byte 0

		mov	word [fat_start], si
		mov	word [fat_start+2], di
 ;	Data_Start
		mov	al, [bsFATs]
		cbw
		push	ax
		mul	word [xsectPerFat+2]
		add	di, ax
		pop	ax
		mul	word [xsectPerFat]
		add	ax, si
		adc	dx, di
		mov	word [data_start], ax
		mov	word [data_start+2], dx
;      fat_secmask
		mov	ax, word [bsBytesPerSec]
		shr	ax, 1
		shr	ax, 1
		dec	ax
		mov	word [fat_secmask], ax
;      fat_secshift
; cx = temp
; ax = fat_secshift
		xchg	ax, cx	; cx = 0 at first
		inc	cx
secshift:	inc	ax
		shr	cx, 1
		cmp	cx, 1
		jne	secshift
		mov	byte [fat_secshift], al
		dec	cx
 
;       FINDFILE: Searches for the file in the root directory.
;
;       Returns:
;            DX:AX = first cluster of file

		mov	word [fat_sector], cx           ; CX is 0 after "dec"
		mov	word [fat_sector + 2], cx

		mov	ax, word [xrootClst]
		mov	dx, word [xrootClst + 2]
ff_next_cluster:
		push	dx                              ; save cluster
		push	ax
		call	convert_cluster
		jc	boot_error                      ; EOC encountered

ff_next_sector:
		push	bx                              ; save sector count

		les	bx, [loadsegoff_60]
		call	readDisk
		push	dx                              ; save sector
		push	ax

		mov	ax, [bsBytesPerSec]

		; Search for KERNEL.SYS file name, and find start cluster.
ff_next_entry:	mov	cx, 11
		mov	si, filename
		mov	di, ax
		sub	di, 0x20
		repe	cmpsb
		jz	ff_done

		sub	ax, 0x20
		jnz	ff_next_entry
		pop	ax                      ; restore  sector
		pop	dx
		pop	bx                      ; restore sector count
		dec	bx
		jnz	ff_next_sector
ff_find_next_cluster:
		pop	ax                      ; restore current cluster
		pop	dx
		call	next_cluster
		jmp	short ff_next_cluster
ff_done:
		mov	ax, [es:di+0x1A-11]        ; get cluster number
		mov	dx, [es:di+0x14-11]
c4:
		sub	bx, bx                  ; ES points to LOADSEG      
c5:
		push	dx
		push	ax
		push	bx
		call	convert_cluster
		jc	boot_success
		mov	di, bx
		pop	bx
c6:
		call	readDisk
		dec	di
		jnz	c6
		pop	ax
		pop	dx
		call	next_cluster
		jmp	short c5
boot_error:
		int	1eh		; fallback to BASIC if something goes wrong
.err_loop:
		jmp	short .err_loop

; input: 
;    DX:AX - cluster
; output:
;    DX:AX - next cluster
;    CX = 0
; modify:
;    DI
next_cluster:  
		push	es
		mov	di, ax
		and	di, [fat_secmask]

		mov	cx, [fat_secshift]
cn_loop:
		shr	dx,1
		rcr	ax,1
		dec	cx
		jnz	cn_loop
						; DX:AX fat sector where our
						; cluster resides
						; DI - cluster index in this
						; sector
                                               
		shl	di,1                   ; DI - offset in the sector
		shl	di,1
		add	ax, [fat_start]
		adc	dx, [fat_start+2]      ; DX:AX absolute fat sector

		push	bx
		mov	bx, FATSEG
		mov	es, bx
		sub	bx, bx

		cmp	ax, [fat_sector]
		jne	cn1                    ; if the last fat sector we
                                               ; read was this, than skip
		cmp	dx,[fat_sector+2]
		je	cn_exit
cn1:
		mov	[fat_sector],ax        ; save the fat sector number,
		mov	[fat_sector+2],dx      ; we are going to read
		call	readDisk
cn_exit:
		pop	bx
		mov	ax, [es:di]             ; DX:AX - next cluster
		mov	dx, [es:di + 2]         ;
		pop	es
		ret


boot_success:
		pop	si
		;xor	ax, ax
		;mov	ds, ax
		;mov	si, [BOOTPART_SCRATCHPAD]
		jmp	word LOADSEG:0000

; Convert cluster to the absolute sector
;input:
;    DX:AX - target cluster
;output:
;    DX:AX - absoulute sector
;    BX - [bsSectPerClust]
;modify:
;    CX
convert_cluster:
		cmp	dx,0x0fff
		jne	c3
		cmp	ax,0xfff8
		jb	c3              ; if cluster is EOC (carry is set), do ret
		stc
		ret
c3:
		mov	cx, dx          ; sector = (cluster - 2)*clussize +
                                        ; + data_start
		sub	ax, 2
		sbb	cx, byte 0           ; CX:AX == cluster - 2
		mov	bl, [bsSecPerClust]
		sub	bh, bh
		xchg	cx, ax          ; AX:CX == cluster - 2
		mul	bx              ; first handle high word
                                        ; DX must be 0 here
		xchg	ax, cx          ; then low word
		mul	bx
		add	dx, cx                          ; DX:AX target sector
		add	ax, [data_start]
		adc	dx, [data_start + 2]
		ret

; prints text after call to this function.

%if 0
print_1sub:
;		push	ax
		push	di
		push	es
		les	di, [csr_off]
		xor	ah, ah
		stosw
		mov	[csr_off], di
;		mov	dx, di
;		mov	ah, 13h
;		int	18h
		pop	es
		pop	di
;		pop	ax
		; fallthrough
print:
		pop	si
print1:
		lodsb
		push	si
		cmp	al, 0
		jne	print_1sub
		ret

csr_off	dw	0
csr_seg	dw	0a000h
%endif

;input:
;   DX:AX - 32-bit DOS sector number
;   ES:BX - destination buffer
;output:
;   ES:BX points one byte after the last byte read.
;   DX:AX - next sector
;modify:
;   ES if DI * bsBytesPerSec >= 65536, CX

readDisk:
read_next:
		push	ax
		push	cx
		
		mov	cx, ax
		push	bx
		push	bp
		mov	bp, bx
	.call_read:
		mov	bx, word [bsBytesPerSec]
		mov	ax, [readDAUA]
		int	1bh
%ifdef DO_INIT_ON_ERROR
		jnc	.read_noerr
		mov	ah, 3
		mov	al, [readDAUA]
		int	1bh
		jmp	short .call_read
	.read_noerr:
%else
;		jc	read_err
		jc	boot_error
%endif
		pop	bp
		pop	bx
	; read_ok:
		add	bx, word [bsBytesPerSec]
		jnc	.next_sector
		mov	cx, es
		add	ch, 10h
		mov	es, cx
	.next_sector:
		pop	cx
		pop	ax
		add	ax, byte 1
		adc	dx, byte 0
		ret

readDAUA	db	0
		db	06h	; disk bios (int 1Bh) read 

       times   0x01f1-$+$$ db 0

filename	db	"KERNEL  SYS"

sign	dw	0, 0xAA55
		; in boot32lb.asm: "Win9x uses all 4 bytes as magic value here."
		; but I'm not sure of NEC PC-98 version...
