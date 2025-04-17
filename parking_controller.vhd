LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

entity parking_controller is
	port (
		clk : IN STD_LOGIC;
		reset : IN STD_LOGIC;
		entr_sn : IN STD_LOGIC; -- entrance sensor
		exit_sn : IN STD_LOGIC; -- exit sensor
		override : IN STD_LOGIC; -- manual Override, count stays the same
		start : IN STD_LOGIC; -- manual input to open the lot
		stop : IN STD_LOGIC; -- manual input to close the lot
		open_sig : OUT STD_LOGIC; -- open status
		full_sig : OUT STD_LOGIC; -- full status
		closed_sig : OUT STD_LOGIC -- closed status
	);
end parking_controller;

architecture FSM_arch of parking_controller is
	type FSMstates is (S_empty, S_partial, S_Full, S_Closed);
	SIGNAL prev_state : FSMStates; -- To store state before closed
	signal curr_state, next_state : FSMstates;
	signal count : integer range 0 to 20;
	signal next_count : integer range 0 to 20;
	signal prev_count : integer range 0 TO 20; -- To store count before closed
	
begin
	state_register : process(clk, reset)
	begin
		if reset = '1' then
			curr_state <= S_Empty;
			count <= 0;
		elsif rising_edge(clk) then
			curr_state <= next_state;
			count <= next_count;
			
		if curr_state /= S_Closed AND next_state = S_Closed then
                prev_state <= curr_state;
                prev_count <= count;
            end if;
		end if;
	end process state_register;
	
	FSM_logic : process (curr_state, entr_sn, exit_sn, override, start, stop, count, prev_state, prev_count)
	begin
		-- default: maintain current state/count
		next_state <= curr_state;
		next_count <= count;
		
		case curr_state is
			-- Count = 0
			when S_empty =>
				-- if stop enabled, go to closed state
				if stop = '1' then
					next_state <= S_Closed;
				elsif override = '0' then
					--handle sensor inputs
					if entr_sn = '1' and exit_sn = '0' then
						next_count <= 1; -- car entered, increment count
						next_state <= S_partial; -- go to partial state
					-- no action for car exit or simultaneous entry/exit
					end if;
				-- if override, do nothing
				end if;
			
			-- 0 < count < 20
			when S_partial => 
				-- if stop enabled, go to closed state
				if stop = '1' then 
					next_state <= S_Closed;
				elsif override = '0' then
				-- handle sensor inputs
					if entr_sn = '1' and exit_sn = '0' then -- car enter
						if count = 19 then -- count=19, car enter -> Full State
							next_count <= 20;
							next_state <= S_Full;
						else
							next_count <= count + 1; -- count=1-18, car enter -> still partial
						end if;
					elsif entr_sn = '0' and exit_sn = '1' then -- car exit
						if count = 1 then
							next_count <= 0;
							next_state <= S_Empty; -- count=1, car exit -> Empty
						else
							next_count <= count - 1; -- decrement counter
						end if;
					-- no action for simultaneous entry/exit
					end if;
				end if;
				
			-- Count = 20
			when S_Full => 
				-- if stop enabled, go to closed state
				if stop = '1' then
					next_state <= S_Closed;
				elsif override = '0' then
					-- handle sensor inputs
					if entr_sn = '0' and exit_sn = '1' then
						next_count <= 19;
						next_state <= S_Partial;
					-- cannot increment further when lot full
					-- no action for simultaneous entry/exit
					end if;
				end if;
				
			-- closed state: do nothing until start is pressed
			-- need to implement return to prev state/count
			when S_Closed =>
				if start = '1' then
					next_state <= prev_state;
					next_count <= prev_count;
				end if;
		end case;
	end process;
	
	-- output assignment logic
	output_assignment : process (curr_state)
	begin
		-- default 
		open_sig <= '0';
		full_sig <= '0';
		closed_sig <= '0';
		
		case curr_state is
			when S_Empty => -- count = 0
				open_sig <= '1';
			when S_Partial => -- 0 < count < 20
				open_sig <= '1';
			when S_Full => -- count = 20
				full_sig <= '1';
			when S_Closed =>
				closed_sig <= '1';
			when others =>
				open_sig <= '0';
				full_sig <= '0';
				closed_sig <= '0';
		end case;
	end process;
end FSM_arch;

LIBRARY IEEE;
USE IEEE.STD_LOGIC_1164.ALL;
USE IEEE.NUMERIC_STD.ALL;

-- Configuration declaration
CONFIGURATION parking_controller_cfg OF parking_controller IS
  FOR FSM_arch
  END FOR;
END CONFIGURATION;
