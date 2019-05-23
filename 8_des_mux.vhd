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
	k_start		: 	in 	std_ulogic_vector(1 to NB_DW);	-- key base
	c_target	:	in	std_ulogic_vector(1 to NB_DW) 	-- cyphertext
	k_high		:	out std_ulogic_vector(1 to NB_DW);	-- highest key
	k_right		:	out std_ulogic_vector(1 to NB_DW);	-- right key when found
	k_found		:	out std_ulogic;						-- set if key found
	
);
end des_mux;

architecture des_mux_arc of des_mux is
	
	signal k_mux is array 0 to DES_N-1 of std_ulogic_vector(1 downto NB_DW);
	signal c_mux is array 0 to DES_N-1 of std_ulogic_vector(1 downto NB_DW);

begin
	
	-- Generate N_DES k to be passed to the cracker(s)
	k_proc: process(k) 
		k_assign: for i in 0 to DES_N loop
			k_mux(i) <= std_logic_vector((unsigned(k)+unsigned(i), k_mux(i)'length);
		end loop;
	end process;
	
	-- Generate DES_N cracker that operates in parallel
	des_mux_gen : for i in 0 to DES_N-1 generate
		des_ent: des	generic map (NB_DW, NB_W, NB_K, NB_KE, NB_KEH)
						port map (clk, rst, en, p, k_mux(i), c_mux(i))
	end generate des_mux_gen;
	
	--Process to check if a key is the right one 
	check_found: process(c_mux, c_target, k_mux)
		k_found <= '0';
		k_right <= (others => '0');

		for i in 0 to DES_N-1 loop
			if (c_mux(i) = c_target) then
				k_found := '1';
				k_right := k_mux(i);
			end if;
		end loop;
	end process;


	k_high <= k_mux(DES_N-1);


end des_mux_arc;