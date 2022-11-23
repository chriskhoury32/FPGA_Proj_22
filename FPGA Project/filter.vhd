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
        audio_uf: in std_logic_vector; --block RAM address of unfiltered audio signal values
        f_coeffs: in std_logic_vector; --block RAM address of filter coefficients
        audio_f:  out std_logic_vector; --block RAM address of filtered audio signal values
        f_trig:   out std_logic --trigger to indicate the filtering is finished
    );
end filter;

architecture arch of filter is
--Begin Signal Declarations
type filter_FSM is      (filter_idle,filter_active,filter_end)
signal filter_state:    filter_FSM:=filter_idle;
--End Signal Declarations

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