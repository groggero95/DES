library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des_mux_tb is
generic (	NB : integer := 64
	);
end des_mux_tb;

architecture des_mux_tb_arc of des_mux_tb is

	signal clk		: std_ulogic := '0';
	signal rst		: std_ulogic := '0';
	signal en 		: std_ulogic := '0';
	signal p		: std_ulogic_vector(1 to NB) := (others => '0'); -- plaintext
	signal k_start	: std_ulogic_vector(1 to NB-8) := (others => '0'); -- key
	signal c_target	: std_ulogic_vector(1 to NB) := (others => '0'); -- cyphertext
	signal k_high	: std_ulogic_vector(1 to NB-8);
	signal k_right	: std_ulogic_vector(1 to NB-8);
	signal k_found	: std_ulogic;

begin

	clk <= not clk after 0.5 ns;

	rst <= '1' after 1 ns;

	en <= '1' after 1 ns;

--	k_start <= x"12695bc9b7b7f8";
	process
	begin
		k_start <= (others => '0');
		wait for 1 ns;
		k_start <= x"12695bc9b7b7e4";
		wait until rising_edge(clk);
		loop
			k_start <= std_ulogic_vector(unsigned(k_start) + NDES);
			wait until rising_edge(clk);
		end loop;
	end process;


	p <= x"0123456789ABCDEF" after 1 ns;

	c_target <= x"85E813540F0AB405" after 1 ns;

	dut : des_mux port map (clk => clk, rst => rst, en => en, p => p, k_start => k_start, c_target => c_target, k_high => k_high, k_right => k_right, k_found => k_found);	

end architecture des_mux_tb_arc;

