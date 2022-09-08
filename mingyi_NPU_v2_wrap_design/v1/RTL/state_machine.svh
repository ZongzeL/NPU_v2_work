


//main state machine
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        CS <= IDLE;
        CS_PASS <= 32'b0;
        set_running <= 0;
        reset_running <= 0;
        read_mem_running <= 0;
        L3_wl_pos <= 8'b0;
        L2_bl_pos <= 8'b0;
        L0_single_point_opt_loop_pos <= 3'b0;
        L1_single_point_loop_pos <= 32'b0;
        L4_whole_range_loop_pos <= 32'b0;
        dac_config_run_addr <= 8'd0;
        dac_config_end_addr <= 8'd0;
        readmem_adc_count <= 4'd0;
        last_opt <= 8'd0;
    end
    else begin
        case (CS) 
            IDLE: begin //0
                if (start_trigger == 3'd1) begin
                    CS <= DAC_CONFIG;
                    dac_config_run_addr <= NPU_WRAP_CONFIG_0_ST;
                    dac_config_end_addr <= NPU_WRAP_CONFIG_0_END;
                end
                else if (start_trigger == 3'd2) begin
                    CS <= DAC_CONFIG;
                    dac_config_run_addr <= NPU_WRAP_CONFIG_1_ST;
                    dac_config_end_addr <= NPU_WRAP_CONFIG_1_END;
                end
                else if (start_trigger == 3'd3) begin
                    CS <= DAC_CONFIG;
                    dac_config_run_addr <= NPU_WRAP_CONFIG_2_ST;
                    dac_config_end_addr <= NPU_WRAP_CONFIG_2_END;
                end
                else if (start_trigger == 3'd4) begin
                    //whole range loop start, every thing start over
                    dac_config_run_addr <= 8'd0;
                    CS <= START; //every time whole start, write SETRESET_WLBL_V
                    L3_wl_pos <= WL_ST; 
                    L2_bl_pos <= BL_ST;
                    L0_single_point_opt_loop_pos <= 0;
                    L1_single_point_loop_pos <= 0;
                    L4_whole_range_loop_pos <= 0;
                    CS_PASS <= NPU_WRAP_config[2][31:0]; //manually disable some states
                end
                else begin
                    CS <= IDLE;
                end
            end
    
            DAC_CONFIG: begin //1
            //{{{
                if (dac_adc_internal_state == SETDAC_INTERNAL_STATE_LIMIT) begin 
                    if (dac_config_run_addr == dac_config_end_addr) begin
                        dac_config_end_addr <= 8'd0;
                        dac_config_run_addr <= 8'd0;
                        CS <= IDLE;
                    end
                    else begin
                        dac_config_run_addr <= dac_config_run_addr + 8'd1;
                    end
                end 
                else begin
                    CS <= DAC_CONFIG;
                end
            end
            //}}} 
            
            DAC_SRREF_V: begin //2
            //{{{
                if (dac_adc_internal_state == SETDAC_INTERNAL_STATE_LIMIT) begin 
                    if (dac_config_run_addr == 8'd2) begin 
                        dac_config_run_addr <= 8'd0;
                        //CS <= APPLY_V;
                        CS <= SETSW;
                    end
                    else begin
                        dac_config_run_addr <= dac_config_run_addr + 8'd1;
                    end
                end 
                else begin
                    CS <= DAC_SRREF_V;
                end
            end
            //}}}

            START: begin //3
            //{{{
                //L0_single_point_opt_loop_pos is stable, current_opt is also stable. 
                dac_config_run_addr <= 8'd0; //dac_run_addr must reset every time start!
                //CS <= SETSW;
                CS <= DAC_SRREF_V;

                if (
                    ((last_opt == RUN_SET || last_opt == RUN_RESET) && current_opt == RUN_READMEM ) ||
                    ((current_opt == RUN_SET || current_opt == RUN_RESET) && last_opt == RUN_READMEM)
                ) begin
                    //last is set reset, this is readmem, or opposite situation, need to rerun sw to open tia and bl
                    CS_PASS[SETSW:SETSW] <= 1'b0; 
                end
            end 
            //}}}

            SETSW: begin //5
            //{{{
                if (CS_PASS[SETSW:SETSW] == 1'b1) begin
                    //skip
                    //CS <= DAC_SRREF_V;
                    CS <= APPLY_V;
                end 
                else begin
                    //running
                    if (setsw_count == WLBL_LENGTH * 2 - 1) begin
                        CS_PASS[SETSW:SETSW] <= 1'b1;
                        CS <= APPLY_V;
                    end
                    else begin
                        CS <= SETSW;
                    end
                end
            end
            //}}}
 
            APPLY_V: begin //6
            //{{{
                if (current_opt == RUN_SET) begin
                    if (pulse_count == NPU_WRAP_set_pulse_width) begin
                        CS_PASS[APPLY_V:APPLY_V] <= 1'b1;
                        CS <= FINISH;
                    end
                end
                else if (current_opt == RUN_RESET) begin
                    if (pulse_count == NPU_WRAP_reset_pulse_width) begin
                        CS_PASS[APPLY_V:APPLY_V] <= 1'b1;
                        CS <= FINISH;
                    end
                end
                else if (current_opt == RUN_READMEM) begin
                    if (pulse_count == NPU_WRAP_readmem_pulse_width) begin
                        CS_PASS[APPLY_V:APPLY_V] <= 1'b1;
                        CS <= ADC_KERNEL;
                    end
                end
                else begin
                    CS <= APPLY_V;
                end
            end
            //}}}

            ADC_KERNEL: begin //8
            //{{{
                if (dac_adc_internal_state == adc_high_delay + adc_low_delay) begin
                    CS <= FINISH; 
                    CS_PASS[ADC_KERNEL : ADC_KERNEL] <= 1'b1;
                    readmem_adc_count <= 8'd0;
                end
                else begin
                    CS <= ADC_KERNEL;
                end
            end
            //}}}


            FINISH: begin //7
            //{{{
                last_opt <= current_opt;
                if (stop_trigger == 1) begin
                    CS <= IDLE;
                end
                else begin
                    CS <= START;
                end

                if (L0_single_point_opt_loop_pos == L0_single_point_opt_loop) begin     //level 0 single point opt
                    L0_single_point_opt_loop_pos <= 0;
                    if (L1_single_point_loop_pos == L1_single_point_loop) begin             //level 1 single point
                        L1_single_point_loop_pos <= 0;
                        CS_PASS[SETSW:SETSW] <= 1'b0; //single point loop finish, next round should switch
                        if (L3_wl_pos == WL_END) begin                                          //level 2 wl
                            L3_wl_pos <= WL_ST;
                            if (L2_bl_pos == BL_END) begin                                          //level 3 bl
                                L2_bl_pos <= BL_ST;
                                if (L4_whole_range_loop_pos == L4_whole_range_loop) begin               //level 4 whole loop
                                    CS <= IDLE;
                                    L4_whole_range_loop_pos <= 0;
                                end
                                else begin                                                              //level 4 whole loop
                                    L4_whole_range_loop_pos <= L4_whole_range_loop_pos + 1;
                                end
                            end
                            else begin                                                              //level 3 bl
                                L2_bl_pos <= L2_bl_pos + 1;
                            end
                        end
                        else begin                                                              //level 2 wl
                            L3_wl_pos <= L3_wl_pos + 1;
                        end 
                    end
                    else begin                                                              //level 1 single point
                        L1_single_point_loop_pos <= L1_single_point_loop_pos + 1'b1;
                    end
                end
                else begin                                                              //level 0 single_point opt
                    L0_single_point_opt_loop_pos <= L0_single_point_opt_loop_pos + 1;
                end
            end
            //}}}

            default: begin
                CS <= IDLE;
                CS_PASS <= 32'b0;
                set_running <= 0;
                reset_running <= 0;
                read_mem_running <= 0;
                L3_wl_pos <= 8'b0;
                L2_bl_pos <= 8'b0;
                L0_single_point_opt_loop_pos <= 3'b0;
                L1_single_point_loop_pos <= 32'b0;
                L4_whole_range_loop_pos <= 32'b0;
                dac_config_run_addr <= 8'd0;
                dac_config_end_addr <= 8'd0;
                readmem_adc_count <= 4'd0;
            end
        endcase 
    end
end
//}}}

//DAC_CONFIG, DAC_SETRESET_SEL_V, DAC_SETRESET_WLBL_V, DAC_SETRESET_SEL_V, ADC_KERNEL
//{{{
always @( posedge clk) begin
    if (
        CS == DAC_CONFIG || 
        CS == DAC_SRREF_V
    ) begin
        if (dac_adc_internal_state != SETDAC_INTERNAL_STATE_LIMIT) begin 
            dac_adc_internal_state <= dac_adc_internal_state + 1'b1;
        end 
        else begin
            dac_adc_internal_state <= 16'b0;
        end
    end
    else if (
        CS == ADC_KERNEL 
    ) begin
        if (
            dac_adc_internal_state != adc_high_delay + adc_low_delay
        ) begin 
            dac_adc_internal_state <= dac_adc_internal_state + 1'b1;
        end 
        else begin
            //if skip, do not count it
            dac_adc_internal_state <= 16'b0;
        end
    end

    else begin   
        //do not need to consider reset, keep 0 except the states above. 
        dac_adc_internal_state <= 16'b0;
    end 
end
//}}}

//SETSW
//{{{
always @( posedge clk) begin
    if (CS != SETSW || CS_PASS[SETSW:SETSW] == 1'b1) begin
        setsw_count <= 9'd0;
    end
    else begin
        setsw_count <= setsw_count + 9'd1;
    end
end
//}}}

//APPLY_V
//{{{
always @(posedge clk) begin
    if (CS != APPLY_V) begin
        pulse_count <= 16'd0;
    end
    else begin
        pulse_count <= pulse_count + 16'd1;
    end
end
//}}}


