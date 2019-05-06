library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity dq_ff is
generic (	NB : integer := 32
	);
port( 
	clk	: 	in 	std_ulogic;
	rst	:   in  std_ulogic;
	en	: 	in  std_ulogic;
	D 	: 	in 	std_ulogic_vector(1 to NB);
	Q	:	out std_ulogic_vector(1 to NB)
);
end dq_ff;

architecture RTL_ASYNC of dq_ff is

begin

	process(clk,rst)
	begin
		if rst = '0' then
			Q <= (others  => '0');
		elsif clk'event and clk = '1' then 
			if en ='1' then
				Q <= D;
			end if;
		end if;
	end process;

end architecture ; -- RTL_ASYNC

architecture RTL_SYNC of dq_ff is

begin

	process(clk)
	begin

		if clk'event and clk = '1' then
			if rst = '0' then 
				Q <= (others  => '0');
			elsif en = '1' then
				Q <= D;
			end if;
		end if;
	end process;

end architecture ; -- RTL_SYNC

configuration dq_ff_ASYNC_CFG of dq_ff is
for RTL_ASYNC
end for;
end configuration dq_ff_ASYNC_CFG;

configuration dq_ff_SYNC_CFG of dq_ff is
for RTL_SYNC
end for;
end configuration dq_ff_SYNC_CFG;

