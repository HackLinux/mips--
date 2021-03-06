# ECE437 Makefile

.SUFFIXES: .vhd 
COMPILE.VHDL = vcom
COMPILE.VHDLFLAGS = -93
SRCDIR = ./source
WORKDIR = ./work
VPATH= $(WORKDIR)

#Rules

%.vhd : $(SRCDIR)/%.vhd
	if [ ! -d $(WORKDIR) ]; then vlib $(WORKDIR); vmap lpm $(WORKDIR); fi
	$(COMPILE.VHDL) $(COMPILE.VHDLFLAGS) $(SRCDIR)/$@

# begin VHDL files (keep this)

common_tb.vhd : common.vhd

regfile_p.vhd : common.vhd
regfile_r.vhd : common.vhd regfile_p.vhd
regfile_tb.vhd : common.vhd common_tb.vhd regfile_p.vhd regfile_r.vhd

alu_p.vhd : common.vhd
alu_r.vhd : common.vhd alu_p.vhd
alu_tb.vhd : common.vhd common_tb.vhd alu_p.vhd alu_r.vhd

pc_r.vhd : common.vhd pc_p.vhd
pc_p.vhd : common.vhd
pc_tb.vhd : common.vhd common_tb.vhd pc_p.vhd pc_r.vhd

cpu.vhd : common.vhd cpu_p.vhd cpu_r.vhd
cpu_r.vhd : common.vhd cpu_p.vhd pc_r.vhd alu_r.vhd regfile_r.vhd rami.vhd ramd.vhd memwait_r.vhd ctrl_r.vhd
cpu_p.vhd : common.vhd
tb_cpu.vhd : cpu.vhd
cpuTest.vhd : cpu.vhd bintohexDecoder.vhd

memwait_p.vhd : common.vhd
memwait_r.vhd : common.vhd memwait_p.vhd
memwait_tb.vhd : common.vhd common_tb.vhd memwait_p.vhd memwait_r.vhd

ctrl_p.vhd : common.vhd
ctrl_r.vhd : common.vhd ctrl_p.vhd
ctrl_tb.vhd : common.vhd common_tb.vhd ctrl_r.vhd

# end VHDL files (keep this)

# Cache rules (cache labs)
# replace this ramAxB.vhd with your own
ram16x50.vhd : 220model.vhd
220pack.vhd:
	if [ ! -d $(WORKDIR) ]; then vlib $(WORKDIR); vmap lpm $(WORKDIR); fi
	$(COMPILE.VHDL) -87 ${HOME437}/lib/LPM/220pack.vhd
220model.vhd: 220pack.vhd
	if [ ! -d $(WORKDIR) ]; then vlib $(WORKDIR); vmap lpm $(WORKDIR); fi
	$(COMPILE.VHDL) -87 ${HOME437}/lib/LPM/220model.vhd

# Lab Rules DO NOT CHANGE THESE
# OR YOU MAY FAIL THE GRADING SCRIPT
lab1: registerFile_tb.vhd
lab2: tb_alu.vhd
lab4: tb_cpu.vhd
lab5: tb_cpu.vhd
lab6: tb_cpu.vhd
lab7: tb_cpu.vhd
lab8: tb_cpu.vhd
lab9: tb_cpu.vhd
lab10: tb_cpu.vhd
lab11: tb_cpu.vhd
lab12: tb_cpu.vhd


# Time Saving Rules
clean:
	$(RM) -rf $(WORKDIR) *.log transcript \._* mapped/*.vhd *.hex
