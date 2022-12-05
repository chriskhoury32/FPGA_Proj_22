library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity top is
    port(
        clk:   in std_logic;                        --system clock (12 mhz)
        btn:   in  std_logic_vector(1 downto 0);    --buttons
        mclk:  out std_logic_vector(1 downto 0);  --master clock
        sclk:  out std_logic_vector(1 downto 0);  --serial clock (or bit clock)
        ws:    out std_logic_vector(1 downto 0);  --word select (or left-right clock)
        sd_rx: in  std_logic;                     --serial data in
        sd_tx: out std_logic;                      --serial data out
		led:   out std_logic_vector(3 downto 0);
        rgb:   out std_logic_vector(2 downto 0)
    );
end top;

architecture arch of top is
    component i2s_playback
        generic(
            d_width: integer := 24
        );
        port(
            clk:   in  std_logic;                     --system clock (12 mhz)
            mclk:  out std_logic_vector(1 downto 0);  --master clock
            sclk:  out std_logic_vector(1 downto 0);  --serial clock (or bit clock)
            ws:    out std_logic_vector(1 downto 0);  --word select (or left-right clock)
            sd_rx: in  std_logic;                     --serial data in
            sd_tx: out std_logic;                     --serial data out

            r_data_o: in  std_logic_vector(d_width-1 downto 0);
            l_data_o: in  std_logic_vector(d_width-1 downto 0);
            r_data_i: out std_logic_vector(d_width-1 downto 0);
            l_data_i: out std_logic_vector(d_width-1 downto 0)
        );
    end component;
    component filter
        port (
            clk:      in std_logic; --input clock
            toggle_btn:  in  std_logic;
            cutoff_btn:   in  std_logic;
            s_trig:   in std_logic; --trigger to start filtering
            uf_audio: in signed(23 downto 0);  --unfiltered audio to write to RAM
            cutoff_leds: out std_logic_vector(3 downto 0);
            rgb_led:  out std_logic_vector(2 downto 0);
            f_audio:  out signed(23 downto 0); --filtered audio signal value
            f_trig:   out std_logic --trigger to indicate the filtering is finished
        );
    end component;
    
    type synchronizer is array(0 to 3) of std_logic_vector(23 downto 0);

    signal clkf:    std_logic;
    signal clkfb:   std_logic;
    signal counter: unsigned(10 downto 0);
    signal btn0_temp:   std_logic_vector(3 downto 0);
    signal btn1_temp:   std_logic_vector(3 downto 0);
    signal btn1:       std_logic;
    signal btn0:       std_logic;

    signal s_trig:     std_logic := '0';
    signal r_audio_i:  synchronizer;
    signal l_audio_i:  synchronizer;
    signal r_audio_o:  std_logic_vector(23 downto 0);
    signal l_audio_o:  std_logic_vector(23 downto 0);
    signal r_uf_audio: signed(23 downto 0);
    signal l_uf_audio: signed(23 downto 0);
    signal r_f_audio:  signed(23 downto 0);
    signal l_f_audio:  signed(23 downto 0);
begin
    playback: i2s_playback port map(
        clk=>clk, mclk=>mclk, sclk=>sclk,
        ws=>ws, sd_rx=>sd_rx, sd_tx=>sd_tx,
        r_data_i=>r_audio_i(0), l_data_i=>l_audio_i(0),
        r_data_o=>r_audio_o, l_data_o=>l_audio_o
    );
    r_filt: filter port map(
        clk=>clkf, toggle_btn=>btn0, cutoff_btn=>btn1, s_trig=>s_trig, 
        uf_audio=>r_uf_audio, cutoff_leds=>led, rgb_led=>rgb, f_audio=>r_f_audio, f_trig=>open
    );
    l_filt: filter port map(
        clk=>clkf, toggle_btn=>btn0, cutoff_btn=>btn1, s_trig=>s_trig, 
        uf_audio=>l_uf_audio, cutoff_leds=>open, rgb_led=>open, f_audio=>l_f_audio, f_trig=>open
    );

    r_uf_audio <= signed(r_audio_i(3));
    r_audio_o <= std_logic_vector(r_f_audio);

    l_uf_audio <= signed(l_audio_i(3));
    l_audio_o <= std_logic_vector(l_f_audio);

    process(clkf)
    begin
        if rising_edge(clkf) then
			btn0<=btn0_temp(2) and (not btn0_temp(3));
			btn0_temp(0)<=btn(0);
			btn0_temp(1)<=btn0_temp(0);
			btn0_temp(2)<=btn0_temp(1);
			btn0_temp(3)<=btn0_temp(2);

            btn1<=btn1_temp(2) and (not btn1_temp(3));
			btn1_temp(0)<=btn(1);
			btn1_temp(1)<=btn1_temp(0);
			btn1_temp(2)<=btn1_temp(1);
			btn1_temp(3)<=btn1_temp(2);
        end if;
    end process;

    process(clkf)
    begin
        if rising_edge(clkf) then
            if counter = to_unsigned(1048-1, counter'length) then
                counter <= to_unsigned(0, counter'length);
                s_trig <= '1';
            else
                counter <= counter + 1;
                s_trig <= '0';
            end if;
        end if;
    end process;

    process(clk)
    begin
        if rising_edge(clkf) then
            r_audio_i(1 to 3) <= r_audio_i(0 to 2);
            l_audio_i(1 to 3) <= l_audio_i(0 to 2);
        end if;
    end process;

    -- 88.2 MHz output
    cmt: MMCME2_BASE generic map (
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
		CLKOUT0_DIVIDE_F=>13.500,
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
		CLKOUT0=>clkf,   -- 1-BIT OUTPUT: CLKOUT0
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

end arch;
