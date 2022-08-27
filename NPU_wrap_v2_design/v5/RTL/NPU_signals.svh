//The following processes, use combinational logic


//DAC: NPU_ADDR, NPU_DIN, NPU_CLKDAC
//{{{
task NPU_CLKDAC_w_gen ();
//{{{
begin
    if (setdac_internal_state >= SETDAC_INTERNAL_VALID_STATE_ST_v2 && setdac_internal_state <= SETDAC_INTERNAL_VALID_STATE_END_v2) begin 
        NPU_CLKDAC_w      = 1'b1;
    end
    else begin
        NPU_CLKDAC_w      = 1'b0;
    end
end
endtask
//}}}

always @(CS or setdac_internal_state or readadc_kernel_run_addr) begin
    case(CS)
        SETDACTIACONFIG: begin //1
        //{{{
            NPU_ADDR_w        = {1'b1, NPU_CORE_config_data_addr[setdactiaconfig_run_addr]};
            NPU_DIN_w         = NPU_CORE_config_data[setdactiaconfig_run_addr];
            NPU_CLKDAC_w_gen();
        end
        //}}}

        SETDAC_KERNEL: begin //3
        //{{{
            NPU_ADDR_w              = {0, setdac_kernel_run_addr};
            NPU_DIN_w               = VMM_in_data[setdac_kernel_internal_addr];
            NPU_CLKDAC_w_gen();
        end
        //}}}
        
        VMM_SETPRELOAD: begin //4   
        //{{{
            NPU_ADDR_w        = 9'h1f6;
            NPU_DIN_w         = NPU_WRAP_wlg_ctrl1;
            NPU_CLKDAC_w_gen();
        end
        //}}}

        SET_RESET_DAC_WRITE_V: begin //5
        //{{{
            if (set_reset_dac_write_v_count == 4'd0) begin
                NPU_ADDR_w        = 9'h1f8;
                NPU_DIN_w         = set_reset_v_sel;
            end 
            else if (set_reset_dac_write_v_count == 4'd1) begin
                NPU_ADDR_w        = 9'h1f9;
                NPU_DIN_w         = set_reset_v_bl;
            end
            else if (set_reset_dac_write_v_count == 4'd2) begin
                NPU_ADDR_w        = 9'h1fa;
                NPU_DIN_w         = set_reset_v_wl;
            end

            NPU_CLKDAC_w_gen();
        end
        //}}} 

        VMM_PRELOAD: begin //6   
        //{{{
            NPU_ADDR_w        = 9'h1f6;
            NPU_DIN_w         = 1'b0;
            NPU_CLKDAC_w_gen();
        end
        //}}}

        READADC_PRELOAD_WRITE_DAC: begin //9
        //{{{

            NPU_ADDR_w        = {1'b1, NPU_CORE_config_data_addr[setdactiaconfig_run_addr]};
            NPU_DIN_w         = NPU_CORE_config_data[setdactiaconfig_run_addr];
            NPU_CLKDAC_w_gen();
        end
        //}}}
        
        READADC_KERNEL: begin //11
            NPU_ADDR_w = {0, readadc_kernel_run_addr};
        end

        default: begin
            NPU_ADDR_w        = 1'b0;
            NPU_DIN_w         = 1'b0;
            NPU_CLKDAC_w      = 1'b0;
        end
    endcase
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        NPU_ADDR    <= 1'b0;
        NPU_DIN     <= 1'b0;
        NPU_CLKDAC  <= 1'b0;
    end
    else begin
        NPU_ADDR    <= NPU_ADDR_w    ;
        NPU_DIN     <= NPU_DIN_w     ;
        NPU_CLKDAC  <= NPU_CLKDAC_w  ;
    end
end
//}}}

//NPU_CLKREG_(SEL/BL/WL/TIA) ,  NPU_DINSWREG_(SEL/BL/WL/TIA)
//{{{
always @(CS or setsw_count) begin
    if (CS != SETSW) begin
        NPU_DINSWREG_SEL_w = 1'b0;
        NPU_DINSWREG_BL_w  = 1'b0;			
        NPU_DINSWREG_WL_w  = 1'b0;	
        NPU_DINSWREG_TIA_w = 1'b0;
        NPU_CLKREG_SEL_w   = 1'b0;
        NPU_CLKREG_BL_w    = 1'b0;
        NPU_CLKREG_WL_w    = 1'b0;	
        NPU_CLKREG_TIA_w   = 1'b0;				
    end 
    else begin
        //BL(3) V2 BL is from 255 to 0
        if (((VMM_MEM_LENGTH - 1 - setsw_count[8:1]) >= setsw_BL_ST) && ((VMM_MEM_LENGTH - 1 - setsw_count[8:1]) <= setsw_BL_END) && SET_RESET_running == 1'b1) begin
            NPU_DINSWREG_BL_w  = 1'b1;
        end
        else begin
            NPU_DINSWREG_BL_w  = 1'b0;
        end 
        
        //TIA(2) V2 TIA is from 0 to 255
        if (setsw_count[8:1] >= setsw_BL_ST && setsw_count[8:1] <= setsw_BL_END && (VMM_running == 1'b1 || READ_MEM_running == 1'b1)) begin
            NPU_DINSWREG_TIA_w  = 1'b1;
        end
        else begin
            NPU_DINSWREG_TIA_w = 1'b0;
        end 

        //WL(0), v2 WL is setting from 255 to 0
        if (((VMM_MEM_LENGTH - 1 - setsw_count[8:1]) >= setsw_WL_ST) && ((VMM_MEM_LENGTH - 1 - setsw_count[8:1]) <= setsw_WL_END)) begin
            NPU_DINSWREG_WL_w = 1'b1;
        end
        else begin
            NPU_DINSWREG_WL_w = 1'b0;
        end 

        //SEL(1), v2 SEL is setting from 0 to 255, match WL_ST and WL_END
        if (setsw_count[8:1] >= setsw_WL_ST && setsw_count[8:1] <= setsw_WL_END) begin
            NPU_DINSWREG_SEL_w = 1'b1;
        end
        else begin
            NPU_DINSWREG_SEL_w = 1'b0;
        end 

        //CLKREG
        if (setsw_count[0] == 1) begin
            NPU_CLKREG_SEL_w   = 1'b1;
            NPU_CLKREG_BL_w    = 1'b1;
            NPU_CLKREG_WL_w    = 1'b1;	
            NPU_CLKREG_TIA_w   = 1'b1;				
        end 
        else begin
            NPU_CLKREG_SEL_w   = 1'b0;
            NPU_CLKREG_BL_w    = 1'b0;
            NPU_CLKREG_WL_w    = 1'b0;	
            NPU_CLKREG_TIA_w   = 1'b0;				
        end
    end 
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        NPU_DINSWREG <= 4'b0;
        NPU_CLKREG   <= 4'b0;
    end
    else begin
        NPU_DINSWREG[0] <= NPU_DINSWREG_WL_w  ;	
        NPU_DINSWREG[1] <= NPU_DINSWREG_SEL_w ;
        NPU_DINSWREG[2] <= NPU_DINSWREG_TIA_w ;
        NPU_DINSWREG[3] <= NPU_DINSWREG_BL_w  ;			
        NPU_CLKREG[0]   <= NPU_CLKREG_WL_w    ;	
        NPU_CLKREG[1]   <= NPU_CLKREG_SEL_w   ;
        NPU_CLKREG[2]   <= NPU_CLKREG_TIA_w   ;				
        NPU_CLKREG[3]   <= NPU_CLKREG_BL_w    ;
    end
end
//}}}

//NPU_DACTIA_SW, NPU_DACWL_SW, NPU_DACBL_SW, NPU_DACSEL_SW, NPU_DACWLREFSW, NPU_ADCRST1, NPU_ADCRST2
//{{{
always @(CS or pulse_count) begin
    case (CS)
        APPLY_V: begin
            NPU_CLKADC_SW_w = 1'b1;
            if (VMM_running) begin
            //{{{
                if (pulse_count >= NPU_WRAP_TIA_SWST) begin
                    NPU_DACTIA_SW_w = 1'b1;
                end
                if (pulse_count >= NPU_WRAP_WL_SWST) begin
                    NPU_DACWL_SW_w = 1'b1;
                    NPU_DACWLREFSW_w = 1'b1;
                end
                if (pulse_count >= NPU_WRAP_SEL_SWST) begin
                    NPU_DACSEL_SW_w = 1'b1;
                end		
            end	
            //}}}
            else if (READ_MEM_running) begin
            //{{{
                NPU_DACWLREFSW_w = 1'b0;
                if (pulse_count >= NPU_WRAP_TIA_SWST_read) begin
                    NPU_DACTIA_SW_w = 1'b1;
                end
                if (pulse_count >= NPU_WRAP_WL_SWST_read) begin
                    NPU_DACWL_SW_w = 1'b1;
                end
                if (pulse_count >= NPU_WRAP_SEL_SWST_read) begin
                    NPU_DACSEL_SW_w = 1'b1;
                end		
            end	
            //}}}
            else if (SET_RESET_running) begin
            //{{{
				if (pulse_count >= NPU_WRAP_WL_pulsewidth_set_st && pulse_count <= NPU_WRAP_WL_pulsewidth_set_end) begin
					NPU_DACWL_SW_w = 1'b1;
                end
                else begin
					NPU_DACWL_SW_w = 1'b0;
                end
				if (pulse_count >= NPU_WRAP_BL_pulsewidth_set_st && pulse_count <= NPU_WRAP_BL_pulsewidth_set_end) begin
					NPU_DACBL_SW_w = 1'b1;
                end
                else begin
					NPU_DACBL_SW_w = 1'b0;
                end
				if (pulse_count >= NPU_WRAP_SEL_pulsewidth_set_st && pulse_count <= NPU_WRAP_SEL_pulsewidth_set_end) begin
					NPU_DACSEL_SW_w = 1'b1;
                end
                else begin
					NPU_DACSEL_SW_w = 1'b0;
                end
            end
            //}}}
        end
       
        READADC_PRELOAD_0: begin
            NPU_CLKADC_SW_w = 1'b1;
            NPU_DACTIA_SW_w = 1'b1;
            NPU_DACWL_SW_w = 1'b1;
            NPU_DACSEL_SW_w = 1'b1;	
        end 
        READADC_PRELOAD_WRITE_DAC: begin
            NPU_CLKADC_SW_w = 1'b1;
            NPU_DACTIA_SW_w = 1'b1;
            NPU_DACWL_SW_w = 1'b1;
            NPU_DACSEL_SW_w = 1'b1;	
        end 
        READADC_PRELOAD_1: begin
            NPU_CLKADC_SW_w = 1'b1;
            NPU_DACTIA_SW_w = 1'b1;
            NPU_DACWL_SW_w = 1'b1;
            NPU_DACSEL_SW_w = 1'b1;	
        end 
            
        READADC_KERNEL: begin
            NPU_CLKADC_SW_w       = 1'b1;
            NPU_DACTIA_SW_w = 1'b1;
            NPU_DACWL_SW_w = 1'b1;
            NPU_DACSEL_SW_w = 1'b1;	
        end

        default: begin
            NPU_CLKADC_SW_w   = 1'b0;
            NPU_DACBL_SW_w   = 1'b0;
            NPU_DACTIA_SW_w  = 1'b0;
            NPU_DACWL_SW_w   = 1'b0;
            NPU_DACWLREFSW_w = 1'b0;
            NPU_DACSEL_SW_w  = 1'b0;
        end
    endcase
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        NPU_CLKADC_SW   <= 1'b0;
        NPU_DACBL_SW   <= 1'b0;
        NPU_DACTIA_SW  <= 1'b0;
        NPU_DACWL_SW   <= 1'b0;
        NPU_DACWLREFSW <= 1'b0;
        NPU_DACSEL_SW  <= 1'b0;
    end
    else begin
        NPU_CLKADC_SW   <= NPU_CLKADC_SW_w;
        NPU_DACBL_SW   <= NPU_DACBL_SW_w   ;
        NPU_DACTIA_SW  <= NPU_DACTIA_SW_w  ;
        NPU_DACWL_SW   <= NPU_DACWL_SW_w   ;
        NPU_DACWLREFSW <= NPU_DACWLREFSW_w ;
        NPU_DACSEL_SW  <= NPU_DACSEL_SW_w  ;
    end
end
//}}}

//NPU_CLKADC_SW, NPU_CLKADC
//{{{
always @(CS or readadc_internal_state) begin
    case (CS)
        READADC_KERNEL: begin
        
            if (readadc_internal_state >= 0 && readadc_internal_state <= adc_high_period_v2 - 1) begin 
                NPU_CLKADC_w          = 1'b1;
            end
            else begin
                NPU_CLKADC_w          = 1'b0;
            end
        end
        
        default: begin
            NPU_CLKADC_w      = 1'b0;
        end
    endcase
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        NPU_CLKADC      <= 1'b0;
    end
    else begin
        NPU_CLKADC      <= NPU_CLKADC_w      ;
    end
end
//}}}

//NPU_SET, NPU_RESET
//{{{
always @(CS) begin
    case (CS)
        APPLY_V: begin
            if (SET_RESET_running == 1'b1) begin
                if (NPU_WRAP_setreset_mode[0] == 1'b1) begin 
                    //1 是set，0是reset              
                    NPU_SET_w   = 1'b1;
                    NPU_RESET_w = 1'b0;
                end 
                else begin
                    NPU_SET_w   = 1'b0;
                    NPU_RESET_w = 1'b1;
                end
            end
            else begin
                NPU_SET_w       = 1'b0;
                NPU_RESET_w     = 1'b0;
            end
        end
        default: begin
            NPU_SET_w     = 1'b0;
            NPU_RESET_w   = 1'b0;
        end 
    endcase
end

always @( posedge clk or negedge rst_n) begin
    if (rst_n == 1'b0) begin
        NPU_SET     <= 1'b0;
        NPU_RESET   <= 1'b0;
    end
    else begin
        NPU_SET     <= NPU_SET_w;
        NPU_RESET   <= NPU_RESET_w;
    end
end
//}}}
