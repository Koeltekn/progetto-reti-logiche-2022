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
    constant VALUE_ZERO:std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(0,8));
    -- FSA STATE
    type S is (
        IDLE,RESET,
        READ_SEQ_LENGTH,READING_SEQ_LENGTH,SEQ_LENGTH_READ,
        READ_INPUT_BYTE,READING_INPUT_BYTE,INPUT_BYTE_READ,
        SERIALIZE_LOAD,SERIALIZE_START,SERIALIZING,
        WRITE_OUTPUT_BYTE,WRITING_OUTPUT_BYTE,OUTPUT_BYTE_WRITTEN,
        DONE
    );
    signal state : S;
    -- INPUT DATA
    signal seq_length:integer;
    signal input_memory_address: std_logic_vector(15 downto 0);
    -- OUTPUT DATA
    signal output_memory_address: std_logic_vector(15 downto 0);
    signal output_byte: std_logic_vector(7 downto 0);
    -- COMMON SIGNALS
    signal enable: std_logic;
    signal res:std_logic;
    --signal seq_counter:integer;
    -- SERIALIZATION
    signal serializer_load: std_logic;
    signal serialized_bit: std_logic:='0';
    signal serializer_counter:integer;
    signal serializer_done:std_logic;
    -- CONVOLUTER
    signal d1:std_logic:='0';
    signal d2:std_logic:='0';
    signal p1:std_logic:='0';
    signal p2:std_logic:='0';
    -- DEBUG
    --signal ser_shift_reg_db:std_logic_vector(7 downto 0);
