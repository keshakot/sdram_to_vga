library ieee;

use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.pcg.all;


entity sdram is

port(
	CLOCK_50: IN STD_LOGIC;
	SW: IN STD_LOGIC_VECTOR(9 downto 0);
	LEDR: OUT STD_LOGIC_VECTOR(9 downto 0);
	------------------SDRAM---------------------------
	DRAM_ADDR: OUT STD_LOGIC_VECTOR(12 downto 0);
	DRAM_BA: OUT STD_LOGIC_VECTOR(1 downto 0);
	DRAM_CAS_N: OUT STD_LOGIC;
	DRAM_CKE: OUT STD_LOGIC;
	DRAM_CLK: OUT STD_LOGIC;
	DRAM_CS_N: OUT STD_LOGIC;
	DRAM_DQ: INOUT STD_LOGIC_VECTOR(15 downto 0);
	DRAM_RAS_N: OUT STD_LOGIC;
	DRAM_WE_N: OUT STD_LOGIC;
	DRAM_LDQM,DRAM_UDQM: OUT STD_LOGIC;
	----------------VGA-Interface---------------------
	VGA_B,VGA_G,VGA_R : OUT STD_LOGIC_VECTOR(3 downto 0);
	VGA_CLK,VGA_HS,VGA_VS: OUT STD_LOGIC
);


end sdram;


architecture  main of sdram is
TYPE STAGES IS (ST0,ST1);
SIGNAL BUFF_CTRL: STAGES:=ST0;
------------------vga----------------------------------
signal NEXTFRAME: std_logic_vector(2 downto 0):="000";
signal FRAMEEND,FRAMESTART: std_logic:='0';
signal ACTVIDEO: std_logic:='0';
signal VGABEGIN: std_logic:='0';
signal RED,GREEN,BLUE: STD_LOGIC_VECTOR(3 downto 0);
---------------------------test signals----------------------------
signal counter : integer range 0 to 1000;
signal test: std_logic:='0';
signal testdata: std_logic_vector(7 downto 0):="00000000";
signal Xpos,Ypos: integer range 0 to 1100:=0;
signal Xpos_fill_sdram,Ypos_fill_sdram: integer range 0 to 800:=0;
------------------clock--------------------------------
SIGNAL CLK143,CLK143_2,CLK49_5: STD_LOGIC;
------------------sdram--------------------------------
SIGNAL SDRAM_ADDR: STD_LOGIC_VECTOR(24 downto 0);
SIGNAL SDRAM_BE_N: STD_LOGIC_VECTOR(1 downto 0);
SIGNAL SDRAM_CS: STD_LOGIC;
SIGNAL SDRAM_RDVAL,SDRAM_WAIT:STD_LOGIC;
SIGNAL SDRAM_RE_N,SDRAM_WE_N: STD_LOGIC;
SIGNAL SDRAM_READDATA,SDRAM_WRITEDATA: STD_LOGIC_VECTOR(15 downto 0);
SIGNAL DRAM_DQM : STD_LOGIC_VECTOR(1 downto 0);
-------------------------dual ram ----------------------------------
signal RAMIN1,RAMOUT2: std_logic_vector(15 downto 0);
signal RAMWE1: std_logic:='0';
signal RAMADDR1,RAMADDR2: integer range 0 to 511:=0;
---------------------------sync-----------------------------
signal BUFF_WAIT: std_logic:='0';
signal VGAFLAG: std_logic_vector(2 downto 0);
-------------------------ram/gray----------------------------
signal RAMFULL_POINTER:integer range 0 to 511:=0;
signal RAMRESTART_POINTER: integer range 0 to 511:=0;
signal RAMADDR1GR,RAMADDR2GR: std_logic_vector(8 downto 0):=(others=>'0');
signal RAMADDR1GR_sync0,RAMADDR1GR_sync1,RAMADDR1GR_sync2,RAMADDR1_bin: std_logic_vector(8 downto 0);
signal RAMADDR2GR_sync0,RAMADDR2GR_sync1,RAMADDR2GR_sync2,RAMADDR2_bin: std_logic_vector(8 downto 0);
SIGNAL RGB_REG : STD_LOGIC_VECTOR(11 downto 0);
--------------------------------------------------------
signal BUFFER_PREFILLED: std_logic := '0';

