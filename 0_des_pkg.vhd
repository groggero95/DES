library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;

package des_pkg is

	type int_array is array (integer range <>) of integer;
	type vect_matrix is array (integer range <>, integer range <>) of std_ulogic_vector(1 to 4);
	type ulogic64_array is array (integer range <>) of std_ulogic_vector(1 to 64);
	type ulogic56_array is array (integer range <>) of std_ulogic_vector(1 to 56);
	type ulogic48_array is array (integer range <>) of std_ulogic_vector(1 to 48);
	type ulogic2_array is array (integer range <>) of std_ulogic_vector(1 to 2);
	type s_array is array (1 to 8) of vect_matrix(0 to 3, 0 to 15);



	constant NB : integer := 32; 

	-- Used to generate subkeys
	constant PC1 : int_array(1 to 56) :=   (57, 49, 41, 33, 25, 17,  9,
											 1, 58, 50, 42, 34, 26, 18,
											10,  2, 59, 51, 43, 35, 27,
											19, 11,  3, 60, 52, 44, 36,
											63, 55, 47, 39, 31, 23, 15,
											 7, 62, 54, 46, 38, 30, 22,
											14,  6, 61, 53, 45, 37, 29,
											21, 13,  5, 28, 20, 12,  4);

	-- Used to generate subkeys
	constant PC2 : int_array(1 to 48) :=   (14, 17, 11, 24,  1,  5,
											 3, 28, 15,  6, 21, 10,
											23, 19, 12,  4, 26,  8,
											16,  7, 27, 20, 13,  2,
											41, 52, 31, 37, 47, 55,
											30, 40, 51, 45, 33, 48,
											44, 49, 39, 56, 34, 53,
											46, 42, 50, 36, 29, 32);


	-- Used to permutate the plaintext
	constant IP : int_array(1 to 64) :=    (58, 50, 42, 34, 26, 18, 10, 2,
											60, 52, 44, 36, 28, 20, 12, 4,
											62, 54, 46, 38, 30, 22, 14, 6,
											64, 56, 48, 40, 32, 24, 16, 8,
											57, 49, 41, 33, 25, 17,  9, 1,
											59, 51, 43, 35, 27, 19, 11, 3,
											61, 53, 45, 37, 29, 21, 13, 5,
											63, 55, 47, 39, 31, 23, 15, 7);


	-- Used expand the plaintext
	constant E : int_array(1 to 48) := (32,  1,  2,  3,  4,  5,
										 4,  5,  6,  7,  8,  9,
										 8,  9, 10, 11, 12, 13,
										12, 13, 14, 15, 16, 17,
										16, 17, 18, 19, 20, 21,
										20, 21, 22, 23, 24, 25,
										24, 25, 26, 27, 28, 29,
										28, 29, 30, 31, 32,  1);

		-- Used encrypt the plaintext
	constant S0 : vect_matrix(0 to 3, 0 to 15) := (("1110", "0100", "1101", "0001", "0010", "1111", "1011", "1000", "0011", "1010", "0110", "1100", "0101", "1001", "0000", "0111"),
												   ("0000", "1111", "0111", "0100", "1110", "0010", "1101", "0001", "1010", "0110", "1100", "1011", "1001", "0101", "0011", "1000"),
												   ("0100", "0001", "1110", "1000", "1101", "0110", "0010", "1011", "1111", "1100", "1001", "0111", "0011", "1010", "0101", "0000"),
												   ("1111", "1100", "1000", "0010", "0100", "1001", "0001", "0111", "0101", "1011", "0011", "1110", "1010", "0000", "0110", "1101"));


			-- Used encrypt the plaintext
	constant S1 : vect_matrix(0 to 3, 0 to 15) := (("1111", "0001", "1000", "1110", "0110", "1011", "0011", "0100", "1001", "0111", "0010", "1101", "1100", "0000", "0101", "1010"),
												  ( "0011", "1101", "0100", "0111", "1111", "0010", "1000", "1110", "1100", "0000", "0001", "1010", "0110", "1001", "1011", "0101"),
												  ( "0000", "1110", "0111", "1011", "1010", "0100", "1101", "0001", "0101", "1000", "1100", "0110", "1001", "0011", "0010", "1111"),
												  ( "1101", "1000", "1010", "0001", "0011", "1111", "0100", "0010", "1011", "0110", "0111", "1100", "0000", "0101", "1110", "1001"));



		-- Used encrypt the plaintext
	constant S2 : vect_matrix(0 to 3, 0 to 15) := (("1010", "0000", "1001", "1110", "0110", "0011", "1111", "0101", "0001", "1101", "1100", "0111", "1011", "0100", "0010", "1000"),
												  ( "1101", "0111", "0000", "1001", "0011", "0100", "0110", "1010", "0010", "1000", "0101", "1110", "1100", "1011", "1111", "0001"),
												  ( "1101", "0110", "0100", "1001", "1000", "1111", "0011", "0000", "1011", "0001", "0010", "1100", "0101", "1010", "1110", "0111"),
												  ( "0001", "1010", "1101", "0000", "0110", "1001", "1000", "0111", "0100", "1111", "1110", "0011", "1011", "0101", "0010", "1100"));


		-- Used encrypt the plaintext
	constant S3 : vect_matrix(0 to 3, 0 to 15) := (("0111", "1101", "1110", "0011", "0000", "0110", "1001", "1010", "0001", "0010", "1000", "0101", "1011", "1100", "0100", "1111"),
												  ( "1101", "1000", "1011", "0101", "0110", "1111", "0000", "0011", "0100", "0111", "0010", "1100", "0001", "1010", "1110", "1001"),
												  ( "1010", "0110", "1001", "0000", "1100", "1011", "0111", "1101", "1111", "0001", "0011", "1110", "0101", "0010", "1000", "0100"),
												  ( "0011", "1111", "0000", "0110", "1010", "0001", "1101", "1000", "1001", "0100", "0101", "1011", "1100", "0111", "0010", "1110"));


		-- Used encrypt the plaintext
	constant S4 : vect_matrix(0 to 3, 0 to 15) := (("0010", "1100", "0100", "0001", "0111", "1010", "1011", "0110", "1000", "0101", "0011", "1111", "1101", "0000", "1110", "1001"),
												  ( "1110", "1011", "0010", "1100", "0100", "0111", "1101", "0001", "0101", "0000", "1111", "1010", "0011", "1001", "1000", "0110"),
												  ( "0100", "0010", "0001", "1011", "1010", "1101", "0111", "1000", "1111", "1001", "1100", "0101", "0110", "0011", "0000", "1110"),
												  ( "1011", "1000", "1100", "0111", "0001", "1110", "0010", "1101", "0110", "1111", "0000", "1001", "1010", "0100", "0101", "0011"));


		-- Used encrypt the plaintext
	constant S5 : vect_matrix(0 to 3, 0 to 15) := (("1100", "0001", "1010", "1111", "1001", "0010", "0110", "1000", "0000", "1101", "0011", "0100", "1110", "0111", "0101", "1011"),
												  ( "1010", "1111", "0100", "0010", "0111", "1100", "1001", "0101", "0110", "0001", "1101", "1110", "0000", "1011", "0011", "1000"),
												  ( "1001", "1110", "1111", "0101", "0010", "1000", "1100", "0011", "0111", "0000", "0100", "1010", "0001", "1101", "1011", "0110"),
												  ( "0100", "0011", "0010", "1100", "1001", "0101", "1111", "1010", "1011", "1110", "0001", "0111", "0110", "0000", "1000", "1101"));


		-- Used encrypt the plaintext
	constant S6 : vect_matrix(0 to 3, 0 to 15) := (("0100", "1011", "0010", "1110", "1111", "0000", "1000", "1101", "0011", "1100", "1001", "0111", "0101", "1010", "0110", "0001"),
												  ( "1101", "0000", "1011", "0111", "0100", "1001", "0001", "1010", "1110", "0011", "0101", "1100", "0010", "1111", "1000", "0110"),
												  ( "0001", "0100", "1011", "1101", "1100", "0011", "0111", "1110", "1010", "1111", "0110", "1000", "0000", "0101", "1001", "0010"),
												  ( "0110", "1011", "1101", "1000", "0001", "0100", "1010", "0111", "1001", "0101", "0000", "1111", "1110", "0010", "0011", "1100"));


		-- Used encrypt the plaintext
	constant S7 : vect_matrix(0 to 3, 0 to 15) := (("1101", "0010", "1000", "0100", "0110", "1111", "1011", "0001", "1010", "1001", "0011", "1110", "0101", "0000", "1100", "0111"),
												  ( "0001", "1111", "1101", "1000", "1010", "0011", "0111", "0100", "1100", "0101", "0110", "1011", "0000", "1110", "1001", "0010"),
												  ( "0111", "1011", "0100", "0001", "1001", "1100", "1110", "0010", "0000", "0110", "1010", "1101", "1111", "0011", "0101", "1000"),
												  ( "0010", "0001", "1110", "0111", "0100", "1010", "1000", "1101", "1111", "1100", "1001", "0000", "0011", "0101", "0110", "1011"));


	constant P : int_array(1 to 32) := (16,  7, 20, 21,
										29, 12, 28, 17,
										 1, 15, 23, 26,
										 5, 18, 31, 10,
										 2,  8, 24, 14,
										32, 27,  3,  9,
										19, 13, 30,  6,
										22, 11,  4, 25);


	constant FP : int_array(1 to 64) := (40, 8, 48, 16, 56, 24, 64, 32,
										 39, 7, 47, 15, 55, 23, 63, 31,
										 38, 6, 46, 14, 54, 22, 62, 30,
										 37, 5, 45, 13, 53, 21, 61, 29,
										 36, 4, 44, 12, 52, 20, 60, 28,
										 35, 3, 43, 11, 51, 19, 59, 27,
										 34, 2, 42, 10, 50, 18, 58, 26,
										 33, 1, 41,  9, 49, 17, 57, 25);


	constant SHIFT : int_array(0 to 15) := (1, 1, 2, 2, 2, 2, 2, 2, 1, 2, 2, 2, 2, 2, 2, 1);

	constant S_BOXES : s_array := (S0, S1, S2, S3, S4, S5, S6, S7); 


	component dq_ff 
	generic (	NB : integer := 32
		);
	port( 
		clk	: 	in 	std_ulogic;
		rst	:   in  std_ulogic;
		en	: 	in  std_ulogic;
		D 	: 	in 	std_ulogic_vector(1 to NB);
		Q	:	out std_ulogic_vector(1 to NB)
	);
	end component;

	component p_box
	generic (	NB_I : integer := 64;
				NB_O : integer := 56;
				P_ARRAY : int_array := IP
		);
	port( 
		d_in	: 	in 	std_ulogic_vector(1 to NB_I);
		p_out	:	out std_ulogic_vector(1 to NB_O)
	);
	end component;

	component s_box
	generic (	NB_I : integer := 48;
				NB_O : integer := 32;
				S_ARR : s_array := S_BOXES
		);
	port( 
		r_ex	: 	in 	std_ulogic_vector(1 to NB_I);
		s_out	:	out std_ulogic_vector(1 to NB_O)
	);
	end component;


	component k_gen
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
	end component;

	component f 
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
	end component;

	component des
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
		p	: 	in 	std_ulogic_vector(1 to NB_DW);	-- plaintext
		k	: 	in 	std_ulogic_vector(1 to NB_DW); -- key
		c	:	out std_ulogic_vector(1 to NB_DW) 	-- cyphertext
	);
	end component;

