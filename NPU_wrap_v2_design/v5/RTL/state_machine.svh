//irq
//{{{
always @( posedge clk) begin
    if (CS == IDLE) begin
        irq_ff <= 1;
    end
    else begin
        irq_ff <= 0;
    end
end
//}}}

//main state machine
//{{{
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        CS <= IDLE;
        VMM_running <= 1'b0;
        READ_MEM_running <= 1'b0;
        SET_RESET_running <= 1'b0;
        setdactiaconfig_end_addr <= 8'd0;
        setdactiaconfig_run_addr <= 8'd0;
        setdac_kernel_run_addr <= 8'd0;
        setdac_kernel_internal_addr <= 8'd0;
        vmm_preload_run_addr <= 8'd0;
        readadc_kernel_run_addr <= 8'd0;
        readadc_kernel_end_addr <= 8'd0;
        read_mem_readadc_count <= 8'd0;
        setsw_WL_ST  <= 8'd0;
        setsw_WL_END <= 8'd0;
        setsw_BL_ST  <= 8'd0;
        setsw_BL_END <= 8'd0;
        apply_v_pulse_count_limit <= 16'd0;
        set_reset_dac_write_v_count <= 4'd0;

        state_machine_one_hot_indexer <= 32'd0;
    end
    else begin
        case(CS)
            IDLE:   begin //0
            //{{{
                if (VMM_valid == 1'b1) begin
                    state_machine_one_hot_indexer <= 32'd0;
                    setdac_kernel_run_addr <= NPU_WRAP_WL_ST; //(WL_ST /4 ) *4
                    setdac_kernel_internal_addr <= VMM_start_addr + (~{6'b0, NPU_WRAP_WL_ST[1:0]} +1'b1);

                    setsw_WL_ST <= NPU_WRAP_WL_ST;
                    setsw_WL_END <= NPU_WRAP_WL_END;
                    setsw_BL_ST <= NPU_WRAP_BL_ST;
                    setsw_BL_END <= NPU_WRAP_BL_END;

                    readadc_kernel_run_addr <= NPU_WRAP_BL_ST;
                    readadc_kernel_end_addr <= NPU_WRAP_BL_END;

                    apply_v_pulse_count_limit <= NPU_WRAP_vmm_pulsewidth;

                    VMM_running <= 1'b1;
                    if (NPU_WRAP_vmm_config_again_skip == 1'b1) begin
                        CS <= VMM_SETPRELOAD;
                    end
                    else begin
                        CS <= SETDACTIACONFIG;
                        setdactiaconfig_run_addr <= NPU_WRAP_VMM_CONFIG_ST;
                        setdactiaconfig_end_addr <= NPU_WRAP_VMM_CONFIG_END;
                    end
                end
                else if (read_mem_instr_valid == 1'b1) begin 
                    state_machine_one_hot_indexer <= 32'd0;

                    READ_MEM_running <= 1'b1;
                    setdactiaconfig_run_addr <= NPU_WRAP_READ_MEM_CONFIG_ST;
                    setdactiaconfig_end_addr <= NPU_WRAP_READ_MEM_CONFIG_END;
                    readadc_kernel_run_addr <= read_mem_bl;
                    readadc_kernel_end_addr <= read_mem_bl;
                    read_mem_readadc_count <= 8'd0;
                    setsw_WL_ST <= read_mem_wl;
                    setsw_WL_END <= read_mem_wl;
                    setsw_BL_ST <= read_mem_bl;
                    setsw_BL_END <= read_mem_bl;
                    
                    apply_v_pulse_count_limit <= NPU_WRAP_read_pulsewidth;

                    CS <= SETDACTIACONFIG;
                end
                else if (set_reset_instr_valid == 1'b1) begin 
                    state_machine_one_hot_indexer <= 32'd0;
                    
                    SET_RESET_running <= 1'b1;
                    
                    setdactiaconfig_run_addr <= NPU_WRAP_SET_RESET_CONFIG_ST;
                    setdactiaconfig_end_addr <= NPU_WRAP_SET_RESET_CONFIG_END;

                    setsw_WL_ST <= set_reset_wl;
                    setsw_WL_END <= set_reset_wl;
                    setsw_BL_ST <= set_reset_bl;
                    setsw_BL_END <= set_reset_bl;

                    apply_v_pulse_count_limit <= NPU_WRAP_pulse_width;

                    CS <= SETDACTIACONFIG;
                end
                else begin
                    CS <= IDLE;
                    VMM_running <= 1'b0;
                    READ_MEM_running <= 1'b0;
                    SET_RESET_running <= 1'b0;
                    setdactiaconfig_end_addr <= 8'd0;
                    setdactiaconfig_run_addr <= 8'd0;
                    setdac_kernel_run_addr <= 8'd0;
                    setdac_kernel_internal_addr <= 8'd0;
                    vmm_preload_run_addr <= 8'd0;
                    readadc_kernel_run_addr <= 8'd0;
                    readadc_kernel_end_addr <= 8'd0;
                    read_mem_readadc_count <= 8'd0;
                    setsw_WL_ST  <= 8'd0;
                    setsw_WL_END <= 8'd0;
                    setsw_BL_ST  <= 8'd0;
                    setsw_BL_END <= 8'd0;
                    apply_v_pulse_count_limit <= 16'd0;
                    set_reset_dac_write_v_count <= 4'd0;
                    
                    //DO NOT RESET state_machine_one_hot_indexer!
                end
            end  
            //}}}
            
            SETDACTIACONFIG: begin //1
            //{{{
                if (setdac_internal_state == SETDAC_INTERNAL_STATE_LIMIT_v2) begin 
                    if (setdactiaconfig_run_addr == setdactiaconfig_end_addr) begin
                        //last config already written
                        if (VMM_running == 1'b1) begin
                            CS <= SETSW; 
                        end
                        else if (READ_MEM_running == 1'b1) begin
                            CS <= SETSW; 
                        end
                        else if (SET_RESET_running == 1'b1) begin
                            CS <= SET_RESET_DAC_WRITE_V; 
                        end
                        state_machine_one_hot_indexer[SETDACTIACONFIG : SETDACTIACONFIG] <= 1'b1;
                        setdactiaconfig_end_addr <= 8'd0;
                        setdactiaconfig_run_addr <= 8'd0;
                    end
                    else begin
                        setdactiaconfig_run_addr <= setdactiaconfig_run_addr + 8'd1;
                    end
                end 
                else begin
                    CS <= SETDACTIACONFIG;
                end
            end
            //}}} 
   
            SETSW: begin //2
            //{{{
                if (setsw_count == VMM_MEM_LENGTH * 2 - 1) begin
                    if (VMM_running == 1'b1) begin 
                        state_machine_one_hot_indexer[SETSW : SETSW] <= 1'b1;
                        CS <= SETDAC_KERNEL; 
                    end
                    else if (READ_MEM_running == 1'b1) begin
                        state_machine_one_hot_indexer[SETSW : SETSW] <= 1'b1;
                        CS <= APPLY_V;
                    end
                    else if (SET_RESET_running == 1'b1) begin
                        state_machine_one_hot_indexer[SETSW : SETSW] <= 1'b1;
                        CS <= APPLY_V;
                    end
                end
                else begin
                    CS <= SETSW;
                end
            end
            //}}}
 
            SETDAC_KERNEL: begin //3
            //{{{
                if (setdac_internal_state == SETDAC_INTERNAL_STATE_LIMIT_v2) begin 
                    if (setdac_kernel_run_addr >= NPU_WRAP_WL_END || setdac_kernel_run_addr == VMM_MEM_LENGTH - 1) begin
                        CS <= VMM_PRELOAD; 
                        state_machine_one_hot_indexer[SETDAC_KERNEL : SETDAC_KERNEL] <= 1'b1;
                        setdac_kernel_run_addr <= 8'd0;
                        setdac_kernel_internal_addr <= 8'd0;
                    end
                    else begin
                        setdac_kernel_run_addr <= setdac_kernel_run_addr + 8'd1;
                        setdac_kernel_internal_addr <= setdac_kernel_internal_addr + 8'd1;
                    end
                end
                else begin
                    CS <= SETDAC_KERNEL;
                end
            end
            //}}}

            VMM_SETPRELOAD: begin //4    
            //{{{  
                if (setdac_internal_state == SETDAC_INTERNAL_STATE_LIMIT_v2) begin 
                    if (vmm_preload_run_addr == 1'b1) begin
                        //last config already written
                        CS <= SETDAC_KERNEL;
                        state_machine_one_hot_indexer[VMM_SETPRELOAD : VMM_SETPRELOAD] <= 1'b1;
                        vmm_preload_run_addr <= 8'd0;
                    end
                    else begin
                        vmm_preload_run_addr <= vmm_preload_run_addr + 8'd1;
                    end
                end
                else begin
                    CS <= VMM_SETPRELOAD;
                end
            end
            //}}}

            SET_RESET_DAC_WRITE_V: begin //5
            //{{{
                if (setdac_internal_state == SETDAC_INTERNAL_STATE_LIMIT_v2) begin 
                    if (set_reset_dac_write_v_count == SET_RESET_DAC_WRITE_V_LIMIT) begin
                        CS <= SETSW;
                        state_machine_one_hot_indexer[SET_RESET_DAC_WRITE_V : SET_RESET_DAC_WRITE_V] <= 1'b1;
                        set_reset_dac_write_v_count <= 0;
                    end
                    else begin
                        set_reset_dac_write_v_count <= set_reset_dac_write_v_count + 4'd1;
                    end
                end 
                else begin
                    CS <= SET_RESET_DAC_WRITE_V;
                end
            end
            //}}}

            VMM_PRELOAD: begin //6    
            //{{{  
                if (setdac_internal_state == SETDAC_INTERNAL_STATE_LIMIT_v2) begin 
                    if (vmm_preload_run_addr == 1'b1) begin
                        //last config already written
                        CS <= APPLY_V;
                        state_machine_one_hot_indexer[VMM_PRELOAD : VMM_PRELOAD] <= 1'b1;
                        vmm_preload_run_addr <= 1'b0;
                    end
                    else begin
                        vmm_preload_run_addr <= vmm_preload_run_addr + 1'b1;
                    end
                end
                else begin
                    CS <= VMM_PRELOAD;
                end
            end
            //}}}

            APPLY_V: begin //7
            //{{{
                //NPU_WRAP_vmm/read_pulsewidth could be 0, do not compare with NPU_WRAP_vmm/read_pulsewidth - 1
                if (pulse_count == apply_v_pulse_count_limit) begin
                    state_machine_one_hot_indexer[APPLY_V : APPLY_V] <= 1'b1;
                    if (VMM_running == 1'b1) begin
                        CS <= READADC_PRELOAD_0;
                    end
                    else if (READ_MEM_running == 1'b1) begin
                        CS <= READADC_PRELOAD_0;
                    end
                    else if (SET_RESET_running == 1'b1) begin
                        CS <= IDLE;
                    end
                end
                else begin
                    CS <= APPLY_V;
                end
            end
            //}}}
                
            READADC_PRELOAD_0: begin //8
            //{{{
                //TODO READADC need to skip several cycles first.
                if (readadc_preload_count == READADC_PRELOAD_COUNT_LIMIT_0) begin
                    CS <= READADC_PRELOAD_WRITE_DAC;
                    state_machine_one_hot_indexer[READADC_PRELOAD_0 : READADC_PRELOAD_0] <= 1'b1;
                    setdactiaconfig_run_addr <= READADC_PRELOAD_DAC_CONFIG_ST;
                    setdactiaconfig_end_addr <= READADC_PRELOAD_DAC_CONFIG_END;
                end
                else begin
                    CS <= READADC_PRELOAD_0;
                end
            end 
            //}}}
            
            READADC_PRELOAD_WRITE_DAC: begin //9
            //{{{
                //TODO READADC need to skip several cycles first.
                if (setdac_internal_state == SETDAC_INTERNAL_STATE_LIMIT_v2) begin 
                    if (setdactiaconfig_run_addr == setdactiaconfig_end_addr) begin
                        CS <= READADC_PRELOAD_1;
                        state_machine_one_hot_indexer[READADC_PRELOAD_WRITE_DAC : READADC_PRELOAD_WRITE_DAC] <= 1'b1;
                        setdactiaconfig_end_addr <= 8'd0;
                        setdactiaconfig_run_addr <= 8'd0;
                    end
                    else begin
                        setdactiaconfig_run_addr <= setdactiaconfig_run_addr + 8'd1;
                    end
                end
                else begin
                    CS <= READADC_PRELOAD_WRITE_DAC;
                end
            end 
            //}}}
            
            READADC_PRELOAD_1: begin //10
            //{{{
                //TODO READADC need to skip several cycles first.
                if (readadc_preload_count == READADC_PRELOAD_COUNT_LIMIT_1) begin
                    CS <= READADC_KERNEL;
                    state_machine_one_hot_indexer[READADC_PRELOAD_1 : READADC_PRELOAD_1] <= 1'b1;
                end
                else begin
                    CS <= READADC_PRELOAD_1;
                end
            end 
            //}}}
            
            READADC_KERNEL: begin //11
            //{{{
                if (VMM_running == 1'b1) begin 
                    if (readadc_internal_state == READADC_INTERNAL_STATE_LIMIT_v2) begin 
                        if (readadc_kernel_run_addr >= readadc_kernel_end_addr || readadc_kernel_run_addr == VMM_MEM_LENGTH) begin
                            CS <= IDLE; 
                            state_machine_one_hot_indexer[READADC_KERNEL : READADC_KERNEL] <= 1'b1;
                            readadc_kernel_run_addr <= 8'd0;
                            readadc_kernel_end_addr <= 8'd0;
                        end
                        else begin
                            readadc_kernel_run_addr <= readadc_kernel_run_addr + 8'd1;
                        end
                    end
                    else begin
                        CS <= READADC_KERNEL;
                    end
                end
                else if (READ_MEM_running == 1'b1) begin
                //{{{
                    if (readadc_internal_state == READADC_INTERNAL_STATE_LIMIT_v2) begin
                        //READ MEM do not judge addr, judge read count. run_addr == end_addr
                        if (read_mem_readadc_count == READ_MEM_repeat_time) begin
                            CS <= IDLE; 
                            state_machine_one_hot_indexer[READADC_KERNEL : READADC_KERNEL] <= 1'b1;
                            readadc_kernel_run_addr <= 8'd0;
                            readadc_kernel_end_addr <= 8'd0;
                            read_mem_readadc_count <= 8'd0;
                        end
                        else begin
                            read_mem_readadc_count <= read_mem_readadc_count + 8'd1;
                        end
                    end
                    else begin
                        CS <= READADC_KERNEL;
                    end
                end
                //}}}
                else begin
                    CS <= IDLE;
                end
            end
            //}}}



            default: begin
                CS <= IDLE;
                VMM_running <= 1'b0;
                READ_MEM_running <= 1'b0;
                SET_RESET_running <= 1'b0;
                setdactiaconfig_end_addr <= 8'd0;
                setdactiaconfig_run_addr <= 8'd0;
                setdac_kernel_run_addr <= 8'd0;
                setdac_kernel_internal_addr <= 8'd0;
                vmm_preload_run_addr <= 8'd0;
                readadc_kernel_run_addr <= 8'd0;
                readadc_kernel_end_addr <= 8'd0;
                setsw_WL_ST  <= 8'd0;
                setsw_WL_END <= 8'd0;
                setsw_BL_ST  <= 8'd0;
                setsw_BL_END <= 8'd0;
                apply_v_pulse_count_limit <= 16'd0;
                set_reset_dac_write_v_count <= 4'd0;



                //DO NOT RESET state_machine_one_hot_indexer!
            end //default 
        endcase 
    end
end
//}}}


//The following processes, use sequential logic, but tragger is only clk, do not add rst_n

//SETDACTIACONFIG, SETDAC_KERNEL, VMM_PRELOAD, VMM_SETPRELOAD, SET_RESET_DAC_WRITE_V, READADC_PRELOAD_WRITE_DAC
//{{{
always @( posedge clk) begin
    if (CS == SETDACTIACONFIG || CS == SETDAC_KERNEL || CS == VMM_PRELOAD || CS == VMM_SETPRELOAD || CS == SET_RESET_DAC_WRITE_V || CS == READADC_PRELOAD_WRITE_DAC) begin
        if (setdac_internal_state != SETDAC_INTERNAL_STATE_LIMIT_v2) begin //0,1,2 are keep running
            setdac_internal_state <= setdac_internal_state + 1'b1;
        end 
        else begin
            setdac_internal_state <= 1'b0;
        end
    end
    else begin    
        setdac_internal_state <= 1'b0;
    end 
end
//}}}

//SETSW
//{{{
always @( posedge clk) begin
    if (CS != SETSW) begin
        setsw_count <= 9'd0;
    end
    else begin
        setsw_count <= setsw_count + 1;
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
        pulse_count <= pulse_count + 1;
    end
end
//}}}

//READADC_KERNEL
//{{{
always @( posedge clk) begin
    if (CS == READADC_KERNEL) begin
        if (readadc_internal_state != READADC_INTERNAL_STATE_LIMIT_v2) begin //0,1,2 are keep running
            readadc_internal_state <= readadc_internal_state + 1;
        end 
        else begin
            readadc_internal_state <= 1'b0;
        end
    end
    else begin    
        readadc_internal_state <= 1'b0;
    end 
end
//}}}

//READADC_PRELOAD_0
//{{{
always @( posedge clk) begin
    if (CS == READADC_PRELOAD_0) begin
        if (readadc_preload_count != READADC_PRELOAD_COUNT_LIMIT_0) begin 
            readadc_preload_count <= readadc_preload_count + 1'b1;
        end 
        else begin
            readadc_preload_count <= 1'b0;
        end
    end
    else if (CS == READADC_PRELOAD_1) begin
        if (readadc_preload_count != READADC_PRELOAD_COUNT_LIMIT_1) begin 
            readadc_preload_count <= readadc_preload_count + 1'b1;
        end 
        else begin
            readadc_preload_count <= 1'b0;
        end
    end
    else begin    
        readadc_preload_count <= 1'b0;
    end 
end
//}}}
