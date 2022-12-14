library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
library UNISIM;
use UNISIM.vcomponents.all;

entity filter is
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
end filter;

architecture arch of filter is
    component filter_select is
        port(
            clk:          in  std_logic;
            pass_toggle:  in  std_logic;
            cutoff_inc:   in  std_logic;
            idx:          in  unsigned(9 downto 0);
            rgb_led:      out std_logic_vector(2 downto 0);
            cutoff_leds:  out std_logic_vector(3 downto 0);
            data:         out signed(17 downto 0)
        );
    end component;
    component unfiltered_audio is
        port(
            clka_i:  in  std_logic;
            wea_i:   in  std_logic;
            addra_i: in  std_logic_vector(9 downto 0);
            dataa_i: in  std_logic_vector(35 downto 0);
            dataa_o: out std_logic_vector(35 downto 0);
            clkb_i:  in  std_logic;
            web_i:   in  std_logic;
            addrb_i: in  std_logic_vector(9 downto 0);
            datab_i: in  std_logic_vector(35 downto 0);
            datab_o: out std_logic_vector(35 downto 0)
        );
    end component;

--Begin Signal Declarations
type filter_FSM is      (filter_idle,filter_write,filter_read,filter_end);
signal filter_state:    filter_FSM:=filter_idle;
signal lowpass_sel:     std_logic;
signal highpass_sel:    std_logic;
signal knob_val:        unsigned(3 downto 0);
signal coeff:           signed(17 downto 0);    -- value of FIR coefficient
signal coeff_addr:      unsigned(9 downto 0);   -- address of coefficient RAM
signal uf_audio_r:      signed(23 downto 0);    -- value of unfiltered audio (read)
signal fir_sum:         signed(41 downto 0);
--signal fir_sum:         signed(23 downto 0);

constant samples: natural:=1024;
signal addra: std_logic_vector(9 downto 0);
signal dataa: std_logic_vector(35 downto 0);
signal uf_addr: unsigned(9 downto 0):=b"00_0000_0000";
signal datab: std_logic_vector(35 downto 0);
signal amp:	  std_logic:='0';
signal web_s: std_logic;
signal uf_audio_w: std_logic_vector(35 downto 0);    -- value of unfiltered audio (write)

signal start_addr:  unsigned(9 downto 0):=b"00_0000_0000";
--End Signal Declarations

begin
    fs: filter_select port map(clk=>clk,pass_toggle=>toggle_btn,cutoff_inc=>cutoff_btn,
                                idx=>coeff_addr,cutoff_leds=>cutoff_leds,rgb_led=>rgb_led,data=>coeff);
    ufa: unfiltered_audio port map(clka_i=>clk,wea_i=>'0',addra_i=>std_logic_vector(uf_addr),dataa_i=>(others=>'0'),
                                    dataa_o=>dataa,clkb_i=>clk,web_i=>web_s,addrb_i=>std_logic_vector(uf_addr),
                                    datab_i=>uf_audio_w,datab_o=>open);

    uf_audio_r<=signed(dataa(23 downto 0));
    uf_audio_w(35 downto 24)<=b"0000_0000_0000";
    uf_audio_w(23 downto 0)<=std_logic_vector(uf_audio);

process(clk)
begin
    if rising_edge(clk)
    then
        case filter_state is
            when filter_idle =>
                web_s<='0';
                f_trig<='0';
                if (s_trig='1')
                then
                    coeff_addr<=b"00_0000_0000";
                    fir_sum<=to_signed(0,fir_sum'length);
                    filter_state<=filter_write;
                else
                    filter_state<=filter_idle;
                end if;
            when filter_write =>
                web_s<='1';
                uf_addr<=start_addr;
                filter_state<=filter_read;
            when filter_read =>
                web_s<='0';
                if (coeff_addr=samples-1)
                then
                    fir_sum<=signed(coeff * uf_audio_r) + fir_sum;
                    --fir_sum<=uf_audio_r;
                    filter_state<=filter_end;
                    if (start_addr=to_unsigned(samples-1,10))
                    then
                        start_addr<=to_unsigned(0,10);
                    else
                        start_addr<=start_addr+1;
                    end if;
                elsif (uf_addr=to_unsigned(samples-1,10)) 
                then
                    uf_addr<=b"00_0000_0000";
                    fir_sum<=signed(coeff * uf_audio_r) + fir_sum;
                    --fir_sum<=uf_audio_r;
                    coeff_addr<=coeff_addr+1;
                else
                    uf_addr<=uf_addr+1;
                    fir_sum<=signed(coeff * uf_audio_r) + fir_sum;
                    --fir_sum<=uf_audio_r;
                    coeff_addr<=coeff_addr+1;
                end if;
            when filter_end =>
                filter_state<=filter_idle;
                f_trig<='1';
                f_audio<=fir_sum(37 downto 14);
                --f_audio<=fir_sum;
        end case;
    end if;
end process;


end arch;