end des_pkg;


package body des_pkg is

end des_pkg;

--[14,  4, 13,  1,  2, 15, 11,  8,  3, 10,  6, 12,  5,  9,  0,  7,
-- 0, 15,  7,  4, 14,  2, 13,  1, 10,  6, 12, 11,  9,  5,  3,  8,
-- 4,  1, 14,  8, 13,  6,  2, 11, 15, 12,  9,  7,  3, 10,  5,  0,
--15, 12,  8,  2,  4,  9,  1,  7,  5, 11,  3, 14, 10,  0,  6, 13]

--[15,  1,  8, 14,  6, 11,  3,  4,  9,  7,  2, 13, 12,  0,  5, 10,
-- 3, 13,  4,  7, 15,  2,  8, 14, 12,  0,  1, 10,  6,  9, 11,  5,
-- 0, 14,  7, 11, 10,  4, 13,  1,  5,  8, 12,  6,  9,  3,  2, 15,
--13,  8, 10,  1,  3, 15,  4,  2, 11,  6,  7, 12,  0,  5, 14,  9]

--[10,  0,  9, 14,  6,  3, 15,  5,  1, 13, 12,  7, 11,  4,  2,  8,
--13,  7,  0,  9,  3,  4,  6, 10,  2,  8,  5, 14, 12, 11, 15,  1,
--13,  6,  4,  9,  8, 15,  3,  0, 11,  1,  2, 12,  5, 10, 14,  7,
-- 1, 10, 13,  0,  6,  9,  8,  7,  4, 15, 14,  3, 11,  5,  2, 12]