component ramsys is
        port (
            clk_clk             : in    std_logic                     := 'X';             -- clk
            reset_reset_n       : in    std_logic                     := 'X';             -- reset_n
            clk143_shift_clk    : out   std_logic;                                        -- clk
            clk143_clk          : out   std_logic;                                        -- clk
            clk49_5_clk         : out   std_logic;                                        -- clk
            wire_addr           : out   std_logic_vector(12 downto 0);                    -- addr
            wire_ba             : out   std_logic_vector(1 downto 0);                     -- ba
            wire_cas_n          : out   std_logic;                                        -- cas_n
            wire_cke            : out   std_logic;                                        -- cke
            wire_cs_n           : out   std_logic;                                        -- cs_n
            wire_dq             : inout std_logic_vector(15 downto 0) := (others => 'X'); -- dq
            wire_dqm            : out   std_logic_vector(1 downto 0);                     -- dqm
            wire_ras_n          : out   std_logic;                                        -- ras_n
            wire_we_n           : out   std_logic;                                        -- we_n
            sdram_address       : in    std_logic_vector(24 downto 0) := (others => 'X'); -- address
            sdram_byteenable_n  : in    std_logic_vector(1 downto 0)  := (others => 'X'); -- byteenable_n
            sdram_chipselect    : in    std_logic                     := 'X';             -- chipselect
            sdram_writedata     : in    std_logic_vector(15 downto 0) := (others => 'X'); -- writedata
            sdram_read_n        : in    std_logic                     := 'X';             -- read_n
            sdram_write_n       : in    std_logic                     := 'X';             -- write_n
            sdram_readdata      : out   std_logic_vector(15 downto 0);                    -- readdata
            sdram_readdatavalid : out   std_logic;                                        -- readdatavalid
            sdram_waitrequest   : out   std_logic                                         -- waitrequest
        );
    end component ramsys;

component vga is
	port(
		CLK: in std_logic;
		R_OUT,G_OUT,B_OUT: OUT std_logic_vector(3 downto 0);
		R_IN,G_IN,B_IN: IN std_logic_vector(3 downto 0);
		VGAHS, VGAVS:OUT std_logic;
		VGA_FRAMESTART: out std_logic;
		VGA_FRAMEEND: out std_logic;
		ACTVID:OUT STD_logic;
		X_POS, Y_POS: OUT integer range 0 to 1100;
		MODE: in std_logic
	);
end component vga;

component true_dual_port_ram_dual_clock is
	port 
	(
		clk_a	: in std_logic;
		clk_b	: in std_logic;
		addr_a	: in natural range 0 to 511;
		addr_b	: in natural range 0 to 511;
		data_a	: in std_logic_vector(15 downto 0);
		data_b	: in std_logic_vector(15 downto 0);
		we_a	: in std_logic := '1';
		we_b	: in std_logic := '1';
		q_a		: out std_logic_vector(15 downto 0);
		q_b		: out std_logic_vector(15 downto 0)
	);

end component true_dual_port_ram_dual_clock;

begin

	u0 : component ramsys
        port map (
            clk_clk             => CLOCK_50,             --          clk.clk
            reset_reset_n       => '1',       --        reset.reset_n
            clk143_shift_clk    => CLK143_2,    -- clk143_shift.clk
            clk143_clk          => CLK143,          --       clk143.clk
            clk49_5_clk         => CLK49_5,         --      clk49_5.clk
            wire_addr           => DRAM_ADDR,           --         wire.addr
            wire_ba             => DRAM_BA,             --             .ba
            wire_cas_n          => DRAM_CAS_N,          --             .cas_n
            wire_cke            => DRAM_CKE,            --             .cke
            wire_cs_n           => DRAM_CS_N,           --             .cs_n
            wire_dq             => DRAM_DQ,             --             .dq
            wire_dqm            => DRAM_DQM,            --             .dqm
            wire_ras_n          => DRAM_RAS_N,          --             .ras_n
            wire_we_n           => DRAM_WE_N,           --             .we_n
            sdram_address       => SDRAM_ADDR,       --        sdram.address
            sdram_byteenable_n  => SDRAM_BE_N,  --             .byteenable_n
            sdram_chipselect    => SDRAM_CS,    --             .chipselect
            sdram_writedata     => SDRAM_WRITEDATA,     --             .writedata
            sdram_read_n        => SDRAM_RE_N,        --             .read_n
            sdram_write_n       => SDRAM_WE_N,       --             .write_n
            sdram_readdata      => SDRAM_READDATA,      --             .readdata
            sdram_readdatavalid => SDRAM_RDVAL, --             .readdatavalid
            sdram_waitrequest   => SDRAM_WAIT    --             .waitrequest
        );
		  

		  
	u1 : component vga
        port map(
					 CLK=>CLK49_5,
					 R_OUT=>VGA_R,
					 G_OUT=>VGA_G,
					 B_OUT=>VGA_B,
					 R_IN=>RED,
					 G_IN=>GREEN,
					 B_IN=>BLUE,
					 VGAHS=>VGA_HS,
					 VGAVS=>VGA_VS,
					 ACTVID=>ACTVIDEO,
					 VGA_FRAMESTART=>FRAMESTART,
					 VGA_FRAMEEND=>FRAMEEND,
					 X_POS=>Xpos,
					 Y_POS=>Ypos,
					 MODE=>SW(0)
        );
		  

		  
	--dual clock FIFO implementation - 
	--		port A is written to from SDRAM @ 143MHz
	--		port B is read to the VGA port  @ 49.5MHz
	u3: component true_dual_port_ram_dual_clock
		port map  (
			clk_a=>CLK143,
         clk_b=>clk49_5,
         addr_a=>RAMADDR1,
         addr_b=>RAMADDR2,
         data_a=>RAMIN1,
         data_b=>(others=>'0'),
         we_a=>RAMWE1,
         we_b=>'0',
         q_a=>open,
         q_b=>RAMOUT2
		);	

