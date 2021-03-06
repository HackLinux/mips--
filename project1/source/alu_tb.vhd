-- alu testbench

use work.common.all;
use work.common_tb.all;
use work.alu_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity alu_tb is
end;

architecture test of alu_tb is

   signal clk     : std_logic := '0';
   signal nrst    : std_logic := '0';
   signal alu_in  : alu_in_type;
   signal alu_out : alu_out_type;

   signal stop : std_logic := '1';


   type alu_tb_vector is record
      d : alu_in_type;
      q : alu_out_type;
   end record;

   type vector_table is array (natural range <>) of alu_tb_vector;

   constant vecs : vector_table := (
      -- adding nothing  to nothing
      (d => (a => to_word(0), b => to_word(0), op => add_alu_op),
       q => (r => to_word(0), n => '0', v => '0', z => '1')),
      
      -- -1 + 1 = 0
      (d => (a => to_word(-1), b => to_word(1), op => add_alu_op),
       q => (r => to_word(0), n => '0', v => '0', z => '1')),

      -- -1 - 1 = -2
      (d => (a => to_word(-1), b => to_word(1), op => sub_alu_op),
       q => (r => to_word(-2), n => '1', v => '0', z => '0')),

      -- 2 + 2 = 4 (not 5?)
      (d => (a => to_word(2), b => to_word(2), op => add_alu_op),
       q => (r => to_word(4), n => '0', v => '0', z => '0')),

      -- test overflow
      (d => (a => x"7FFFFFFF", b => to_word(1), op => add_alu_op),
       q => (r => x"80000000", n => '1', v => '1', z => '0')),

      -- test overflow with subtraction
      (d => (a => to_word(5), b => to_word(6), op => sub_alu_op),
       q => (r => to_word(-1), n => '1', v => '0', z => '0')),

      -- 0 + 0 = 0
      (d => (a => to_word(0), b => to_word(0), op => add_alu_op),
       q => (r => to_word(0), n => '0', v => '0', z => '1')),

      -- -1 - 1 = -2
      (d => (a => to_word(-1), b => to_word(1), op => sub_alu_op),
       q => (r => to_word(-2), n => '1', v => '0', z => '0')),

      -- 243 - -1337 = 1580
      (d => (a => to_word(243), b => to_word(-1337), op => sub_alu_op),
       q => (r => to_word(1580), n => '0', v => '0', z => '0')),

      -- test out AND
      (d => (a => x"DEADBEEF", b => x"FFFF0000", op => and_alu_op),
       q => (r => x"DEAD0000", n => '1', v => '0', z => '0')),

      -- test out OR
      (d => (a => x"ABC0C0F0", b => x"000D0A0E", op => or_alu_op),
       q => (r => x"ABCDCAFE", n => '1', v => '0', z => '0')),

      -- test out NOR
      (d => (a => x"AA000055", b => x"FF00AA00", op => nor_alu_op),
       q => (r => x"00FF55AA", n => '0', v => '0', z => '0')),

      -- test out XOR
      (d => (a => x"AAFF0003", b => x"55FF0012", op => xor_alu_op),
       q => (r => x"FF000011", n => '1', v => '0', z => '0')),

      -- test out SLL
      (d => (a => x"00000001", b => x"00000004", op => sll_alu_op),
       q => (r => x"00000010", n => '0', v => '0', z => '0')),

      -- test out SRL
      (d => (a => x"00000010", b => x"00000004", op => srl_alu_op),
       q => (r => x"00000001", n => '0', v => '0', z => '0')),

      -- 5 < 6 (should be 1)
      (d => (a => to_word(5), b => to_word(6), op => slt_alu_op),
       q => (r => to_word(1), n => '0', v => '0', z => '0')),

      -- same as above but with sltu (should be 1)
      (d => (a => to_word(5), b => to_word(6), op => sltu_alu_op),
       q => (r => to_word(1), n => '0', v => '0', z => '0')),

      -- INT_MIN < INT_MAX (should be 1)
      (d => (a => x"80000000", b => x"7FFFFFFF", op => slt_alu_op),
       q => (r => to_word(1), n => '0', v => '0', z => '0')),

      -- unsigned(INT_MIN) < unsigned(INT_MAX) (should be 0)
      (d => (a => x"80000000", b => x"7FFFFFFF", op => sltu_alu_op),
       q => (r => to_word(0), n => '0', v => '0', z => '1')),
      
      -- 1337 < 243 (should be 0) 
      (d => (a => to_word(1337), b => to_word(243), op => slt_alu_op),
       q => (r => to_word(0), n => '0', v => '0', z => '1')),

      -- same as above but with sltu (should be 0)
      (d => (a => to_word(1337), b => to_word(243), op => sltu_alu_op),
       q => (r => to_word(0), n => '0', v => '0', z => '1'))
    );


begin

   alu_b : alu_r port map (
      d => alu_in, q => alu_out
   );

   -- clock when stop isnt asserted
   clk <= not clk and not stop after clk_per/2;

   process
      variable rand_state : prng_state;
      variable rand  : word;
      variable res   : word;
   begin

      prng_init(rand_state, to_dword(243));

      -- initialize inputs
      alu_in.a <= (others => '0');
      alu_in.b <= (others => '0');
      alu_in.op <= sll_alu_op;

      -- start the clock and reset
      stop <= '0';
      nrst <= '0';
      tick(clk, 1);
      nrst <= '1';
      tick(clk, 1);

      for i in vecs'range loop
         alu_in <= vecs(i).d;
         tick(clk, 1);
         assert alu_out = vecs(i).q;
      end loop;


      -- try to add numbers
      alu_in.op <= add_alu_op;
      for i in 0 to 7 loop
         for j in 0 to 7 loop
            alu_in.a <= to_word(i);
            alu_in.b <= to_word(j);
            tick(clk, 1);
            assert alu_out.r = to_word(i+j);
            assert alu_out.n = '0';
            assert alu_out.v = '0';
            if j = 0 and i = 0 then
               assert alu_out.z = '1';
            else
               assert alu_out.z = '0';
            end if;
         end loop;
      end loop;

      -- try some random subtractions
      alu_in.op <= sub_alu_op;
      for i in 0 to 255 loop
         prng_gen(rand_state, rand);
         alu_in.a <= rand;
         
         prng_gen(rand_state, rand);
         alu_in.b <= rand;
         
         tick(clk, 1);

         res := alu_in.a - alu_in.b;
         
         assert alu_out.r = res report "res";

         assert alu_out.n = res(res'high) report "n";         

         if res = 0 then
            assert alu_out.z = '1' report "zt";
         else
            assert alu_out.z = '0' report "zf";
         end if;
         
         -- '1' because we're subtracting
         assert alu_out.v = calc_overflow(alu_in.a, alu_in.b, res, '1') report "v";
      end loop;
      
      -- stop the clock
      stop <= '1';
      tick(clk, 1);
      wait;

   end process;

end;

