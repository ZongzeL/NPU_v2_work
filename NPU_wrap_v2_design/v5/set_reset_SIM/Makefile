#:%s/^[ ]\+/\t/g
all:
	vcs -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed -debug_pp -sverilog \
	+vcd+vcdpluson \
	-f flist.f \
    +incdir+../RTL/ \
	+define+VCS_SIM 


sc:
	syscan -cflags "-g" -full64 -cpp g++-4.8 -cc gcc-4.8 -sysc=2.3 \
	../SC_RTL/NPU_wrap_axi.cpp:NPU_wrap \
	../SC_RTL/NPU_wrap_Data_memory.cpp \
	../SC_RTL/NPU_wrap_func.cpp \
	../SC_RTL/state_machine.cpp \
	../SC_RTL/NPU_signals.cpp 
	vcs -full64 -cpp g++-4.8 -cc gcc-4.8 -LDFLAGS -Wl,--no-as-needed -debug_pp +vcd+vcdpluson -sverilog \
    -sysc=2.3 \
	-f flist_sc.f \
	-sysc=adjust_timeres \
	+define+VCS_SIM \
	+define+SYSTEMC

run :
	./simv -l run_debug.log  -gui -i systemc_on_top.tcl

opendve:
	dve -full64 -vpd waveforms.vpd

clean:
	if [ -e csrc ]; then rm -r csrc; fi
	if [ -e simv ]; then rm simv; fi
	if [ -e simv.daidir ]; then rm -r simv.daidir; fi
	if [ -e vnc_logs ]; then rm -r vnc_logs; fi
	if [ -e ucli.key ]; then rm ucli.key; fi
	if [ -e waveforms.vpd ]; then rm waveforms.vpd; fi
	if [ -e inter.vpd ]; then rm inter.vpd; fi
	if [ -e DVEfiles ]; then rm -r DVEfiles; fi
	if [ -e AN.DB ]; then rm -r AN.DB; fi
	if [ -e run_debug.log ]; then rm -r run_debug.log; fi
	if [ -e .vlogansetup.args ]; then rm .vlogansetup.args; fi
	if [ -e .vlogansetup.env ]; then rm .vlogansetup.env ; fi


