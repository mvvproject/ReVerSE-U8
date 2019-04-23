; -----------------------------------------------------------------[29.01.2017]
; ReVerSE-U8 Loader Build 20170129 By MVV, dsp
; -----------------------------------------------------------------------------
; 12.08.2014	первая версия
; 21.09.2014	RTC Setup
; 22.07.2015	добавлено чтение silicon ID spiflash
; 04.10.2015	добавлено чтение roms/zxevo.rom из SD

 		DEVICE	ZXSPECTRUM48
system_port	equ #0001	; bit2: 0=loader on, 1=loader off; bit1: 0=sram<->cpu0, 1=sram<->gs; bit0: 0=m25p40, 1=vs1053b
pr_param	equ #7f00
page3init 	equ #7f04      	; RAM mem in  BANK1 (lowest  addr)
cursor_pos	equ #7f05
block_16k_cnt 	equ #7f06
buffer		equ #8000
time_pos_y	equ #0a
time_pos_yx	equ #0a00
TOTAL_PAGE	equ 32

	org #0000
startprog:
	di               	; disable int
	ld sp,#7ffe	 	; stack - bank1:(exec code - bank0):destination 
	
	xor a
	ld bc,system_port	; bit2: 0=loader on, 1=loader off; bit1: 0=sram<->cpu0, 1=sram<->gs; bit0: 0=m25p40, 1=vs1053b
	out (#fe),a		; цвет бордюра
	out (c),a
	call cls		; очистка экрана
	ld hl,str1
	call print_str

;------------------------------------------------------------------------------		
; ID read
;------------------------------------------------------------------------------		
ID_READ
	call spi_start
	ld d,%10101011		; command ID read
	call spi_w
	call spi_r
	call spi_r
	call spi_r
	call spi_r
	call print_hex
	call spi_end

	ld hl,str5
	call print_str

; 0x060000 = gs105.rom    32K
; -----------------------------------------------------------------------------
; SPI autoloader
; -----------------------------------------------------------------------------
	call spi_start
	ld d,%00000011		; command = read
	call spi_w

	ld d,#06		; address = #060000
	call spi_w
	ld d,#00
	call spi_w
	ld d,#00
	call spi_w

	ld hl,buffer		; GS ROM 32K
spi_loader1
	call spi_r
	ld (hl),a
	inc hl
	ld a,l
	or h
	jr nz,spi_loader1
	ld a,l
	or h
	jr nz,spi_loader1
	call spi_end

	ld a,%00000011
	ld bc,system_port	; bit2: 0=loader on, 1=loader off; bit1: 0=sram<->cpu0, 1=sram<->gs; bit0: 0=m25p40, 1=vs1053b
	out (c),a

	ld hl,str3
	call print_str


	ld hl,str8
	call print_str

; -----------------------------------------------------------------------------
; SD Loader
; -----------------------------------------------------------------------------
	ld sp,PWA
	ld bc,SYC
	ld a,DEFREQ
	out(c),a		;SET DEFREQ:%00000010-14MHz
	;PAGE3
	ld b,PW3/256
	in a,(c)		;READ PAGE3 //PW3:#13AF
	ld (page3init),a	;(page3init) <- SAVE orig PAGE3
	;PAGE2
	ld b,PW2/256
	in a,(c)		;READ PAGE2 //PW2:#12AF 
	ld e,PG0
	out (c),e		;SET PAGE2=0xF7
	ld (PGR),a		;(PGR) <- SAVE orig PAGE2
	;step_1: INIT SD CARD
	ld a,#00 		;STREAM: SD_INIT, HDD
	call FAT_DRV
	jr nz,ERR		;INIT - FAILED
	;step_2: find DIR entry
	ld hl,FES1
	ld a,#01 		;find DIR entry
	call FAT_DRV
	jr nz,ERR		;dir not found
	ld a,#02		;SET CURR DIR - ACTIVE
	call FAT_DRV
	;step_3: find File entry
	ld hl,FES2
	ld a,#01		;find File entry
	call FAT_DRV
	jr nz,ERR		;file not  found
	;step_4: download data
	ld a,#00		;#0 - start page 

	; Open 1st Page = ROM
	ld (block_16k_cnt),a	;RESTORE block_16kB_cnt 
	ld c,a			;page Number
	ld de,#0000		;offset in PAGE: 
  	ld b,32			;1 block-512Byte/32bloks-16kB
	ld a,#03		;code 3: LOAD512(TSFAT.ASM) c
	call FAT_DRV		;return CDE - Address 

LOAD_16kb
	;Open 2snd Page = ROM 
	ld a,(block_16k_cnt)	;загружаем ячейку счетчика страниц в A
	inc a			;lock_16kB_cnt+1  увеличиваем значение на 1 
	ld (block_16k_cnt),a	;сохраняем новое значение

	ld c,a			;page 
	ld de,#0000		;offset in Win3: 
	ld b,32			;1 block-512Byte // 32- 16kB

	;load data from opened file
	ld a,#03		;LOAD512(TSFAT.ASM) 
	call FAT_DRV		;читаем вторые 16kB
	jr nz,DONE		;EOF -EXIT
	
	;CHECK CNT
	ld a,(block_16k_cnt)	;загружаем ячейку счетчика страниц в A
	sub TOTAL_PAGE		;проверяем это был последний блок или нет
	jr nz,LOAD_16kb		;если да то выход, если нет то возврат на 
DONE
	ld hl,str3
	call print_str
	jr RTC_INIT
ERR
	ld sp,#7ffe
	ld hl,str_absent
	call print_str

;------------------------------------------------------------------------------		
; Инициализация RTC
;------------------------------------------------------------------------------		
RTC_INIT
	ld hl,str4		; инициализация RTC
	call print_str

	call rtc_read
	ld hl,str_absent
	jr z,label1
	ld hl,str3
label1
	call print_str

;------------------------------------------------------------------------------
; VS1053 Init
;------------------------------------------------------------------------------
vs_init
	ld hl,str9
	call print_str

	ld a,%00000000          ; xcs=0 xdcs=0
	out (#05),a
	ld hl,table
	ld b,44
vs_init1
	ld d,(hl)
	call vs_rw
	inc hl
	djnz vs_init1
	ld a,%00100000          ; xcs=0 xdcs=1
	out (#05),a

	ld hl,str3		;завершено
	call print_str

	ld hl,str0		; any key
	call print_str

; Start System
	call anykey
	call mc14818a_init

	ld a,%00000111
	ld bc,system_port	; bit2: 0=loader on, 1=loader off; bit1: 0=sram<->cpu0, 1=sram<->gs; bit0: 0=m25p40, 1=vs1053b
	out (c),a
	ld sp,#ffff
	jp #0000		; запуск системы

;------------------------------------------------------------------------------
; Ожидание клавиши
;------------------------------------------------------------------------------
anykey1
	ld hl,str0
	call print_str
	ld bc,system_port
anykey2
	in a,(c)		; чтение сканкода клавиатуры
	cp #ff
	jr nz,anykey2
anykey
	ld hl,time_pos_yx		; координаты вывода даты и времени
	ld (pr_param),hl
	call rtc_read		; чтение даты и времени
	call rtc_data		; вывод
	ld bc,system_port
	in a,(c)		; чтение сканкода клавиатуры
	cp #1b			; <S> ?
	jp z,rtc_setup
	cp #5a			; <ENTER> ?
	jr nz,anykey
	ret

; -----------------------------------------------------------------------------
; I2C PCF8583 read
; -----------------------------------------------------------------------------
rtc_read
	ld bc,#0000
	ld hl,buffer
	ld d,%10100001		; Device Address RTC PCF8583 + read
	call i2c

	ld b,#00
; проверка
; z=error, nz=ok
check_buffer
	ld hl,buffer
check_buffer1
	ld a,(hl)
	inc a
	ret nz
	ld (hl),a
	inc hl
	djnz check_buffer1
	ret
	
; -----------------------------------------------------------------------------
; инициализация MC14818A
; -----------------------------------------------------------------------------
mc14818a_init
	ld a,#80
	ld bc,#eff7
	out(c),a

; register b
	ld a,#0b
	ld b,#df
	out (c),a
	ld a,#82
	ld b,#bf
	out (c),a
; seconds
	ld a,#00
	ld b,#df
	out (c),a
	ld a,(buffer+2)		; 02h seconds
	ld b,#bf
	out (c),a
; minutes		
	ld a,#02
	ld b,#df
	out (c),a
	ld a,(buffer+3)		; 03h minutes
	ld b,#bf
	out (c),a
; hours		
	ld a,#04
	ld b,#df
	out (c),a
	ld a,(buffer+4)		; 04h hours
	and #3f
	ld b,#bf
	out (c),a
; day of the week		
	ld a,#06
	ld b,#df
	out (c),a
	ld a,(buffer+6)		; 06h day
	and #e0
	rlca
	rlca
	rlca
	inc a
	ld b,#bf
	out (c),a
; date of the month
	ld a,#07
	ld b,#df
	out (c),a
	ld a,(buffer+5)		; 04h date
	and #3f
	ld b,#bf
	out (c),a
; month
	ld a,#08
	ld b,#df
	out (c),a
	ld a,(buffer+6)		; 06h month
	and #1f
	ld b,#bf
	out (c),a
; year
	ld a,#09
	ld b,#df
	out (c),a
	ld a,(buffer+5)
	and #c0
	rlca
	rlca
	ld b,a
	ld a,(buffer+16)	; ячейка для хранения года (8 бит)
	and %11111100
	or b
	ld b,#bf
	out (c),a
; register b
	ld a,#0b
	ld b,#df
	out (c),a
	ld a,#02
	ld b,#bf
	out (c),a

	ld a,#00
	ld bc,#eff7
	out(c),a
	ret

; -----------------------------------------------------------------------------
; Вывод даты и времени
; -----------------------------------------------------------------------------
rtc_data
	; вывод даты
	ld a,(buffer+6)
	and %11100000
	rlca
	rlca
	rlca
	add a,a
	add a,a
	ld hl,day		; день недели
	ld e,a
	ld d,0
	add hl,de
	call print_str
	ld a,","
	call print_char
	ld a,(buffer+5)		; число
	and %00111111
	call print_hex
	ld a,"."
	call print_char
	ld a,(buffer+6)		; месяц
	and %00011111
	call print_hex
	ld a,"."
	call print_char
	ld a,#20
	call print_hex
	ld a,(buffer+5)		; год
	and %11000000
	rlca
	rlca
	ld b,a
	ld a,(buffer+16)	; ячейка для хранения года (8 бит)
	and %11111100
	or b
	call print_hex
	ld a," "
	call print_char
	; вывод времени
	ld a,(buffer+4)		; час
	and %00111111
	call print_hex
	ld a,":"
	call print_char
	ld a,(buffer+3)		; минуты
	call print_hex
	ld a,":"
	call print_char
	ld a,(buffer+2)		; секунды
	jp print_hex		

; -----------------------------------------------------------------------------	
; I2C 
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
; D = Device Address (bit0: 0=WR, 1=RD)

i2c	
	ld a,%11111101		; start
	out (#9c),a
	ld a,d			; slave address w
	and %11111110
	out (#8c),a
	call i2c_ack
	bit 0,d
	jr nz,i2c_4		; четение
	ld a,%11111100		; idle
	out (#9c),a
	ld a,c			; word address
	out (#8c),a
	call i2c_ack
	jr i2c_2
i2c_4
	ld a,%11111110		; nstart
	out (#9c),a
	ld a,c			; word address
	out (#8c),a
	call i2c_ack
	ld a,%11111101		; start
	out (#9c),a
	ld a,d			; slave address r/w
	out (#8c),a
	call i2c_ack
	ld a,%11111100		; idle
	out (#9c),a
i2c_2
	ld a,b
	dec a
	jr nz,i2c_1
	ld a,%11111111		; stop
	out (#9c),a
i2c_1
	ld a,(hl)
	out (#8c),a
	call i2c_ack
	bit 0,d
	jr z,i2c_3		; запись? да
	in a,(#8c)
	ld (hl),a
i2c_3	
	inc hl
	djnz i2c_2
	ret

; wait ack
i2c_ack
	in a,(#9c)
	rrca			; ack?
	jr c,i2c_ack
	rrca			; error?
	ret
	
; -----------------------------------------------------------------------------	
; SPI 
; -----------------------------------------------------------------------------
; Ports:

; #02: Data Buffer (write/read)
;	bit 7-0	= Stores SPI read/write data

; #03: Command/Status Register (write)
;	bit 7-1	= Reserved
;	bit 0	= 1:END   	(Deselect device after transfer/or immediately if START = '0')
; #03: Command/Status Register (read):
; 	bit 7	= 1:BUSY	(Currently transmitting data)
;	bit 6	= 0:INT ENC424J600
;	bit 5-0	= Reserved

spi_end
	ld a,%00000001		; config = end
	out (#03),a
	ret
spi_start
	xor a
	out (#03),a
	ret
spi_w
	in a,(#03)
	rlca
	jr c,spi_w
	ld a,d
	out (#02),a
	ret
spi_r
	ld d,#ff
	call spi_w
spi_r1	
	in a,(#03)
	rlca
	jr c,spi_r1
	in a,(#02)
	ret

;------------------------------------------------------------------------------
; VS1053
;------------------------------------------------------------------------------
vs_rw
	in a,(#05)
	rlca 
	jr c,vs_rw
	rlca 
	jr nc,vs_rw
	ld a,d
	out (#04),a
vs_rw1  
	in a,(#05)
	rlca 
	jr c,vs_rw1
	rlca 
	jr nc,vs_rw1
	in a,(#04)
	ret 

table   
	db #52,#49,#46,#46,#ff,#ff,#ff,#ff      ;reff....
	db #57,#41,#56,#45,#66,#6d,#74,#20      ;wavefmt
	db #10
	db #00,#00,#00,#01,#00,#02,#00

	db #80,#bb,#00,#00      ;48khz
	db #00,#ee,#02,#00

;   	db #44,#ac,#00,#00      ;41.1khz
;  	db #10,#b1,#02,#00

	db #04,#00
	db #10,#00
	db #64,#61,#74,#61	;data
	db #ff,#ff,#ff,#ff

; -----------------------------------------------------------------------------	
; clear screen
; -----------------------------------------------------------------------------	
cls
	xor a
	out (#fe),a
	ld hl,#5aff
cls1
	ld (hl),a
	or (hl)
	dec hl
	jr z,cls1
	ret

; -----------------------------------------------------------------------------	
; print string i: hl - pointer to string zero-terminated
; -----------------------------------------------------------------------------	
print_str
	ld a,(hl)
	cp 17
	jr z,print_color
	cp 23
	jr z,print_pos_xy
	cp 24
	jr z,print_pos_x
	cp 25
	jr z,print_pos_y
	or a
	ret z
	inc hl
	call print_char
	jr print_str
print_color
	inc hl
	ld a,(hl)
	ld (pr_param+2),a	; color
	inc hl
	jr print_str
print_pos_xy
	inc hl
	ld a,(hl)
	ld (pr_param),a		; x-coord
	inc hl
	ld a,(hl)
	ld (pr_param+1),a	; y-coord
	inc hl
	jr print_str
print_pos_x
	inc hl
	ld a,(hl)
	ld (pr_param),a		; x-coord
	inc hl
	jr print_str
print_pos_y
	inc hl
	ld a,(hl)
	ld (pr_param+1),a	; y-coord
	inc hl
	jr print_str

; print character i: a - ansi char
print_char
	push hl
	push de
	push bc
	cp 13
	jr z,pchar2
	sub 32
	ld c,a			; временно сохранить в с
	ld hl,(pr_param)	; hl=yx
	;координаты -> scr adr
	;in: H - Y координата, L - X координата
	;out:hl - screen adress
	ld a,h
	and 7
	rrca
	rrca
	rrca
	or l
	ld l,a
	ld a,h
        and 24
	or 64
	ld d,a
	;scr adr -> attr adr
	;in: hl - screen adress
	;out:hl - attr adress
	rrca
	rrca
	rrca
	and 3
	or #58
	ld h,a
	ld a,(pr_param+2)	; цвет
	ld (hl),a		; печать атрибута символа
	ld e,l
	ld l,c			; l= символ
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	ld bc,font
	add hl,bc
	ld b,8
pchar3	ld a,(hl)
	ld (de),a
	inc d
	inc hl
	djnz pchar3
	ld a,(pr_param)		; x
	inc a
	cp 32
	jr nz,pchar1
pchar2
	ld a,(pr_param+1)	; y
	inc a
	cp 24
	jr nz,pchar0
	;сдвиг вверх на один символ
	call ssrl_up
	call asrl_up
	jr pchar00
pchar0
	ld (pr_param+1),a
pchar00
	xor a
pchar1
	ld (pr_param),a
	pop bc
	pop de
	pop hl
	ret

; print hexadecimal i: a - 8 bit number
print_hex
	ld b,a
	and $f0
	rrca
	rrca
	rrca
	rrca
	call hex2
	ld a,b
	and $0f
hex2
	cp 10
	jr nc,hex1
	add 48
	jp print_char
hex1
	add 55
	jp print_char

; print decimal i: l,d,e - 24 bit number , e - low byte
print_dec
	ld ix,dectb_w
	ld b,8
	ld h,0
lp_pdw1
	ld c,"0"-1
lp_pdw2
	inc c
	ld a,e
	sub (ix+0)
	ld e,a
	ld a,d
	sbc (ix+1)
	ld d,a
	ld a,l
	sbc (ix+2)
	ld l,a
	jr nc,lp_pdw2
	ld a,e
	add (ix+0)
	ld e,a
	ld a,d
	adc (ix+1)
	ld d,a
	ld a,l
	adc (ix+2)
	ld l,a
	inc ix
	inc ix
	inc ix
	ld a,h
	or a
	jr nz,prd3
	ld a,c
	cp "0"
	ld a," "
	jr z,prd4
prd3
	ld a,c
	ld h,1
prd4
	call print_char
	djnz lp_pdw1
	ret
dectb_w
	db #80,#96,#98		; 10000000 decimal
	db #40,#42,#0f		; 1000000
	db #a0,#86,#01		; 100000
	db #10,#27,0		; 10000
	db #e8,#03,0		; 1000
	db 100,0,0		; 100
	db 10,0,0		; 10
	db 1,0,0		; 1

; -----------------------------------------------------------------------------	
; Сдвиг изображения вверх на один символ
; -----------------------------------------------------------------------------	
ssrl_up
        ld de,#4000     	; начало экранной области
lp_ssu1 
	push de           	; сохраняем адрес линии на стеке
        ld bc,#0020     	; в линии - 32 байта
        ld a,e          	; в регистре de находится адрес
        add a,c          	; верхней линии. в регистре
        ld l,a          	; hl необходимо получить адрес
        ld a,d          	; линии, лежащей ниже с шагом 8.
        jr nc,go_ssup   	; для этого к регистру e прибав-
        add a,#08        	; ляем 32 и заносим в l. если про-
go_ssup 
	ld h,a         		; изошло переполнение, то h=d+8
        ldir                 	; перенос одной линии (32 байта)
        pop de           	; восстанавливаем адрес начала линии
        ld a,h          	; проверяем: а не пора ли нам закру-
        cp #58          	; гляться? (перенесли все 23 ряда)
        jr nc,lp_ssu2   	; если да, то переход на очистку
        inc d            	; ---------------------------------
        ld a,d          	; down_de
        and #07          	; стандартная последовательность
        jr nz,lp_ssu1   	; команд для перехода на линию
        ld a,e         		; вниз в экранной области
        add a,#20        	; (для регистра de)
        ld e,a          	;
        jr c,lp_ssu1    	; на входе:  de - адрес линии
        ld a,d          	; на выходе: de - адрес линии ниже
        sub #08          	; используется аккумулятор
        ld d,a          	;
        jr lp_ssu1      	; ---------------------------------
lp_ssu2 
	xor a            	; очистка аккумулятора
lp_ssu3 
	ld (de),a       	; и с его помощью -
        inc e            	; очистка одной линии изображения
        jr nz,lp_ssu3   	; всего: 32 байта
        ld e,#e0        	; переход к следующей
        inc d            	; (нижней) линии изображения
        bit 3,d          	; заполнили весь последний ряд?
        jr z,lp_ssu2    	; если нет, то продолжаем заполнять
        ret                  	; выход из процедуры	

; -----------------------------------------------------------------------------	
; Сдвиг атрибутов вверх
; -----------------------------------------------------------------------------	
asrl_up
        ld hl,#5820     	; адрес второй линии атрибутов
        ld de,#5800     	; адрес первой линии атрибутов
        ld bc,#02e0     	; перемещать: 23 линии по 32 байта
        ldir                 	; сдвигаем 23 нижние линии вверх
        xor a   		; цвет для заполнения нижней линии
lp_asup 
	ld (de),a       	; устанавливаем новый атрибут
        inc e            	; если заполнили всю последнюю линию
        jr nz,lp_asup   	; (e=0), то прерываем цикл
        ret                  	; выход из процедуры

; -----------------------------------------------------------------------------	
; Расчет адреса атрибута
; -----------------------------------------------------------------------------
; e = y(0-23)		hl = адрес
; d = x(0-31)
attr_addr
	ld a,e
        rrca
        rrca
        rrca
        ld l,a
        and 31
        or 88
        ld h,a
        ld a,l
        and 252
        or d
        ld l,a
	ret

; -----------------------------------------------------------------------------	
; RTC Setup
; -----------------------------------------------------------------------------
; a = позиция		ix = адрес
get_cursor
	ld de,cursor_pos_data
	ld l,a
	ld h,0
	add hl,hl
	add hl,hl
	add hl,hl
	add hl,de
	push hl
	pop ix
	ret

; -----------------------------------------------------------------------------
; c = цвет
; a = позиция
print_cursor
	ld c,%01001111		; цвет курсора
print_cursor1
	call get_cursor
	ld d,(hl)		; координата х
	inc hl
	ld b,(hl)		; ширина курсора
	ld e,time_pos_y
	call attr_addr
print_cursor2	
	ld (hl),c
	inc hl
	djnz print_cursor2
	ret

; -----------------------------------------------------------------------------
rtc_setup
	ld hl,str6
	call print_str
	call rtc_depac

	xor a
cursor1
	ld (cursor_pos),a	; курсор в начало
cursor2
	call print_cursor	; установить курсор
key_press
	ld bc,system_port
	in a,(c)		; чтение сканкода клавиатуры
	cp #ff
	jr nz,key_press
key_press1
	ld bc,system_port
	in a,(c)		; чтение сканкода клавиатуры
	cp #5a			; <ENTER> ?
	jr z,key_enter
	cp #75			; <UP> ?
	jr z,key_up
	cp #72			; <DOWN> ?
	jr z,key_down
	cp #6b			; <LEFT> ?
	jr z,key_left
	cp #74			; <RIGHT> ?
	jr z,key_right
	cp #76			; <ESC>?
	jp z,anykey1
	jr key_press1

key_left
	ld a,(cursor_pos)
	or a			; первая позиция?
	jr z,key_press		; да, оставить без изменений
	ld c,%00000111
	call print_cursor1	; убрать курсор
	ld a,(cursor_pos)
	dec a
	jr cursor1

key_right
	ld a,(cursor_pos)
	cp 6			; последняя позиция?
	jr nc,key_press		; да, оставить без изменений
	ld c,%00000111
	call print_cursor1	; убрать курсор
	ld a,(cursor_pos)
	inc a
	jr cursor1

key_up
	ld d,(ix+4)
	ld e,(ix+5)
	ld a,(de)
	cp (ix+3)
	jr z,key_up2		; = max?
	add a,1			; арифметическое сложение
key_up1
	daa
	ld (de),a
key_up2
	ld hl,time_pos_yx	; координаты вывода даты и времени
	ld (pr_param),hl
	call rtc_pac
	call rtc_data		; вывод
	ld a,(cursor_pos)
	jr cursor2

key_down
	ld d,(ix+4)
	ld e,(ix+5)
	ld a,(de)
	cp (ix+2)
	jr z,key_up2		; = min?
	sub 1			; арифметическое вычитание
	jr key_up1

key_enter
	call rtc_pac
	ld hl,buffer
	set 7,(hl)
	ld hl,buffer
	ld bc,#0000
	ld d,%10100000		; Device Address RTC PCF8583 + write
	call i2c

	ld hl,buffer
	res 7,(hl)
	ld bc,#0100
	ld d,%10100000		; Device Address RTC PCF8583 + write
	call i2c
	jp anykey1

; -----------------------------------------------------------------------------	
; расспаковка
; -----------------------------------------------------------------------------	
rtc_depac
	ld a,(buffer+4)		; час
	and #3f
	ld (buffer+256),a
	ld a,(buffer+6)		; день недели
	and %11100000
	rlca
	rlca
	rlca
	ld (buffer+257),a
	ld a,(buffer+5)		; день месяца
	and #3f
	ld (buffer+258),a
	ld a,(buffer+6)		; месяц
	and #1f
	ld (buffer+259),a
	ld a,(buffer+5)		; год
	and %11000000
	rlca
	rlca
	ld b,a
	ld a,(buffer+16)
	and %11111100
	or b
	ld (buffer+16),a
	ret

; -----------------------------------------------------------------------------	
; упаковка
; -----------------------------------------------------------------------------	
rtc_pac
	ld a,(buffer+256)
	ld (buffer+4),a		; 04 hours
	ld a,(buffer+16)	; year
	and %00000011
	rrca
	rrca
	ld b,a
	ld a,(buffer+258)	; data
	or b
	ld (buffer+5),a		; 05 year/data
	ld a,(buffer+257)	; weekdays
	rrca
	rrca
	rrca
	ld b,a
	ld a,(buffer+259)	; mounths
	or b
	ld (buffer+6),a		; 06 weekdays/mounths
	ret

;управляющие коды
;13 (0x0d)		- след строка
;17 (0x11),color	- изменить цвет последующих символов
;23 (0x17),x,y		- изменить позицию на координаты x,y
;24 (0x18),x		- изменить позицию по x
;25 (0x19),y		- изменить позицию по y
;0			- конец строки

str1	db 23,0,0,17,#47,"ReVerSE-U8 DevBoard",17,7
	db 13,13,"FPGA SoftCore - TSConf"
	db 13,"(build 20170129) By MVV"
	db 13,13,"ASP configuration device ID 0x",0	; EPCS1	0x10 (1 Mb), EPCS4 0x12 (4 Mb), EPCS16 0x14 (16 Mb), EPCS64 0x16 (64 Mb)
str5	db "Copying data from FLASH...",0
str8	db 13,"Loading roms/zxevo.rom...",0
str3	db 17,4," Done",17,7,0
str4	db 13,13,"RTC data read...",0
str0	db 23,0,22,"Press ENTER to continue         "
	db	   "S: RTC Setup  PrtScr: 49Hz/60Hz",0
str_error
	db 17,2," Error",17,7,0
str9
	db 13,13,13,"Init VS1053b...",0
str6
	db 23,0,22,"<>:Select Item   ENTER:Save&Exit"
	db "^",127,  ":Change Values   ESC:Abort   ",0
str_absent
	db 17,2," Absent",17,7,13,0

; Fri 05.09.2014 23:53:29
; 0-6 1-31 1-12 0-99 0-23 0-59 0-59
cursor_pos_data
	db 0,3,#00,#06,#81,#01,#00,#00		; х, ширина, min, max, адрес переменной
	db 4,2,#01,#31,#81,#02,#00,#00
	db 7,2,#01,#12,#81,#03,#00,#00
	db 10,4,#00,#99,#80,#10,#00,#00
	db 15,2,#00,#23,#81,#00,#00,#00
	db 18,2,#00,#59,#80,#03,#00,#00
	db 21,2,#00,#59,#80,#02,#00,#00

day
	db "Sun",0,"Mon",0,"Tue",0,"Wed",0,"Thu",0,"Fri",0,"Sat",0,"Err",0
FES1	
	db #10 		;flag (#00 - file, #10 - dir)
	db "ROMS"	;DIR name
	db #00
FES2
	db #00
	db "ZXEVO.ROM"    ;file name //
	db #00

	INCLUDE "TSFAT.ASM"
font	
	INCBIN "font.bin"


	savebin "loader.bin",startprog, 8192
;	savesna "loader.sna",startprog

	display "Size of ROM is: ",/a, $