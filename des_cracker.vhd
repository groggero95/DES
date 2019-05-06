library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des_cracker is
generic (	NB_DW  : integer := 64;
			NB_W   : integer := 32;
			NB_K   : integer := 48;
			NB_KE  : integer := 56;
			NB_KEH : integer := 28
	);
port( 
	aclk			: 	in 	std_ulogic;
	aresetn			: 	in  std_ulogic;
	s0_axi_araddr	: 	in 	std_ulogic_vector(11 downto 0);	
	s0_axi_arvalid	: 	in 	std_ulogic;	
	s0_axi_arready	: 	out	std_ulogic;	
	s0_axi_awaddr	: 	in 	std_ulogic_vector(11 downto 0);	
	s0_axi_awvalid	: 	in 	std_ulogic;	
	s0_axi_awready	: 	out	std_ulogic_vector(11 downto 0);	
	s0_axi_wdata	: 	in 	std_ulogic_vector(31 downto 0);	
	s0_axi_wstrb	: 	in 	std_ulogic_vector( 3 downto 0);	
	s0_axi_wvalid	: 	in 	std_ulogic;	
	s0_axi_wready	: 	out	std_ulogic;	
	s0_axi_rdata	: 	out	std_ulogic_vector(31 downto 0);	
	s0_axi_rresp	: 	out	std_ulogic_vector( 1 downto 0);	
	s0_axi_rvalid	: 	out	std_ulogic;	
	s0_axi_rready	: 	in 	std_ulogic;	
	s0_axi_bresp	: 	out	std_ulogic_vector( 1 downto 0);	
	s0_axi_bvalid	: 	out	std_ulogic;	
	s0_axi_bready	: 	in 	std_ulogic;	
	irq				: 	out	std_ulogic;	
	led				: 	out	std_ulogic_vector( 3 downto 0)
);
end des_cracker;

architecture rtl of des_cracker is

	signal p  : std_ulogic_vector(63 downto 0)
	signal c  : std_ulogic_vector(63 downto 0)
	signal k0 : std_ulogic_vector(55 downto 0)
	signal k  : std_ulogic_vector(55 downto 0)
	signal k1 : std_ulogic_vector(55 downto 0)

begin


end rtl;