DRAM_LDQM<=DRAM_DQM(0);
DRAM_UDQM<=DRAM_DQM(1);
DRAM_CLK<=CLK143_2;
SDRAM_CS<='1';
SDRAM_BE_N<="00";

BUFF_CTRL <= st1 when (SW(9)='1') else st0;

PROCESS (CLK143)
begin
if rising_edge(clk143)then

	RAMADDR1GR<=bin_to_gray_8(std_logic_vector(to_unsigned(RAMADDR1,9)));
	------------double flop sync----------------------
   RAMADDR2GR_sync0<=RAMADDR2GR;
   RAMADDR2GR_sync1<=RAMADDR2GR_sync0;
   RAMADDR2_bin<=gray_to_bin_8(RAMADDR2GR_sync1);

	case BUFF_CTRL is
		when st0=>------------write screen data to  SDRAM     
			if (SDRAM_WAIT='0')then	
				 SDRAM_WE_N<='0';
				 SDRAM_RE_N<='1';
				 
				 if (Xpos_fill_sdram < 799) then
					Xpos_fill_sdram <= Xpos_fill_sdram + 1;
				 else
					Xpos_fill_sdram <= 0;
					if (Ypos_fill_sdram < 599) then
						Ypos_fill_sdram <= Ypos_fill_sdram + 1;
					else
						Ypos_fill_sdram <= 0;
					end if;
				 end if;
				 
	--			 if(Ypos_fill_sdram < 300) then
	--				SDRAM_WRITEDATA <= "0000" & "111100000000";
	--			 else
	--				SDRAM_WRITEDATA <= "0000" & "000000001111";
	--			 end if;	
				 
				 --if (Xpos_fill_sdram = 0 or Xpos_fill_sdram = 799 or Ypos_fill_sdram = 0 or Ypos_fill_sdram = 599) then
