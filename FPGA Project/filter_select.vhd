library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity filter_select is
    port(
        clk:          in  std_logic;
        pass_toggle:  in  std_logic;
        cutoff_inc:   in  std_logic;
        idx:          in  unsigned(9 downto 0);
        cutoff_leds:  out std_logic_vector(3 downto 0);
        rgb_led:      out std_logic_vector(2 downto 0);
        data:         out signed(17 downto 0)
    );
end filter_select;

architecture arch of filter_select is
    component filter_table is
        port(
            clk:  in  std_logic;
            addr: in  std_logic_vector(14 downto 0);
            data: out signed(17 downto 0)
        );
    end component;

    signal addr: std_logic_vector(14 downto 0);

    signal pass_bit: std_logic := '0';  -- '0' - lowpass; '1' - highpass
    signal cutoff:   unsigned(3 downto 0) := b"0000";
begin
    ft: filter_table port map(clk=>clk, addr=>addr, data=>data);
    
    cutoff_leds<=std_logic_vector(cutoff);
    addr <= pass_bit & std_logic_vector(cutoff) & std_logic_vector(idx);

    process(clk)
    begin
        if rising_edge(clk) then
            if pass_bit = '1' then
                rgb_led<=b"110"; --highpass = yellow
            else
                rgb_led<=b"101"; --lowpass = purple
            end if;
            if pass_toggle = '1' then
                pass_bit <= not pass_bit;
            end if;
            if cutoff_inc = '1' then
                if (cutoff=b"1111") then
                    cutoff<=b"0000";
                else
                    cutoff <= cutoff + 1;
                end if;
            end if;
        end if;
    end process;
end arch;