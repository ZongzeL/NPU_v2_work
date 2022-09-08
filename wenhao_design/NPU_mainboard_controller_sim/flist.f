./timescale.sv

#Design
+incdir+../RTL/

#TB_lib
../../../NPU_global_lib/NPU_wrap_TB_lib/interface/axi_lite.sv  
../../../NPU_global_lib/NPU_wrap_TB_lib/axi_lite_driver.sv
../../../NPU_global_lib/NPU_wrap_TB_lib/API.sv

../RTL/common_M00_AXIS.v
../RTL/common_S00_AXIS.v
../RTL/top_S00_AXI.v
../RTL/top_main.v

../../NPU_v2_module/RTL/NPU_v2_module_read_mem_set_reset.v


./VMM_top_main_mainboard_tb.sv

