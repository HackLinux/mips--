-- this is the data cache for the cpu

use work.common.all;
use work.dcache_pkg.all;
use work.reduce_pack.all;

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;


entity dcache_r is


   port (
      clk   : in  std_logic;
      nrst  : in  std_logic;
      d     : in  dcache_in_type;
      q     : out dcache_out_type
   );


   function binlog_zero (
      i : natural
   ) return natural is
      variable tmp : natural := i;
      variable log : natural := 0;
   begin
      while (tmp > 1) loop
         tmp := tmp / 2;
         log := log + 1;
      end loop;

      return log;
   end;


end;

architecture twoproc of dcache_r is

   subtype tag_type is unsigned(31 downto 7);

   type block_type is array (1 downto 0) of word;

   type frame_type is record
      valid : std_logic;
      dirty : std_logic;
      tag   : tag_type;
      words : block_type;
   end record;

   type way_type is array (15 downto 0) of frame_type;

   type set_type is array (1 downto 0) of way_type;

   type cache_state_type is (cache_idle, cache_read, cache_write, cache_flush, cache_flush_write, cache_halt);

   type cache_reg_type is record
      state          : cache_state_type;
      counter        : unsigned(0 downto 0);
      line_counter   : integer range 0 to 15;
      way_counter    : integer range 0 to 1;
   end record;

   type reg_type is record
      ways  : set_type;
      lru   : std_logic_vector(way_type'range);
      cache : cache_reg_type;
   end record;

   signal r, rin : reg_type;

begin

   -- combinatiorial process
   comb : process(d, r)
      variable v           : reg_type;
      variable index       : integer range 0 to 15;
      variable block_off   : integer range 0 to 1;
      variable wanted_tag  : tag_type;
      variable hits        : unsigned(1 downto 0);
      variable hit         : std_logic;
      variable hit_way     : integer range 0 to 1;
      variable evict_way   : integer range 0 to 1;
   begin
      -- default assignment
      v := r;

      -- module algorithm

      -- calculate various indicies
      index := to_integer(d.cpu.addr(6 downto 3));
      wanted_tag := d.cpu.addr(31 downto 7);
      block_off := to_integer(d.cpu.addr(2 downto 2));

      if r.ways(0)(index).valid = '0' then
         evict_way := 0;
      elsif r.ways(1)(index).valid = '0' then
         evict_way := 1;
      else
         if r.lru(index) = '0' then
            evict_way := 0;
         else
            evict_way := 1;
         end if;
      end if;

      for i in r.ways'range loop
         if wanted_tag = r.ways(i)(index).tag and r.ways(i)(index).valid = '1' then
            hits(i) := '1';
         else
            hits(i) := '0';
         end if;
      end loop;

      hit := or_reduce(hits);
      hit_way := binlog_zero(to_integer(hits));

      if (d.cpu.ren = '1' or d.cpu.wen = '1') and hit = '1' then
         -- if the hit is on the 0th way
         if hits(0) = '1' then
            -- mark the 1th way as being the least recently used
            v.lru(index) := '1';
         else
            -- the hit is on the 1th way, mark the 0th way as being the least recently used
            v.lru(index) := '0';
         end if;
      end if;

      -- cache FSM next state logic
      case r.cache.state is
         when cache_idle =>
            if d.cpu.ren = '1' then
               
               if hit = '0' then
                  if v.ways(evict_way)(index).valid = '1' and v.ways(evict_way)(index).dirty = '1' then
                     -- must evict the old block
                     v.cache.state := cache_write;
                  else
                     -- read in the block
                     v.cache.state := cache_read;
                  end if;
               else
                  -- no further action needed, data output later in process
               end if;
            elsif d.cpu.wen = '1' then
               if hit = '0' then
                  -- must pull in and write
                  if v.ways(evict_way)(index).valid = '1' and v.ways(evict_way)(index).dirty = '1' then
                     -- must evict the old block
                     v.cache.state := cache_write;
                  else
                     -- nothing needed a write-back, pull in the block for writing
                     v.cache.state := cache_read;
                  end if;
               else
                  -- the block is already in the cache, write to it and set dirty bit
                  v.ways(hit_way)(index).words(block_off) := d.cpu.wdat;
                  v.ways(hit_way)(index).dirty := '1';
               end if;
            elsif d.cpu.halt = '1' then
               v.cache.state := cache_flush;
            end if;

         when cache_read =>
            -- if the memory isnt done with the current operation, do nothing
            if d.mem.done = '1' then
               -- the memory has finished its operation, we can proceed
               v.cache.counter := r.cache.counter + 1;
               v.ways(evict_way)(index).words(to_integer(r.cache.counter)) := d.mem.rdat;
               v.ways(evict_way)(index).tag := wanted_tag;
               -- the cache line is invalid during an update
               v.ways(evict_way)(index).valid := '0';

               if r.cache.counter = 1 then
                  -- this is the last word in the block, leave the read state
                  v.cache.state := cache_idle;
                  -- reset the counter for the next user
                  v.cache.counter := (others => '0');
                  -- block is now valid
                  v.ways(evict_way)(index).valid := '1';
               end if;
            end if;

         when cache_write =>
            -- if the memory isnt done with the current operation, do nothing
            if d.mem.done = '1' then
               -- the memory has finished its operation, we can proceed
               v.cache.counter := r.cache.counter + 1;

               if r.cache.counter = 1 then
                  -- this is the last word in the block, leave the read state
                  v.cache.state := cache_idle;
                  -- reset counter for next user
                  v.cache.counter := (others => '0');
                  -- block is no longer dirty
                  v.ways(evict_way)(index).dirty := '0';
               end if;
            end if;

         when cache_flush =>
            if  v.ways(r.cache.way_counter)(r.cache.line_counter).valid = '1' and
                v.ways(r.cache.way_counter)(r.cache.line_counter).dirty = '1' then
               v.cache.state := cache_flush_write;
            else
               if r.cache.line_counter = 15 then
                  v.cache.line_counter := 0;
                  if r.cache.way_counter = 1 then
                     v.cache.way_counter := 0;
                  else
                     v.cache.way_counter := r.cache.way_counter + 1;
                  end if;
               else
                  v.cache.line_counter := r.cache.line_counter + 1;
               end if;

               if r.cache.line_counter = 15 and r.cache.way_counter = 1 then
                  v.cache.state := cache_halt;
               else
                  v.cache.state := cache_flush;
               end if;
            end if;

         when cache_flush_write =>
            -- if the memory isnt done with the current operation, do nothing
            if d.mem.done = '1' then

               -- the memory has finished its operation, we can proceed
               v.cache.counter := r.cache.counter + 1;

               if r.cache.counter = 1 then
                  -- this is the last word in the block, leave the read state
                  v.cache.counter := (others => '0');

                  if r.cache.line_counter = 15 then
                     v.cache.line_counter := 0;
                     if r.cache.way_counter = 1 then
                        v.cache.way_counter := 0;
                     else
                        v.cache.way_counter := r.cache.way_counter + 1;
                     end if;
                  else
                     v.cache.line_counter := r.cache.line_counter + 1;
                  end if;

                  if r.cache.line_counter = 15 and r.cache.way_counter = 1 then
                     v.cache.state := cache_halt;
                  else
                     v.cache.state := cache_flush;
                  end if;
               end if;
            end if;

         when cache_halt =>
            -- do nothing, we're halted!

         when others =>
      end case;

      -- drive the register inputs
      rin <= v;

      -- drive module outputs

      q.cpu.hit <= hit;
      
      -- always output the rdat, even if the cpu is writing
      q.cpu.rdat <= r.ways(hit_way)(index).words(block_off);

      -- always output the wdat, even if the cpu is reading
      q.mem.wdat <= v.ways(evict_way)(index).words(to_integer(r.cache.counter));

      q.mem.addr <= x"FEEDF00D";
      q.mem.ren <= '0';
      q.mem.wen <= '0';

      q.cpu.halt <= '0';

      -- cache FSM output logic
      case r.cache.state is
         when cache_idle =>
            -- default assignments are fine
         when cache_read =>
            q.mem.ren <= '1';
            q.mem.addr <= d.cpu.addr(31 downto 3) & r.cache.counter & "00";
         when cache_write =>
            q.mem.wen <= '1';
            q.mem.addr <= v.ways(evict_way)(index).tag & d.cpu.addr(6 downto 3) & r.cache.counter & "00";

         when cache_flush =>
            -- defaults are fine

         when cache_flush_write =>
            q.mem.wen <= '1';
            q.mem.addr <= v.ways(r.cache.way_counter)(r.cache.line_counter).tag & to_unsigned(r.cache.line_counter, 4) & r.cache.counter & "00";
            q.mem.wdat <= v.ways(r.cache.way_counter)(r.cache.line_counter).words(to_integer(r.cache.counter));

         when cache_halt =>
            q.cpu.halt <= '1';

         when others =>
            -- default assignments are fine
      end case;

   end process;


   -- the register process
   regs : process(clk, nrst)
   begin
      if nrst = '0' then
         -- reset the ways
         -- loop through each way
         for i in r.ways'range loop
            -- loop through each frame
            for j in r.ways(i)'range loop
               r.ways(i)(j).valid <= '0';
               r.ways(i)(j).dirty <= '0';
               r.ways(i)(j).tag <= (others => '0');
               -- loop through each word in a block
               for k in r.ways(i)(j).words'range loop
                  r.ways(i)(j).words(k) <= to_word(0);
               end loop;
            end loop;
         end loop;

         -- reset the lru bits
         r.lru <= (others => '0');

         -- reset the state machines
         -- cache FSM
         r.cache.state <= cache_idle;
         r.cache.counter <= (others => '0');
         r.cache.way_counter <= 0;
         r.cache.line_counter <= 0;

      elsif rising_edge(clk) then
         r <= rin;
      end if;
   end process;

end;

