//assign    
//AXI related
//{{{
    assign  axi_aw_wrap_size = (axi_instr_awlen << 2); 
    //  assign  axi_aw_wrap_size = (AXI_DATA_WIDTH/8 * (axi_instr_awlen)); 
    assign  axi_aw_wrap_en = ((axi_instr_awaddr & axi_aw_wrap_size) == axi_aw_wrap_size)? 1'b1: 1'b0;
    

    assign axi_aw_instr_valid = (CS == IDLE 
                                && ~AXI_awready && AXI_awvalid 
                                && ~axi_aw_flag && ~axi_ar_flag 
                                && AXI_awaddr >= NPU_AXI_BASE_ADDR 
                                && AXI_awaddr < (NPU_AXI_BASE_ADDR + 32'h8_0000)
                                ) ? 1 : 0;
    

    assign axi_aw_VMM_in_data_instr_valid = (
                                                (
                                                (NPU_WRAP_disable_access_data_anytime == 0 && CS != SETDAC_KERNEL)
                                                || (NPU_WRAP_disable_access_data_anytime == 1 && CS == IDLE)
                                                )
                                            && ~AXI_awready && AXI_awvalid 
                                            && ~axi_aw_flag && ~axi_ar_flag 
                                            && AXI_awaddr >= NPU_AXI_BASE_ADDR     
                                            && AXI_awaddr < (NPU_AXI_BASE_ADDR + 32'h8_0000) 
                                            && AXI_awaddr[18:0] >= NPU_VMM_INPUT_START_ADDR 
                                            && AXI_awaddr[18:0] < NPU_VMM_INPUT_END_ADDR 
                                            ) ? 1 : 0; //This aw_valid is only used for writing VMM_in_data
    

    assign  axi_ar_wrap_size = (axi_instr_arlen << 2); 
    //  assign  axi_ar_wrap_size = (AXI_DATA_WIDTH/8 * (axi_instr_arlen)); 
    assign  axi_wr_wrap_en = ((axi_instr_araddr & axi_ar_wrap_size) == axi_ar_wrap_size)? 1'b1: 1'b0;


    assign axi_ar_instr_valid = (CS == IDLE 
                                && ~AXI_arready && AXI_arvalid 
                                && ~axi_aw_flag && ~axi_ar_flag 
                                && AXI_araddr >= NPU_AXI_BASE_ADDR
                                && AXI_araddr < (NPU_AXI_BASE_ADDR + 32'h8_0000)
                                ) ? 1 : 0;

    assign axi_ar_VMM_data_instr_valid = (
                                                (
                                                (NPU_WRAP_disable_access_data_anytime == 0 && CS != SETDAC_KERNEL)
                                                || (NPU_WRAP_disable_access_data_anytime == 1 && CS == IDLE)
                                                )
                                        && ~AXI_arready && AXI_arvalid 
                                        && ~axi_aw_flag && ~axi_ar_flag 
                                        && AXI_araddr >= NPU_AXI_BASE_ADDR 
                                        && AXI_araddr < (NPU_AXI_BASE_ADDR + 32'h8_0000)
                                        && ((AXI_araddr[18:0] >= NPU_VMM_INPUT_START_ADDR && AXI_araddr[18:0] < NPU_VMM_INPUT_END_ADDR) || 
                                            (AXI_araddr[18:0] >= NPU_VMM_OUTPUT_START_ADDR && AXI_araddr[18:0] < NPU_VMM_OUTPUT_END_ADDR))
                                        ) ? 1 : 0;

//}}}

//awready
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        AXI_awready <= 1'b0;
        axi_aw_flag <= 1'b0;
    end 
    else begin    
        if (axi_aw_instr_valid == 1'b1 || axi_aw_VMM_in_data_instr_valid == 1'b1) begin
            AXI_awready <= 1'b1;
            axi_aw_flag <= 1'b1;
        end
        else if (AXI_wlast && AXI_wready & AXI_wvalid) begin
            axi_aw_flag  <= 1'b0;
        end
        else begin
            AXI_awready <= 1'b0;
        end
    end 
end      
//}}}

//axi_aw_write_config_flag, axi_aw_set_reset_write_mem_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_aw_write_config_flag <= 1'b0;
        axi_aw_set_reset_write_mem_flag <= 1'b0;
    end 
    else begin    
        if (axi_aw_instr_valid == 1'b1) begin
            if (AXI_awaddr[18:0] >= NPU_CONFIG_START_ADDR && AXI_awaddr[18:0] < NPU_CONFIG_END_ADDR) begin
                axi_aw_write_config_flag <= 1'b1; 
            end
            else if (AXI_awaddr[18:0] >= NPU_MEM_START_ADDR && AXI_awaddr[18:0] < NPU_MEM_END_ADDR) begin
                axi_aw_set_reset_write_mem_flag <= 1'b1;
            end
        end
        else if (AXI_bvalid == 1'b1) begin 
            //bvalid == 1 means AXI wdata is stable in wrap, now can lower flag
            axi_aw_write_config_flag <= 1'b0;
            axi_aw_set_reset_write_mem_flag <= 1'b0;
        end
    end 
end      
//}}}

//axi_aw_write_vmm_input_data_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_aw_write_vmm_input_data_flag <= 1'b0;
    end 
    else begin    
        if (axi_aw_VMM_in_data_instr_valid == 1'b1) begin
            //do not need NPU_VMM_INPUT_START/END_ADDR judgement, already in axi_aw_VMM_in_data_instr_valid
            axi_aw_write_vmm_input_data_flag <= 1'b1; 
        end
        else if (AXI_bvalid == 1'b1) begin 
            //bvalid == 1 means AXI wdata is stable in wrap, now can lower flag
            axi_aw_write_vmm_input_data_flag <= 1'b0;
        end
    end 
end      
//}}}

//axi_instr_awaddr
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_instr_awaddr <= 1'b0;
        axi_instr_awlen_cntr <= 1'b0;
        axi_instr_awburst <= 1'b0;
        axi_instr_awlen <= 1'b0;
    end 
    else begin    
        if (axi_aw_instr_valid == 1'b1 || axi_aw_VMM_in_data_instr_valid == 1'b1)begin
            axi_instr_awaddr <= AXI_awaddr[AXI_ADDR_WIDTH - 1:0] - NPU_AXI_BASE_ADDR;  
            axi_instr_awburst <= AXI_awburst; 
            axi_instr_awlen <= AXI_awlen;     
            // start address of transfer
            axi_instr_awlen_cntr <= 1'b0;
        end   
        else if((axi_instr_awlen_cntr <= axi_instr_awlen) && AXI_wready && AXI_wvalid) begin
            axi_instr_awlen_cntr <= axi_instr_awlen_cntr + 1;
            case (axi_instr_awburst)
            2'b00: // fixed burst
                begin
                    axi_instr_awaddr <= axi_instr_awaddr;          
                end   
            2'b01: //incremental burst
                begin
                    axi_instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    axi_instr_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                end   
            2'b10: //Wrapping burst
                if (axi_aw_wrap_en) begin
                    axi_instr_awaddr <= (axi_instr_awaddr - axi_aw_wrap_size); 
                end
                else begin
                    axi_instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                    axi_instr_awaddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}}; 
                end                      
            default: //reserved (incremental burst for example)
                begin
                    axi_instr_awaddr <= axi_instr_awaddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1;
                end
            endcase              
        end
    end 
end      
//}}}

//wready
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        AXI_wready <= 1'b0;
    end 
    else begin
        //if (~AXI_wready && AXI_wvalid && axi_aw_flag) begin //FPGA edition
        //if (~AXI_wready && axi_aw_flag) begin //Charles and me agreed edition
        //    AXI_wready <= 1'b1;
        //end
        if (axi_aw_flag == 1'b1) begin
            if (CS == SETDAC_KERNEL && axi_aw_write_vmm_input_data_flag == 1'b1) begin
                //if I send AW on the end of state SETSW and the W will begin and could not finish if state move to SETDAC_KERNEL.
                //use this method to pause the transmission if state is SETDAC_KERNEL

                AXI_wready <= 1'b0;
            end
            else begin
                if (AXI_wready == 1'b0)begin
                    AXI_wready <= 1'b1;
                end
            end
        end
        else if (AXI_wlast && AXI_wready) begin
            AXI_wready <= 1'b0;
        end
     end
end
//}}}

//WRITE_RESP (B)
//{{{
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_bvalid <= 1'b0;
        AXI_bresp <= 2'b0;
        AXI_buser <= 1'b0;
    end 
    else begin    
        if (axi_aw_flag && AXI_wready && AXI_wvalid && ~AXI_bvalid && AXI_wlast ) begin
            AXI_bvalid <= 1'b1;
            AXI_bresp  <= 2'b0; 
        end                   
        else begin
            if (AXI_bready && AXI_bvalid) begin
                AXI_bvalid <= 1'b0; 
            end  
        end
    end
end  

always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_bid   <= 1'b0;
    end 
    else begin           
        if (axi_aw_instr_valid == 1'b1 || axi_aw_VMM_in_data_instr_valid == 1'b1)begin
            AXI_bid <= AXI_awid;
        end 
    end
end
    

//}}}

//arready
//{{{   
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_arready <= 1'b0;
        axi_ar_flag <= 1'b0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1 || axi_ar_VMM_data_instr_valid == 1'b1) begin
            AXI_arready <= 1'b1;
            axi_ar_flag <= 1'b1;
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            axi_ar_flag  <= 1'b0;
        end
        else begin
            AXI_arready <= 1'b0;
        end
    end 
end      
//}}}

//axi_ar_read_config_flag, axi_ar_read_mem_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_ar_read_config_flag <= 1'b0;
        axi_ar_read_mem_flag <= 1'b0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1) begin
            //judge read mem, two methods:
            //1. judge whole AXI_araddr[18:0]. (current solution)
            //2. judge AXI_araddr[18:16] = 400 ~ 7ff, if so, is read mem.
                //must do this first, then can judge AXI_araddr[11:0] for read config or read data
    
            if (AXI_araddr[18:0] >= NPU_CONFIG_START_ADDR && AXI_araddr[18:0] < NPU_CONFIG_END_ADDR) begin
                axi_ar_read_config_flag <= 1'b1; 
            end
            else if (AXI_araddr[18:0] >= NPU_MEM_START_ADDR && AXI_araddr[18:0] < NPU_MEM_END_ADDR) begin
                axi_ar_read_mem_flag <= 1'b1; 
            end
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            axi_ar_read_config_flag <= 1'b0;
            axi_ar_read_mem_flag <= 1'b0;
        end
    end 
end      
//}}}

//axi_ar_read_vmm_input_data_flag, axi_ar_read_vmm_output_data_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_ar_read_vmm_input_data_flag <= 1'b0;
        axi_ar_read_vmm_output_data_flag <= 1'b0;
    end 
    else begin    
        if (axi_ar_VMM_data_instr_valid == 1'b1) begin
            if (AXI_araddr[18:0] >= NPU_VMM_INPUT_START_ADDR && AXI_araddr[18:0] < NPU_VMM_INPUT_END_ADDR) begin
                axi_ar_read_vmm_input_data_flag <= 1'b1; 
            end
            else if (AXI_araddr[18:0] >= NPU_VMM_OUTPUT_START_ADDR && AXI_araddr[18:0] < NPU_VMM_OUTPUT_END_ADDR) begin
                axi_ar_read_vmm_output_data_flag <= 1'b1; 
            end
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            axi_ar_read_vmm_input_data_flag <= 1'b0; 
            axi_ar_read_vmm_output_data_flag <= 1'b0;
        end
    end 
end      
//}}}

//axi_instr_araddr
//{{{
//This process is used to latch the address when both 
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        axi_instr_araddr <= 1'b0;
        axi_instr_arlen_cntr <= 1'b0;
        axi_instr_arburst <= 1'b0;
        axi_instr_arlen <= 1'b0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1 || axi_ar_VMM_data_instr_valid == 1'b1) begin
            axi_instr_araddr <= AXI_araddr[AXI_ADDR_WIDTH - 1 : 0] - NPU_AXI_BASE_ADDR; 
            axi_instr_arburst <= AXI_arburst; 
            axi_instr_arlen <= AXI_arlen;     
            axi_instr_arlen_cntr <= 1'b0;
        end   
        else if((axi_instr_arlen_cntr <= axi_instr_arlen) && AXI_rvalid && AXI_rready) begin
            axi_instr_arlen_cntr <= axi_instr_arlen_cntr + 1;
        
            case (axi_instr_arburst)
            2'b00: // fixed burst
                begin
                    axi_instr_araddr       <= axi_instr_araddr;        
                end   
            2'b01: //incremental burst
                begin
                    axi_instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                    axi_instr_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                end   
            2'b10: //Wrapping burst
                if (axi_wr_wrap_en) begin
                    axi_instr_araddr <= (axi_instr_araddr - axi_ar_wrap_size); 
                end
                else begin
                    axi_instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] <= axi_instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB] + 1; 
                //araddr aligned to 4 byte boundary
                    axi_instr_araddr[ADDR_LSB-1:0]  <= {ADDR_LSB{1'b0}};   
                end                      
            default: //reserved (incremental burst for example)
                begin
                    axi_instr_araddr <= axi_instr_araddr[AXI_ADDR_WIDTH - 1:ADDR_LSB]+1;
                end
            endcase              
        end
    end 
end       
//}}}

//rlast
//{{{
always @(*) begin
    AXI_ruser = 1'b0;
    if((axi_instr_arlen_cntr == axi_instr_arlen) && AXI_rvalid == 1'b1) begin
        AXI_rlast = 1'b1;
    end
    else begin
        AXI_rlast = 1'b0;
    end
end
//}}}

//rvalid
//{{{    
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_rvalid <= 1'b0;
        AXI_rresp  <= 1'b0;
    end 
    else begin    
        if (axi_ar_flag) begin
            if (axi_ar_read_mem_flag == 1'b1 && AXI_rvalid == 1'b0) begin
                //read mem
                //{{{
                //need to sync with rlast
                if (NPU_WRAP_setreset_mode[1] == 1'b0) begin
                    //when running read mem, we need to judge if the switch NPU_WRAP_setreset_mode == 2'b10, if not, means the read mem/vmm mode is not opened, NPU wrap should not move its state machine.
                    //however, we still need to rise rvalid and rlast. if not, it will block the AXI channel. 
                    AXI_rvalid <= 1'b1;
                    AXI_rresp  <= 2'b0; 
                end
                else begin
                    if (state_machine_one_hot_indexer[READADC_KERNEL : READADC_KERNEL] == 1 && read_mem_instr_valid == 1'b0) begin
                        //Why judging state_machine_one_hot_indexer[READADC_KERNEL]:
                        //  On the AXI part, read mem is only one instr, but on state machine, it's a group of operations.
                        //  If we rise the rvalid immediately when see axi_ar_read_mem_flag == 1, that group of operations will not execute.
                        //  Judging the passed CS have READADC_KERNEL means, the last round of the group of read mem operations have been successfully executed. 
                        //Why judging read_mem_instr_valid == 1'b0:
                        //  Once AXI receive read_mem instr, axi_ar_read_mem_flag and read_mem_instr_valid will rise together, axi_ar_read_mem_flag will last until CS go back to IDLE, but read_mem_instr_valid is only used to trigger the CS to move
                        //  Once CS moved, the state_machine_one_hot_indexer will be reset to 0 and read_mem_instr_valid will also become 0. That means if state_machine_one_hot_indexer[READADC_KERNEL] = 1 again, means the new round of read mem is finished. 

                        AXI_rvalid <= 1'b1;
                        AXI_rresp  <= 2'b0; 
                    end
                    else begin
                        AXI_rvalid <= 1'b0;
                        AXI_rresp  <= 2'b0; 
                    end
                end
                //}}}
            end
            else if (axi_ar_read_vmm_input_data_flag == 1'b1 || axi_ar_read_vmm_output_data_flag == 1'b1) begin
                //Read VMM related data
                if (CS == READADC_KERNEL) begin
                    AXI_rvalid <= 1'b0;
                    AXI_rresp  <= 2'b0; 
                end
                else begin
                    if (AXI_rvalid == 1'b0) begin
                        AXI_rvalid <= 1'b1;
                        AXI_rresp  <= 2'b0; 
                    end
                end
            end
            else if (axi_ar_read_config_flag == 1'b1 && AXI_rvalid == 1'b0) begin
                AXI_rvalid <= 1'b1;
                AXI_rresp  <= 2'b0; 
            end
        end   
        if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            AXI_rvalid <= 1'b0;
            AXI_rresp  <= 2'b0; 
        end            
    end
end    

//{{{
/*
always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_rvalid <= 1'b0;
        AXI_rresp  <= 1'b0;
    end 
    else begin    
        if (axi_ar_flag && ~AXI_rvalid) begin
            if (axi_ar_read_mem_flag  == 1'b0) begin
                AXI_rvalid <= 1'b1;
                AXI_rresp  <= 2'b0; 
            end
            else begin
                //need to sync with rlast
                if (NPU_WRAP_setreset_mode[1] == 1'b0) begin
                    //TODO ARES
                    //read_mem_flag的时候，要判断是不是NPU_WRAP_setreset_mode[1] == 1，如果不是，就不动状态机了。
                    //但是rvalid 和rlast还是要动的，否则外面的AXI 会卡住。
                    //这就要求这里有个判断，如果需要动状态机则走下面的条件，如果不动状态机则直接起rvalid
                    AXI_rvalid <= 1'b1;
                    AXI_rresp  <= 2'b0; 
                end
                else begin
                    if (state_machine_one_hot_indexer[READADC_KERNEL : READADC_KERNEL] == 1 && read_mem_instr_valid == 1'b0) begin
                        AXI_rvalid <= 1'b1;
                        AXI_rresp  <= 2'b0; 
                    end
                    else begin
                        AXI_rvalid <= 1'b0;
                        AXI_rresp  <= 2'b0; 
                    end
                end
            end
        end   
        else if (AXI_rvalid && AXI_rready && axi_instr_arlen_cntr == axi_instr_arlen) begin
            AXI_rvalid <= 1'b0;
            AXI_rresp  <= 2'b0; 
        end            
    end
end    
*/
//}}}


always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_rid    <= 1'b0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1 || axi_ar_VMM_data_instr_valid == 1'b1) begin
            AXI_rid    <= AXI_arid;
        end
    end
end
//}}}

//rdata
//{{{
    //assign rdata = VMM_in_data[axi_r_opt_addr];
always @(axi_r_opt_addr, AXI_rvalid) begin
    //ARES TODO, not sure this tragger condition is enough
    //rvalid 一变化，rdata相应变化，外面clk采沿看见rvalid稳定，rdata也稳定
    //但是不确定是不是需要判断其他的flag

    if( axi_ar_read_config_flag == 1'b1 ) begin
        //rdata = config_data[axi_r_opt_addr];
        //000 to 400
        //TODO
        //000 is reading NPU_CORE_config_data
        //100 is reading NPU_CORE_config_data_addr
        //200 is reading NPU_WRAP_config_data
        //280 is reading NPU_WRAP_NN_config_data
        //axi address is 1_0000_0000, axi_w_opt_addr = 1_0000_00
        //axi_w_opt_addr
        if (axi_r_opt_addr[7:6] == 2'd0 ) begin 
            AXI_rdata = {24'b0, NPU_CORE_config_data[axi_r_opt_addr[5:0]][7:0]};
        end 
        else if (axi_r_opt_addr[7:6] == 2'd1 ) begin
            AXI_rdata = {24'b0, NPU_CORE_config_data_addr[axi_r_opt_addr[5:0]][7:0]};
        end
        else if (axi_r_opt_addr[7:6] == 2'd2 && axi_r_opt_addr[5:5] == 1'b0 ) begin
            AXI_rdata = NPU_WRAP_config_data[axi_r_opt_addr[4:0]];
        end
    end
    else if ( axi_ar_read_vmm_input_data_flag == 1'b1 ) begin
        AXI_rdata[7:0]   = VMM_in_data[(axi_r_opt_addr[5:0] << 2) + 0];
        AXI_rdata[15:8]  = VMM_in_data[(axi_r_opt_addr[5:0] << 2) + 1];
        AXI_rdata[23:16] = VMM_in_data[(axi_r_opt_addr[5:0] << 2) + 2];
        AXI_rdata[31:24] = VMM_in_data[(axi_r_opt_addr[5:0] << 2) + 3];
    end
    else if ( axi_ar_read_vmm_output_data_flag == 1'b1 || axi_ar_read_mem_flag == 1'b1  ) begin
        AXI_rdata[7:0]   = VMM_out_data[(axi_r_opt_addr[5:0] << 2) + 0];
        AXI_rdata[15:8]  = VMM_out_data[(axi_r_opt_addr[5:0] << 2) + 1];
        AXI_rdata[23:16] = VMM_out_data[(axi_r_opt_addr[5:0] << 2) + 2];
        AXI_rdata[31:24] = VMM_out_data[(axi_r_opt_addr[5:0] << 2) + 3];
    end
    else begin
        AXI_rdata = 1'b0;
    end
end
//}}}


