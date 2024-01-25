-- cpu.vhd: Simple 8-bit CPU (BrainFuck interpreter)
-- Copyright (C) 2023 Brno University of Technology,
--                    Faculty of Information Technology
-- Author(s): Vaclav Berny <xberny00 AT stud.fit.vutbr.cz>
--
library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

-- ----------------------------------------------------------------------------
--                        Entity declaration
-- ----------------------------------------------------------------------------
entity cpu is
 port (
   CLK   : in std_logic;  -- hodinovy signal
   RESET : in std_logic;  -- asynchronni reset procesoru
   EN    : in std_logic;  -- povoleni cinnosti procesoru
 
   -- synchronni pamet RAM
   DATA_ADDR  : out std_logic_vector(12 downto 0); -- adresa do pameti
   DATA_WDATA : out std_logic_vector(7 downto 0); -- mem[DATA_ADDR] <- DATA_WDATA pokud DATA_EN='1'
   DATA_RDATA : in std_logic_vector(7 downto 0);  -- DATA_RDATA <- ram[DATA_ADDR] pokud DATA_EN='1'
   DATA_RDWR  : out std_logic;                    -- cteni (0) / zapis (1)
   DATA_EN    : out std_logic;                    -- povoleni cinnosti
   
   -- vstupni port
   IN_DATA   : in std_logic_vector(7 downto 0);   -- IN_DATA <- stav klavesnice pokud IN_VLD='1' a IN_REQ='1'
   IN_VLD    : in std_logic;                      -- data platna
   IN_REQ    : out std_logic;                     -- pozadavek na vstup data
   
   -- vystupni port
   OUT_DATA : out  std_logic_vector(7 downto 0);  -- zapisovana data
   OUT_BUSY : in std_logic;                       -- LCD je zaneprazdnen (1), nelze zapisovat
   OUT_WE   : out std_logic;                      -- LCD <- OUT_DATA pokud OUT_WE='1' a OUT_BUSY='0'

   -- stavove signaly
   READY    : out std_logic;                      -- hodnota 1 znamena, ze byl procesor inicializovan a zacina vykonavat program
   DONE     : out std_logic                       -- hodnota 1 znamena, ze procesor ukoncil vykonavani programu (narazil na instrukci halt)
 );
end cpu;


-- ----------------------------------------------------------------------------
--                      Architecture declaration
-- ----------------------------------------------------------------------------
architecture behavioral of cpu is
-- PC
	signal pc 	  : std_logic_vector(12 downto 0);
	signal pc_inc : std_logic;
	signal pc_dec : std_logic;
-- PC

-- PTR
	signal pointer		: std_logic_vector(12 downto 0);
	signal pointer_inc	: std_logic;
	signal pointer_dec	: std_logic;
	signal pointer_rst	: std_logic;
-- PTR

-- states
	type fsm_states is (
		start,
		prefetch,
		fetch,
		fetch_2,
		fetch_3,
		find_ptr,
		find_ptr2,
		find_ptr3,
		mx1_sel,
		decode,
		ptr_inc,	-- >
		ptr_dec,	-- <
		value_inc,	-- +
		value_inc_2,
		value_inc_3,
		value_inc_4,
		value_dec,	-- -
		value_dec_2,
		value_dec_3,
		value_dec_4,
		jz,			-- [ jump if zero
		jnz,		-- ] jump if not zero
		break,		-- ~
		print,		-- .
		print_2,
		print_3,
		print_4,
		load,		-- ,
		load_2,
		load_3,
		load_4,
		rtrn		-- @
	);
	signal current_state : fsm_states := start;
	signal next_state	 : fsm_states := start;
-- states

-- MX1
	signal MX1_out		: std_logic_vector(12 downto 0) := (others => '0');
	signal MX1_select 	: std_logic_vector(1  downto 0) := (others => '0');
-- MX1


-- MX2
	signal MX2_out		: std_logic_vector(7  downto 0) := (others => '0');
	signal MX2_select	: std_logic_vector(1  downto 0) := (others => '0');
-- MX2


 -- pri tvorbe kodu reflektujte rady ze cviceni INP, zejmena mejte na pameti, ze 
 --   - nelze z vice procesu ovladat stejny signal,
 --   - je vhodne mit jeden proces pro popis jedne hardwarove komponenty, protoze pak
 --      - u synchronnich komponent obsahuje sensitivity list pouze CLK a RESET a 
 --      - u kombinacnich komponent obsahuje sensitivity list vsechny ctene signaly. 

