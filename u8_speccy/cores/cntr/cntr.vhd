-------------------------------------------------------------------[19.03.2014]
-- OSD
-------------------------------------------------------------------------------
-- V0.1 	16.02.2014	первая версия

library IEEE; 
use IEEE.std_logic_1164.all; 
use IEEE.numeric_std.ALL;
use IEEE.std_logic_unsigned.all;

entity cntr is
	port (
		CLK		: in std_logic;							-- 50MHz
		RESET	: in std_logic;
		SEL		: in std_logic;
		IOADDR	: in std_logic_vector(15 downto 0);
		IODATA	: in std_logic_vector(7 downto 0);
		IORD	: out std_logic;
		IOFLAG	: in std_logic;
		RGB		: out std_logic_vector(5 downto 0);		-- RRGGBB
		HSYNC	: out std_logic;
		VSYNC	: out std_logic);		
end entity;

architecture rtl of cntr is

signal n80_di			: std_logic_vector(7 downto 0);
signal n80_do			: std_logic_vector(7 downto 0);
signal n80_addr			: std_logic_vector(15 downto 0);
signal n80_wr			: std_logic;
signal n80_mreq			: std_logic;
signal n80_iorq			: std_logic;

signal txt_char_di		: std_logic_vector(15 downto 0);
signal txt_font_di		: std_logic_vector(7 downto 0);
signal txt_char_addr	: std_logic_vector(11 downto 0);
signal txt_font_addr	: std_logic_vector(11 downto 0);
signal txt_addr1		: std_logic_vector(7 downto 0);
signal txt_addr2		: std_logic_vector(7 downto 0);

signal txt_clken		: std_logic;
signal ram_wr			: std_logic;
signal ram_do			: std_logic_vector(7 downto 0);
signal reg_fe			: std_logic_vector(7 downto 0);
signal txt_buffer		: std_logic_vector(13 downto 0);

begin

-- n80cpu
n80cpu: entity work.n80
port map(
	CLK			=> not CLK,
	ENA			=> '1',
	RESET		=> RESET,
	NMI			=> '0',
	INT			=> '0',
	DI			=> n80_di,
	DO			=> n80_do,
	ADDR		=> n80_addr, 
	WR			=> n80_wr,
	MREQ		=> n80_mreq,
	IORQ		=> n80_iorq,
	HALT		=> open,
	M1			=> open);

-- Text Mode 80x30 (640x480 60Hz) 4800 bytes, Font 8x16 4096 bytes
vga: entity work.txt
port map(
	CLK			=> CLK,
	CLKEN		=> txt_clken,
	CHAR_DI		=> txt_char_di,
	FONT_DI		=> txt_font_di,
	CHAR_ADDR	=> txt_char_addr,
	FONT_ADDR	=> txt_font_addr,
	RGB			=> RGB,
	HS			=> HSYNC,
	VS			=> VSYNC);
	
-- RAM 16K
ram0: entity work.altram2
port map(
	address_a	=> n80_addr(13 downto 0),
	address_b	=> txt_buffer(12 downto 0),
	clock_a	 	=> CLK,
	clock_b	 	=> CLK,
	enable_a	=> '1',
	enable_b	=> txt_clken,
	data_a	 	=> n80_do,
	data_b	 	=> (others => '0'),
	wren_a	 	=> ram_wr,
	wren_b	 	=> '0',
	q_a	 		=> ram_do,
	q_b	 		=> txt_char_di);

-- FONT 4K
font: entity work.altrom1
port map(
	address		=> txt_font_addr,
	clock		=> CLK,
	clken		=> '1',
	q			=> txt_font_di);

process(CLK)
begin
	if (CLK'event and CLK = '0') then
		txt_clken <= not txt_clken;
	end if;
end process;

-------------------------------------------------------------------------------
-- Карта памяти CPU
-------------------------------------------------------------------------------
-- A15 A14 A13
-- 0   0   0	0000-3FFF (16384) RAM
--						  ( 4800) текстовый буфер (символ, цвет, символ...)

-- #BF W/R:txt0_addr1 мл.адрес начала текстового видео буфера
-- #7F W/R:txt0_addr2 ст.адрес начала текстового видео буфера

txt_buffer <= std_logic_vector (unsigned( '0' & txt_char_addr) + unsigned (txt_addr2(5 downto 0) & txt_addr1));	-- Адрес начала текстового буфера

-------------------------------------------------------------------------------
-- n80cpu
n80_di <=	ram_do when (n80_addr(15 downto 14) = "00" and n80_mreq = '1' and n80_wr = '0') else

			IOADDR(7 downto 0) when (n80_addr(0) = '0' and n80_iorq = '1' and n80_wr = '0') else
			IOADDR(15 downto 8) when (n80_addr(1) = '0' and n80_iorq = '1' and n80_wr = '0') else
			IODATA when (n80_addr(2) = '0' and n80_iorq = '1' and n80_wr = '0') else
			IOFLAG & "111111" & SEL when (n80_addr(3) = '0' and n80_iorq = '1' and n80_wr = '0') else
			txt_addr1 when (n80_addr(6) = '0' and n80_iorq = '1' and n80_wr = '0') else
			txt_addr2 when (n80_addr(7) = '0' and n80_iorq = '1' and n80_wr = '0') else
			(others => '1');

ram_wr <= not n80_addr(15) and not n80_addr(14) and n80_mreq and n80_wr;

-------------------------------------------------------------------------------
-- n80CPU I/O
process (CLK, reset, n80_addr, n80_iorq, n80_mreq, n80_wr)
begin
	if (CLK'event and CLK = '1') then
		if (n80_addr(6) = '0' and n80_iorq = '1' and n80_wr = '1') then txt_addr1 <= n80_do; end if;
		if (n80_addr(7) = '0' and n80_iorq = '1' and n80_wr = '1') then txt_addr2 <= n80_do; end if;
	end if;
end process;

IORD <= '1' when (n80_addr(2) = '0' and n80_iorq = '1' and n80_wr = '0') else '0';	-- После чтения IODATA
	
end architecture;