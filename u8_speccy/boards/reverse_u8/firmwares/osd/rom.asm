	DEVICE	ZXSPECTRUM48

; PCB ReVerSE U8EP3C POST v0.2 (build 20140327)

; -------------------------------------------------------------------------------
; -- Карта памяти N80v1 CPU
; -------------------------------------------------------------------------------
; -- A15 A14 A13
; -- 0   0   x	0000-3FFF (16384) RAM
; -- 			  ( 4800) текстовый буфер (символ, цвет, символ...)

; -- #BF W/R:txt0_addr1 мл.адрес начала текстового видео буфера
; -- #7F W/R:txt0_addr2 ст.адрес начала текстового видео буфера

BUFFER			EQU #2000	; Адрес начала текстового буфера
VARIABLES		EQU #003a	; Адрес начала переменных

; Переменные
print_color		EQU VARIABLES+0
print_addr		EQU VARIABLES+1


; I/O
port_addr_low		EQU %11111110
port_addr_hi		EQU %11111101
port_data		EQU %11111011
port_status		EQU %11110111	;IOFLAG & "111111" & SEL

port_txt_addr1		EQU #bf
port_txt_addr2		EQU #7f

;--------------------------------------
; Reset
		ORG #0000
StartProg:
		di
		ld a,#00
		out (port_txt_addr1),a
		ld a,#10
		out (port_txt_addr2),a
		jp Test
;--------------------------------------
; INT
		ORG #0038
Int
		reti
;--------------------------------------
; NMI
		ORG #0066
Nmi
		retn
;--------------------------------------
Test
		ld sp,#3FFF

		call Cls
		
		ld de,str01
		ld hl,BUFFER
		call PrintStr

		ld de,str02
		ld hl,BUFFER+160*2
		call PrintStr

		ld de,str03
		ld hl,BUFFER+160*28
		call PrintStr

test1		in a,(port_addr_hi)
		ld hl,BUFFER+160*2+4*2
		call ByteToHexStr

		in a,(port_addr_low)
		call ByteToHexStr

		in a,(port_data)
		ld hl,BUFFER+160*2+16*2
		call ByteToHexStr

		jp test1

;--------------------------------------
; Очистка текстового видео буфера	
;--------------------------------------
Cls		ld de,#0F00
		ld bc,#0960
		ld hl,BUFFER
cls1		ld (hl),e
		inc hl
		ld (hl),d
		inc hl
		dec bc
		ld a,c
		or b
		jr nz,cls1
		ret

;--------------------------------------
; Печать
;--------------------------------------
PrintStr	ld a,(print_color)
printStr2	ld c,a
printStr3	ld a,(de)
		or a
		ret z
		inc de
		cp #01
		jr z,printStr1
		ld (hl),a
		inc hl
		ld (hl),c
		inc hl
		jr printStr3
printStr1	ld a,(de)
		ld (print_color),a
		inc de
		jr printStr2

;--------------------------------------
; Byte to HEX string
;--------------------------------------
; A  = byte
; HL = buffer
ByteToHexStr	ld b,a
		rrca
		rrca
		rrca
		rrca
		and #0f
		add a,#90
		daa
		adc a,#40
		daa
		ld (hl),a
		inc hl
		inc hl
		ld a,b
		and #0f
		add a,#90
		daa
		adc a,#40
		daa
		ld (hl),a
		inc hl
		inc hl
		ret

; цвет
; b2..0 = ink
; b5..3 = paper
; b6	= bright
; b7	= -

;				 00000000001111111111222222222233333333334444444444555555555566666666667777777777	
;				 01234567890123456789012345678901234567890123456789012345678901234567890123456789
str01		db 1,%01111000,	"                                   REVERSE-U8                                   "
		db 1,%00001111, "U8-Speccy Version 0.8.8 Rev20140401 By MVV",0
str02		db 1,%00001111,	"IO= ....h Data= ..h",0
str03		db 1,%00101000, "F4-CPU Reset  F5-NMI       F6-DivIDE  F7-Frame           F8-Info       F9-Turbo "
		db 1,%00101000, "F10-GS Reset  F11-SounDrv  F12-Mode   Scroll-Hard Reset  Num-Kempston           ",0
				
		; db "System Time:"
		; db "System Data:"
		; db "CPU Speed:"
		; db "Turbo:"
		; db "Memory Port:"
		; db "Memory Size:"
		; db "Mouse:"
		; db "Kempston:"
		; db "DivMMC:"
		; db "TurboSound:"
		; db "General Sound:"
		; db "Z-Controller:"
		; db "RTC:"
		
		; db "0.856","1.75","3.5","7.0","14.0"
		; db "Disabled","Enabled"
		; db "48","128","256","512","1024","2048","4096"
		; db "7FFD","7FFD & DFFD","7FFD & FDFD"
		; db "00:00:00"
		; db "01.01.2014"

	savebin "rom.bin",StartProg, 16384