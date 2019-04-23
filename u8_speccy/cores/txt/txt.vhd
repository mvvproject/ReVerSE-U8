-------------------------------------------------------------------[24.02.2014]
-- VGA Text
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use IEEE.STD_LOGIC_ARITH.all;

entity txt is
	port (
		CLK			: in std_logic; 						-- VGA dot clock 25MHz
		CLKEN		: in std_logic;
		CHAR_DI		: in std_logic_vector(15 downto 0);
		FONT_DI		: in std_logic_vector(7 downto 0);
		CHAR_ADDR	: out std_logic_vector(11 downto 0);
		FONT_ADDR	: out std_logic_vector(11 downto 0);
		RGB			: out std_logic_vector(5 downto 0); 	-- color RR:GG:BB
		HS			: out std_logic;						-- horizontal (line) sync
		VS			: out std_logic 						-- vertical (frame) sync
	);
end entity;

architecture rtl of txt is
	-- Horizontal timing (line)
	constant h_visible_area		: integer := 640;
	constant h_front_porch		: integer := 16;
	constant h_sync_pulse		: integer := 96;
	constant h_back_porch		: integer := 48;
	constant h_whole_line		: integer := 800;
	-- Vertical timing (frame)	
	constant v_visible_area		: integer := 480;
	constant v_front_porch		: integer := 10;
	constant v_sync_pulse		: integer := 2;
	constant v_back_porch		: integer := 33;
	constant v_whole_frame		: integer := 525;
	-- Horizontal Timing constants  
	constant h_pixels_across	: integer := h_visible_area - 1;
	constant h_sync_on			: integer := h_visible_area + h_front_porch - 1;
	constant h_sync_off			: integer := h_visible_area + h_front_porch + h_sync_pulse - 2;
	constant h_end_count		: integer := h_whole_line - 1;
	-- Vertical Timing constants
	constant v_pixels_down		: integer := v_visible_area - 1;
	constant v_sync_on			: integer := v_visible_area + v_front_porch - 1;
	constant v_sync_off			: integer := v_visible_area + v_front_porch + v_sync_pulse - 2;
	constant v_end_count		: integer := v_whole_frame - 1;

	signal h_count_reg			: std_logic_vector(9 downto 0) := "0000000000"; 	-- horizontal pixel counter
	signal v_count_reg			: std_logic_vector(9 downto 0) := "0000000000"; 	-- vertical line counter
	signal h_count				: std_logic_vector(9 downto 0) := "0000000000";
	signal v_count				: std_logic_vector(9 downto 0) := "0000000000";
	signal h_sync				: std_logic;
	signal v_sync				: std_logic;
	signal pixel				: std_logic;
	signal blank				: std_logic;
	signal color				: std_logic_vector(7 downto 0);
	signal rgb_temp				: std_logic_vector(5 downto 0);
	
begin
		
	process (CLK, FONT_DI, h_count_reg)
	begin
		if (CLK'event and CLK = '1') then
			if (CLKEN = '1') then
				HS 			<= h_sync;
				RGB			<= rgb_temp;
				h_count_reg	<= h_count;
				if (h_count_reg = h_sync_on) then
					VS			<= v_sync;
					v_count_reg	<= v_count;
				end if;
			end if;
		end if;		 
		case h_count_reg(2 downto 0) is
			when "000" => pixel <= FONT_DI(7);
			when "001" => pixel <= FONT_DI(6);
			when "010" => pixel <= FONT_DI(5);
			when "011" => pixel <= FONT_DI(4);
			when "100" => pixel <= FONT_DI(3);
			when "101" => pixel <= FONT_DI(2);
			when "110" => pixel <= FONT_DI(1);
			when "111" => pixel <= FONT_DI(0);
			when  others => null;
		end case;
	end process;

	h_count		<=	(others => '0') when (h_count_reg = h_end_count) else h_count_reg + 1;
	v_count		<=	(others => '0') when (v_count_reg = v_end_count) else v_count_reg + 1;
	h_sync		<=	'1' when (h_count_reg < h_sync_on) or (h_count_reg > h_sync_off) else '0';
	v_sync		<=	'1' when (v_count_reg < v_sync_on) or (v_count_reg > v_sync_off) else '0';
	color		<=	CHAR_DI(15 downto 8);
	blank		<=	'1' when (h_count_reg > h_pixels_across) or (v_count > v_pixels_down) else '0';
	rgb_temp	<=	(others => '0') when blank = '1' else
					color(4) & (color(4) and color(6)) & color(5) & (color(5) and color(6)) & color(3) & (color(3) and color(6)) when pixel = '0' else	-- Paper
					color(1) & (color(1) and color(6)) & color(2) & (color(2) and color(6)) & color(0) & (color(0) and color(6));						-- Ink
	CHAR_ADDR	<=	v_count(8 downto 4) * conv_std_logic_vector(80,7) + h_count(9 downto 3);
	FONT_ADDR	<=	CHAR_DI(7 downto 0) & v_count(3 downto 0);

end architecture;