
//VMM
//{{{

//VMM_input_indexer, USELESS, just keep the code
//{{{
/*
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        VMM_input_indexer <= 256'b0;
        VMM_input_indexer_update <= 1'b0;
    end
    else begin
        if (CS == IDLE) begin
            if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_write_config_flag) begin
                if (axi_w_opt_addr[7:6] == 2'd2 && axi_w_opt_addr[5:0] == 6'd1) begin
                    //write NPU_WRAP_WL_ST and NPU_WRAP_WL_LEN, need to update VMM_input_indexer
                    //need to wait one cycle to wait NPU_WRAP_WL_ST and NPU_WRAP_WL_LEN are stable
                    VMM_input_indexer_update <= 1'b1;
                end//addr
            end//AXI
    
            if (VMM_input_indexer_update == 1) begin
                //TODO, this part may need to change, maybe we need several clk to update the indexer to avoid big area
                VMM_input_indexer_update <= 1'b0;
                for ( i = 0; i < VMM_MEM_LENGTH; i = i + 1) begin
                    if (i <= NPU_WRAP_WL_END && i >= NPU_WRAP_WL_ST) begin
                        VMM_input_indexer[i] <= 1'b1;
                    end
                    else begin
                        VMM_input_indexer[i] <= 1'b0;
                    end
                end //for
            end //update
        end //CS
    end //else
end
*/
//}}}

//VMM_input_counter, USELESS, just keep the code
//{{{
/*
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        VMM_input_counter <= 256'b0;
    end
    else begin
        if (CS == IDLE) begin
            if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_write_vmm_input_data_flag) begin
                //write VMM_in_data
                for ( i = 0; i < 4; i = i + 1) begin
                    if (AXI_wstrb[i] == 1'b1) begin
                        VMM_input_counter[axi_w_opt_addr * 4 + i] <= 1'b1; //TODO ARES
                    end
                end
            end//AXI
        end//CS
        else begin
            VMM_input_counter <= 256'b0;
        end
    end
end
*/
//}}}

//}}}

//READ_MEM
//{{{
//read_mem_instr_valid
//This thing's tragger condition is same as axi_ar_read_mem_flag, 
//However, it's only feature is tragger CS move forward. Once CS move, it must be reset to 0.
//This instr_valid and the VMM_input_counter are all traggering an instr valid, and make CS move forward.
//The reason this instr_valid and VMM_input_counter need to be reset is, the VMM_input_valid and read_mem_instr_valid should not keep high, when CS move back to IDLE, tragger CS move forward again.
//axi_ar_read_mem_flag must keep until the data is really read from AXI.
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        read_mem_instr_valid <= 1'b0;
    end
    else begin
        if (CS == IDLE) begin
            //when idle and have valid ar instr, rise read_mem_instr_valid until CS move
            if (axi_ar_instr_valid == 1'b1) begin
                if (AXI_araddr[18:0] >= NPU_MEM_START_ADDR && AXI_araddr[18:0] < NPU_MEM_END_ADDR ) begin
                    //same as axi_ar_read_mem_flag
                    if (NPU_WRAP_setreset_mode[1] == 1'b1) begin
                        //TODO ARES
                        //read_mem_flag的时候，要判断是不是NPU_WRAP_setreset_mode[1] == 1，如果不是，就不动状态机了。
                        read_mem_instr_valid <= 1'b1; 
                    end
                end
            end
        end
        else begin
            read_mem_instr_valid <= 1'b0;
        end
    end
end
//}}}

//SET_RESET
//{{{
    //instr valid rise should not use AXI_awvalid, need to use AXI_wvalid, 
    //because:
        //1, aw send wl bl info
        //2, w send v_sel, v_wl, v_bl info
        //only when receive valid wdata, the whole instr is complete. in this case can rise instr valid
    //instr valid is used for CS to move forward, once CS change, instr valid is useless. now need to lower it immediately.
    //instr_valid 's rise condition is same as set_reset_v_sel, but set_reset_v_sel need to keep its value even CS != IDLE
    //so, do not share set_reset_instr_valid's lower condition with set_reset_v_sel

always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        set_reset_instr_valid <= 1'b0;
    end
    else begin
        if (CS == IDLE) begin
            //if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_set_reset_write_mem_flag) begin
            if (AXI_bvalid && axi_aw_set_reset_write_mem_flag) begin
                //bvalid == 1 means AXI fully receive the input instr and input data
                //axi_aw_set_reset_write_mem_flag == 1'b1 means this is a set reset instr
                if (NPU_WRAP_setreset_mode[1] == 1'b0) begin
                    //need to judge is mode[1] is read/vmm mode or set mode
                    set_reset_instr_valid <= 1'b1;
                end
            end
        end
        else begin
            set_reset_instr_valid <= 1'b0;
        end
    end
end

//set_reset_v_sel, set_reset_v_wl, set_reset_v_bl
//{{{
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        set_reset_v_sel <= 0;
        set_reset_v_wl <= 0;
        set_reset_v_bl <= 0;
    end
    else begin
        if ( AXI_wready && AXI_wvalid && axi_aw_flag && axi_aw_set_reset_write_mem_flag) begin
            //data receive condition is same as VMM_in_data 
            set_reset_v_sel <= AXI_wdata[7:0];
            if (NPU_WRAP_setreset_mode[0] == 1'b1) begin
                set_reset_v_bl <= AXI_wdata[15:8];
                set_reset_v_wl <= 8'b0;
            end
            else begin
                set_reset_v_bl <= 8'b0;
                set_reset_v_wl <= AXI_wdata[15:8];
            end
        end
    end
end
//}}}
//}}}
