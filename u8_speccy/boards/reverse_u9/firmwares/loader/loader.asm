 		DEVICE	ZXSPECTRUM48
; -----------------------------------------------------------------[24.03.2014]
; U9EP3C Loader Version 0.8 By MVV
; -----------------------------------------------------------------------------
; V0.1	05.11.2011	первая версия
; V0.5	09.11.2011	добавил SPI загрузчик и GS, VS1053
; V0.6	14.01.2012	добавил расширение памяти KAY
; V0.7	19.09.2012	по умолчанию режим память 4MB Profi, 96K ROM грузится из M25P40, wav 48kHz, FAT16 loader отключен
; V0.8	19.03.2014	размер загрузчика 1К

; На будущее: В память с CD/MMC карты грузится файл u8ldr и запускается.
; u8ldr представляет собой BIOS, проверяет, настраивает, загружает файлы системы

SYSTEM_PORT	EQU #0001	; bit2 = 0:Loader ON, 1:Loader OFF; bit1 = 0:SRAM<->CPU0, 1:SRAM<->GS; bit0 = 0:TDA1543, 1:M25P40
MASK_PORT	EQU #0000	; Маска порта EXT_MEM_PORT по AND
EXT_MEM_PORT	EQU #DFFD	; Порт памяти

		ORG #0000
StartProg:
		DI
		LD SP,#7FFE
		
		LD A,%00000001	; Bit2 = 0:Loader ON, 1:Loader OFF; Bit1 = 0:SRAM<->CPU0, 1:SRAM<->GS; Bit0 = 0:TDA1543, 1:M25P40
		LD BC,SYSTEM_PORT
		OUT (C),A

		LD HL,STR_TEST1
		CALL TX_STR

; 060000 GS 	32K
; 068000 GLUK	16K	0
; 06C000 TR-DOS	16K	1
; 070000 OS'86	16K	2
; 074000 OS'82	16K	3
; 078000 divMMC	 8K	4

; -----------------------------------------------------------------------------
; SPI autoloader
; -----------------------------------------------------------------------------
		CALL SPI_START
		LD D,%00000011	; Command = READ
		CALL SPI_W

		LD D,#06	; Address = #060000
		CALL SPI_W
		LD D,#00
		CALL SPI_W
		LD D,#00
		CALL SPI_W
		
		LD HL,#8000	; GS ROM 32K
SPI_LOADER1	CALL SPI_R
		LD (HL),A
		INC HL
		LD A,L
		OR H
		JR NZ,SPI_LOADER1
		
		LD A,%00000111	; Bit2 = 0:Loader ON, 1:Loader OFF; Bit1 = 0:SRAM<->CPU0, 1:SRAM<->GS; Bit0 = 0:TDA1543, 1:M25P40
		LD BC,SYSTEM_PORT
		OUT (C),A
		LD BC,MASK_PORT
		LD A,%11111111	; Маска порта по AND
		OUT (C),A
		LD A,%10000100
		LD BC,EXT_MEM_PORT
		OUT (C),A

		XOR A		; открываем страницу ОЗУ
SPI_LOADER3	LD BC,#7FFD
		OUT (C),A
		LD HL,#C000
		LD E,A
SPI_LOADER2	CALL SPI_R
		LD (HL),A
		INC HL
		LD A,L
		OR H
		JR NZ,SPI_LOADER2
		LD A,E
		INC A
		CP 5
		JR C,SPI_LOADER3

		CALL SPI_END
		LD A,%00000110	; Bit2 = 0:Loader ON, 1:Loader OFF; Bit1 = 0:SRAM<->CPU0, 1:SRAM<->GS; Bit0 = 0:TDA1543, 1:M25P40
		LD BC,SYSTEM_PORT
		OUT (C),A
		XOR A
		LD BC,#7FFD
		OUT (C),A
		LD BC,EXT_MEM_PORT
		OUT (C),A
		LD A,%00011111	; Маска порта (разрешаем 4MB)
		LD BC,MASK_PORT
		OUT (C),A
		LD A,%00000110	; Bit2 = 0:Loader ON, 1:Loader OFF; Bit1 = 0:SRAM<->CPU0, 1:SRAM<->GS; Bit0 = 0:TDA1543, 1:M25P40
		LD BC,SYSTEM_PORT
		OUT (C),A
		
