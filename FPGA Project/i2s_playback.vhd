--------------------------------------------------------------------------------
--
--   filename:         i2s_playback.vhd
--   dependencies:     i2s_transceiver.vhd, clk_wiz_0 (pll)
--   design software:  vivado v2017.2
--
--   hdl code is provided "as is."  digi-key expressly disclaims any
--   warranty of any kind, whether express or implied, including but not
--   limited to, the implied warranties of merchantability, fitness for a
--   particular purpose, or non-infringement. in no event shall digi-key
--   be liable for any incidental, special, indirect or consequential
--   damages, lost profits or lost data, harm to your equipment, cost of
--   procurement of substitute goods, technology or services, any claims
--   by third parties (including but not limited to any defense thereof),
--   any claims for indemnity or contribution, or other similar costs.
--
--   version history
--   version 1.0 04/19/2019 scott larson
--     initial public release
-- 
--------------------------------------------------------------------------------

library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity i2s_playback is
    generic(
        d_width     :  integer := 24);                    --data width
    port(
        clk         :  in  std_logic;                     --system clock (12 mhz)
        mclk        :  out std_logic_vector(1 downto 0);  --master clock
        sclk        :  out std_logic_vector(1 downto 0);  --serial clock (or bit clock)
        ws          :  out std_logic_vector(1 downto 0);  --word select (or left-right clock)
        sd_rx       :  in  std_logic;                     --serial data in
        sd_tx       :  out std_logic);                    --serial data out
end i2s_playback;

architecture logic of i2s_playback is
    signal clkfb        :  std_logic;
    signal master_clk   :  std_logic;                             --internal master clock signal
    signal serial_clk   :  std_logic := '0';                      --internal serial clock signal
    signal word_select  :  std_logic := '0';                      --internal word select signal
    signal l_data_rx    :  std_logic_vector(d_width-1 downto 0);  --left channel data received from i2s transceiver component
    signal r_data_rx    :  std_logic_vector(d_width-1 downto 0);  --right channel data received from i2s transceiver component
    signal l_data_tx    :  std_logic_vector(d_width-1 downto 0);  --left channel data to transmit using i2s transceiver component
    signal r_data_tx    :  std_logic_vector(d_width-1 downto 0);  --right channel data to transmit using i2s transceiver component
	signal reset_n		:  std_logic:='1';

    --declare i2s transceiver component
    component i2s_transceiver is
        generic(
            mclk_sclk_ratio :  integer := 4;    --number of mclk periods per sclk period
            sclk_ws_ratio   :  integer := 64;   --number of sclk periods per word select period
            d_width         :  integer := 24);  --data width
        port(
            reset_n     :  in   std_logic;                              --asynchronous active low reset
            mclk        :  in   std_logic;                              --master clock
            sclk        :  out  std_logic;                              --serial clock (or bit clock)
            ws          :  out  std_logic;                              --word select (or left-right clock)
            sd_tx       :  out  std_logic;                              --serial data transmit
            sd_rx       :  in   std_logic;                              --serial data receive
            l_data_tx   :  in   std_logic_vector(d_width-1 downto 0);   --left channel data to transmit
            r_data_tx   :  in   std_logic_vector(d_width-1 downto 0);   --right channel data to transmit
            l_data_rx   :  out  std_logic_vector(d_width-1 downto 0);   --left channel data received
            r_data_rx   :  out  std_logic_vector(d_width-1 downto 0));  --right channel data received
    end component;
    
