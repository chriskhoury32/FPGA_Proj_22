library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

entity filter_select is
    port(
        clk:          in  std_logic;
        lowpass_sel:  in  std_logic;
        highpass_sel: in  std_logic;
        knob_val:     in  unsigned(3 downto 0);
        idx:          in  unsigned(9 downto 0);
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

    type pass_type is (highpass, lowpass);

    signal addr: std_logic_vector(14 downto 0);

    signal pass:     pass_type := highpass;
    signal pass_bit: std_logic;
begin
    ft: filter_table port map(clk=>clk, addr=>addr, data=>data);
    
    pass_bit <= '1' when pass = highpass else '0';
    addr <= pass_bit & std_logic_vector(knob_val) & std_logic_vector(idx);
end arch;