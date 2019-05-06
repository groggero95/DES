library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity s_box is
generic (	NB_I : integer := 48;
			NB_O : integer := 32;
			S_ARR : s_array := S_BOXES
	);
port( 
	r_ex	: 	in 	std_ulogic_vector(1 to NB_I);
	s_out	:	out std_ulogic_vector(1 to NB_O)
);
end s_box;

architecture s_box_arc of s_box is

	signal index : ulogic2_array(1 to NB_O/4);

begin

	s_box_gen : for i in 1 to NB_O/4 generate
		index(i) <= r_ex(i*6 - 5) & r_ex(i*6);
		s_out(i*4 - 3 to i*4) <= S_ARR(i)(to_integer(unsigned(index(i))), to_integer(unsigned( r_ex(i*6-4 to i*6-1))));
	end generate;

end s_box_arc;