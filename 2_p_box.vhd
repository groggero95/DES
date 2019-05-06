library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity p_box is
generic (	NB_I : integer := 64;
			NB_O : integer := 56;
			P_ARRAY : int_array := IP
	);
port( 
	d_in	: 	in 	std_ulogic_vector(1 to NB_I);
	p_out	:	out std_ulogic_vector(1 to NB_O)
);
end p_box;

architecture p_box_arc of p_box is

begin

	p_box_gen : for i in 1 to NB_O generate
		p_out(i) <= d_in(P_ARRAY(i));
	end generate;

end p_box_arc;