begin
	pc_p: process(CLK, RESET, pc_inc, pc_dec) is
	begin
		if RESET = '1' then pc <= (others => '0');
		elsif rising_edge(CLK) then
			if pc_inc = '1' 
				then pc <= pc + 1;
			elsif pc_dec = '1'
				then pc <= pc - 1;
			end if;
		end if;
	end process;
 
	pointer_p: process(CLK, RESET, pointer_inc, pointer_dec, pointer_rst) is
	begin
		if RESET = '1' then pointer <= (others => '0');
		elsif rising_edge(CLK) then
			if pointer_inc = '1' then
				pointer <= pointer + 1;
			elsif pointer_dec = '1' then
				pointer <= pointer - 1;
			elsif pointer_rst = '1' then
				pointer <= (others => '0');
			end if;
		end if;	
	end process;
	

	MX1_p: process(CLK, RESET, MX1_select, pc, pointer) is
	begin
		if RESET = '1' then MX1_out <= (others => '0');
		elsif rising_edge(CLK) then
			case MX1_select is
				when "10" =>
					MX1_out <= pointer;
				when "01" =>
					MX1_out <= pc; 
				when others =>
					MX1_out <= (others => '0');
			end case;
		end if;
	end process;
	DATA_ADDR <= MX1_out;

	MX2_p: process(CLK, RESET, MX2_select) is
	begin
		if RESET = '1' then MX2_out <= (others => '0');
		elsif rising_edge(CLK) then
			case MX2_select is
				when "00" =>
					MX2_out <= IN_DATA;
				when "01" =>
					MX2_out <= DATA_RDATA + 1;
				when "10" =>
					MX2_out <= DATA_RDATA - 1;
				when others =>
					MX2_out <= (others => '0');
			end case;
		end if;
	end process;
	DATA_WDATA <= MX2_out;
	OUT_DATA <= DATA_RDATA;
-- FSM
	state_log: process(CLK, RESET, EN) is
	begin
		if RESET = '1' then 
			current_state <= start;
		elsif rising_edge(CLK) then
			if EN = '1' then
				current_state <= next_state;
			end if;
		end if;
	end process;


	fsm: process(current_state, OUT_BUSY, EN) is
	begin
-- init
		pc_inc <= '0';
		pc_dec <= '0';
		pointer_inc <= '0';
		pointer_dec <= '0';
		pointer_rst <= '0';
		DATA_EN <= '1';
		DATA_RDWR <= '0';
		OUT_WE <= '0';
-- init

		case current_state is
			when start =>
				DONE <= '0';
				READY <= '0';
				DATA_RDWR <= '0';
				next_state <= find_ptr;
				IN_REQ <= '0';
-- fetch with some delay
			when fetch =>
				MX1_select <= "01";
				next_state <= fetch_2;
			when fetch_2 =>
				next_state <= fetch_3;
			when fetch_3 =>
				next_state <= decode;
-- fetch with some delay


-- get initial pointer value
			when find_ptr =>
				case DATA_RDATA is
					when X"40" =>
						READY <= '1';
						next_state <= fetch;
					when others =>
						next_state <= find_ptr2;
				end case;
			when find_ptr2 =>
				pointer_inc <= '1';
				next_state <= find_ptr3;
			when find_ptr3 => 
				MX1_select <= "10";
				next_state <= find_ptr;
-- get initial pointer value

			when decode =>
				case DATA_RDATA is
					when X"3E" =>
						next_state <= ptr_inc;
					when X"3C" =>
						next_state <= ptr_dec;
					when X"2B" => 
						next_state <= value_inc;
					when X"2D" =>
						next_state <= value_dec;
					when X"2E" =>
						next_state <= print;
					when X"2C" =>
						next_state <= load;
					when X"40" =>
						next_state <= rtrn;
					when others =>
						pc_inc <= '1';
						next_state <= fetch;
				end case;

--increment value
			when value_inc =>
				MX1_select <= "10";
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				next_state <= value_inc_2;
			when value_inc_2 =>
				next_state <= value_inc_3;
			when value_inc_3 => 
				MX2_select <= "01";
				next_state <= value_inc_4;
			when value_inc_4 =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				pc_inc <= '1';
				next_state <= fetch;
--increment value

--decrement value
			when value_dec =>
				MX1_select <= "10";
				DATA_EN <= '1';
				DATA_RDWR <= '0';
				next_state <= value_dec_2;
			when value_dec_2 =>
				next_state <= value_dec_3;
			when value_dec_3 =>
				MX2_select <= "10";
				next_state <= value_dec_4;
			when value_dec_4 =>
				DATA_EN <= '1';
				DATA_RDWR <= '1';
				pc_inc <= '1';
				next_state <= fetch;
--decrement value

--move
			when ptr_inc =>
				pointer_inc <= '1';
				pc_inc <= '1';
				next_state <= fetch;
			when ptr_dec =>
				pointer_dec <= '1';
				pc_inc <= '1';
				next_state <= fetch;
-- move

-- print
			when print =>
				MX1_select <= "10";
				next_state <= print_2;
			when print_2 =>
				next_state <= print_3;
			when print_3 =>
				MX1_select <= "10";
				next_state <= print_4;
			when print_4 =>
				next_state <= print_2;
				if OUT_BUSY = '0' then	
					OUT_WE <= '1';
					pc_inc <= '1';
					DATA_RDWR <= '0';
					next_state <= fetch;
				else
					next_state <= print_3;
				end if;
-- print

-- load
			when load =>
				MX1_select <= "10";
				IN_REQ <= '1';
				MX2_select <= "00";
				next_state <= load_2;

			when load_2 =>
				if IN_VLD /= '1' then
					IN_REQ <= '1';
					next_state <= load_3;
				else
					DATA_RDWR <= '1';
					pc_inc <= '1';
					IN_REQ <= '1';
					next_state <= load_4;
				end if;
			when load_3 =>
				IN_REQ <= '1';
				next_state <= load_2;
			when load_4 =>
				DATA_RDWR <= '0';
				IN_REQ <= '0';
				next_state <= fetch;
-- load
			when rtrn => 
				DONE <= '1';
			when others =>
				null;
		end case;		
				
	end process;
-- FSM
end behavioral;

