
//wire
//AXI related
//{{{
wire axi_aw_wrap_en;
wire axi_wr_wrap_en;
wire [31:0]  axi_aw_wrap_size ; 
wire [31:0]  axi_ar_wrap_size ;
wire axi_aw_instr_valid; 
wire axi_ar_instr_valid;
wire axi_aw_write_wrap_control_instr_valid;
wire axi_ar_read_wrap_control_instr_valid;

//}}}

//reg	
//AXI related
//{{{
reg [AXI_ADDR_WIDTH - 1 : 0] 	axi_instr_awaddr;
reg [AXI_ADDR_WIDTH - 1 : 0] 	axi_instr_araddr;

reg [AXI_ADDR_WIDTH - 1 : 0]   axi_w_opt_addr; //TODO width can change
reg [AXI_ADDR_WIDTH - 1 : 0]   axi_r_opt_addr;

reg axi_aw_flag;    //writing 
reg axi_ar_flag;    //reading

reg [7:0] axi_instr_awlen_cntr;
reg [7:0] axi_instr_arlen_cntr;
reg [1:0] axi_instr_arburst;
reg [1:0] axi_instr_awburst;
reg [7:0] axi_instr_arlen;
reg [7:0] axi_instr_awlen;

reg axi_aw_write_core_config_flag;
reg axi_aw_write_wrap_config_flag;
reg axi_aw_write_wrap_control_flag;
reg axi_ar_read_output_flag;
reg axi_ar_read_core_config_flag;
reg axi_ar_read_wrap_config_flag;
reg axi_ar_read_wrap_control_flag;
//}}}

