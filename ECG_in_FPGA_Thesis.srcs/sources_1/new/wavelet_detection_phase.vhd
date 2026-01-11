----------------------------------------------------------------------------------
-- Company: 
-- Engineer: 
-- 
-- Create Date: 11.01.2026 22:53:59
-- Design Name: 
-- Module Name: wavelet_detection_phase - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

-- Uncomment the following library declaration if using
-- arithmetic functions with Signed or Unsigned values
--use IEEE.NUMERIC_STD.ALL;

-- Uncomment the following library declaration if instantiating
-- any Xilinx leaf cells in this code.
--library UNISIM;
--use UNISIM.VComponents.all;

entity wavelet_detection_phase is
Port (
        clk         : in STD_LOGIC;
        reset       : in STD_LOGIC;
        d_in_valid  : in STD_LOGIC;
        d_wavelet   : in SIGNED(23 downto 0); -- Viene de D4 o D3
        
        pulse_out   : out STD_LOGIC -- '1' un ciclo cuando detecta latido
    );
end wavelet_detection_phase;

architecture Behavioral of wavelet_detection_phase is

begin


end Behavioral;
