
//NPU_WRAP_config
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        for (i = 0; i < CONFIG_LENGTH; i = i + 1) begin
            NPU_WRAP_config[i] <= 0;
        end
    end
    else begin
        if (CS == IDLE) begin
            if (AXI_wready && AXI_wvalid &&
                axi_aw_write_wrap_config_flag == 1'b1
                ) begin
                NPU_WRAP_config[axi_w_opt_addr] <= AXI_wdata;
            end
        end
        else begin
            //this is the trigger, once trigger CS move, reset it back to 0
            NPU_WRAP_config[0] <= 32'b0;
        end
    end
end
//}}}

//NPU_WRAP_control
//{{{
always @( posedge clk) begin
    if ( rst_n == 1'b0 ) begin
        for (i = 0; i < 16; i = i + 1) begin
            NPU_WRAP_control[i] <= 0;
        end
    end
    else begin
        if (AXI_wready && AXI_wvalid &&
            axi_aw_write_wrap_control_flag == 1'b1
            ) begin
            NPU_WRAP_control[axi_w_opt_addr] <= AXI_wdata;
        end
        //start
        if ((start_trigger == 1 || 
            start_trigger == 2 || 
            start_trigger == 3 ) && 
            CS == DAC_CONFIG
            ) begin
            //write config, once trigger write, reset to 0
            //1,2,3 only trigger write config, need to use a specific condition to reset, other it will always trigger write config  
            NPU_WRAP_control[0] <= 0;
        end
        
        if (start_trigger != 0 && 
            CS == START
            ) begin 
            //any other situation, once trigger start, reset to 0 
            //this is covering in the future add more trigger mode
            NPU_WRAP_control[0] <= 0;
        end

        if (CS == IDLE) begin 
            //stop
            NPU_WRAP_control[1] <= 0;
        end

        if (CS == FINISH) begin
            NPU_WRAP_control[8] <= L3_wl_pos;
            NPU_WRAP_control[9] <= L2_bl_pos;
            NPU_WRAP_control[10] <= L0_single_point_opt_loop_pos;
            NPU_WRAP_control[11] <= L1_single_point_loop_pos;
            NPU_WRAP_control[12] <= L4_whole_range_loop_pos;
        end
    end
end
//}}}

//NPU_core_config
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        for (i = 0; i < 64; i = i + 1) begin
            NPU_core_config[i] <= 0;
        end
    end
    else begin
        if (CS == IDLE && 
            AXI_wready && AXI_wvalid &&
            axi_aw_write_core_config_flag == 1'b1
            ) begin
            NPU_core_config[axi_w_opt_addr] <= AXI_wdata;
        end
    end
end
//}}}

//data_mem
//{{{
always @( posedge clk ) begin
    if ( rst_n == 1'b0 ) begin
        for (i = 0; i < DATA_LENGTH; i = i + 1) begin
            data_mem[i] <= 0;
        end
    end
    else begin
        if (CS == ADC_KERNEL && CLKADC == 1) begin
            if (ADDR[1:0] == 0) begin
                data_mem[ADDR[7:2]][7:0] <= DOUT;
            end
            else if (ADDR[1:0] == 1) begin
                data_mem[ADDR[7:2]][15:8] <= DOUT;
            end
            else if (ADDR[1:0] == 2) begin
                data_mem[ADDR[7:2]][23:16] <= DOUT;
            end
            else if (ADDR[1:0] == 3) begin
                data_mem[ADDR[7:2]][31:24] <= DOUT;
            end

        end
    end
end
//}}}


