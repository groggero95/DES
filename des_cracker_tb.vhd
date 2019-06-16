use std.env.all;
use std.textio.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.rnd_pkg.all;
use work.utils_pkg.all;


entity des_cracker_axi_wrapper_sim is
	generic(
	frequency_mhz: positive:= 1;
	start_us:      positive:= 200;
	warm_us:       positive:= 250
);
port(
		s0_axi_arready: out   std_ulogic;
		s0_axi_awready: out   std_ulogic;
		s0_axi_wready:  out   std_ulogic;
		s0_axi_rdata:   out   std_ulogic_vector(31 downto 0);
		s0_axi_rresp:   out   std_ulogic_vector(1 downto 0);
		s0_axi_rvalid:  out   std_ulogic;
		s0_axi_bresp:   out   std_ulogic_vector(1 downto 0);
		s0_axi_bvalid:  out   std_ulogic;
		data:           inout std_logic;
		led:            out   std_ulogic_vector(3 downto 0)
	);
end entity des_cracker_axi_wrapper_sim;

architecture sim of des_cracker_axi_wrapper_sim is

	constant axi_resp_okay:   std_ulogic_vector(1 downto 0) := "00";
	constant axi_resp_exokay: std_ulogic_vector(1 downto 0) := "01";
	constant axi_resp_slverr: std_ulogic_vector(1 downto 0) := "10";
	constant axi_resp_decerr: std_ulogic_vector(1 downto 0) := "11";

	constant period:          time := (1 ns) / real(frequency_mhz);
	constant startl_max:      natural := start_us + start_us / 10; -- Maximum of start low phase
	constant starth_max:      natural := 40; -- Maximum of start high phase
	constant acknowledge:     natural := 80; -- Acknowledge phases
	constant bitl:            natural := 50; -- Bit low phase
	constant bit1h:           natural := 70; -- Bit 1 high phase
	constant acquisition_max: natural := startl_max + starth_max + 2 * acknowledge + 40 * (bitl + bit1h) + bitl;

	signal aclk:            std_ulogic;
	signal aresetn:         std_ulogic;
	signal s0_axi_araddr:   std_ulogic_vector(11 downto 0);
	signal s0_axi_arvalid:  std_ulogic;
	signal s0_axi_rready:   std_ulogic;
	signal s0_axi_awaddr:   std_ulogic_vector(11 downto 0);
	signal s0_axi_awvalid:  std_ulogic;
	signal s0_axi_wdata:    std_ulogic_vector(31 downto 0);
	signal s0_axi_wstrb:    std_ulogic_vector(3 downto 0);
	signal s0_axi_wvalid:   std_ulogic;
	signal s0_axi_bready:   std_ulogic;

	signal dso:             std_ulogic;
	signal perr:            std_ulogic;
	signal cerr:            std_ulogic;
	signal irq:				std_ulogic;
	signal val:             std_ulogic_vector(39 downto 0);

	signal check:           boolean;
	signal last:            std_ulogic;
	signal last_perr:       std_ulogic;
	signal last_cerr:       std_ulogic;
	signal last_val:        std_ulogic_vector(39 downto 0);
	signal ok:              std_ulogic;
	signal ok_val:          std_ulogic_vector(39 downto 0);

	signal s0_axi_arready_ref: std_ulogic;
	signal s0_axi_rdata_ref:   std_ulogic_vector(31 downto 0);
	signal s0_axi_rresp_ref:   std_ulogic_vector(1 downto 0);
	signal s0_axi_rvalid_ref:  std_ulogic;
	signal s0_axi_awready_ref: std_ulogic;
	signal s0_axi_wready_ref:  std_ulogic;
	signal s0_axi_bresp_ref:   std_ulogic_vector(1 downto 0);
	signal s0_axi_bvalid_ref:  std_ulogic;

	signal led_ref:            std_ulogic_vector(3 downto 0);

