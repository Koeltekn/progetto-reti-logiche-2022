library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_tb is
end project_tb;
    
architecture tb of project_tb is
    signal i_start, i_clk, i_rst : std_logic;  -- inputs 
    signal i_data : std_logic_vector(7 downto 0); 
    signal counter_tb: integer;
begin
    -- connecting testbench signals with half_adder.vhd
    UUT : entity work.project_reti_logiche port map (i_clk=>i_clk,i_rst=>i_rst, i_start=>i_start, i_data=>i_data, counter_tb=>counter_tb);

    -- inputs
    -- 00 at 0 ns
    -- 01 at 20 ns, as b is 0 at 20 ns and a is changed to 1 at 20 ns
    -- 10 at 40 ns
    -- 11 at 60 ns
    i_clk <= '0', 
        '1' after 10 ns,
        '0' after 20 ns,
        '1' after 30 ns,
        '0' after 40 ns,
        '1' after 50 ns,
        '0' after 60 ns,
        '1' after 70 ns,
        '0' after 80 ns,
        '1' after 90 ns,
        '0' after 100 ns,
        '1' after 110 ns,
        '0' after 120 ns,
        '1' after 130 ns,
        '0' after 140 ns,
        '1' after 150 ns,
        '0' after 160 ns,
        '1' after 170 ns,
        '0' after 180 ns,
        '1' after 190 ns,
        '0' after 200 ns,
        '1' after 210 ns,
        '0' after 220 ns,
        '1' after 230 ns,
        '0' after 340 ns;
    i_rst <= '1', '0' after 5 ns;
end tb ;