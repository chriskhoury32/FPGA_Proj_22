library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity filter is
    -- generic (    );
    port (
        clk:    in std_logic; --input clock
        s_trig:   in std_logic; --trigger to start filtering
        ufa_addr: in std_logic_vector; --block RAM address of unfiltered audio signal values
        f_addr: in std_logic_vector; --block RAM address of filter coefficients
        fa_addr:  out std_logic_vector; --block RAM address of filtered audio signal values
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
            data:         out signed(17 downto 0);
        );
    end component;

--Begin Signal Declarations
type filter_FSM is      (filter_idle,filter_active,filter_end)
signal filter_state:    filter_FSM:=filter_idle;
signal data:            signed(17 downto 0);
signal data_24b:        signed (23 downto 0);
--End Signal Declarations

begin
    ft: filter_table port map(clk=>clk,addr=>addr,data=>data);
    fs: filter_select port map(clk=>clk,lowpass_sel=>lowpass_sel,highpass_sel=>highpass_sel,
                                knob_val=>knob_val,idx=>idx,data=>data,f_addr=>f_addr);

process(clk)
begin
    data_24b<=signed(b"000000"&std_logic_vector(data));
end process;

process(clk)
begin
    if rising_edge(clk)
    then
        case filter_state is
            when filter_idle =>
                f_trig<='0';
                if (s_trig='1')
                then
                    filter_state<=filter_active;
                end if;
            when filter_active =>
                
            when filter_end =>
                filter_state<=filter_idle;
                f_trig<='1';
        end case;
    end if;
end process;


end arch;