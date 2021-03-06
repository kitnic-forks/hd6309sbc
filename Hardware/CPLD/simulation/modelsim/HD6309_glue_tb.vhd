
-------------------------------------------------------------
--
-- Program : HD6309 Glue Logic Testbench
--
-------------------------------------------------------------

---import std_logic from the IEEE library
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;
USE ieee.std_logic_unsigned.all;
USE ieee.numeric_std.ALL;

--declare entity: no inputs, no outputs
entity HD6309_glue_tb is
end HD6309_glue_tb;

architecture behavior of HD6309_glue_tb is
   --pass glue logic entity to the testbench as component
  component HD6309_glue_top is
	port ( 
		XOSC : in std_logic;			-- Oscillator input for CPU (nominally 24 MHz)
		WOSC : in std_logic;			-- Oscillator input for ACLK/BCLK (nominally 14.745 MHz)

		QCLK : out std_logic;		-- Q phase clock output (nom 2.5 MHz, XOSC divided by 8)
		ECLK : out std_logic;		-- E phase clock output (nom 2.5 MHz, XOSC divided by 8)
		BCLK : out std_logic;		-- SCC ch B baudrate (WOSC/48 for 19.2kbps at connector)
		ACLK : out std_logic;		-- SCC ch A baudrate (WOSC/8 for 115.2kbps at USB bridge)
		
		RESET : in std_logic;		-- active low RESET input
		
		ADDR : in std_logic_vector (15 downto 4);  -- A[15:] from CPU
		RW : in std_logic;			-- H = RD, L = WR input from CPU
		DATA : inout std_logic_vector (7 downto 0); -- D[7:0] from CPU
		LIC : in std_logic;			-- Instruction Decode flag from CPU		
		
		ROMCS : out std_logic;		-- active low EPROM chip select
		RAM1CS : out std_logic;		-- active low SRAM #1 chip select
		RAM2CS : out std_logic;		-- active low SRAM #1 chip select		
		CIOCS : out std_logic;		-- active low CIO chip select
		RTCCS : out std_logic;		-- active low RTC chip select
		SCCCS : out std_logic;		-- active low SCC chip select
		RD : out std_logic;			-- E-qualified active low RD signal e.g. SRAM, ROM
		WR : out std_logic;			-- E-qualified active low WR signal 
		ZRD : out std_logic;			-- active low RD signal for CIO and SCC
		ZWR : out std_logic;			-- active low WR signal for CIO and SCC
		
		ROMP27 : OUT std_logic; -- E(E)PROM pin 27
		
		TP11 : out std_logic;		-- PCB testpoint TP11
		TP12 : out std_logic;		-- PCB testpoint TP12
		TP13 : out std_logic;  -- PCB testpoint TP13
		TP14 : out std_logic;		-- PCB testpoint TP14
		
		CONF : in std_logic;			-- configuration option (pulled high)
		SPARE : out std_logic;		-- decode of 0x280...0x2FF (unused I/O space)
		PBTN : in std_logic;			-- input from pushbutton (to be routed to input port)
		
		LED : out std_logic_vector (2 downto 0);	-- LED outputs (H = ON)
		
		SDCK : out std_logic;		-- SD card clock output
		SDDO : out std_logic;		-- SD card data output (from CPU)
		SDCS : out std_logic;		-- SD card chip select
		SDDI : in std_logic;			-- SD card data intput (to CPU)
		SDSW : in std_logic			-- SD card present switch (L = present)
	);
  end component;

 	signal ROMCS, CIOCS, RTCCS: std_logic;
	signal RESET, RW, ROMSEL, PBTN : std_logic;
	signal ECLK, QCLK, ACLK, BCLK : std_logic;
	signal XOSC, WOSC, SCCCS, RD, WR : std_logic;
	signal ADDR : std_logic_vector (15 downto 0);
	signal DATA : std_logic_vector (7 downto 0);
	signal RAM1CS, RAM2CS : std_logic;
	signal ZRD, ZWR : std_logic;
	signal ROMP27, TP11, TP12, TP13, TP14 : std_logic;
	signal ALLADDR : std_logic_vector (15 downto 0);
	signal SDDO, SDCS, SDCK : std_logic;

	constant Tpw_xosc : time := 21 ns;
	constant Tpw_wosc : time := 34 ns;	
  constant Tpw_pbtn : time := 1700 ns;
	
