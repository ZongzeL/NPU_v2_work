
./timescale.sv

#TB_lib
../../../NPU_pro_TB_lib/interface/axi_bus.sv  
../../../NPU_pro_TB_lib/interface/NPU_pro.sv
../../../NPU_pro_TB_lib/driver.sv
../../../NPU_pro_TB_lib/NPU_pro_driver.sv
../../../NPU_pro_TB_lib/API.sv

#NPU WRAP RTL
../RTL/npu_wrap.v

#NPU_pro_model
../../../NPU_v2_module/RTL/NPU_v2_module_read_mem_set_reset.v

./npu_wrap_test.sv