--[ 7, 13, 14,  3,  0,  6,  9, 10,  1,  2,  8,  5, 11, 12,  4, 15,
--13,  8, 11,  5,  6, 15,  0,  3,  4,  7,  2, 12,  1, 10, 14,  9,
--10,  6,  9,  0, 12, 11,  7, 13, 15,  1,  3, 14,  5,  2,  8,  4,
-- 3, 15,  0,  6, 10,  1, 13,  8,  9,  4,  5, 11, 12,  7,  2, 14]


--[ 2, 12,  4,  1,  7, 10, 11,  6,  8,  5,  3, 15, 13,  0, 14,  9,
--14, 11,  2, 12,  4,  7, 13,  1,  5,  0, 15, 10,  3,  9,  8,  6,
-- 4,  2,  1, 11, 10, 13,  7,  8, 15,  9, 12,  5,  6,  3,  0, 14,
--11,  8, 12,  7,  1, 14,  2, 13,  6, 15,  0,  9, 10,  4,  5,  3]

--[12,  1, 10, 15,  9,  2,  6,  8,  0, 13,  3,  4, 14,  7,  5, 11,
--10, 15,  4,  2,  7, 12,  9,  5,  6,  1, 13, 14,  0, 11,  3,  8,
-- 9, 14, 15,  5,  2,  8, 12,  3,  7,  0,  4, 10,  1, 13, 11,  6,
-- 4,  3,  2, 12,  9,  5, 15, 10, 11, 14,  1,  7,  6,  0,  8, 13]