; -----------------------------------------------------------------------------
; I2C PCF8583 to MC14818 loader
; -----------------------------------------------------------------------------
RTC_INIT	LD BC,#0000
		LD HL,#8000
		CALL I2C_GET

		LD A,#80
		LD BC,#EFF7
		OUT(C),A

; REGISTER B
		LD A,#0B
		LD B,#DF
		OUT (C),A
		LD A,#82
		LD B,#BF
		OUT (C),A
; SECONDS
		LD A,#00
		LD B,#DF
		OUT (C),A
		LD A,(#8002)
		LD B,#BF
		OUT (C),A
; MINUTES		
		LD A,#02
		LD B,#DF
		OUT (C),A
		LD A,(#8003)
		LD B,#BF
		OUT (C),A
; HOURS		
		LD A,#04
		LD B,#DF
		OUT (C),A
		LD A,(#8004)
		AND #3F
		LD B,#BF
		OUT (C),A
; DAY OF THE WEEK		
		LD A,#06
		LD B,#DF
		OUT (C),A
		LD A,(#8006)
		AND #E0
		RLCA
		RLCA
		RLCA
		INC A
		LD B,#BF
		OUT (C),A
; DATE OF THE MONTH
		LD A,#07
		LD B,#DF
		OUT (C),A
		LD A,(#8005)
		AND #3F
		LD B,#BF
		OUT (C),A
; MONTH
		LD A,#08
		LD B,#DF
		OUT (C),A
		LD A,(#8006)
		AND #1F
		LD B,#BF
		OUT (C),A
; YEAR
		LD A,#09
		LD B,#DF
		OUT (C),A
		LD A,(#8005)
		AND #C0
		RLCA
		RLCA
		LD HL,#8010	; ячейка для хранения года (8 бит)
		ADD A,(HL)	; год из PCF + поправка из ячейки
		LD B,#BF
		OUT (C),A
; REGISTER B
		LD A,#0B
		LD B,#DF
		OUT (C),A
		LD A,#02
		LD B,#BF
		OUT (C),A

		LD A,#00
		LD BC,#EFF7
		OUT(C),A

;------------------------------------------------------------------------------
; VS1053 Init
;------------------------------------------------------------------------------
; VS_INIT		LD A,%00000000          ; XCS=0 XDCS=0
		; OUT (#05),A
		; LD HL,TABLE
		; LD B,44
; VS_INIT1 	LD D,(HL)
		; CALL VS_RW
		; INC HL
		; DJNZ VS_INIT1
		; LD A,%00100000          ; XCS=0 XDCS=1
		; OUT (#05),A

;------------------------------------------------------------------------------		
		LD SP,#FFFF
		JP #0000	; Запуск системы

; -----------------------------------------------------------------------------	
; I2C PCF8583 
; -----------------------------------------------------------------------------
; Ports:
; #8C: Data (write/read)
;	bit 7-0	= Stores I2C read/write data
; #8C: Address (write)
; 	bit 7-1	= Holds the first seven address bits of the I2C slave device
; 	bit 0	= I2C 1:read/0:write bit

; #9C: Command/Status Register (write)
;	bit 7-2	= Reserved
;	bit 1-0	= 00: IDLE; 01: START; 10: nSTART; 11: STOP
; #9C: Command/Status Register (read)
;	bit 7-2	= Reserved
;	bit 1 	= 1:ERROR 	(I2C transaction error)
;	bit 0 	= 1:BUSY 	(I2C bus busy)

; HL= адрес буфера
; B = длина (0=256 байт)
; C = адрес
I2C_GET		LD A,%11111101	; START
		OUT (#9C),A
		LD A,%10100000	; SLAVE ADDRESS W
		OUT (#8C),A
		CALL I2C_ACK
		LD A,%11111110	; NSTART
		OUT (#9C),A
		LD A,C		; WORD ADDRESS
		OUT (#8C),A
		CALL I2C_ACK
		LD A,%11111101	; START
		OUT (#9C),A
		LD A,%10100001	; SLAVE ADDRESS R
		OUT (#8C),A
		CALL I2C_ACK
		LD A,%11111100	; IDLE
		OUT (#9C),A
		
I2C_GET2	OUT (#8C),A
		CALL I2C_ACK
		IN A,(#8C)
		LD (HL),A
		INC HL
		LD A,B
		CP 2
		JR NZ,I2C_GET1
		LD A,%11111111	; STOP
		OUT (#9C),A
I2C_GET1	DJNZ I2C_GET2
		RET

; Wait ACK
I2C_ACK		IN A,(#9C)
		RRCA		; ACK?
		JR C,I2C_ACK
		RRCA		; ERROR?
		RET

; -----------------------------------------------------------------------------	
; SPI 
; -----------------------------------------------------------------------------
; Ports:

; #02: Data Buffer (write/read)
;	bit 7-0	= Stores SPI read/write data

; #03: Command/Status Register (write)
;	bit 7-2	= Reserved
;	bit 1	= 1:IRQEN 	(Generate IRQ at end of transfer)
;	bit 0	= 1:END   	(Deselect device after transfer/or immediately if START = '0')
; #03: Command/Status Register (read):
; 	bit 7	= 1:BUSY	(Currently transmitting data)
;	bit 6	= 1:DESEL	(Deselect device)
;	bit 5-0	= Reserved

SPI_END		LD A,%00000001	; Config = END
		OUT (#03),A
		RET
		
SPI_START	XOR A
		OUT (#03),A
		RET
		
SPI_W		IN A,(#03)
		RLCA
		JR C,SPI_W
		LD A,D
		OUT (#02),A
		RET
		
SPI_R		LD D,#FF
		CALL SPI_W
SPI_R1		IN A,(#03)
		RLCA
		JR C,SPI_R1
		IN A,(#02)
		RET
; -----------------------------------------------------------------------------	
; UART 
; -----------------------------------------------------------------------------
; Ports:
; #BC DATA	W/R
; #AC STATUS	R b7: 1=tx_busy, b6: 0=CBUS4(FT232R POWER ON), b5..2: NC, b1: 1=rx_error, b0: 1=rx_avail
; HL=STRING, #00 = END STRING

P_TXREG		EQU #BC
P_TXSTA		EQU #AC

TX_IF		RLCA
		RET C		; CY=1 FT232R NO CONNECT TO HOST!
TX_STR		IN A,(P_TXSTA)
		RLCA
		JR C,TX_IF	; CY=1 busy...
		LD A,(HL)
		OR A
		RET Z		; Z=0 :END STRING
		INC HL
		OUT (P_TXREG),A
		JR TX_STR
		
;------------------------------------------------------------------------------
; VS1053
;------------------------------------------------------------------------------
; VS_RW   	IN A,(#05)
		; RLCA 
		; JR C,VS_RW
		; RLCA 
		; JR NC,VS_RW
		; LD A,D
		; OUT (#04),A
; VS_RW1  	IN A,(#05)
		; RLCA 
		; JR C,VS_RW1
		; RLCA 
		; JR NC,VS_RW1
		; IN A,(#04)
		; RET 

; TABLE   	DB #52,#49,#46,#46,#FF,#FF,#FF,#FF      ;REFF....
		; DB #57,#41,#56,#45,#66,#6D,#74,#20      ;WAVEfmt
		; DB #10
		; DB #00,#00,#00,#01,#00,#02,#00

		; DB #80,#BB,#00,#00      ;48kHz
		; DB #00,#EE,#02,#00

; ;   		DB #44,#AC,#00,#00      ;41.1kHz
; ;  		DB #10,#B1,#02,#00

		; DB #04,#00
		; DB #10,#00
		; DB #64,#61,#74,#61                      ;data
		; DB #FF,#FF,#FF,#FF

STR_TEST1	DB #0D,#0A
		DB #0D,#0A,"ReVerSE-U9 Loader, version 0.8"
		DB #0D,#0A,"Copyright (C) 2011-2014 MVV",#0D,#0A,0

		savebin "loader.bin",StartProg, 1024