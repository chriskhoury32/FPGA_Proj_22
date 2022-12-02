--------------------------------------------------------------------------------
--
--   filename:         i2s_transceiver.vhd
--   dependencies:     none
--   design software:  quartus prime version 17.0.0 build 595 sj lite edition
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
--   version 1.0 03/29/2019 scott larson
--     initial public release
-- 
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;

entity i2s_transceiver is
  generic(
    mclk_sclk_ratio  :  integer := 4;    --number of mclk periods per sclk period
    sclk_ws_ratio    :  integer := 64;   --number of sclk periods per word select period
    d_width          :  integer := 24);  --data width
  port(
    reset_n    :  in   std_logic;                             --asynchronous active low reset
    mclk       :  in   std_logic;                             --master clock
    sclk       :  out  std_logic;                             --serial clock (or bit clock)
    ws         :  out  std_logic;                             --word select (or left-right clock)
    sd_tx      :  out  std_logic;                             --serial data transmit
    sd_rx      :  in   std_logic;                             --serial data receive
    l_data_tx  :  in   std_logic_vector(d_width-1 downto 0);  --left channel data to transmit
    r_data_tx  :  in   std_logic_vector(d_width-1 downto 0);  --right channel data to transmit
    l_data_rx  :  out  std_logic_vector(d_width-1 downto 0);  --left channel data received
    r_data_rx  :  out  std_logic_vector(d_width-1 downto 0)); --right channel data received
end i2s_transceiver;

architecture logic of i2s_transceiver is

  signal sclk_int       :  std_logic := '0';                      --internal serial clock signal
  signal ws_int         :  std_logic := '0';                      --internal word select signal
  signal l_data_rx_int  :  std_logic_vector(d_width-1 downto 0);  --internal left channel rx data buffer
  signal r_data_rx_int  :  std_logic_vector(d_width-1 downto 0);  --internal right channel rx data buffer
  signal l_data_tx_int  :  std_logic_vector(d_width-1 downto 0);  --internal left channel tx data buffer
  signal r_data_tx_int  :  std_logic_vector(d_width-1 downto 0);  --internal right channel tx data buffer
   
begin  
  
  process(mclk, reset_n)
    variable sclk_cnt  :  integer := 0;  --counter of master clocks during half period of serial clock
    variable ws_cnt    :  integer := 0;  --counter of serial clock toggles during half period of word select
  begin
    
    if(reset_n = '0') then                                           --asynchronous reset
      sclk_cnt := 0;                                                   --clear mclk/sclk counter
      ws_cnt := 0;                                                     --clear sclk/ws counter
      sclk_int <= '0';                                                 --clear serial clock signal
      ws_int <= '0';                                                   --clear word select signal
      l_data_rx_int <= (others => '0');                                --clear internal left channel rx data buffer
      r_data_rx_int <= (others => '0');                                --clear internal right channel rx data buffer
      l_data_tx_int <= (others => '0');                                --clear internal left channel tx data buffer
      r_data_tx_int <= (others => '0');                                --clear internal right channel tx data buffer
      sd_tx <= '0';                                                    --clear serial data transmit output
      l_data_rx <= (others => '0');                                    --clear left channel received data output
      r_data_rx <= (others => '0');                                    --clear right channel received data output
    elsif(mclk'event and mclk = '1') then                            --master clock rising edge
      if(sclk_cnt < mclk_sclk_ratio/2-1) then                          --less than half period of sclk
        sclk_cnt := sclk_cnt + 1;                                        --increment mclk/sclk counter
      else                                                             --half period of sclk
        sclk_cnt := 0;                                                   --reset mclk/sclk counter
        sclk_int <= not sclk_int;                                        --toggle serial clock
        if(ws_cnt < sclk_ws_ratio-1) then                                --less than half period of ws
          ws_cnt := ws_cnt + 1;                                            --increment sclk/ws counter
          if(sclk_int = '0' and ws_cnt > 1 and ws_cnt < d_width*2+2) then  --rising edge of sclk during data word
            if(ws_int = '1') then                                            --right channel
              r_data_rx_int <= r_data_rx_int(d_width-2 downto 0) & sd_rx;      --shift data bit into right channel rx data buffer
            else                                                             --left channel
              l_data_rx_int <= l_data_rx_int(d_width-2 downto 0) & sd_rx;      --shift data bit into left channel rx data buffer
            end if;
          end if;
          if(sclk_int = '1' and ws_cnt < d_width*2+3) then                 --falling edge of sclk during data word
            if(ws_int = '1') then                                            --right channel
              sd_tx <= r_data_tx_int(d_width-1);                               --transmit serial data bit 
              r_data_tx_int <= r_data_tx_int(d_width-2 downto 0) & '0';        --shift data of right channel tx data buffer
            else                                                             --left channel
              sd_tx <= l_data_tx_int(d_width-1);                               --transmit serial data bit
              l_data_tx_int <= l_data_tx_int(d_width-2 downto 0) & '0';        --shift data of left channel tx data buffer
            end if;
          end if;        
        else                                                            --half period of ws
          ws_cnt := 0;                                                    --reset sclk/ws counter
          ws_int <= not ws_int;                                           --toggle word select
          r_data_rx <= r_data_rx_int;                                     --output right channel received data
          l_data_rx <= l_data_rx_int;                                     --output left channel received data
          r_data_tx_int <= r_data_tx;                                     --latch in right channel data to transmit
          l_data_tx_int <= l_data_tx;                                     --latch in left channel data to transmit
        end if;
      end if;
    end if;    
  end process;
  
  sclk <= sclk_int;  --output serial clock
  ws <= ws_int;      --output word select
  
end logic;
    
