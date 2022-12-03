library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity filter is
    -- generic (    );
    port (
        clk:      in std_logic; --input clock
        s_trig:   in std_logic; --trigger to start filtering
        f_audio:  out signed(23 downto 0); --filtered audio signal value
        f_trig:   out std_logic --trigger to indicate the filtering is finished
    );
end filter;

architecture arch of filter is
    component filter_select is
        port(
            clk:          in  std_logic;
            lowpass_sel:  in  std_logic;
            highpass_sel: in  std_logic;
            knob_val:     in  unsigned(3 downto 0);
            idx:          in  unsigned(9 downto 0);
            data:         out signed(17 downto 0)
        );
    end component;
    component unfiltered_audio is
        port(
            clk:          in std_logic;
            addr:         in unsigned(14 downto 0);
            data:         out signed(23 downto 0)
        );
    end component;

--Begin Signal Declarations
type filter_FSM is      (filter_idle,filter_active,filter_end)
signal filter_state:    filter_FSM:=filter_idle;
signal lowpass_sel:     std_logic;
signal highpass_sel:    std_logic;
signal knob_val:        unsigned(3 downto 0);
signal coeff:           signed(17 downto 0);    -- value of FIR coefficient
signal coeff_addr:      unsigned(9 downto 0);   -- address of coefficient RAM
signal uf_addr:         unsigned (14 downto 0); -- address of unfiltered audio RAM
signal uf_audio:        signed(23 downto 0);    -- value of unfiltered audio
signal fir_sum:         signed(51 downto 0);
--End Signal Declarations

begin
    fs: filter_select port map(clk=>clk,lowpass_sel=>lowpass_sel,highpass_sel=>highpass_sel,
                                knob_val=>knob_val,idx=>coeff_addr,data=>coeff);
    ufa: unfiltered_audio port map(clk=>clk,addr=>uf_addr,data=>uf_audio);

process(clk)
begin
    if rising_edge(clk)
    then
        case filter_state is
            when filter_idle =>
                f_trig<='0';
                if (s_trig='1')
                then
                    coeff_addr<=to_unsigned(0,10);
                    uf_addr<=to_unsigned(0,15);
                    fir_sum<=to_signed(0,41);
                    filter_state<=filter_active;
                else
                    filter_state<=filter_idle;
                end if;
            when filter_active =>
                if (coeff_addr=to_unsigned(1023,10) and uf_addr=to_unsigned(1023,15))
                then
                    coeff_addr<=to_unsigned(0,10);
                    uf_addr<=to_unsigned(0,15);
                    filter_state<=filter_end;
                else
                    fir_sum<=signed(b"00_0000_0000"&(coeff * uf_audio)) + fir_sum;
                    coeff_addr<=coeff_addr+1;
                    uf_addr<=uf_addr+1;
                    filter_state<=filter_active;
                end if;
            when filter_end =>
                filter_state<=filter_idle;
                f_trig<='1';
        end case;
    end if;
end process;


end arch;