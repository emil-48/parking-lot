library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity parking_controller is
    port (
        clk        : in  std_logic;  
        reset      : in  std_logic;  -- active low

        entr_sn    : in  std_logic;  -- entrance sensor 
        exit_sn    : in  std_logic;  -- exit sensor   

        override   : in  std_logic;  -- attendant override (hold count)
        start      : in  std_logic;  -- reopen parking
        stop       : in  std_logic;  -- close parking

        open_sig   : out std_logic;  -- ACTIVE-LOW  LED1  (lot open  & not full)
        full_sig   : out std_logic;  -- ACTIVE-LOW  LED2  (lot full)
        closed_sig : out std_logic;  -- ACTIVE-LOW  LED3  (lot closed)
        
        anode   : out std_logic_vector(3 downto 0);
        segment : out std_logic_vector(6 downto 0)
    );
end parking_controller;

architecture parking_controller_arch of parking_controller is

    
    type fsm_t is (EMPTY, PARTIAL, FULL, CLOSED);

    signal curr_state, next_state, prev_state : fsm_t := EMPTY;
    signal count, next_count, prev_count : integer range 0 to 20 := 0;

    
	-- sensor synchronisers and edge detectors
    signal entr_d1, entr_d2 : std_logic := '0';
    signal exit_d1, exit_d2 : std_logic := '0';
    signal entr_tick, exit_tick : std_logic;
    signal db_entr_tick, db_exit_tick : std_logic;
    signal clk_1kHz : std_logic := '0';
    signal segment_i : std_logic_vector(6 downto 0) := "1111111";
    signal anode_i : STD_LOGIC_VECTOR(3 downto 0) := "1111";
    

begin

    debouncer_entr : entity work.button_debounce 
        port map (
            clk => clk,
            rst => reset,
            btn_in => entr_tick,
            btn_out => db_entr_tick
        );
        
    debouncer_exit : entity work.button_debounce 
        port map (
            clk => clk,
            rst => reset,
            btn_in => exit_tick,
            btn_out => db_exit_tick
        );

    --************************************************************************
    -- Clock-Domain Crossing with 2 FFs-Actually delaying with 2 clock cycles to synch.
    
    
    
    sync_proc : process(clk)
    begin
        if rising_edge(clk) then
            entr_d1 <= entr_sn;  entr_d2 <= entr_d1;
            exit_d1 <= exit_sn;  exit_d2 <= exit_d1;
        end if;
    end process;

    entr_tick <= entr_d1 and not entr_d2;  
    exit_tick <= exit_d1 and not exit_d2;
	--************************************************************************

    
    init_proc : process(clk)
    begin
        if rising_edge(clk) then
            if reset = '1' then                
                curr_state <= EMPTY;
                count      <= 0;
            else
                -- remember last non-closed state/count
                if stop = '1' and curr_state /= CLOSED then
                    prev_state <= curr_state;
                    prev_count <= count;
                end if;

                curr_state <= next_state;
                count      <= next_count;
            end if;
        end if;
    end process;

    
    state_proc : process(curr_state, count, db_entr_tick, db_exit_tick,
                        override, stop, start,
                        prev_state, prev_count)
    begin
        
        next_state <= curr_state;
        next_count <= count;

        case curr_state is
            --------------------------------------------------------
            when EMPTY =>
                if stop = '1' then
                    next_state <= CLOSED;

                elsif override = '0' and db_entr_tick = '1' then
                    next_state <= PARTIAL;
                    next_count <= 1;
                end if;

            --------------------------------------------------------
            when PARTIAL =>
                if stop = '1' then
                    next_state <= CLOSED;

                elsif override = '0' then
                    if db_entr_tick = '1' then
                        if count = 19 then
                            next_state <= FULL;
                            next_count <= 20;
                        else
                            next_count <= count + 1;
                        end if;

                    elsif db_exit_tick = '1' then
                        if count = 1 then
                            next_state <= EMPTY;
                            next_count <= 0;
                        else
                            next_count <= count - 1;
                        end if;
                    end if;
                end if;

            --------------------------------------------------------
            when FULL =>
                if stop = '1' then
                    next_state <= CLOSED;

                elsif override = '0' and db_exit_tick = '1' then
                    next_state <= PARTIAL;
                    next_count <= 19;
                end if;

            --------------------------------------------------------
            when CLOSED =>
                if start = '1' then
                    next_state <= prev_state;
                    next_count <= prev_count;
                end if;
        end case;
    end process;
    
    clk_div : process(clk) is
	   constant max_count : integer := (100_000_000 / 1_000) / 2;
	   variable clk_count : integer range 0 to max_count := 0;
	begin
	   if rising_edge(clk) then
	       if reset = '1' then
	           clk_count := 0;
	           clk_1kHz <= '0';
	       else
	           if clk_count = max_count then
	               clk_1kHz <= not clk_1kHz;
	           else
	               clk_count := clk_count + 1;
	           end if;
	       end if;
	   end if;
    end process clk_div;
	
	anode_mux : process(clk_1kHz, anode_i, segment_i) is
	   variable count : integer range 0 to 3 := 0;
	   variable temp : integer range 0 to 9 := 0;
	begin
	   if rising_edge(clk_1kHz) then
	       if reset = '1' then
	           count := 0;
	           temp := 0;
	       end if;
	       
	       if count = 3 then
	           count := 0;
	       else
	           count := count + 1;
	       end if;
	       
	       case count is
	           when 0 =>
	               anode_i <= "1110";
	           when 1 =>
	               anode_i <= "1101";
	           when 2 =>
	               anode_i <= "1011";
	           when others =>
	               anode_i <= "0111";
	       end case;
	       
	       case anode_i is
                when "1110" =>
                    temp := count mod 10;
                when "1101" =>
                    temp := (count / 10) mod 10;
                when "1011" =>
                    temp := (count / 100) mod 10;
                when "0111" =>
                    temp := (count / 1000) mod 10;
                when others =>
                    temp := 0;
            end case;
            
            case temp is
                when 0 =>
                    segment_i <= "0000001";
                when 1 =>
                    segment_i <= "1001111";
                when 2 =>
                    segment_i <= "0010010";
                when 3 =>
                    segment_i <= "0000110";
                when 4 =>
                    segment_i <= "1001100";
                when 5 =>
                    segment_i <= "0100100";
                when 6 =>
                    segment_i <= "0100000";
                when 7 =>
                    segment_i <= "0001111";
                when 8 =>
                    segment_i <= "0000000";
                when 9 =>
                    segment_i <= "0000100";
                when others =>
                    segment_i <= "1111111";
            end case;
	   end if;
	   anode <= anode_i;
	   segment <= segment_i;
	end process anode_mux;

    ----------------------------------------------------------------
    open_sig   <= '1' when curr_state = EMPTY or curr_state = PARTIAL else '0';
    full_sig   <= '1' when curr_state = FULL                          else '0';
    closed_sig <= '1' when curr_state = CLOSED                        else '0';

end parking_controller_arch;