begin	
	-- instantiate the unit and map signals to ports
	uut : HD6309_glue_top port map(
    XOSC => XOSC,
    WOSC => WOSC,
    QCLK => QCLK,
    ECLK => ECLK,
    BCLK => BCLK,
    ACLK => ACLK,
		RESET => RESET,
		ADDR => ADDR(15 downto 4),
		RW => RW,
		LIC => '0',
		DATA => DATA,
		ROMCS => ROMCS,
		RAM1CS => RAM1CS,
		RAM2CS => RAM2CS,		
		CIOCS => CIOCS,
		RTCCS => RTCCS,		
		SCCCS => SCCCS,
		ROMP27 => ROMP27,
		TP11 => TP11,
		TP12 => TP12,
		TP13 => TP13,
		TP14 => TP14,
		CONF => '1',
		SPARE => open,
		PBTN => PBTN,
		LED => open,
		SDDI => WOSC,
		SDSW => PBTN,
		SDCK => SDCK,
		SDDO => SDDO,
		SDCS => SDCS,
		RD => RD,
		WR => WR,
		ZRD => ZRD,
		ZWR => ZWR
	);
	
	-- make a 24 MHz clock
	xosc_gen : process is
	  begin
	    XOSC <= '0' after Tpw_xosc, '1' after 2 * Tpw_xosc;
	    wait for 2*Tpw_xosc;
	end process xosc_gen;
	
	-- make a 14.7 MHz clock
	wosc_gen : process is
	  begin
	    WOSC <= '0' after Tpw_wosc, '1' after 2 * Tpw_wosc;
	    wait for 2*Tpw_wosc;
	end process wosc_gen;
	
	-- make a 500kHz clock on PB
	pb_gen : process is
	   begin
	     PBTN <='0' after Tpw_pbtn, '1' after 2 * Tpw_pbtn;
	     wait for 2*Tpw_pbtn;
	end process pb_gen;
	
  stim : process is
		  
	procedure internal_cyc is 
	  begin
        wait until ECLK'event and ECLK='0';
        ALLADDR(15 downto 0) <= "1111111111111111";   -- an internal cycle
       		  
        wait until QCLK'event and QCLK='1';
    		  ADDR(15 downto 0) <= ALLADDR(15 downto 0);
        RW <= '1';
        DATA <= "ZZZZZZZZ";
	end procedure internal_cyc;
	
	procedure write_cyc(waddress: in std_logic_vector(15 downto 0);
	                       wdata : in std_logic_vector(7 downto 0)) is
	   begin
        wait until ECLK'event and ECLK='0';
			  ALLADDR <= waddress;        
			          
        wait until QCLK'event and QCLK='1';
			  ADDR(15 downto 0) <= ALLADDR(15 downto 0);
        RW <= '0';
        DATA <= wdata;
  end procedure write_cyc;
  
	procedure read_cyc(raddress: in std_logic_vector(15 downto 0)) is
	   begin
        wait until ECLK'event and ECLK='0';
			  ALLADDR <= raddress;        
			          
        wait until QCLK'event and QCLK='1';
			  ADDR(15 downto 0) <= ALLADDR(15 downto 0);
        RW <= '1';
  end procedure read_cyc;

  begin
		  
      RESET <= '0';
  		  ADDR <= "1111111111111111";
  		  RW <= '1';
		  wait for 500 ns;
		  
		  RESET <= '1';
		  wait for 10 ns;

  -- test each bigpage (x0000, x1000, x2000, etc.)
		  
--			for address in 0 to 15 loop
--	      
--	      internal_cyc;
--	      internal_cyc;
--	      read_cyc(std_logic_vector(to_unsigned(address, 4)) & "000000000000");
--	      internal_cyc;
--	      internal_cyc;
--	      write_cyc(std_logic_vector(to_unsigned(address, 4)) & "000000000000", "11001010");
--	      internal_cyc;
--	      read_cyc(std_logic_vector(to_unsigned(address, 4)) & "000000000000");
--
--      end loop;        
   
   -- now test IO pages (0xE000, 0xE010, 0xE020...)
      
--      for address in 0 to 15 loop
--        
--        internal_cyc;
--        internal_cyc;
--        read_cyc(x"E0" & std_logic_vector(to_unsigned(address, 4)) & x"0");
--        internal_cyc;
--        internal_cyc;
--        write_cyc(x"E0" & std_logic_vector(to_unsigned(address, 4)) & x"0","00001111");
--        
--			end loop;
			
	-- now test banked RAM

--      internal_cyc;
--
--      -- test SET ROMSEL, ROMSEH
--      write_cyc(x"E040",x"0E");
--   
--      internal_cyc;
--      read_cyc(x"DB00");
--      internal_cyc;
--      write_cyc(x"DB00",x"11");
--      internal_cyc;
--      read_cyc(x"E800");
--      internal_cyc;
--      write_cyc(x"E800",x"11");      
--      internal_cyc;
--
--      -- test CLEAR ROMSEL
--      write_cyc(x"E040",x"0C");
--   
--      internal_cyc;
--      read_cyc(x"DB00");
--      internal_cyc;
--      write_cyc(x"DB00",x"10");
--      internal_cyc;
--      read_cyc(x"E800");
--      internal_cyc;
--      write_cyc(x"E800",x"10");      
--      internal_cyc;
--
--      -- test CLEAR ROMSEH
--      write_cyc(x"E040",x"0A");
--   
--      internal_cyc;
--      read_cyc(x"DB00");
--      internal_cyc;
--      write_cyc(x"DB00",x"01");
--      internal_cyc;
--      read_cyc(x"E800");
--      internal_cyc;
--      write_cyc(x"E800",x"01");      
--      internal_cyc;
--
--      -- test CLEAR ROMSEH, ROMSEL
--      write_cyc(x"E040",x"08");
--   
--      internal_cyc;
--      read_cyc(x"DB00");
--      internal_cyc;
--      write_cyc(x"DB00",x"00");
--      internal_cyc;
--      read_cyc(x"E800");
--      internal_cyc;
--      write_cyc(x"E800",x"00");      
--      internal_cyc;
      
  -- now test Pseudo Random generator
  
    for address in 1 to 257 loop
      read_cyc(x"E060");
      internal_cyc;
    end loop;
			
		wait;
  end process stim;
	
end architecture;

