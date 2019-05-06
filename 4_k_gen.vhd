library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity k_gen is
generic (	NB   : integer := 28;
			NB_K : integer := 48;
			SH   : integer :=  1;
			P_ARRAY : int_array := PC1
	);
port( 
	c_in	: 	in 	std_ulogic_vector(1 to NB);
	d_in	: 	in 	std_ulogic_vector(1 to NB);
	c_out	:	out std_ulogic_vector(1 to NB);
	d_out	:	out std_ulogic_vector(1 to NB);
	k_out	:	out std_ulogic_vector(1 to NB_K)
);
end k_gen;

architecture k_gen_arc of k_gen is

	signal c_sh : std_ulogic_vector(1 to NB);
	signal d_sh : std_ulogic_vector(1 to NB);
	signal k_in : std_ulogic_vector(1 to NB_K+8);

begin

	c_sh <= std_ulogic_vector(rotate_left(unsigned(c_in),SH));
	d_sh <= std_ulogic_vector(rotate_left(unsigned(d_in),SH));

	k_in <= c_sh & d_sh;

	k_permutation : p_box generic map (NB_I => NB_K+8, NB_O => NB_K, P_ARRAY => PC2) port map (d_in => k_in, p_out => k_out);

	c_out <= c_sh;
	d_out <= d_sh;

end k_gen_arc;