//assign    
//AXI related
//{{{
    assign  axi_aw_wrap_size = (axi_instr_awlen << 2); 
    assign  axi_aw_wrap_en = ((axi_instr_awaddr & axi_aw_wrap_size) == axi_aw_wrap_size)? 1'b1: 1'b0;
    

    assign axi_aw_instr_valid = ( CS == IDLE && 
                                ~AXI_awready && AXI_awvalid 
                                && ~axi_aw_flag && ~axi_ar_flag 
                                ) ? 1 : 0;
    
    assign axi_aw_write_wrap_control_instr_valid = (  
                                ~AXI_awready && AXI_awvalid 
                                && ~axi_aw_flag && ~axi_ar_flag 
                                && AXI_awaddr >= NPU_WRAP_CONTROL_ADDR_ST
                                && AXI_awaddr < (NPU_WRAP_CONTROL_ADDR_ST + CONTROL_LENGTH * 4)
                                ) ? 1 : 0;

    
    assign  axi_ar_wrap_size = (axi_instr_arlen << 2); 
    assign  axi_wr_wrap_en = ((axi_instr_araddr & axi_ar_wrap_size) == axi_ar_wrap_size)? 1'b1: 1'b0;


    assign axi_ar_instr_valid = ( CS == IDLE &&
                                ~AXI_arready && AXI_arvalid 
                                && ~axi_aw_flag && ~axi_ar_flag 
                                ) ? 1 : 0;

    assign axi_ar_read_wrap_control_instr_valid = (
                                ~AXI_arready && AXI_arvalid 
                                && ~axi_aw_flag && ~axi_ar_flag 
                                && AXI_araddr >= NPU_WRAP_CONTROL_ADDR_ST
                                && AXI_araddr < (NPU_WRAP_CONTROL_ADDR_ST + CONTROL_LENGTH * 4)
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
        if (axi_aw_instr_valid == 1'b1 || axi_aw_write_wrap_control_instr_valid == 1'b1) begin
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

//axi_aw_write_core_config_flag, axi_aw_write_wrap_config_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_aw_write_core_config_flag <= 1'b0;
        axi_aw_write_wrap_config_flag <= 1'b0;
    end 
    else begin    
        if (axi_aw_instr_valid == 1'b1) begin
            if (AXI_awaddr >=NPU_CORE_CONFIG_ADDR_ST && 
                AXI_awaddr < NPU_CORE_CONFIG_ADDR_ST + 64 * 4) begin
                axi_aw_write_core_config_flag <= 1'b1;
            end
            else if (AXI_awaddr >=NPU_WRAP_CONFIG_ADDR_ST &&
                AXI_awaddr < NPU_WRAP_CONFIG_ADDR_ST + CONFIG_LENGTH * 4) begin
                axi_aw_write_wrap_config_flag <= 1'b1;
            end
        end
        else if (AXI_bvalid == 1'b1) begin 
            axi_aw_write_core_config_flag <= 1'b0;
            axi_aw_write_wrap_config_flag <= 1'b0;
        end
    end 
end      
//}}}

//axi_aw_write_wrap_control_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_aw_write_wrap_control_flag <= 1'b0;
    end 
    else begin    
        if (axi_aw_write_wrap_control_instr_valid == 1'b1) begin
            axi_aw_write_wrap_control_flag <= 1'b1;
        end
        else if (AXI_bvalid == 1'b1) begin 
            axi_aw_write_wrap_control_flag <= 1'b0;
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
        if (axi_aw_instr_valid == 1'b1 || axi_aw_write_wrap_control_instr_valid == 1'b1)begin
            axi_instr_awaddr <= AXI_awaddr[AXI_ADDR_WIDTH - 1:0] - AXI_BASE_ADDR;  
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
        if (axi_aw_flag == 1'b1) begin
            if (AXI_wready == 1'b0)begin
                AXI_wready <= 1'b1;
            end
        end
        if (AXI_wlast && AXI_wready) begin
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
        if (axi_aw_instr_valid == 1'b1) begin
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
        if (axi_ar_instr_valid == 1'b1 || axi_ar_read_wrap_control_instr_valid == 1'b1) begin
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

//axi_ar_read_output_flag, axi_ar_read_core_config_flag, axi_ar_read_wrap_config_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_ar_read_output_flag <= 1'b0;
        axi_ar_read_core_config_flag <= 1'b0;
        axi_ar_read_wrap_config_flag <= 1'b0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1) begin
            if (AXI_araddr[AXI_ADDR_WIDTH - 1:0] >= AXI_OUT_DATA_ADDR_ST && 
                AXI_araddr[AXI_ADDR_WIDTH - 1:0] < AXI_OUT_DATA_ADDR_ST + DATA_LENGTH * 4) begin
                axi_ar_read_output_flag <= 1'b1; 
            end
            else if (AXI_araddr[AXI_ADDR_WIDTH - 1:0] >= NPU_CORE_CONFIG_ADDR_ST && 
                AXI_araddr[AXI_ADDR_WIDTH - 1:0] < NPU_CORE_CONFIG_ADDR_ST + 'h100) begin
                axi_ar_read_core_config_flag <= 1'b1;
            end
            else if (AXI_araddr[AXI_ADDR_WIDTH - 1:0] >= NPU_WRAP_CONFIG_ADDR_ST && 
                AXI_araddr[AXI_ADDR_WIDTH - 1:0] < NPU_WRAP_CONFIG_ADDR_ST + CONFIG_LENGTH * 4) begin
                axi_ar_read_wrap_config_flag <= 1'b1;
            end
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            axi_ar_read_output_flag <= 1'b0;
            axi_ar_read_core_config_flag <= 1'b0;
            axi_ar_read_wrap_config_flag <= 1'b0;
        end
    end 
end      
//}}}

//axi_ar_read_wrap_control_flag
//{{{
always @( posedge clk or negedge rst_n )
begin
    if ( rst_n == 1'b0 ) begin
        axi_ar_read_wrap_control_flag <= 1'b0;
    end 
    else begin    
        if (axi_ar_read_wrap_control_instr_valid == 1'b1) begin
            if (AXI_araddr >= NPU_WRAP_CONTROL_ADDR_ST && 
                AXI_araddr < (NPU_WRAP_CONTROL_ADDR_ST + CONTROL_LENGTH * 4 )
            ) begin
                axi_ar_read_wrap_control_flag <= 1'b1; 
            end
        end
        else if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            axi_ar_read_wrap_control_flag <= 1'b0;
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
        if (axi_ar_instr_valid == 1'b1 || axi_ar_read_wrap_control_instr_valid == 1'b1) begin
            axi_instr_araddr <= AXI_araddr[AXI_ADDR_WIDTH - 1 : 0] - AXI_BASE_ADDR; 
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
        AXI_rresp  <= 2'b0;
    end 
    else begin    
        if (axi_ar_flag == 1'b1 && AXI_rvalid == 1'b0) begin 
            AXI_rvalid <= 1'b1;
        end
        if (AXI_rlast == 1'b1 && AXI_rready == 1'b1) begin
            AXI_rvalid <= 1'b0;
        end            
    end
end    

always @( posedge clk or negedge rst_n ) begin
    if ( rst_n == 1'b0 ) begin
        AXI_rid <= 1'b0;
    end 
    else begin    
        if (axi_ar_instr_valid == 1'b1) begin
            AXI_rid    <= AXI_arid;
        end
    end
end
//}}}

//rdata
//{{{
always @(*) begin
    if ( axi_ar_read_output_flag == 1'b1 ) begin
        AXI_rdata = data_mem[axi_r_opt_addr]; //use output_mem_addr_buffer_1
    end
    else if (axi_ar_read_core_config_flag  == 1'b1 ) begin
        AXI_rdata = NPU_core_config[axi_r_opt_addr]; //use axi_r_opt_addr
    end
    else if (axi_ar_read_wrap_config_flag  == 1'b1 ) begin
        AXI_rdata = NPU_WRAP_config[axi_r_opt_addr]; //use axi_r_opt_addr
    end
    else if (axi_ar_read_wrap_control_flag  == 1'b1 ) begin
        AXI_rdata = NPU_WRAP_control[axi_r_opt_addr]; //use axi_r_opt_addr
    end
    else begin
        AXI_rdata = 1'b0;
    end
end
//}}}

always @(axi_aw_write_core_config_flag, 
        axi_aw_write_wrap_config_flag, 
        axi_aw_write_wrap_control_flag, 
        axi_instr_awaddr) begin
    if(axi_aw_write_core_config_flag  == 1'b1 ) begin
        axi_w_opt_addr = (axi_instr_awaddr - NPU_CORE_CONFIG_ADDR_ST) >> ADDR_LSB;
    end
    else if(axi_aw_write_wrap_config_flag == 1'b1 ) begin
        axi_w_opt_addr = (axi_instr_awaddr - NPU_WRAP_CONFIG_ADDR_ST) >> ADDR_LSB;
    end
    else if(axi_aw_write_wrap_control_flag == 1'b1 ) begin
        axi_w_opt_addr = (axi_instr_awaddr - NPU_WRAP_CONTROL_ADDR_ST) >> ADDR_LSB;
    end
    else begin
        axi_w_opt_addr = 1'b0;
    end
end

always @(axi_ar_read_output_flag, 
        axi_ar_read_core_config_flag, 
        axi_ar_read_wrap_config_flag, 
        axi_ar_read_wrap_control_flag, 
        axi_instr_araddr) begin
    if( axi_ar_read_output_flag == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - AXI_OUT_DATA_ADDR_ST) >> ADDR_LSB;
    end
    else if(axi_ar_read_core_config_flag  == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - NPU_CORE_CONFIG_ADDR_ST) >> ADDR_LSB;
    end
    else if(axi_ar_read_wrap_config_flag  == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - NPU_WRAP_CONFIG_ADDR_ST) >> ADDR_LSB;
    end
    else if(axi_ar_read_wrap_control_flag  == 1'b1 ) begin
        axi_r_opt_addr = (axi_instr_araddr - NPU_WRAP_CONTROL_ADDR_ST) >> ADDR_LSB;
    end
    else begin
        axi_r_opt_addr = 1'b0;
    end
end



