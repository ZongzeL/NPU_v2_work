./timescale.sv

#TB_lib
../../../NPU_pro_TB_lib/interface/axi_bus.sv  
../../../NPU_pro_TB_lib/interface/NPU_pro.sv
../../../NPU_pro_TB_lib/driver.sv
../../../NPU_pro_TB_lib/NPU_pro_driver.sv
../../../NPU_pro_TB_lib/API.sv

#NPU WRAP RTL
#../RTL/npu_wrap.v

#NPU_pro_model
../../../NPU_pro_module/RTL/NPU_pro_module_read_mem_set_reset.v

#NPU_wrap_NN_module
#../../NN_module/v1/RTL/NPU_wrap_NN_module.v
#../../NN_module/v1/RTL/device.v
#../../multiplier/v3/RTL/16_bit_multiplier.v

./npu_wrap_test.sv

