library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des is
generic (	NB_DW  : integer := 64;
			NB_W   : integer := 32;
			NB_K   : integer := 48;
			NB_KE  : integer := 56;
			NB_KEH : integer := 28
	);
port( 
	clk	: 	in 	std_ulogic;
	rst	: 	in  std_ulogic;
	en 	: 	in  std_ulogic;
	p	: 	in 	std_ulogic_vector(1 to NB_DW); -- plaintext
	k	: 	in 	std_ulogic_vector(1 to NB_DW); -- input key
	k_c :	out std_ulogic_vector(1 to NB_KE); -- key of the current cyphertext
	c	:	out std_ulogic_vector(1 to NB_DW)  -- cyphertext
);
end des;

architecture des_arc of des is

	signal c_final 	: std_ulogic_vector(1 to NB_DW);
	signal k_start 	: std_ulogic_vector(1 to NB_DW);
	signal lr_n 	: ulogic64_array(0 to 16);
	signal lr_pipe 	: ulogic64_array(0 to 16);
	signal lr_rev 	: std_ulogic_vector(1 to NB_DW);
	signal k_c_pipe : std_ulogic_vector(1 to NB_KE);
	signal k_n 		: ulogic48_array(0 to 15);
	signal cd_n 	: ulogic56_array(0 to 16);
	signal cd_pipe 	: ulogic56_array(1 to 15);


begin

	des_gen : for i in 0 to 16 generate
		start_pipe : if (i = 0) generate

			-- Plaintext encryption part
			ff_init_c : dq_ff generic map (NB => NB_DW) port map (clk => clk ,rst => rst , en => en, D => p, Q => lr_pipe(i));
			init_c 	: p_box generic map (NB_I => NB_DW, NB_O => NB_DW, P_ARRAY => IP) port map (d_in => lr_pipe(i), p_out => lr_n(i));
			cypher_init_c : f generic map (NB_LR => NB_W, NB_K => NB_K, S_ARR => S_BOXES) port map (l_in => lr_n(i)(1 to NB_DW/2), r_in => lr_n(i)(NB_DW/2 + 1 to NB_DW), k_in => k_n(i), l_out => lr_n(i+1)(1 to NB_DW/2), r_out => lr_n(i+1)(NB_DW/2 + 1 to NB_DW));

			-- key generation part
			ff_init_k : dq_ff generic map (NB => NB_DW) port map (clk => clk ,rst => rst ,en => en,D => k,Q => k_start);
			init_k : p_box generic map (NB_I => NB_DW, NB_O => NB_KE, P_ARRAY => PC1) port map (d_in => k_start, p_out => cd_n(i));
			key_init_k : k_gen generic map (NB => NB_KEH, NB_K => NB_K, SH => SHIFT(i), P_ARRAY => PC2) port map (c_in => cd_n(i)(1 to NB_KE/2), d_in => cd_n(i)(NB_KE/2 + 1 to NB_KE), c_out => cd_n(i+1)(1 to NB_KE/2), d_out => cd_n(i+1)(NB_KE/2 + 1 to NB_KE), k_out => k_n(i));
		end generate start_pipe;

		middle_pipe : if (i /= 16 and i /=0) generate			

			-- Plaintext encryption part
			ff_c_i : dq_ff generic map (NB => NB_DW) port map (clk => clk, rst => rst, en => en, D => lr_n(i), Q => lr_pipe(i));
			cypher_i: f generic map (NB_LR => NB_W, NB_K => NB_K, S_ARR => S_BOXES) port map (l_in => lr_pipe(i)(1 to NB_DW/2), r_in => lr_pipe(i)(NB_DW/2 + 1 to NB_DW), k_in => k_n(i), l_out => lr_n(i+1)(1 to NB_DW/2), r_out => lr_n(i+1)(NB_DW/2 + 1 to NB_DW));

			-- key generation part
			ff_k_i : dq_ff generic map (NB => NB_KE) port map (clk => clk ,rst => rst ,en => en,D => cd_n(i),Q => cd_pipe(i));
			key_i : k_gen generic map (NB => NB_KEH, NB_K => NB_K, SH => SHIFT(i), P_ARRAY => PC2) port map (c_in => cd_pipe(i)(1 to NB_KE/2), d_in => cd_pipe(i)(NB_KE/2 + 1 to NB_KE), c_out => cd_n(i+1)(1 to NB_KE/2), d_out => cd_n(i+1)(NB_KE/2 + 1 to NB_KE), k_out => k_n(i));

		end generate middle_pipe;


		end_pipe: if (i = 16) generate

			-- In the last iteraation we do not reverse L and R so restore them
			lr_rev <=  lr_n(i)(NB_DW/2+1 to NB_DW) & lr_n(i)(1 to NB_DW/2);

			-- Plaintext encryption part
			last_c 	: p_box generic map (NB_I => NB_DW, NB_O => NB_DW, P_ARRAY => FP) port map (d_in => lr_rev, p_out => c_final);
			ff_last : dq_ff generic map (NB => NB_DW) port map (clk => clk, rst => rst, en => en, D => c_final, Q => c);
		end generate end_pipe;
	end generate des_gen;

	-- This p bos is used to rebuilt a 56 bit version of the input key, i.e. without 
	k_reb 		: p_box generic map (NB_I => NB_KE, NB_O => NB_KE, P_ARRAY => PC1_INV) port map (d_in => cd_n(16), p_out => k_c_pipe);
	ff_key_reb 	: dq_ff generic map (NB => NB_KE) port map (clk => clk, rst => rst, en => en, D => k_c_pipe, Q => k_c);

end des_arc;