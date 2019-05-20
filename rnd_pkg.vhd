library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use ieee.math_real.all;

package rnd_pkg is

	type rnd_generator is protected
		procedure init(s1, s2: positive);
		impure function get_boolean return boolean;
		impure function get_integer(min, max: integer) return integer;
		impure function get_bit return bit;
		impure function get_bit_vector(size: positive) return bit_vector;
		impure function get_std_ulogic return std_ulogic;
		impure function get_std_ulogic_vector(size: positive) return std_ulogic_vector;
		impure function get_u_unsigned(size: positive) return u_unsigned;
	end protected rnd_generator;

end package rnd_pkg;

package body rnd_pkg is

	type rnd_generator is protected body
		variable seed1: positive := 1;
		variable seed2: positive := 1;
		variable rnd:   real;

		procedure throw is
		begin
			uniform(seed1, seed2, rnd);
		end procedure throw;

		procedure init(s1, s2: positive) is
		begin
			seed1 := s1;
			seed2 := s2;
		end procedure init;

		impure function get_boolean return boolean is
		begin
			throw;
			return rnd < 0.5;
		end function get_boolean;

		impure function get_integer(min, max: integer) return integer is
			variable tmp: integer;
		begin
			throw;
			tmp := min + integer(real(max - min) * rnd + 0.5);
			return tmp;
		end function get_integer;

		impure function get_bit return bit is
		variable res: bit;
		begin
			res := '0' when get_boolean else '1';
			return res;
		end function get_bit;

		impure function get_std_ulogic return std_ulogic is
		variable res: std_ulogic;
		begin
			res := '0' when get_boolean else '1';
			return res;
		end function get_std_ulogic;

		impure function get_u_unsigned(size: positive) return u_unsigned is
		variable res: u_unsigned(1 to size);
		begin
			if size < 30 then
				res := to_unsigned(get_integer(0, 2**size - 1), size);
			else
				res := to_unsigned(get_integer(0, 2**30 - 1), 30) & get_u_unsigned(size - 30);
			end if;
			return res;
		end function get_u_unsigned;

		impure function get_std_ulogic_vector(size: positive) return std_ulogic_vector is
		begin
			return std_ulogic_vector(get_u_unsigned(size));
		end function get_std_ulogic_vector;

		impure function get_bit_vector(size: positive) return bit_vector is
		begin
			return to_bitvector(get_std_ulogic_vector(size));
		end function get_bit_vector;
	end protected body rnd_generator;

end package body rnd_pkg;

use std.textio.all;
use std.env.all;

library ieee;
use ieee.std_logic_1164.all;

package utils_pkg is

	procedure check_unknowns(v: in std_ulogic; s: in string);
	procedure check_unknowns(v: in std_ulogic_vector; s: in string);
    procedure check_ref(v, r: in std_ulogic; s: in string);
	procedure check_ref(v, r: in std_ulogic_vector; s: in string);

end package utils_pkg;

package body utils_pkg is

	function is_01(b: std_ulogic) return boolean is
	begin
		return (b = '0') or (b = '1');
	end function is_01;

	function is_01(b: std_ulogic_vector) return boolean is
	begin
		for i in b'range loop
			if not is_01(b(i)) then
				return false;
			end if;
		end loop;
		return true;
	end function is_01;

	procedure check_unknowns(v: in std_ulogic; s: in string) is
		variable l: line;
	begin
		if not is_01(v) then
			write(l, string'("NON REGRESSION TEST FAILED - "));
			write(l, now);
			writeline(output, l);
			write(l, string'("  INVALID ") & s & string'(" VALUE: "));
			write(l, v);
			writeline(output, l);
			finish;
		end if;
	end procedure check_unknowns;

	procedure check_unknowns(v: in std_ulogic_vector; s: in string) is
		variable l: line;
	begin
		if not is_01(v) then
			write(l, string'("NON REGRESSION TEST FAILED - "));
			write(l, now);
			writeline(output, l);
			write(l, string'("  INVALID ") & s & string'(" VALUE: "));
			write(l, v);
			writeline(output, l);
			finish;
		end if;
	end procedure check_unknowns;

    procedure check_ref(v, r: in std_ulogic; s: in string) is
		variable l: line;
	begin
		if r /= '-' and v /= r then
			write(l, string'("NON REGRESSION TEST FAILED - "));
			write(l, now);
			writeline(output, l);
			write(l, string'("  EXPECTED ") & s & string'("="));
			write(l, r);
			writeline(output, l);
			write(l, string'("       GOT ") & s & string'("="));
			write(l, v);
			writeline(output, l);
			finish;
		end if;
	end procedure check_ref;

    procedure check_ref(v, r: in std_ulogic_vector; s: in string) is
		variable l: line;
        constant lv: std_ulogic_vector(v'length - 1 downto 0) := v;
        constant lr: std_ulogic_vector(r'length - 1 downto 0) := r;
	begin
        for i in v'length - 1 downto 0 loop
            if lr(i) /= '-' and lv(i) /= lr(i) then
                write(l, string'("NON REGRESSION TEST FAILED - "));
                write(l, now);
                writeline(output, l);
                write(l, string'("  EXPECTED ") & s & string'("="));
                write(l, r);
                writeline(output, l);
                write(l, string'("       GOT ") & s & string'("="));
                write(l, v);
                writeline(output, l);
                finish;
            end if;
        end loop;
	end procedure check_ref;

end package body utils_pkg;