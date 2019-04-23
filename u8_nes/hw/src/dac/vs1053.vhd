-------------------------------------------------------------------[04.10.2013]
-- VS1053 SPI Controller
-------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity stream is
port (
	-- CPU Interface Signals
	CLK			: in std_logic;
	CN			: in std_logic_vector(31 downto 0);
	-- VS1053 Interface Signals
	DREQ		: in std_logic;
	SO			: in std_logic;
	SI			: out std_logic;
	SCLK		: out std_logic;
	XDCS		: out std_logic;
	XCS			: out std_logic);
end;

architecture rtl of stream is

	signal state           	: std_logic := '0';
	signal shift_reg       	: std_logic_vector(31 downto 0) := X"00000000";	-- Shift register
	signal bit_cnt          : std_logic_vector(4 downto 0) := "00000";		-- Number of bits transfered  
	signal addr				: std_logic_vector(3 downto 0) := X"1"; 

begin

process (CLK)
begin
	if CLK'event and CLK = '1' then
		case state is
			when '0' =>
				if DREQ = '1' then					
					state <= '1';
					XCS   <= '0';
					XDCS  <= '0';
					case addr is
						when X"0" => shift_reg <= X"02004804";	-- WriteData|MODE|SM_LINE1=LINE1 & SM_SDINEW=yes & SM_RESET=reset
							XDCS <= '1';
						when X"1" => shift_reg <= X"52494646";	-- PCM RIFF Header
						when X"2" => shift_reg <= X"FFFFFFFF";
						when X"3" => shift_reg <= X"57415645";
						when X"4" => shift_reg <= X"666D7420";
						when X"5" => shift_reg <= X"10000000";
						when X"6" => shift_reg <= X"01000200";
						when X"7" => shift_reg <= X"80BB0000";
						when X"8" => shift_reg <= X"00EE0200";
						when X"9" => shift_reg <= X"04001000";
						when X"A" => shift_reg <= X"64617461";
						when X"B" => shift_reg <= X"FFFFFFFF";
						when others => null;
					end case;
				end if;
			when '1' =>
				bit_cnt <= bit_cnt + 1;
				shift_reg <= shift_reg(30 downto 0) & '0';
				if bit_cnt = "11111" then
					bit_cnt <= (others => '0');
					if addr = X"C" then
						shift_reg <= CN;
					else
						addr <= addr + 1;											
						state <= '0';				
					end if;
				end if;
			when others => null;
		end case;
	end if;
end process;

SCLK 	<= not CLK when state = '1' else '0';
SI 		<= shift_reg(31);

end rtl;