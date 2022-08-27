
//axi_w_opt_addr, set_reset_wl, set_reset_bl
//{{{
always @(axi_aw_write_config_flag, axi_aw_write_vmm_input_data_flag, axi_instr_awaddr) begin
    if( axi_aw_write_config_flag == 1'b1 ) begin
        axi_w_opt_addr = (axi_instr_awaddr - NPU_CONFIG_START_ADDR) >> ADDR_LSB;
    end
    else if ( axi_aw_write_vmm_input_data_flag == 1'b1 ) begin
        axi_w_opt_addr = (axi_instr_awaddr - NPU_VMM_INPUT_START_ADDR) >> ADDR_LSB;
    end
    else begin
        axi_w_opt_addr = 1'b0;
    end
end

//set_reset_wl, set_reset_bl
    /*
    else if ( axi_aw_set_reset_write_mem_flag == 1'b1 ) begin
        set_reset_tmp_axi_instr_awaddr = (axi_instr_awaddr - NPU_MEM_START_ADDR) >> ADDR_LSB;
        set_reset_wl = set_reset_tmp_axi_instr_awaddr[7:0];
        set_reset_bl = set_reset_tmp_axi_instr_awaddr[15:8];
        axi_w_opt_addr = set_reset_wl[7:2]; //may not necessary, because I don't need axi_w_opt_addr to write VMM_in_data
    end
    */
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        set_reset_wl <= 8'd0;
        set_reset_bl <= 8'd0;
    end 
    else begin    
        if (axi_aw_instr_valid == 1'b1) begin
            if (AXI_awaddr[18:0] >= NPU_MEM_START_ADDR && AXI_awaddr[18:0] < NPU_MEM_END_ADDR) begin
                //assign condition is same as axi_aw_set_reset_write_mem_flag
            
                set_reset_bl[7:0] <= ((AXI_awaddr[18:0] - NPU_MEM_START_ADDR >> ADDR_LSB) & 16'hff00) >> 8;
                set_reset_wl[7:0] <= (AXI_awaddr[18:0] - NPU_MEM_START_ADDR >> ADDR_LSB) & 16'h00ff;
            end
        end
    end 
end      


//}}}

//VMM_in_data
//{{{
//VMM_in_data: (400 - 4ff), (axi_w_opt_addr - 400)[7:6] = 0
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        for ( i = 0; i < DATA_MEM_LENGTH << 2; i = i + 1) begin
            VMM_in_data[i] <= 1'b0;
        end
    end
    else begin
        if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_write_vmm_input_data_flag) begin
            if (axi_w_opt_addr[7:6] == 2'd0 ) begin
                //axi_w_opt_addr from 0 to 63, VMM_in_data addr from 0 to 255
                if (AXI_wstrb[0:0] == 1'b1) begin
                    VMM_in_data[(axi_w_opt_addr[5:0] << 2) + 0] <= AXI_wdata[7:0];
                end
                if (AXI_wstrb[1:1] == 1'b1) begin
                    VMM_in_data[(axi_w_opt_addr[5:0] << 2) + 1] <= AXI_wdata[15:8];
                end
                if (AXI_wstrb[2:2] == 1'b1) begin
                    VMM_in_data[(axi_w_opt_addr[5:0] << 2) + 2] <= AXI_wdata[23:16];
                end
                if (AXI_wstrb[3:3] == 1'b1) begin
                    VMM_in_data[(axi_w_opt_addr[5:0] << 2) + 3] <= AXI_wdata[31:24];
                end

                //VMM_in_data[axi_w_opt_addr[5:0]] <= AXI_wdata;
            end
        end
    end
end
//}}}

//NPU_CORE_config_data, NPU_CORE_config_data_addr
//{{{
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        for ( i = 0; i < NPU_CONFIG_DATA_MEM_LENGTH; i = i + 1) begin
            NPU_CORE_config_data[i] <= 1'b0;
            NPU_CORE_config_data_addr[i] <= 1'b0;
        end
    end
    else begin
        if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_write_config_flag) begin
            //TODO
            //000 is writing NPU_CORE_config_data
            //100 is writing NPU_CORE_config_data_addr
            //axi address is 1_0000_0000, axi_w_opt_addr = 1_0000_00
            //axi_w_opt_addr
            if (axi_w_opt_addr[7:6] == 2'd0 || axi_w_opt_addr[7:6] == 2'd1 ) begin 
                NPU_CORE_config_data[axi_w_opt_addr[5:0]][7:0] <= AXI_wdata[7:0];
                NPU_CORE_config_data_addr[axi_w_opt_addr[5:0]][7:0] <= AXI_wdata[15:8];
            end
        end
    end
end
//}}}

//NPU_WRAP_config_data
//{{{
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        for ( i = 0; i < NPU_WRAP_CONFIG_DATA_MEM_LENGTH; i = i + 1) begin
            NPU_WRAP_config_data[i] <= 1'b0;
        end
    end
    else begin
        if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_write_config_flag) begin
            //000 to 400
            //200, first 32 is writing NPU_WRAP_config_data (currently, only 16 are valid )
            //axi address is 2_0000_0000, axi_w_opt_addr = 2_0000_00
            //axi_w_opt_addr
            if (axi_w_opt_addr[7:6] == 2'd2 && axi_w_opt_addr[5:5] == 1'b0 ) begin
                //first 32
                if (AXI_wstrb[0:0] == 1'b1) begin
                    NPU_WRAP_config_data[axi_w_opt_addr[4:0]][7:0] <= AXI_wdata[7:0];
                end
                if (AXI_wstrb[1:1] == 1'b1) begin
                    NPU_WRAP_config_data[axi_w_opt_addr[4:0]][15:8] <= AXI_wdata[15:8];
                end
                if (AXI_wstrb[2:2] == 1'b1) begin
                    NPU_WRAP_config_data[axi_w_opt_addr[4:0]][23:16] <= AXI_wdata[23:16];
                end
                if (AXI_wstrb[3:3] == 1'b1) begin
                    NPU_WRAP_config_data[axi_w_opt_addr[4:0]][31:24] <= AXI_wdata[31:24];
                end
                //NPU_WRAP_config_data[axi_w_opt_addr[4:0]] <= AXI_wdata;
            end
        end
        //prepare the last config data for passed FSM check 
        NPU_WRAP_config_data [NPU_WRAP_CONFIG_DATA_MEM_LENGTH - 1][31:0] <= state_machine_one_hot_indexer[31:0];
        if (CS != IDLE) begin
            NPU_WRAP_config_data[NPU_WRAP_CONFIG_DATA_VMM_INST][31:0] <= 32'b0;
        end
    end
end
//}}}

//VMM_out_data
//{{{
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        for ( i = 0; i < DATA_MEM_LENGTH; i = i + 1) begin
            VMM_out_data[i] <= 32'b0;
        end
    end
    else begin
        if (READ_MEM_running == 1'b1) begin
            if (NPU_CLKADC_SW == 1'b1) begin
                VMM_out_data[NPU_ADDR] <= NPU_DOUT;
            end
        end
        else if (VMM_running == 1'b1) begin
            if (NPU_CLKADC_SW == 1'b1) begin
                VMM_out_data[NPU_ADDR] <= NPU_DOUT;
            end
        end
    end
end
//}}}

//axi_r_opt_addr, read_mem_wl, read_mem_bl
//{{{
always @(axi_ar_read_config_flag, axi_ar_read_vmm_input_data_flag, axi_ar_read_vmm_output_data_flag, axi_ar_read_mem_flag, axi_instr_araddr) begin
    if( axi_ar_read_config_flag == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - NPU_CONFIG_START_ADDR) >> ADDR_LSB;
    end
    else if ( axi_ar_read_vmm_input_data_flag == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - NPU_VMM_INPUT_START_ADDR) >> ADDR_LSB;
    end
    else if ( axi_ar_read_vmm_output_data_flag == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - NPU_VMM_OUTPUT_START_ADDR) >> ADDR_LSB;
    end
    else if (axi_ar_read_mem_flag  == 1'b1 ) begin
        //this is necessary, need to write into AXI output buffer
        //can also use read_mem_bl[7:ADDR_LSB], at this point, read_mem_bl is already stable
        axi_r_opt_addr = (((axi_instr_araddr - NPU_MEM_START_ADDR) >> ADDR_LSB) & 16'hff00) >> 10;
        //axi_r_opt_addr = read_mem_bl[7:ADDR_LSB];
    end
    else begin
        axi_r_opt_addr = 1'b0;
    end
end

//read_mem_wl, read_mem_bl
/*
    else if ( axi_ar_read_mem_flag == 1'b1 ) begin
        //if axi_r_opt_addr is directly used in out_mem, then the above is necessary
        read_mem_tmp_axi_instr_araddr = (axi_instr_araddr - NPU_MEM_START_ADDR) >> ADDR_LSB;
        read_mem_wl = read_mem_tmp_axi_instr_araddr[7:0];
        read_mem_bl = read_mem_tmp_axi_instr_araddr[15:8];
        axi_r_opt_addr = read_mem_bl[7:2];
    end
*/

always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        read_mem_wl <= 8'd0;
        read_mem_bl <= 8'd0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1) begin
            if (AXI_araddr[18:0] >= NPU_MEM_START_ADDR && AXI_araddr[18:0] < NPU_MEM_END_ADDR) begin
                //assign condition is same as axi_ar_read_mem_flag
            
                read_mem_bl[7:0] <= ((AXI_araddr[18:0] - NPU_MEM_START_ADDR >> ADDR_LSB) & 16'hff00) >> 8;
                read_mem_wl[7:0] <= (AXI_araddr[18:0] - NPU_MEM_START_ADDR >> ADDR_LSB) & 16'h00ff;
            end
        end
    end 
end      


//}}}
