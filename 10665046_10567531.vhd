library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;                           --Clock
        i_rst : in std_logic;                           --Reset signal to initialize
        i_start : in std_logic;                         --Start signal
        i_data : in std_logic_vector(7 downto 0);       --Data vector (to be serialized before being fed in the convolution module)
        o_address : out std_logic_vector(15 downto 0);  --Memory address to write the output data
        o_done : out std_logic;                         --End of computation
        o_en : out std_logic;                           --Enable input and output to memory
        o_we : out std_logic;                           --1 to write to memory, 0 to read
        o_data : out std_logic_vector (7 downto 0);     --Data to be written to memory (after being deserialized)
        counter_tb : inout integer
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    constant zero: std_logic := '0';
    signal serialized_bit: std_logic;
    signal counter: integer;
    signal serialization_done: std_logic:='0';
begin
    serializer: process(i_clk,i_rst)
    begin
        if i_rst='1' then
            counter<=0;
            counter_tb<=0;
            serialization_done<='0';
        elsif rising_edge(i_clk) then
            counter<=counter+1;
            counter_tb<=counter_tb+1;
            --serialized_bit<=i_data(counter);
            if counter=7 then
                counter<=0;
                counter_tb<=0;
                serialization_done<='1';
            end if;
        end if;
    end process serializer;
    --o_done<=serialization_done;
    --o_data<=std_logic_vector(to_unsigned(counter, o_data'length));
end Behavioral;
