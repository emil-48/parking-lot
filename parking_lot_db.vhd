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
        closed_sig : out std_logic   -- ACTIVE-LOW  LED3  (lot closed)
    );
end parking_controller;

architecture parking_controller_arch of parking_controller is

    
    type fsm_t is (EMPTY, PARTIAL, FULL, CLOSED);

    signal curr_state, next_state, prev_state : fsm_t := EMPTY;
    signal count, next_count, prev_count : integer range 0 to 20 := 0;

    
	-- sensor synchronisers and edge detectors
    signal db_entr_tick, db_exit_tick : std_logic;
    

begin

    debouncer_entr : entity work.button_debounce 
        port map (
            clk => clk,
            rst => reset,
            btn_in => entr_sn,
            btn_out => db_entr_tick
        );
        
    debouncer_exit : entity work.button_debounce 
        port map (
            clk => clk,
            rst => reset,
            btn_in => exit_sn,
            btn_out => db_exit_tick
        );
    
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
    ----------------------------------------------------------------
    open_sig   <= '1' when curr_state = EMPTY or curr_state = PARTIAL else '0';
    full_sig   <= '1' when curr_state = FULL                          else '0';
    closed_sig <= '1' when curr_state = CLOSED                        else '0';

end parking_controller_arch;
