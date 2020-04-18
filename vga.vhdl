library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity vga is
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
end vga;


architecture arc of vga is

	signal Xpos,Ypos : integer range 0 to 1100:=0;
	
begin
	PROCESS (CLK) ---------------VGA OUTPUT
	BEGIN
		IF rising_edge(CLK) THEN
		
			IF (YPOS = 624) THEN
				VGA_FRAMESTART<='1';
			ELSE
				VGA_FRAMESTART<='0';
			END IF;
			
			--Set FRAMEEND
			IF(YPOS=600)THEN
				VGA_FRAMEEND<='1';
			ELSE
				VGA_FRAMEEND<='0';
			END IF;
		
			--XPOS, YPOS Counter
			IF(XPOS<1055)THEN
				XPOS<=XPOS+1;
			ELSE
				XPOS<=0;
				if (YPOS < 624) then
					YPOS <= YPOS+1;
				else
					YPOS <= 0;
				end if;
			END IF;
			
			--HSYNC Pulse
			IF(XPOS>816 AND XPOS<896)THEN
				VGAHS<='0';
			ELSE
				VGAHS<='1';
			END IF;
			
			--VSYNC Pulse
			IF(YPOS>601 AND YPOS<605)THEN
				VGAVS<='0';
			ELSE
				VGAVS<='1';
			END IF;
			
			--offset of 2
			--Set ACTVID
			IF (XPOS >= 1054 and (YPOS < 599 or YPOS = 624)) THEN
				ACTVID <= '1';
			--ELSIF(XPOS = 799 or YPOS > 599) THEN
			ELSIF(XPOS = 798 or YPOS > 599) THEN
				ACTVID <= '0';
			END IF;

			--Set RGB outputs depending on whether the video is active or not
			IF(XPOS<800 AND YPOS<600)THEN-----visible img  
				if (MODE = '1') then
					IF(XPOS = 799 or YPOS = 599 or XPOS = 0 or YPOS = 0)THEN
						B_OUT<=(others=>'1');
						G_OUT<=(others=>'1');
						R_OUT<=(others=>'1');
					ELSE
						B_OUT<=B_IN;
						R_OUT<=R_IN;
						G_OUT<=G_IN;
					END IF;	
				else
					B_OUT<=B_IN;
					R_OUT<=R_IN;
					G_OUT<=G_IN;
				end if;
			ELSE
				B_OUT<=(others=>'0');
				G_OUT<=(others=>'0');
				R_OUT<=(others=>'0'); 
			end if;
			
		END IF;
	END PROCESS;
	
	--offset by -1
--	X_POS <= XPOS - 1 when XPOS > 0 else 1055;
--	Y_POS <= YPOS when XPOS > 0 
--				else YPOS - 1 when YPOS > 0
--				else 624;
	
	--offset by 1
	X_POS <= XPOS + 1 when XPOS <1055 else 0;
	Y_POS <= YPOS when XPOS < 1055 
				else YPOS + 1 when YPOS < 624
				else 0;
	
--	X_POS <= XPOS;
--	Y_POS <= YPOS;
	
end arc;
