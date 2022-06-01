-- Number of words to be read saved at address 0
-- First byte of the input sequence saved at address 1
-- First byte of the output sequence has to be saved from byte 1000 (decimal)
-----------------------------------------------------------------------------------------
-- First signal to be received is Reset
-- Before each elaboration, the Start signal must be set to HIGH, and kept HIGH untill the Done signal is set HIGH
-- The Done signal is set HIGH after the last byte has been saved to memory 
-- The Done signal must be kept HIGH untill the Start signal is set LOW
-- A new Start signal cannot be sent until DONE is set LOW
-- When the Start signal is set HIGH, the convoluter must be reset (state 00)
-----------------------------------------------------------------------------------------
-- Memory writing is asynchronous, memory reading is synchronous (the data gets read after 1 clock cycle)
-----------------------------------------------------------------------------------------
-- To read from memory
-- o_address set to the memory address to be read
-- o_en set to high
-- o_we set to low
-- read data is in i_data (AFTER 1 CLOCK CYCLE)
-----------------------------------------------------------------------------------------
-- To write to memory
-- o_address set to the memory address to be written into
-- o_en set to high
-- o_we set to high
-- o_data set to the data to be written


library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.std_logic_unsigned.all;

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
        o_data : out std_logic_vector (7 downto 0)      --Data to be written to memory (after being deserialized)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
    -- FSA STATE
    type S is (IDLE, START, READING_NUMBER_OF_BYTES, NUMBER_OF_BYTES_READ, READING_BYTE, BYTE_READ,START_SERIALIZE, SERIALIZATION_ENDED);
    signal state : S;
    -- INPUT DATA
    signal number_of_bytes: integer;
    signal input_memory_address: std_logic_vector(15 downto 0);
    signal input_byte: std_logic_vector(0 to 7);
    -- OUTPUT DATA
    signal output_memory_address: std_logic_vector(15 downto 0);
    -- SERIALIZATION
    signal serialize_enable: std_logic;
    signal serialized_bit: std_logic;
    signal serialization_done: std_logic;
    -- CONVOLUTER
    signal p1:std_logic;
    signal p2:std_logic;
    -- DESERIALIZATION
    signal deserialize_enable: std_logic;
    signal deserialize_done:std_logic;
    -- DEBUG SIGNALS
    signal counter_deb:integer;
    signal d1_deb:std_logic;
    signal d2_deb:std_logic;
    signal output_byte_db:std_logic_vector(7 downto 0);
begin
    next_state_function: process(i_clk, i_rst)
    begin
        if i_rst='1' then
            state<=IDLE;
        elsif rising_edge(i_clk) then
            case state is
                when IDLE =>
                    if i_start='1' then
                        state<=START;
                    end if;
                when START =>
                    state<=READING_NUMBER_OF_BYTES;
                when READING_NUMBER_OF_BYTES =>
                    state<=NUMBER_OF_BYTES_READ;
                when NUMBER_OF_BYTES_READ =>
                    state<=READING_BYTE;
                when READING_BYTE=>
                    state<=BYTE_READ;
                when BYTE_READ=>
                    state<=START_SERIALIZE;
                when START_SERIALIZE=>
                    if serialization_done='1' and deserialize_done='1' then
                        state<=SERIALIZATION_ENDED;
                    end if;
                when SERIALIZATION_ENDED=>
            end case;
        end if;
    end process next_state_function;

    output_state_function: process(state)
    begin
        case state is
            when IDLE =>
            when START =>
                -- Reset signals for new elaboration
                serialize_enable<='0';
                number_of_bytes<=0;
                input_memory_address<=std_logic_vector(to_unsigned(1,16));
                output_memory_address<=std_logic_vector(to_unsigned(1000,16));
                input_byte<=std_logic_vector(to_unsigned(0,8));
                -- Read number of bytes from memory
                o_address<=std_logic_vector(to_unsigned(0,16));
                o_en<='1';
                o_we<='0';
            when READING_NUMBER_OF_BYTES =>
            when NUMBER_OF_BYTES_READ =>
                -- Save the number of bytes to be converted
                number_of_bytes<=to_integer(unsigned(i_data));
                -- Read the first byte
                o_address<=input_memory_address;
            when READING_BYTE=>
            when BYTE_READ=>
                o_en<='0';
                input_byte<=i_data;
            when START_SERIALIZE=>
                serialize_enable<='1';
            when SERIALIZATION_ENDED=>
                serialize_enable<='0';
                o_done<='1';
        end case;
    end process output_state_function;

    serializer: process(i_clk,i_start)
        variable counter:integer;
    begin
        if serialize_enable='1' then
            if falling_edge(i_clk) then
                if counter=4 then
                    serialization_done<='1';
                else
                    serialized_bit<=input_byte(counter);
                    counter:=counter+1;
                end if;   
            end if;
        elsif i_start='1' then
            counter:=0;
            serialization_done<='0';
            serialized_bit<='U';
        end if;
        counter_deb<=counter;
    end process serializer;

    convoluter: process(i_clk,i_start)
        variable d1:std_logic;
        variable d2:std_logic;       
    begin
        if serialize_enable='1' then
            if rising_edge(i_clk) then
                p1<=serialized_bit xor d2;
                p2<=serialized_bit xor d1 xor d2;
                d2:=d1;
                d1:=serialized_bit;
                deserialize_enable<='1';
            end if;
        elsif i_start='1' then
            d1:='0';
            d2:='0';
            p1<='0';
            p2<='0';
            deserialize_enable<='0';
        end if;
        d1_deb<=d1;
        d2_deb<=d2;
    end process convoluter;

    deserializer: process(i_clk,i_start)
        variable counter1:integer;
        variable counter2:integer;
        variable output_byte: std_logic_vector(7 downto 0);
    begin
        if deserialize_enable='1' then
            if falling_edge(i_clk) then
                if counter1=6 then
                    deserialize_done<='1';
                end if;
                output_byte(counter1):=p1;
                output_byte(counter2):=p2;
                counter1:=counter1+2;
                counter2:=counter2+2;
            end if;
        elsif i_start='1' then
            counter1:=0;
            counter2:=1;
            deserialize_done<='0';
            output_byte:=std_logic_vector(to_unsigned(0,8));
        end if;
        output_byte_db<=output_byte;
    end process deserializer;
end Behavioral;
