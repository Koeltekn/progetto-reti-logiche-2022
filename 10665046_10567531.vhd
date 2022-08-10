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
    -- CONSTANTS
    constant SEQ_LENGTH_ADDRESS: std_logic_vector(15 downto 0):=std_logic_vector(to_unsigned(0,16));
    constant FIRST_INPUT_ADDRESS: std_logic_vector(15 downto 0):=std_logic_vector(to_unsigned(1,16));
    constant FIRST_OUTPUT_ADDRESS: std_logic_vector(15 downto 0):=std_logic_vector(to_unsigned(1000,16));
    -- FSA STATE
    type S is (
        RESET,
        READ_SEQ_LENGTH,READING_SEQ_LENGTH,SEQ_LENGTH_READ,
        READ_INPUT_BYTE,READING_INPUT_BYTE,INPUT_BYTE_READ,
        SERIALIZE_LOAD,SERIALIZE_START,SERIALIZING,
        WRITE_OUTPUT_BYTE,WRITING_OUTPUT_BYTE,OUTPUT_BYTE_WRITTEN
    );
    signal state : S:=RESET;
    -- INPUT DATA
    signal seq_length:integer:=0;
    signal input_memory_address: std_logic_vector(15 downto 0):=std_logic_vector(to_unsigned(0,16));
    signal input_byte: std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(0,8));
    -- OUTPUT DATA
    signal output_memory_address: std_logic_vector(15 downto 0):=std_logic_vector(to_unsigned(0,16));
    signal output_byte: std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(0,8));
    -- COMMON SIGNALS
    signal enable: std_logic:='0';
    -- SERIALIZATION
    signal serializer_load: std_logic:='0';
    signal serialized_bit: std_logic:='0';
    signal serializer_counter:integer:=0;
    -- CONVOLUTER
    signal d1:std_logic:='0';
    signal d2:std_logic:='0';
    signal p1:std_logic:='0';
    signal p2:std_logic:='0';
    -- DEBUG
    --signal ser_shift_reg_db:std_logic_vector(7 downto 0);
begin
    next_state_function: process(i_clk, i_rst)
    begin
        if i_rst='1' then
            state<=RESET;
        elsif rising_edge(i_clk) then
            case state is
                when RESET =>
                    if i_start='1' then
                        state<=READ_SEQ_LENGTH;
                    end if;
                when READ_SEQ_LENGTH =>
                    state<=READING_SEQ_LENGTH;
                when READING_SEQ_LENGTH =>
                    state<=SEQ_LENGTH_READ;
                when SEQ_LENGTH_READ =>
                    state<=READ_INPUT_BYTE;
                when READ_INPUT_BYTE =>
                    state<=READING_INPUT_BYTE;
                when READING_INPUT_BYTE =>
                    state<=INPUT_BYTE_READ;
                when INPUT_BYTE_READ =>
                    state<=SERIALIZE_LOAD;
                when SERIALIZE_LOAD =>
                    state<=SERIALIZE_START;
                when SERIALIZE_START =>
                    state<=SERIALIZING;
                when SERIALIZING =>
                    if serializer_counter=4 or serializer_counter=9 then
                        state<=WRITE_OUTPUT_BYTE;
                    else
                    end if;
                when WRITE_OUTPUT_BYTE =>
                    state<=WRITING_OUTPUT_BYTE;
                when WRITING_OUTPUT_BYTE =>
                    state<=OUTPUT_BYTE_WRITTEN;
                when OUTPUT_BYTE_WRITTEN =>
                    if serializer_counter=5 then
                        state<=SERIALIZE_START;
                    end if;
                when others =>
            end case;
        end if;
    end process next_state_function;

    output_state_function: process(state)
    begin
        case state is
            when RESET =>
                input_memory_address<=FIRST_INPUT_ADDRESS;
                output_memory_address<=FIRST_OUTPUT_ADDRESS;
                enable<='0';
                serializer_load<='0';
            when READ_SEQ_LENGTH =>
                o_address<=SEQ_LENGTH_ADDRESS;
                o_en<='1';
                o_we<='0';
            when SEQ_LENGTH_READ =>
                seq_length<=to_integer(unsigned(i_data));
                o_en<='0';
            when READ_INPUT_BYTE =>
                o_address<=input_memory_address;
                o_en<='1';
                o_we<='0';
            when INPUT_BYTE_READ =>
                input_byte<=i_data;
                o_en<='0';
            when SERIALIZE_LOAD =>
                serializer_load<='1';
            when SERIALIZE_START =>
                serializer_load<='0';
                enable<='1';
            when WRITE_OUTPUT_BYTE =>
                enable<='0';
                o_address<=output_memory_address;
                o_en<='1';
                o_we<='1';
                O_data<=output_byte;
            when OUTPUT_BYTE_WRITTEN =>
                o_en<='0';
                o_we<='0';
                output_memory_address<=std_logic_vector(unsigned(output_memory_address)+1);
            when others =>
        end case;
    end process output_state_function;

    ser_conv_des: process(i_clk,i_rst)
        variable ser_shift_reg:std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(0,8));
    begin
        if i_rst='1' then
            ser_shift_reg:=std_logic_vector(to_unsigned(0,8));
            d1<='0';
            d2<='0';
            p1<='0';
            p2<='0';
            output_byte<=std_logic_vector(to_unsigned(0,8));
        else
            if rising_edge(i_clk) then
                if serializer_load='1' then
                    ser_shift_reg:=input_byte;
                elsif enable='1' and serializer_counter<9 then
                    -- Serializer
                    serialized_bit<=ser_shift_reg(7);
                    ser_shift_reg := ser_shift_reg( 6 downto 0) & '0';
                    serializer_counter<=serializer_counter+1;
                    
                    -- Deserializer
                    output_byte <= output_byte(5 downto 0) & p1 & p2;
                end if;
            end if;
            if falling_edge(i_clk) then
                if enable='1' and serializer_counter<9 then
                    -- Convoluter
                    p1<=serialized_bit xor d2;
                    p2<=serialized_bit xor d1 xor d2;
                    d2<=d1;
                    d1<=serialized_bit;
                end if;
            end if;
        end if;
        --ser_shift_reg_db<=ser_shift_reg;
    end process ser_conv_des;    
end Behavioral;
