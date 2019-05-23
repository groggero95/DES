library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des_tb is
generic (	NB : integer := 64
	);
end des_tb;

architecture des_tb_arc of des_tb is

	signal clk	: std_ulogic := '0';
	signal rst	: std_ulogic := '0';
	signal en 	: std_ulogic := '0';
	signal p	: std_ulogic_vector(1 to NB); -- plaintext
	signal k	: std_ulogic_vector(1 to NB); -- key
	signal c	: std_ulogic_vector(1 to NB); -- cyphertext
	signal k_c 	: std_ulogic_vector(1 to NB-8);

begin

	clk <= not clk after 0.5 ns;

	rst <= '1' after 1.5 ns;

	en <= '1' after 1.7 ns;

	k <= x"133457799BBCDFF1";

	p <= x"0123456789ABCDEF";

	dut : des port map (clk => clk, rst => rst, en => en, p => p, k => k, k_c => k_c, c => c);	

end architecture des_tb_arc;

