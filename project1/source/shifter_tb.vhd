-- shifter testbench

use work.common.all;
use work.common_tb.all;
use work.shifter_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity shifter_tb is
end;

architecture test of shifter_tb is

   signal clk              : std_logic := '0';
   signal sl_in, sr_in     : shifter_in_type;
   signal sl_out, sr_out   : shifter_out_type;

   signal stop : std_logic := '1';


   type shifter_tb_vector is record
      d : shifter_in_type;
      q : shifter_out_type;
   end record;

   type vector_table is array (natural range <>) of shifter_tb_vector;

   constant left_vecs : vector_table := (
      -- no shift!
      (d => (a => x"00000001", b => to_unsigned(0, 5)),
       q => (r => x"00000001")),
      
      -- shift 1 left a nibble
      (d => (a => x"00000001", b => to_unsigned(4, 5)),
       q => (r => x"00000010")),

      -- shift 1 left two nibbles
      (d => (a => x"00000001", b => to_unsigned(8, 5)),
       q => (r => x"00000100"))
    );


begin

   -- left shifter
   sl_b : shifter_r generic map (
      to_the_left => true
   ) port map (
      d => sl_in, q => sl_out
   );

   -- right shifter
   sr_b : shifter_r generic map (
      to_the_left => false
   ) port map (
      d => sr_in, q => sr_out
   );


   -- clock when stop isnt asserted
   clk <= not clk and not stop after clk_per/2;

   process
      variable rand_state : prng_state;
      variable rand  : word;
   begin

      prng_init(rand_state, to_dword(243));

      -- start the clock and reset
      stop <= '0';

      -- go through the test vectors for the left shifter
      -- note: i didnt feel it was worthwile to write
      -- corresponding vectors for the right shifter
      -- with all of the other automated tests
      for i in left_vecs'range loop
         sl_in <= left_vecs(i).d;
         tick(clk, 1);
         assert sl_out = left_vecs(i).q;
      end loop;

      -- shift left a single bit through the entire 32-bits
      sl_in.a <= to_word(1);
      for i in word'reverse_range loop
         sl_in.b <= to_unsigned(i, 5);
         tick(clk, 1);
         assert sl_out.r = to_word(1) sll i;
      end loop;

      -- shift right a single bit through the entire 32-bits
      sr_in.a <= x"80000000";
      for i in word'reverse_range loop
         sr_in.b <= to_unsigned(i, 5);
         tick(clk, 1);
         assert sr_out.r = x"80000000" srl i;
      end loop;

      -- try random left shifting
      for i in 0 to 255 loop
         prng_gen(rand_state, rand);
         sl_in.a <= rand;
         prng_gen(rand_state, rand);
         sl_in.b <= resize(rand, 5);
         tick(clk, 1);
         assert sl_out.r = sl_in.a sll to_integer(resize(sl_in.b, 5));
      end loop;

      -- try random right shifting
      for i in 0 to 255 loop
         prng_gen(rand_state, rand);
         sr_in.a <= rand;
         prng_gen(rand_state, rand);
         sr_in.b <= resize(rand, 5);
         tick(clk, 1);
         assert sr_out.r = sr_in.a srl to_integer(resize(sr_in.b, 5));
      end loop;
      
      -- stop the clock
      stop <= '1';
      tick(clk, 1);
      wait;

   end process;

end;

