library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des_mux is
generic (	NB_DW  : integer := 64;
			NB_W   : integer := 32;
			NB_K   : integer := 48;
			NB_KE  : integer := 56;
			NB_KEH : integer := 28;
			DES_N	: natural := NDES
	);
port( 
	clk			: 	in 	std_ulogic;
	rst			: 	in  std_ulogic;
	en			: 	in  std_ulogic;
	p			: 	in 	std_ulogic_vector(1 to NB_DW);	-- plaintext
	k_start		: 	in 	std_ulogic_vector(1 to NB_KE);	-- key base
	c_target	:	in	std_ulogic_vector(1 to NB_DW); 	-- cyphertext
	k_high		:	out std_ulogic_vector(1 to NB_KE);	-- highest key
	k_right		:	out std_ulogic_vector(1 to NB_KE);	-- right key when found
	k_found		:	out std_ulogic						-- set if key found
);
end des_mux;

architecture des_mux_arc of des_mux is
	
	signal k_mux: ulogic64_array(0 to DES_N-1); 
	signal c_mux: ulogic64_array(0 to DES_N-1); 
	signal k_result: ulogic56_array(0 to DES_N-1); 
	signal valid : std_ulogic_vector(16 downto 0);

begin
	
	-- Generate N_DES k to be passed to the cracker(s)
	k_proc: process(k_start)
	   variable k_temp : std_ulogic_vector(NB_KE-1 downto 0);
	begin
		k_assign: for i in 0 to DES_N-1 loop
			k_temp := std_ulogic_vector(unsigned(k_start) + i);
			k_mux(i) <=  k_temp(55 downto 49) & '0' & k_temp(48 downto 42) & '0' & k_temp(41 downto 35) & '0' & k_temp(34 downto 28) & '0' & k_temp(27 downto 21) & '0' & k_temp(20 downto 14) & '0' & k_temp(13 downto 7) & '0' & k_temp(6 downto 0) & '0';
		end loop;
	end process;
	
	-- Generate DES_N cracker that operates in parallel
	des_mux_gen : for i in 0 to DES_N-1 generate
		des_ent: des	generic map (NB_DW => NB_DW, NB_W => NB_W, NB_K => NB_K, NB_KE => NB_KE, NB_KEH => NB_KEH)
						port map (clk => clk, rst => rst, en => en, p => p, k => k_mux(i), k_c => k_result(i), c => c_mux(i));
	end generate des_mux_gen;

	en_shr : process (clk)
	begin
		if (clk'event and clk = '1') then
			if en = '0' then 
				valid <= (others => '0');
			else
				shr_loop : for i in 0 to 16 loop
					if (i = 0) then
						valid(i) <= en;
					else
						valid(i) <= valid(i-1);
					end if;
				end loop;
			end if;
		end if;
	end process en_shr;
	
	--Process to check if a key is the right one 
	check_found: process(c_mux, c_target, k_result, valid(16))
	begin
		k_found <= '0';
		k_right <= (others => '0');
		for i in 0 to DES_N-1 loop
			if (c_mux(i) = c_target) and valid(16) = '1' then
				k_found <= '1';
				k_right <= k_result(i);
			end if;
		end loop;
	end process;


	k_high <= k_result(DES_N-1);


end des_mux_arc;