begin

	process
	begin
		aclk <= '0';
		wait for period / 2;
		aclk <= '1';
		wait for period / 2;
	end process;

	-- Pull-up resistor
	data <= 'H';

	des_cracker0: entity work.des_cracker(rtl)
	generic map(
				   NB_DW   => 64,
				   NB_W    => 32,
				   NB_K    => 48,
				   NB_KE   => 56,
				   NB_KEH  => 28
			   )
	port map(
				aclk			=> aclk,
				aresetn			=> aresetn,
				s0_axi_araddr	=> s0_axi_araddr,
				s0_axi_arvalid	=> s0_axi_arvalid,
				s0_axi_arready	=> s0_axi_arready,
				s0_axi_awaddr	=> s0_axi_awaddr,
				s0_axi_awvalid	=> s0_axi_awvalid,
				s0_axi_awready	=> s0_axi_awready,
				s0_axi_wdata	=> s0_axi_wdata,
				s0_axi_wstrb	=> s0_axi_wstrb,
				s0_axi_wvalid	=> s0_axi_wvalid,
				s0_axi_wready	=> s0_axi_wready,
				s0_axi_rdata	=> s0_axi_rdata,
				s0_axi_rresp	=> s0_axi_rresp,
				s0_axi_rvalid	=> s0_axi_rvalid,
				s0_axi_rready	=> s0_axi_rready,
				s0_axi_bresp	=> s0_axi_bresp,
				s0_axi_bvalid	=> s0_axi_bvalid,
				s0_axi_bready	=> s0_axi_bready,
				irq				=> irq,
				led				=> led
			);

	-- Submit random AXI4 lite requests for read and write
	process
		variable l:   line;
		variable rg: rnd_generator;
	begin
		aresetn        <= '0';
		s0_axi_araddr  <= (others => '0');
		s0_axi_arvalid <= '0';
		s0_axi_rready  <= '0';
		s0_axi_awaddr  <= (others => '0');
		s0_axi_awvalid <= '0';
		s0_axi_wdata   <= (others => '0');
		s0_axi_wstrb   <= (others => '0');
		s0_axi_wvalid  <= '0';
		s0_axi_bready  <= '0';
		-- Reset for the cycles
		for i in 1 to 10 loop
			wait until rising_edge(aclk);
		end loop;
		aresetn <= '1';
		-- Start infinite loop
		loop
			wait until rising_edge(aclk);
			-- Write random acknowledge to the cracker
			s0_axi_rready <= rg.get_std_ulogic;
			s0_axi_bready <= rg.get_std_ulogic;
			-- In case the address is not valid or the axi has aknowledged a request
			-- update the read address with random value
			if s0_axi_arvalid = '0' or s0_axi_arready = '1' then
				s0_axi_araddr <= rg.get_std_ulogic_vector(12);
				-- One out of nine chance to use a garbage address
				if rg.get_integer(0, 9) /= 9 then
					s0_axi_araddr(11 downto 6) <= (others => '0');
				end if;
				-- Update randomly the valid flag for the cracker
				s0_axi_arvalid <= rg.get_std_ulogic;
			end if;
			-- Same thing for the write part
			if s0_axi_awvalid = '0' or s0_axi_awready = '1' then
				s0_axi_awaddr <= rg.get_std_ulogic_vector(12);
				if rg.get_integer(0, 9) /= 9 then
					s0_axi_awaddr(11 downto 5) <= (others => '0');
				end if;
				s0_axi_awvalid <= rg.get_std_ulogic;
			end if;
			if s0_axi_wvalid = '0' or s0_axi_wready = '1' then
				s0_axi_wdata  <= rg.get_std_ulogic_vector(32);
				s0_axi_wstrb  <= rg.get_std_ulogic_vector(4);
				s0_axi_wvalid <= rg.get_std_ulogic;
			end if;
		end loop;
	end process;

	-- Termination after nmax acquisitions, check periodicity of acquisitions,
	-- error if no acquisition in twice the warm-up time plus maximum
	-- acquisition time
	--process
	--	variable l:     line;
	--	constant nmax:  positive := 100;
	--begin
	--	wait until rising_edge(aclk) and aresetn = '0';
	--	wait until rising_edge(aclk) and aresetn = '1';
	--	for n in 1 to nmax loop
	--		wait until dso = '1' and rising_edge(aclk) for (acquisition_max + warm_us) * 2 us;
	--		if dso /= '1' then
	--			write(l, string'("NON REGRESSION TEST FAILED - "));
	--			write(l, now);
	--			writeline(output, l);
	--			write(l, string'("  NO ACQUISITION IN "));
	--			write(l, (acquisition_max + warm_us) * 2 us);
	--			writeline(output, l);
	--			finish;
	--		end if;
	--		wait until dso = '0' and rising_edge(aclk);
	--	end loop;
	--	write(l, string'("NON REGRESSION TEST PASSED - "));
	--	write(l, now);
	--	writeline(output, l);
	--	finish;
	--end process;

	-- Compute reference values and check flag. Actual and reference values are
	-- compared only when check flag is true. Check flag is false until reset
	-- is asserted low and during 10 us after the DHT11 emulator outputs
	-- reference values.
	--process
	--begin
	--	check     <= false;
	--       wait until rising_edge(aclk) and aresetn = '0';
	--	check     <= true;
	--       last      <= '0';
	--       last_perr <= '0';
	--       last_cerr <= '0';
	--       last_val  <= (others => '0');
	--       ok        <= '0';
	--       ok_val    <= (others => '0');
	--       loop
	--           wait until rising_edge(aclk) and dso = '1';
	--           check <= false;
	--           wait for 10 us;
	--           wait until rising_edge(aclk);
	--           check     <= true;
	--           last      <= '1';
	--           last_perr <= perr;
	--           last_cerr <= cerr;
	--           last_val  <= val;
	--           if perr = '0' and cerr = '0' then
	--               ok      <= '1';
	--               ok_val  <= val;
	--           end if;
	--           wait until rising_edge(aclk) and dso = '0';
	--       end loop;
	--   end process;

	--led_ref <= (others => '-') when not check else ok & last & last_perr & last_cerr;

	-- Check unknowns
	process
	begin
		wait until rising_edge(aclk) and aresetn = '0';
		loop
			wait until rising_edge(aclk);
			check_unknowns(s0_axi_araddr, "s0_axi_araddr");
			check_unknowns(s0_axi_arvalid, "s0_axi_arvalid");
			check_unknowns(s0_axi_arready, "s0_axi_arready");
			check_unknowns(s0_axi_awaddr, "s0_axi_awaddr");
			check_unknowns(s0_axi_awvalid, "s0_axi_awvalid");
			check_unknowns(s0_axi_awready, "s0_axi_awready");
			check_unknowns(s0_axi_wdata, "s0_axi_wdata");
			check_unknowns(s0_axi_wstrb, "s0_axi_wstrb");
			check_unknowns(s0_axi_wvalid, "s0_axi_wvalid");
			check_unknowns(s0_axi_wready, "s0_axi_wready");
			check_unknowns(s0_axi_rdata, "s0_axi_rdata");
			check_unknowns(s0_axi_rresp, "s0_axi_rresp");
			check_unknowns(s0_axi_rvalid, "s0_axi_rvalid");
			check_unknowns(s0_axi_rready, "s0_axi_rready");
			check_unknowns(s0_axi_bresp, "s0_axi_bresp");
			check_unknowns(s0_axi_bvalid, "s0_axi_bvalid");
			check_unknowns(s0_axi_bready, "s0_axi_bready");
		end loop;
	end process;
	--
	--Reference slave behavior on AXI read channels. Use don't care values for no-check.
	process
		variable add: natural range 0 to 2**10 - 1;
	begin
		wait until rising_edge(aclk) and aresetn = '0';
		s0_axi_arready_ref <= '0';
		s0_axi_rvalid_ref  <= '0';
		s0_axi_rresp_ref   <= (others => '0');
		s0_axi_rdata_ref   <= (others => '0');
		wait until rising_edge(aclk) and aresetn = '1';
		loop
			if s0_axi_arvalid = '0' then
				wait until rising_edge(aclk) and s0_axi_arvalid = '1';
			end if;
			add := to_integer(unsigned(s0_axi_araddr(11 downto 2)));
			s0_axi_arready_ref <= '1';
			s0_axi_rvalid_ref  <= '1';
			if add < 10 then
				s0_axi_rresp_ref   <= axi_resp_okay;
			else
				s0_axi_rresp_ref   <= axi_resp_decerr;
			end if;
			wait until rising_edge(aclk);
			s0_axi_arready_ref <= '0';
			if s0_axi_rready = '0' then
				wait until rising_edge(aclk) and s0_axi_rready = '1';
			end if;
			s0_axi_rvalid_ref <= '0';
			wait until rising_edge(aclk);
		end loop;
	end process;

	process
	begin
		wait until rising_edge(aclk) and aresetn = '0';
		loop
			wait until rising_edge(aclk);
			check_ref(v => s0_axi_arready, r => s0_axi_arready_ref, s => "s0_axi_arready");
			--check_ref(v => s0_axi_rdata, r => s0_axi_rdata_ref, s => "s0_axi_rdata");
			check_ref(v => s0_axi_rresp, r => s0_axi_rresp_ref, s => "s0_axi_rresp");
			check_ref(v => s0_axi_rvalid, r => s0_axi_rvalid_ref, s => "s0_axi_rvalid");
		end loop;
	end process;

	--Reference slave behavior on AXI write channels. Use don't care values for no-check.
	process
		variable add: natural range 0 to 2**10 - 1;
	begin
		wait until rising_edge(aclk) and aresetn = '0';
		s0_axi_awready_ref <= '0';
		s0_axi_wready_ref  <= '0';
		s0_axi_bvalid_ref  <= '0';
		s0_axi_bresp_ref   <= (others => '0');
		wait until rising_edge(aclk) and aresetn = '1';
		loop
			if s0_axi_awvalid = '0' or s0_axi_wvalid = '0' then
				wait until rising_edge(aclk) and (s0_axi_awvalid = '1') and (s0_axi_wvalid = '1');
			end if;
			add := to_integer(unsigned(s0_axi_awaddr(11 downto 2)));
			s0_axi_awready_ref <= '1';
			s0_axi_wready_ref  <= '1';
			wait until rising_edge(aclk);
			if add < 6 then
				s0_axi_bresp_ref   <= axi_resp_okay;
			elsif add < 8 then
				s0_axi_bresp_ref   <= axi_resp_slverr;
			else
				s0_axi_bresp_ref   <= axi_resp_decerr;
			end if;
			s0_axi_awready_ref <= '0';
			s0_axi_wready_ref  <= '0';
			s0_axi_bvalid_ref  <= '1';
			wait until rising_edge(aclk);
			if s0_axi_bready = '0' then
				wait until rising_edge(aclk) and s0_axi_bready = '1';
			end if;
			s0_axi_bvalid_ref <= '0';
			wait until rising_edge(aclk);
		end loop;
	end process;

	process
	begin
		wait until rising_edge(aclk) and aresetn = '0';
		loop
			wait until rising_edge(aclk);
			check_ref(v => s0_axi_awready, r => s0_axi_awready_ref, s => "s0_axi_awready");
			check_ref(v => s0_axi_wready, r => s0_axi_wready_ref, s => "s0_axi_wready");
			check_ref(v => s0_axi_bvalid, r => s0_axi_bvalid_ref, s => "s0_axi_bvalid");
			check_ref(v => s0_axi_bresp, r => s0_axi_bresp_ref, s => "s0_axi_bresp");
		end loop;
	end process;

--postponed process(led, led_ref)
--begin
--	check_ref(v => led, r => led_ref, s => "led");
--end process;

end architecture sim;

-- vim: set tabstop=4 softtabstop=4 shiftwidth=4 noexpandtab textwidth=0:
