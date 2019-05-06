library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity f is
generic (	NB_LR : integer := 32;
			NB_K  : integer := 48;
			S_ARR : s_array := S_BOXES
	);
port( 
	l_in	: 	in 	std_ulogic_vector(1 to NB_LR);
	r_in	: 	in 	std_ulogic_vector(1 to NB_LR);
	k_in	: 	in 	std_ulogic_vector(1 to NB_K);
	l_out	:	out std_ulogic_vector(1 to NB_LR);
	r_out	:	out std_ulogic_vector(1 to NB_LR)
);
end f;

architecture f_arc of f is

	signal r_exp : std_ulogic_vector(1 to NB_K);
	signal r_xor : std_ulogic_vector(1 to NB_K);
	signal r_box : std_ulogic_vector(1 to NB_LR);
	signal r_per : std_ulogic_vector(1 to NB_LR);


begin

	expansion : p_box generic map (NB_I => NB_LR, NB_O => NB_K, P_ARRAY => E) port map (d_in => r_in, p_out => r_exp);

	r_xor <= r_exp xor k_in;

	substitution : s_box generic map (NB_I => NB_K, NB_O => NB_LR, S_ARR => S_ARR) port map (r_ex => r_xor,s_out => r_box);

	permutation : p_box generic map (NB_I => NB_LR, NB_O => NB_LR, P_ARRAY => P) port map (d_in => r_box, p_out => r_per);

	l_out <= r_in;

	r_out <= r_per xor l_in;

end f_arc;