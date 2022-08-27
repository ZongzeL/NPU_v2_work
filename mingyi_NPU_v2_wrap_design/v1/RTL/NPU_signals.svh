//DAC: ADDR, DIN, BYTE_EN, CLKDAC
//{{{
task NPU_CLKDAC_w_gen ();
//{{{
begin
    if (dac_adc_internal_state[3:0] >= SETDAC_INTERNAL_VALID_STATE_ST[3:0] 
        && dac_adc_internal_state[3:0] <= SETDAC_INTERNAL_VALID_STATE_END[3:0]
        ) begin
        CLKDAC_w      = 1'b1;
    end
    else begin
        CLKDAC_w      = 1'b0;
    end
end
endtask
//}}}

task NPU_CLKADC_w_gen ();
//{{{
begin
    if (dac_adc_internal_state >= READADC_INTERNAL_VALID_STATE_ST && 
        dac_adc_internal_state <= READADC_INTERNAL_VALID_STATE_END) begin 
        CLKADC_w          = 1'b1;
    end
    else begin
        CLKADC_w          = 1'b0;
    end
end
endtask
//}}}

always @(CS
        or dac_config_run_addr
        or dac_adc_internal_state
        or SETDAC_INTERNAL_VALID_STATE_ST
        or SETDAC_INTERNAL_VALID_STATE_END
        or READADC_INTERNAL_VALID_STATE_ST
        or READADC_INTERNAL_VALID_STATE_END
    ) begin
    ADDR_w        = 9'b0;
    DIN_w         = 8'b0;
    CLKDAC_w      = 1'b0;
    CLKADC_w      = 1'b0;
    
    if (CS == DAC_CONFIG) begin //1
    //{{{
        ADDR_w        = {1'b1, NPU_core_config[dac_config_run_addr][15:8]};
        DIN_w         = NPU_core_config[dac_config_run_addr][7:0];
        NPU_CLKDAC_w_gen();
    end
    //}}}
    
    else if (CS == DAC_SETRESET_WLBL_V) begin //2
    //{{{
        if (dac_config_run_addr == 0) begin
            ADDR_w = 9'h1f9;
            DIN_w  = set_bl_v; 
            NPU_CLKDAC_w_gen();
        end
        else if (dac_config_run_addr == 1) begin
            ADDR_w = 9'h1fa;
            DIN_w  = reset_wl_v; 
            NPU_CLKDAC_w_gen();
        end

    end
    //}}}
    
    else if (CS == DAC_SETRESET_SEL_V) begin //4
    //{{{
        ADDR_w = 9'h1f8;
        if (current_opt == RUN_RESET) begin
            DIN_w = reset_sel_v;
        end
        else if (current_opt == RUN_SET) begin
            DIN_w = set_sel_v;
        end
        NPU_CLKDAC_w_gen();
    end
    //}}}

    else if (CS == ADC_KERNEL) begin //8
    //{{{
        ADDR_w = L3_bl_pos;
        NPU_CLKADC_w_gen();
    end
    //}}}
    
    else begin
        ADDR_w        = 9'b0;
        DIN_w         = 8'b0;
        CLKDAC_w      = 1'b0;
        CLKADC_w      = 1'b0;
    end
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        ADDR    <= 9'b0;
        DIN     <= 32'b0;
        CLKDAC  <= 1'b0;
    end
    else begin
        ADDR    <= ADDR_w    ;
        DIN     <= DIN_w     ;
        CLKDAC  <= CLKDAC_w  ;
    end
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        CLKADCSW    <= 1'b0;
        CLKADC      <= 1'b0;
    end
    else begin
        CLKADCSW    <= CLKADC_w      ;
        CLKADC      <= CLKADC_w      ;
    end
end
//}}}


//CLKREG_(SEL/BL/WL/TIA) ,  DINSWREG_(SEL/BL/WL/TIA)
//{{{
//always @(CS or setsw_count) begin
always @(*) begin
    if (CS != SETSW) begin
        DINSWREG_SEL_w = 1'b0;
        DINSWREG_BL_w  = 1'b0;			
        DINSWREG_WL_w  = 1'b0;	
        DINSWREG_TIA_w = 1'b0;
        CLKREG_w       = 1'b0;
        DACWLREFSW_w = 1'b0; //VMM use only
    end 
    else begin

        //if run readmem, need to open this
        DINSWREG_TIA_w = 1'b0;


        //WL
        if ((WLBL_LENGTH - 1 - setsw_count[8:1]) == L2_wl_pos) begin
            DINSWREG_WL_w = 1'b1;
        end
        else begin
            DINSWREG_WL_w = 1'b0;
        end
        
        //BL
        if ((WLBL_LENGTH - 1 - setsw_count[8:1]) == L3_bl_pos) begin
            DINSWREG_BL_w  = 1'b1;
            DINSWREG_SEL_w = 1'b1;
        end
        else begin
            DINSWREG_BL_w  = 1'b0;
            DINSWREG_SEL_w = 1'b0;
        end

        //CLKREG
        if (setsw_count[0] == 1) begin
            CLKREG_w       = 1'b1;
        end 
        else begin
            CLKREG_w       = 1'b0;
        end
    end 
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        DINSWREG[3:0] <= 4'b0;
        CLKREG[3:0]  <= 4'b0;
        DACWLREFSW    <= 0;
    end
    else begin
        DINSWREG[0:0] <= DINSWREG_WL_w  ;
        DINSWREG[1:1] <= DINSWREG_SEL_w ;			
        DINSWREG[2:2] <= DINSWREG_TIA_w ;	
        DINSWREG[3:3] <= DINSWREG_BL_w  ;
        CLKREG[0:0]   <= CLKREG_w       ;
        CLKREG[1:1]   <= CLKREG_w       ;
        CLKREG[2:2]   <= CLKREG_w       ;	
        CLKREG[3:3]   <= CLKREG_w       ;	
        DACWLREFSW    <= DACWLREFSW_w   ;
    end
end
//}}}

//DACBL_SW, DACBL_SW2, DACSEL_SW, DACWL_SW
//{{{
always @(*) begin
    DACBL_SW_w    = 0;
    DACBL_SW2_w   = 0;
    DACSEL_SW_w   = 0;
    DACWL_SW_w    = 0;
    if (CS == APPLY_V) begin
        if (current_opt == RUN_SET) begin
        //{{{
            DACBL_SW2_w   = 0; //TIA
            //BL
            if (pulse_count >= NPU_WRAP_BL_pulsewidth_set_st &&
                pulse_count <= NPU_WRAP_BL_pulsewidth_set_end
            ) begin 
                DACBL_SW_w    = 1;
            end
            else begin
                DACBL_SW_w    = 0;
            end
            //WL
            if (pulse_count >= NPU_WRAP_WL_pulsewidth_set_st &&
                pulse_count <= NPU_WRAP_WL_pulsewidth_set_end
            ) begin 
                DACWL_SW_w    = 1;
            end
            else begin
                DACWL_SW_w    = 0;
            end
            //BL
            if (pulse_count >= NPU_WRAP_SEL_pulsewidth_set_st &&
                pulse_count <= NPU_WRAP_SEL_pulsewidth_set_end
            ) begin 
                DACSEL_SW_w    = 1;
            end
            else begin
                DACSEL_SW_w    = 0;
            end
        end
        //}}}
        else if (current_opt == RUN_RESET) begin
        //{{{
            DACBL_SW2_w   = 0; //TIA
            //BL
            if (pulse_count >= NPU_WRAP_BL_pulsewidth_reset_st &&
                pulse_count <= NPU_WRAP_BL_pulsewidth_reset_end
            ) begin 
                DACBL_SW_w    = 1;
            end
            else begin
                DACBL_SW_w    = 0;
            end
            //WL
            if (pulse_count >= NPU_WRAP_WL_pulsewidth_reset_st &&
                pulse_count <= NPU_WRAP_WL_pulsewidth_reset_end
            ) begin 
                DACWL_SW_w    = 1;
            end
            else begin
                DACWL_SW_w    = 0;
            end
            //BL
            if (pulse_count >= NPU_WRAP_SEL_pulsewidth_reset_st &&
                pulse_count <= NPU_WRAP_SEL_pulsewidth_reset_end
            ) begin 
                DACSEL_SW_w    = 1;
            end
            else begin
                DACSEL_SW_w    = 0;
            end
        end
        //}}}
        else if (current_opt == RUN_READMEM) begin
        //{{{
            DACBL_SW_w   = 0; //BL
            //TIA
            if (pulse_count >= NPU_WRAP_BL_pulsewidth_readmem_st) begin 
                DACBL_SW2_w    = 1;
            end
            else begin
                DACBL_SW2_w    = 0;
            end
            //WL
            if (pulse_count >= NPU_WRAP_WL_pulsewidth_readmem_st) begin 
                DACWL_SW_w    = 1;
            end
            else begin
                DACWL_SW_w    = 0;
            end
            //SEL
            if (pulse_count >= NPU_WRAP_SEL_pulsewidth_readmem_st) begin 
                DACSEL_SW_w    = 1;
            end
            else begin
                DACSEL_SW_w    = 0;
            end
        end
        //}}}
    end
    else if (CS == ADC_KERNEL) begin
        DACBL_SW_w    = 0;
        DACBL_SW2_w   = 1;
        DACSEL_SW_w   = 1;
        DACWL_SW_w    = 1;
    end
    else begin
        DACBL_SW_w    = 0;
        DACBL_SW2_w   = 0;
        DACSEL_SW_w   = 0;
        DACWL_SW_w    = 0;
    end
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        DACBL_SW    <= 0;
        DACBL_SW2   <= 0;
        DACSEL_SW   <= 0;
        DACWL_SW    <= 0;
    end
    else begin
        DACBL_SW    <= DACBL_SW_w;
        DACBL_SW2   <= DACBL_SW2_w;
        DACSEL_SW   <= DACSEL_SW_w;
        DACWL_SW    <= DACWL_SW_w;
    end
end
//}}}

//SET, RESET
//{{{
always @(*) begin
    if (CS != APPLY_V) begin
        SET_w = 0;
        RESET_w = 0;
    end
    else begin
        if (current_opt == RUN_RESET) begin
            SET_w = 0;
            RESET_w = 1;
        end
        else if (current_opt == RUN_SET) begin
            SET_w = 1;
            RESET_w = 0;
        end
        else begin
            SET_w = 0;
            RESET_w = 0;
        end
    end
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        SET     <= 1'b0;
        RESET   <= 1'b0;
    end
    else begin
        SET     <= SET_w;
        RESET   <= RESET_w;
    end
end
//}}}