begin
    next_state_function: process(i_clk, i_rst,i_start)
    begin
        if i_rst='1' then
            state<=RESET;
        elsif rising_edge(i_clk) then
            case state is
                when IDLE =>
                    if i_start='1' then
                        state<=RESET;
                    end if;
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
                    if seq_length>0 then
                        state<=READING_INPUT_BYTE;
                    else
                        state<=DONE;
                    end if;
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
                    end if;
                when WRITE_OUTPUT_BYTE =>
                    state<=WRITING_OUTPUT_BYTE;
                when WRITING_OUTPUT_BYTE =>
                    state<=OUTPUT_BYTE_WRITTEN;
                when OUTPUT_BYTE_WRITTEN =>
                    if serializer_done='1' then
                        if seq_length>0 then
                            state<=READ_INPUT_BYTE;
                        else
                            state<=DONE;
                        end if;
                    else
                        state<=SERIALIZE_START;
                    end if;
                when DONE =>
                    if i_start='0' then
                        state<=IDLE;
                    end if;
            end case;
        end if;
    end process next_state_function;

    output_state_function: process(state)
    begin
        o_en<='0';
        o_we<='0';
        o_data<=VALUE_ZERO;
        enable<='0';
        serializer_load<='0';
        o_done<='0';
        res<='0';
        case state is
            when IDLE =>
            when RESET =>
                res<='1';
            when READ_SEQ_LENGTH =>
                o_en<='1';
            when READING_SEQ_LENGTH =>
                o_en<='1';
            when SEQ_LENGTH_READ =>
            when READ_INPUT_BYTE =>
                o_en<='1';
            when READING_INPUT_BYTE =>
                o_en<='1';
            when INPUT_BYTE_READ =>
            when SERIALIZE_LOAD =>
                serializer_load<='1';
            when SERIALIZE_START =>
                enable<='1';
            when SERIALIZING =>
                enable<='1';
            when WRITE_OUTPUT_BYTE =>
                o_en<='1';
                o_we<='1';
                o_data<=output_byte;
            when WRITING_OUTPUT_BYTE =>
                o_en<='1';
                o_we<='1';
                o_data<=output_byte;
            when OUTPUT_BYTE_WRITTEN =>
            when DONE =>
                o_done<='1';
        end case;
    end process output_state_function;

    counter: process(i_clk,i_rst,res)
    begin
        if i_rst='1' or res='1' then
            seq_length<=0;
        elsif rising_edge(i_clk) then
            case state is
                when SEQ_LENGTH_READ =>
                    seq_length<=to_integer(unsigned(i_data));
                when WRITING_OUTPUT_BYTE =>
                    if serializer_done='1' then
                        seq_length<=seq_length-1;
                    end if;
               when others =>
            end case;
        end if;
    end process counter;

    address_generator: process(i_clk,i_rst,res)
    begin
        if i_rst='1' or res='1' then
            input_memory_address<=FIRST_INPUT_ADDRESS;
            output_memory_address<=FIRST_OUTPUT_ADDRESS;
        elsif rising_edge(i_clk) then
            case state is
                when OUTPUT_BYTE_WRITTEN =>
                    output_memory_address<=std_logic_vector(unsigned(output_memory_address)+1);
                    if serializer_done='1' then
                        input_memory_address<=std_logic_vector(unsigned(input_memory_address)+1);
                    end if;
                when others =>
            end case;
        end if;
    end process address_generator;
    
    output_address_generator: process(i_clk)
    begin
        if rising_edge(i_clk) then
            case state is
                when READ_SEQ_LENGTH =>
                    o_address<=SEQ_LENGTH_ADDRESS;
                when READING_SEQ_LENGTH =>
                    o_address<=SEQ_LENGTH_ADDRESS;
                when SEQ_LENGTH_READ =>
                    o_address<=input_memory_address;
                when READ_INPUT_BYTE =>
                    o_address<=input_memory_address;                    
                when READING_INPUT_BYTE =>
                    o_address<=input_memory_address;
                when SERIALIZING =>
                    o_address<=output_memory_address;
                when WRITE_OUTPUT_BYTE =>
                    o_address<=output_memory_address;
                when WRITING_OUTPUT_BYTE =>
                    o_address<=output_memory_address;
                when OUTPUT_BYTE_WRITTEN =>
                    if serializer_done='1' then
                        o_address<=input_memory_address+1;
                    else
                        o_address<=input_memory_address;
                    end if;
                when others=>
            end case;
        end if;
    end process output_address_generator;

    serializer: process(i_clk,i_rst,res)
        variable ser_shift_reg:std_logic_vector(7 downto 0):=std_logic_vector(to_unsigned(0,8));
    begin
        if i_rst='1' or res='1' then
            ser_shift_reg:=std_logic_vector(to_unsigned(0,8));
            serializer_counter<=0;
            serializer_done<='0';
        elsif rising_edge(i_clk) then
            if serializer_load='1' then
                ser_shift_reg:=i_data;
            elsif enable='1' then
                if serializer_counter<9 then
                    serialized_bit<=ser_shift_reg(7);
                    ser_shift_reg := ser_shift_reg( 6 downto 0) & '0';
                    serializer_counter<=serializer_counter+1; 
                    serializer_done<='0';
                else
                    serializer_done<='1';
                    serializer_counter<=0;
                end if;
            end if;
        end if;
    end process serializer;
    
    convoluter:process(i_clk,i_rst,res)
    begin
        if i_rst='1' or res='1' then
            d1<='0';
            d2<='0';
            p1<='0';
            p2<='0';
        elsif falling_edge(i_clk) then
            if enable='1' and serializer_counter<9 and (state=SERIALIZING or serializer_counter=5) then
                d1<=serialized_bit;
                d2<=d1;
                p1<=serialized_bit xor d2;
                p2<=serialized_bit xor d1 xor d2;
            end if;
        end if;
    end process convoluter;
    
    deserializer: process(i_clk,i_rst,res)
    begin
        if i_rst='1' or res='1' then
            output_byte<=std_logic_vector(to_unsigned(0,8));
        elsif rising_edge(i_clk) then
            if enable='1' and serializer_counter<9 then
                output_byte <= output_byte(5 downto 0) & p1 & p2;
            end if;        
        end if;
    end process deserializer;
end Behavioral;