--				 if (Xpos_fill_sdram = 0 and Ypos_fill_sdram = 0)  
--					  or (Xpos_fill_sdram = 0 and Ypos_fill_sdram = 1)
--					  or (Xpos_fill_sdram = 0 and Ypos_fill_sdram = 2)
--					  or (Xpos_fill_sdram = 0 and Ypos_fill_sdram = 3)
--					  or (Xpos_fill_sdram = 0 and Ypos_fill_sdram = 4)
--					  or (Xpos_fill_sdram = 0 and Ypos_fill_sdram = 5) then
--					SDRAM_WRITEDATA <= "0000" & "000000001111";
				 if (SW(1) = '1' and Xpos_fill_sdram = 0) then
					SDRAM_WRITEDATA <= "0000" & "111100000000";
				 elsif (SW(2) = '1' and Xpos_fill_sdram = 799) then
					SDRAM_WRITEDATA <= "0000" & "111100000000";
				 elsif (SW(3) = '1' and Ypos_fill_sdram = 0) then
					SDRAM_WRITEDATA <= "0000" & "111100000000";
				 elsif (SW(4) = '1' and Ypos_fill_sdram = 599) then
					SDRAM_WRITEDATA <= "0000" & "111100000000";
				 elsif (SW(5) = '1' and Xpos_fill_sdram = 1) then
					SDRAM_WRITEDATA <= "0000" & "111100000000";
				 else
					SDRAM_WRITEDATA <= "0000" & "000000000000";
				 end if;
				 
				 SDRAM_ADDR<=std_logic_vector(to_unsigned(Xpos_fill_sdram+Ypos_fill_sdram*800, SDRAM_ADDR'length));
			end if;	
		when st1=>-----------write from SDRAM to BUFFER
		      --Set bits to read from SDRAM
				SDRAM_WE_N <= '1';
				SDRAM_RE_N <= '0';
				--enable write to FIFO when SDRAM data valid
				RAMWE1 <= SDRAM_RDVAL;
				
				--prefill the buffer with pixels 0-511
				if (FRAMESTART = '1' and BUFFER_PREFILLED = '0') then
					if(to_integer(unsigned(SDRAM_ADDR)) < 512) then
						RAMADDR1 <= to_integer(unsigned(SDRAM_ADDR));
						if(SDRAM_WAIT = '0' and SDRAM_RDVAL = '1') then
							RAMIN1 <= SDRAM_READDATA;
							SDRAM_ADDR<=std_logic_vector(unsigned(SDRAM_ADDR) + 1);
--							if (RAMADDR1 < 511) then
--								RAMADDR1 <= RAMADDR1 + 1;
--							else
--								RAMADDR1 <= 0;
--							end if;
						end if;
					else
						RAMADDR1 <= 0;
						BUFFER_PREFILLED <= '1';
						RAMRESTART_POINTER <= 64;
						RAMFULL_POINTER <= 0;
					end if;
				--if the video is active, fill the buffer in increments of 64 until write address is 10 less than the read address
				elsif (ACTVIDEO = '1') then
					if(to_integer(unsigned(RAMADDR2_bin)) = RAMRESTART_POINTER) then
						RAMFULL_POINTER <= RAMRESTART_POINTER;
						RAMRESTART_POINTER <= (RAMFULL_POINTER + 64) mod 512;
					end if;
					
					if (RAMADDR1 /= RAMFULL_POINTER) then
						if(SDRAM_WAIT = '0' and SDRAM_RDVAL = '1') then
							RAMIN1 <= SDRAM_READDATA;
							RAMADDR1 <= (RAMADDR1 + 1) mod 512;
							SDRAM_ADDR<=std_logic_vector(unsigned(SDRAM_ADDR) + 1);
						end if;
					end if;
				--when the frame ends, reset the sdram_address to 0 (the first pixel)
				elsif (FRAMEEND = '1') then
					SDRAM_RE_N <= '1';
					SDRAM_ADDR <= (others=>'0');
					RAMADDR1 <= 0;
					BUFFER_PREFILLED <= '0';
				end if;
				
		when others=>NULL;
		END CASE;

end if;
end process;

--read image date from the FIFO
--		if in the display area, read the data from the FIFO as (Xpos*Ypos) mod 512
--		if in the blaking interval, pull down RGB signals
process(CLK49_5) begin
	if rising_edge(CLK49_5) then
	
	RAMADDR2GR<=bin_to_gray_8(std_logic_vector(to_unsigned(RAMADDR2,9)));
	RAMADDR1_bin<=gray_to_bin_8(RAMADDR1GR_sync1);
	-------------dual clock sync-------------------------
	RAMADDR1GR_sync0<=RAMADDR1GR;
	RAMADDR1GR_sync1<=RAMADDR1GR_sync0;
	VGAFLAG(1)<=VGAFLAG(0);
	VGAFLAG(2)<=VGAFLAG(1);

	if (FRAMEEND = '1') then
		RAMADDR2 <= 0;
	end if;
	
		if(ACTVIDEO = '1') then
			RAMADDR2<=(Xpos+Ypos*800) mod 512;
			
			if(Xpos = 0 and Ypos = 0) or (Xpos = 0 and Ypos = 599) 
				or (Xpos = 799 and Ypos = 0) or (Xpos = 799 and Ypos = 599) then
				RED<=(others=>'1');
				GREEN<=(others=>'1');
				BLUE<=(others=>'1');
			else
				RED<=RAMOUT2(11 downto 8);
				GREEN<=RAMOUT2(7 downto 4);
				BLUE<=RAMOUT2(3 downto 0);	
			end if;
		
--			RED<=RAMOUT2(11 downto 8);
--			GREEN<=RAMOUT2(7 downto 4);
--			BLUE<=RAMOUT2(3 downto 0);		
		else
			RED<=(others=>'0');
			GREEN<=(others=>'1');
			BLUE<=(others=>'0');		
		end if;
	end if;
end process;

end main;