begin
    --instantiate i2s transceiver component
    i2s_transceiver_0: i2s_transceiver
    generic map(mclk_sclk_ratio => 4, sclk_ws_ratio => 64, d_width => 24)
    port map(reset_n => reset_n, mclk => master_clk, sclk => serial_clk, ws => word_select, sd_tx => sd_tx, sd_rx => sd_rx,
             l_data_tx => l_data_tx, r_data_tx => r_data_tx, l_data_rx => l_data_rx, r_data_rx => r_data_rx);
    
    ------------------------------------------------------------------
	-- CLOCK MANAGEMENT TILE
	--
	-- INPUT CLOCK: 12 MHZ
	-- OUTPUT CLOCK: 22.57 MHZ
	--
	-- Fvco = Fclkin * CLKFBOUT_MULT_F / DIVCLK_DIVIDE
	-- Fout0 = Fvco / CLKOUT0_DIVIDE_F
	--
	-- CLKFBOUT_MULT_F: 52.000
	-- CLKOUT0_DIVIDE_F: 27.647
	-- DIVCLK_DIVIDE: 1
	------------------------------------------------------------------
	CMT: MMCME2_BASE GENERIC MAP (
		-- JITTER PROGRAMMING (OPTIMIZED, HIGH, LOW)
		BANDWIDTH=>"OPTIMIZED",
		-- MULTIPLY VALUE FOR ALL CLKOUT (2.000-64.000).
		CLKFBOUT_MULT_F=>52.000,
		-- PHASE OFFSET IN DEGREES OF CLKFB (-360.000-360.000).
		CLKFBOUT_PHASE=>0.0,
		-- INPUT CLOCK PERIOD IN NS TO PS RESOLUTION (I.E. 33.333 IS 30 MHZ).
		CLKIN1_PERIOD=>83.333,
		-- DIVIDE AMOUNT FOR EACH CLKOUT (1-128)
		CLKOUT1_DIVIDE=>1,
		CLKOUT2_DIVIDE=>1,
		CLKOUT3_DIVIDE=>1,
		CLKOUT4_DIVIDE=>1,
		CLKOUT5_DIVIDE=>1,
		CLKOUT6_DIVIDE=>1,
		-- DIVIDE AMOUNT FOR CLKOUT0 (1.000-128.000):
		CLKOUT0_DIVIDE_F=>27.625,
		-- DUTY CYCLE FOR EACH CLKOUT (0.01-0.99):
		CLKOUT0_DUTY_CYCLE=>0.5,
		CLKOUT1_DUTY_CYCLE=>0.5,
		CLKOUT2_DUTY_CYCLE=>0.5,
		CLKOUT3_DUTY_CYCLE=>0.5,
		CLKOUT4_DUTY_CYCLE=>0.5,
		CLKOUT5_DUTY_CYCLE=>0.5,
		CLKOUT6_DUTY_CYCLE=>0.5,
		-- PHASE OFFSET FOR EACH CLKOUT (-360.000-360.000):
		CLKOUT0_PHASE=>0.0,
		CLKOUT1_PHASE=>0.0,
		CLKOUT2_PHASE=>0.0,
		CLKOUT3_PHASE=>0.0,
		CLKOUT4_PHASE=>0.0,
		CLKOUT5_PHASE=>0.0,
		CLKOUT6_PHASE=>0.0,
		-- CASCADE CLKOUT4 COUNTER WITH CLKOUT6 (FALSE, TRUE)
		CLKOUT4_CASCADE=>FALSE,
		-- MASTER DIVISION VALUE (1-106)
		DIVCLK_DIVIDE=>1,
		-- REFERENCE INPUT JITTER IN UI (0.000-0.999).
		REF_JITTER1=>0.0,
		-- DELAYS DONE UNTIL MMCM IS LOCKED (FALSE, TRUE)
		STARTUP_WAIT=>FALSE
	) PORT MAP (
		-- USER CONFIGURABLE CLOCK OUTPUTS:
		CLKOUT0=>master_clk,  -- 1-BIT OUTPUT: CLKOUT0
		CLKOUT0B=>OPEN,  -- 1-BIT OUTPUT: INVERTED CLKOUT0
		CLKOUT1=>OPEN,   -- 1-BIT OUTPUT: CLKOUT1
		CLKOUT1B=>OPEN,  -- 1-BIT OUTPUT: INVERTED CLKOUT1
		CLKOUT2=>OPEN,   -- 1-BIT OUTPUT: CLKOUT2
		CLKOUT2B=>OPEN,  -- 1-BIT OUTPUT: INVERTED CLKOUT2
		CLKOUT3=>OPEN,   -- 1-BIT OUTPUT: CLKOUT3
		CLKOUT3B=>OPEN,  -- 1-BIT OUTPUT: INVERTED CLKOUT3
		CLKOUT4=>OPEN,   -- 1-BIT OUTPUT: CLKOUT4
		CLKOUT5=>OPEN,   -- 1-BIT OUTPUT: CLKOUT5
		CLKOUT6=>OPEN,   -- 1-BIT OUTPUT: CLKOUT6
		-- CLOCK FEEDBACK OUTPUT PORTS:
		CLKFBOUT=>clkfb,-- 1-BIT OUTPUT: FEEDBACK CLOCK
		CLKFBOUTB=>OPEN, -- 1-BIT OUTPUT: INVERTED CLKFBOUT
		-- MMCM STATUS PORTS:
		LOCKED=>OPEN,    -- 1-BIT OUTPUT: LOCK
		-- CLOCK INPUT:
		CLKIN1=>CLK,   -- 1-BIT INPUT: CLOCK
		-- MMCM CONTROL PORTS:
		PWRDWN=>'0',     -- 1-BIT INPUT: POWER-DOWN
		RST=>'0',        -- 1-BIT INPUT: RESET
		-- CLOCK FEEDBACK INPUT PORT:
		CLKFBIN=>clkfb  -- 1-BIT INPUT: FEEDBACK CLOCK
	);

    mclk(0) <= master_clk;  --output master clock to adc
    mclk(1) <= master_clk;  --output master clock to dac
    sclk(0) <= serial_clk;  --output serial clock (from i2s transceiver) to adc
    sclk(1) <= serial_clk;  --output serial clock (from i2s transceiver) to dac
    ws(0) <= word_select;   --output word select (from i2s transceiver) to adc
    ws(1) <= word_select;   --output word select (from i2s transceiver) to dac

    r_data_tx <= r_data_rx;  --assign right channel received data to transmit (to playback out received data)
    l_data_tx <= l_data_rx;  --assign left channel received data to transmit (to playback out received data)

end logic;
