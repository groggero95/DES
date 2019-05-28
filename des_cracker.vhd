library IEEE;
use IEEE.std_logic_1164.all;
use IEEE.numeric_std.all;
use work.des_pkg.all;

entity des_cracker is
generic (	NB_DW	: integer := 64;
			NB_W	: integer := 32;
			NB_K	: integer := 48;
			NB_KE	: integer := 56;
			NB_KEH	: integer := 28;
			DES_N	: integer := NDES
	);
port(
	aclk			: 	in 	std_ulogic;
	aresetn			: 	in  std_ulogic;
	s0_axi_araddr	: 	in 	std_ulogic_vector(11 downto 0);
	s0_axi_arvalid	: 	in 	std_ulogic;
	s0_axi_arready	: 	out	std_ulogic;
	s0_axi_awaddr	: 	in 	std_ulogic_vector(11 downto 0);
	s0_axi_awvalid	: 	in 	std_ulogic;
	s0_axi_awready	: 	out	std_ulogic;
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

	type state_axi is (IDLE,ACKRREQ,WAITACK);
	type state_attack is (START,FOUND,WAITING);
	type state_read_k is (WAIT_LOW,WAIT_HIGH);
	signal c_state_r, n_state_r, c_state_w, n_state_w : state_axi;
	signal c_state_a, n_state_a : state_attack;
	signal c_state_k, n_state_k : state_read_k;

	signal p		: std_ulogic_vector(63 downto 0);
	signal c		: std_ulogic_vector(63 downto 0);
	signal k0		: std_ulogic_vector(55 downto 0);
	signal k		: std_ulogic_vector(55 downto 0);
	signal k1		: std_ulogic_vector(55 downto 0);
	signal k_in		: std_ulogic_vector(55 downto 0);
	signal des_en	: std_ulogic;
	signal stall_k	: std_ulogic;
	signal k_high	: std_ulogic_vector(1 to NB_KE);
	signal k_right	: std_ulogic_vector(1 to NB_KE);
	signal k_found	: std_ulogic;

	constant OKAY : std_ulogic_vector(1 downto 0) := "00";
	constant EXOKAY : std_ulogic_vector(1 downto 0) := "01";
	constant SLVERR : std_ulogic_vector(1 downto 0) := "10";
	constant DECERR : std_ulogic_vector(1 downto 0) := "11";

begin

	des0 : des_mux  generic map	(NB_DW => NB_DW, NB_W => NB_W, NB_K => NB_K, NB_KE => NB_KE, NB_KEH => NB_KEH, DES_N => DES_N)
					port map 	(clk => aclk, rst => aresetn, en => des_en, p => p, k_start => k_in, c_target => c, k_high => k_high, k_right => k_right, k_found => k_found);


	nState : process(aclk)
	begin
		if rising_edge(aclk) then
			if aresetn = '0' then
				c_state_r <= IDLE;
				c_state_w <= IDLE;
				c_state_a <= WAITING;
				c_state_k <= WAIT_LOW;
			else
				c_state_r <= n_state_r;
				c_state_w <= n_state_w;
				c_state_a <= n_state_a;
				c_state_k <= n_state_k;
			end if;
		end if;
	end process ; -- nState

	readlogicIn : process(c_state_r,s0_axi_arvalid,s0_axi_rready)
	begin
		n_state_r <= c_state_r;
		case (c_state_r) is
			when IDLE 	=> 	if s0_axi_arvalid = '1' then
								n_state_r <= ACKRREQ;
							end if;

			when ACKRREQ => if s0_axi_rready = '1' then
								n_state_r <= IDLE;
							else
								n_state_r <= WAITACK;
							end if;

			when WAITACK => if s0_axi_rready = '1' then
								n_state_r <= IDLE;
							end if;

			when others =>	null;
		end case;

	end process ; -- readlogicIn

	readlogicOut : process(c_state_r)
	begin
		s0_axi_arready 	<= '0';
		s0_axi_rvalid 	<= '0';
		case (c_state_r) is
			when IDLE 		=>
								null;
			when ACKRREQ 	=>
								s0_axi_arready <= '1';
								s0_axi_rvalid <= '1';

			when WAITACK =>
								s0_axi_rvalid <= '1';

			when others =>		null;
		end case;

	end process ; -- readlogicOut

	readOutSync : process( aclk )
	begin
		if aclk'event and aclk = '1' then
			if aresetn = '0' then
				s0_axi_rresp <= (others => '0');
				s0_axi_rdata <= (others => '0');
			elsif n_state_r = ACKRREQ then
				case (s0_axi_araddr) is
					when "000000000000" | "000000000001" | "000000000010" | "000000000011"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= p(31 downto 0);
					when "000000000100" | "000000000101" | "000000000110" | "000000000111"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= p(63 downto 32);
					when "000000001000" | "000000001001" | "000000001010" | "000000001011"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= c(31 downto 0);
					when "000000001100" | "000000001101" | "000000001110" | "000000001111"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= c(63 downto 32);
					when "000000010000" | "000000010001" | "000000010010" | "000000010011"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= k0(31 downto 0);
					when "000000010100" | "000000010101" | "000000010110" | "000000010111"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= "00000000" & k0(55 downto 32);
					when "000000011000" | "000000011001" | "000000011010" | "000000011011"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= k(31 downto 0);
					when "000000011100" | "000000011101" | "000000011110" | "000000011111"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= "00000000" & k(55 downto 32);
					when "000000100000" | "000000100001" | "000000100010" | "000000100011"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= k1(31 downto 0);
					when "000000100100" | "000000100101" | "000000100110" | "000000100111"  =>	s0_axi_rresp <= OKAY;
																								s0_axi_rdata <= "00000000" & k1(55 downto 32);
					when others => 	s0_axi_rresp <= DECERR;
									s0_axi_rdata <= (others => '0');
				end case;
			end if;
		end if;
	end process ; -- readOutSync


	writelogicIn : process(c_state_w, s0_axi_wvalid, s0_axi_awvalid, s0_axi_bready)
	begin
		n_state_w <= c_state_w;
		case (c_state_w) is
			when IDLE 	=> 	if (s0_axi_awvalid = '1' and s0_axi_wvalid = '1') then
								n_state_w <= ACKRREQ;
							end if;

			when ACKRREQ => if s0_axi_bready = '1' then
								n_state_w <= IDLE;
							else
								n_state_w <= WAITACK;
							end if;

			when WAITACK => if s0_axi_bready = '1' then
								n_state_w <= IDLE;
							end if;

			when others =>	null;
		end case;

	end process ; -- writelogicIn

	writelogicOut : process(c_state_w)
	begin
		s0_axi_wready 	<= '0';
		s0_axi_awready 	<= '0';
		s0_axi_bvalid 	<= '0';
		case (c_state_w) is
			when IDLE		=> null;

			when ACKRREQ 	=>
							s0_axi_wready 	<= '1';
							s0_axi_awready 	<= '1';
							s0_axi_bvalid 	<= '1';

			when WAITACK =>
							s0_axi_bvalid 	<= '1';

			when others =>	null;
		end case;

	end process ; -- writelogicOut

	writeOutSync : process( aclk )
	begin
		if aclk'event and aclk = '1' then
			if aresetn = '0' then
				s0_axi_bresp <= (others => '0');
				p <= (others => '0');
				c <= (others => '0');
				k0 <= (others => '0');
			else
				if n_state_w = ACKRREQ then
					case (s0_axi_awaddr) is
						when "000000000000" | "000000000001" | "000000000010" | "000000000011"  =>	s0_axi_bresp <= OKAY;
																									p(31 downto 0) <= s0_axi_wdata;
						when "000000000100" | "000000000101" | "000000000110" | "000000000111"  =>	s0_axi_bresp <= OKAY;
																									p(63 downto 32) <= s0_axi_wdata;
						when "000000001000" | "000000001001" | "000000001010" | "000000001011"  =>	s0_axi_bresp <= OKAY;
																									c(31 downto 0) <= s0_axi_wdata;
						when "000000001100" | "000000001101" | "000000001110" | "000000001111"  =>	s0_axi_bresp <= OKAY;
																									c(63 downto 32) <= s0_axi_wdata;
						when "000000010000" | "000000010001" | "000000010010" | "000000010011"  =>	s0_axi_bresp <= OKAY;
																									k0(31 downto 0) <= s0_axi_wdata;
						when "000000010100" | "000000010101" | "000000010110" | "000000010111"  =>	s0_axi_bresp <= OKAY;
																									k0(55 downto 32) <= s0_axi_wdata(23 downto 0);
						when "000000011000" | "000000011001" | "000000011010" | "000000011011"  |
							 "000000011100" | "000000011101" | "000000011110" | "000000011111"  |
							 "000000100000" | "000000100001" | "000000100010" | "000000100011"  |
							 "000000100100" | "000000100101" | "000000100110" | "000000100111"  =>	s0_axi_bresp <= SLVERR;

						when others => 	s0_axi_bresp <= DECERR;
					end case;
				end if;
			end if;
		end if;
	end process ; -- writeOutSync


	attacklogicIn : process(c_state_a, n_state_w, s0_axi_awaddr,k_found)
	begin
		n_state_a <= c_state_a;
		case (c_state_a) is
			when WAITING => if n_state_w = ACKRREQ and s0_axi_awaddr(11 downto 2) = "0000000101" then
								n_state_a <= START;
							end if;

			when START => 	if n_state_w = ACKRREQ and s0_axi_awaddr(11 downto 2) = "0000000100" then
								n_state_a <= WAITING;
							elsif k_found = '1' then
								n_state_a <= FOUND;
							end if;

			when FOUND =>	n_state_a <= WAITING;

			when others =>	null;
		end case;

	end process ; -- attacklogicIn



	attacklogicOut : process(c_state_a)
	begin
		irq 	<= '0';
		des_en 	<= '0';
		case (c_state_a) is
			when WAITING =>	null;

			when START 	=> 	des_en <= '1';

			when FOUND	=> 	irq <= '1';

			when others =>	null;
		end case;

	end process ; -- attacklogicOut

	k1_reg : process (aclk)
	begin
		if (aclk'event and aclk = '1') then
			if (aresetn = '0') then
				k1 <= (others => '0');
			else
				if k_found = '1' then
					k1 <= k_right;
				end if;
			end if;
		end if;
	end process k1_reg;

	counter : process(aclk)
	begin
	  	if (aclk'event and aclk = '1') then
		  	if (n_state_a = START and c_state_a = WAITING) or aresetn = '0' then
	  			k_in <= s0_axi_wdata(23 downto 0) & k0(31 downto 0);
	  		else
	    		k_in <= std_ulogic_vector(unsigned(k_in) + DES_N);
		    end if;
	    end if;
	end process counter;


	led <= k(33 downto 30);

	k_reg : process (aclk)
	begin
		if (aclk'event and aclk = '1') then
			if (aresetn = '0') then
				k <= (others => '0');
			else
				if stall_k = '0' then
					k <= k_high;
				end if;
			end if;
		end if;
	end process k_reg;

	readKlogicIn : process(c_state_k, n_state_r, s0_axi_araddr)
	begin
		n_state_k <= c_state_k;
		case (c_state_k) is
			when WAIT_LOW => if n_state_r = ACKRREQ and s0_axi_araddr(11 downto 2) = "0000000110" then
								n_state_k <= WAIT_HIGH;
							end if;

			when WAIT_HIGH => if n_state_r = ACKRREQ and s0_axi_araddr(11 downto 2) = "0000000111" then
								n_state_k <= WAIT_LOW;
							end if;

			when others =>	null;
		end case;

	end process ; -- readKlogicIn



	readKlogicOut : process(c_state_k,n_state_k)
	begin
		stall_k <= '0';
		case (c_state_k) is
			when WAIT_LOW =>	if n_state_k = WAIT_HIGH then
									stall_k <= '1';
								end if;

			when WAIT_HIGH => 	if n_state_k /= WAIT_LOW then
									stall_k <= '1';
								end if;

			when others =>	null;
		end case;

	end process ; -- readKlogicOut


end rtl;