--[ 4, 11,  2, 14, 15,  0,  8, 13,  3, 12,  9,  7,  5, 10,  6,  1,
--13,  0, 11,  7,  4,  9,  1, 10, 14,  3,  5, 12,  2, 15,  8,  6,
-- 1,  4, 11, 13, 12,  3,  7, 14, 10, 15,  6,  8,  0,  5,  9,  2,
-- 6, 11, 13,  8,  1,  4, 10,  7,  9,  5,  0, 15, 14,  2,  3, 12]

--[13,  2,  8,  4,  6, 15, 11,  1, 10,  9,  3, 14,  5,  0, 12,  7,
-- 1, 15, 13,  8, 10,  3,  7,  4, 12,  5,  6, 11,  0, 14,  9,  2,
-- 7, 11,  4,  1,  9, 12, 14,  2,  0,  6, 10, 13, 15,  3,  5,  8,
-- 2,  1, 14,  7,  4, 10,  8, 13, 15, 12,  9,  0,  3,  5,  6, 11]

--def aaa(a):
--    for i,j in enumerate(a):
--            k = '{0:04b}'.format(j)
--            if (i+1) % 16 == 0:
--                    sys.stdout.write("\"" + k + "\"\n" )
--            else:
--                    sys.stdout.write("\"" + k + "\", " )
