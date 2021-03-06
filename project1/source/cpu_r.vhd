-- cpu (record style)

use work.common.all;
use work.cpu_pkg.all;
use work.alu_pkg.all;
use work.regfile_pkg.all;
use work.pc_pkg.all;
use work.memwait_pkg.all;
use work.ctrl_pkg.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity cpu_r is
   port (
      clk   : in std_logic;
      nrst  : in std_logic;
      d     : in  cpu_in_type;
      q     : out cpu_out_type
   );
end;


architecture structural of cpu_r is

   signal alu_in  : alu_in_type;
   signal alu_out : alu_out_type;

   signal reg_in  : regfile_in_type;
   signal reg_out : regfile_out_type;

   signal pc_in   : pc_in_type;
   signal pc_out  : pc_out_type;

   signal memwait_in    : memwait_in_type;
   signal memwait_out   : memwait_out_type;   

   signal ctrl_in    : ctrl_in_type;
   signal ctrl_out   : ctrl_out_type;

   signal imem_addr     : address;
   signal imem_dat      : word;
   signal imem_dat_slv  : word_slv;

   signal dmem_addr     : address;
   signal dmem_rdat     : word;
   signal dmem_rdat_slv : word_slv;
   signal dmem_wdat     : word;
   signal dmem_wen      : std_logic;

   signal r_ins : r_type;
   signal j_ins : j_type;
   signal i_ins : i_type;

   signal z : std_logic;

   signal halt    : std_logic;
   signal memwait : std_logic;

   signal dump_addr : dump_address;

begin


   regfile_b : regfile_r port map (
      clk => clk, nrst => nrst,
      d => reg_in, q => reg_out
   );

   reg_in.rsel1 <= r_ins.rs;
   reg_in.rsel2 <= r_ins.rt;
   reg_in.wen <= ctrl_out.reg_write and not memwait and not halt;

   reg_write_sel : process(ctrl_out.reg_dst, r_ins.rt, r_ins.rd, r_ins.op)
      variable i : reg_index;
   begin
      if r_ins.op = jal_op then
         i := 31;
      elsif ctrl_out.reg_dst = '1' then
         i := r_ins.rd;
      else
         i := r_ins.rt;
      end if;

      reg_in.wsel <= i;
   end process;

   reg_write_mux : process(ctrl_out.reg_src, pc_out.pc, dmem_rdat, alu_out.r)
      variable r : word;
   begin
      case ctrl_out.reg_src is
         when mem_reg_src  => r := dmem_rdat;
         when pc_reg_src   => r := pc_out.pc + 4;
         when alu_reg_src  => r := alu_out.r;
      end case;

      reg_in.wdat <= r;
   end process;


   alu_b : alu_r port map (
      d => alu_in, q => alu_out
   );

   z <= alu_out.z;
   alu_in.a <= reg_out.rdat1;
   alu_in.op <= ctrl_out.alu_op;
   
   alu_mux : process (ctrl_out.alu_src, reg_out.rdat2, i_ins.imm, r_ins.sa)
      variable r : word;
   begin
      case ctrl_out.alu_src is
         when reg_alu_src  => r := reg_out.rdat2;
         when imm_alu_src  => r := unsigned(resize(signed(i_ins.imm), r'length));
         when immu_alu_src => r := resize(i_ins.imm, r'length);
         when sa_alu_src   => r := to_unsigned(r_ins.sa, r'length);
         when lui_alu_src  => r := zero_fill_right(i_ins.imm, r'length);
      end case;

      alu_in.b <= r;
   end process;


   ctrl_b : ctrl_r port map (
      d => ctrl_in, q => ctrl_out
   );

   ctrl_in.r_ins <= r_ins;
   ctrl_in.i_ins <= i_ins;
   ctrl_in.j_ins <= j_ins;

   imem_b : entity work.rami port map (
      clock => clk,
      address => std_logic_vector(imem_addr(15 downto 0)), data => (others => '0'),
      wren => '0', q => imem_dat_slv
   );

   imem_dat <= unsigned(imem_dat_slv);

   r_ins <= to_r_type(std_logic_vector(imem_dat));
   j_ins <= to_j_type(std_logic_vector(imem_dat));
   i_ins <= to_i_type(std_logic_vector(imem_dat));


   pc_b : pc_r port map (
      clk => clk, nrst => nrst,
      d => pc_in, q => pc_out
   );

   pc_in.z        <= z;
   pc_in.op       <= r_ins.op;
   pc_in.func     <= r_ins.func;
   pc_in.imm      <= i_ins.imm;
   pc_in.j_addr   <= j_ins.j_addr;
   pc_in.r_addr   <= reg_out.rdat1;
   pc_in.we       <= not halt and not memwait;

   imem_addr      <= pc_out.pc;
 

   memwait_b : memwait_r port map (
      clk => clk, nrst => nrst,
      d => memwait_in, q => memwait_out
   );

   memwait_in.op <= r_ins.op;
   memwait <= memwait_out.memwait;

   dmem_b : entity work.ramd port map (
      clock => clk,
      address => std_logic_vector(dmem_addr(15 downto 0)), data => std_logic_vector(dmem_wdat),
      wren => dmem_wen, q => dmem_rdat_slv
   );

   dmem_addr <= alu_out.r when halt = '0' else resize(d.dump_addr, address'length);
   dmem_rdat <= unsigned(dmem_rdat_slv);
   dmem_wdat <= reg_out.rdat2;
   dmem_wen  <= ctrl_out.mem_write;


   halt <= '1' when r_ins.op = halt_op else '0';
   q.halt <= halt;


   -- cpu mappings
   q.imem_addr <= imem_addr;
   q.imem_dat <= imem_dat;
   q.dmem_addr <= dmem_addr;
   q.dmem_rdat <= dmem_rdat;
   q.dmem_wdat <= dmem_wdat;


end;

