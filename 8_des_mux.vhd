library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des_mux is
	generic (
			NB_DW  : integer := 64;
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
	signal c_mux_high: ulogic32_array(0 to DES_N-1);
	signal c_mux_low: ulogic32_array(0 to DES_N-1);
	signal k_found_high: ulogic_array(0 to DES_N-1);
	signal k_found_low: ulogic_array(0 to DES_N-1);
	signal k_result: ulogic56_array(0 to DES_N-1);
	signal c_target_high: std_ulogic_vector(1 to 32);
	signal c_target_low: std_ulogic_vector(1 to 32);
	signal valid : std_ulogic_vector(16 downto 0);

	-- Signals for additional stage
	signal k_f_buf_l: ulogic_array(0 to DES_N-1);
	signal k_f_buf_h: ulogic_array(0 to DES_N-1);
	signal k_res_buf: ulogic56_array(0 to DES_N-1);


begin

	-- Split the ciphertext
	c_target_low	<= c_target(1 to 32);
	c_target_high	<= c_target(33 to 64);
	-- Generate N_DES k to be passed to the cracker(s)
	k_proc: process(k_start)
		variable k_temp : std_ulogic_vector(NB_KE-1 downto 0);
	begin
		k_assign: for i in 0 to DES_N-1 loop
			k_temp := std_ulogic_vector(unsigned(k_start) + i);
			k_mux(i) <=  exp_inv(k_temp);
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

	ciph_split: process(c_mux)
	begin
		for i in 0 to DES_N-1 loop
			c_mux_high(i)	<= c_mux(i)(33 to 64);
			c_mux_low(i)	<= c_mux(i)(1 to 32);
		end loop;
	end process;

	--Process to compare higher part of the keys
	check_high: process(c_mux_high, c_target_high, valid(16))
	begin
		for i in 0 to DES_N-1 loop
			if ((c_mux_high(i) = c_target_high) and valid(16) = '1') then
				k_found_high(i) <= '1';
			else
				k_found_high(i) <= '0';
			end if;
		end loop;
	end process;

	-- Process to compare lower part of the keys
	check_low: process(c_mux_low, c_target_low, valid(16))
	begin
		for i in 0 to DES_N-1 loop
			if ((c_mux_low(i) = c_target_low) and (valid(16) = '1')) then
				k_found_low(i) <= '1';
			else
				k_found_low(i) <= '0';
			end if;
		end loop;
	end process;

	int_check: process(clk)
	begin
		if clk'event and clk = '1' then
			if rst = '0' then
				for i in 0 to DES_N-1 loop
					k_f_buf_l(i) <= '0';
					k_f_buf_h(i) <= '0';
					k_res_buf(i) <= (others => '0');
				end loop;
			else
				k_f_buf_l <= k_found_low;
			   	k_f_buf_h <= k_found_high;
				k_res_buf <= k_result;
			end if;
		end if;
	end process;


	check_end: process(k_f_buf_l, k_f_buf_h, k_res_buf)
	begin
		k_found <= '0';
		k_right <= (others => '0');
		for i in 0 to DES_N-1 loop
			if ((k_f_buf_h(i) = '1') and (k_f_buf_l(i) = '1')) then
				k_found <= '1';
				k_right <= k_res_buf(i);
			end if;
		end loop;
	end process;

	k_high <= k_result(DES_N-1);


end des_mux_arc;