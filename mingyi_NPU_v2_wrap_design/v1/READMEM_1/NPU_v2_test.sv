
`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;

module NPU_v2_wrap_mingyi_tb #(
    // Parameters of Axi Slave Bus Interface AXI_Full_data
    parameter integer AXI_ID_WIDTH	= 1,
    parameter integer AXI_DATA_WIDTH	= 32,
    parameter integer AXI_ADDR_WIDTH	= 32,
    parameter integer AXI_USER_WIDTH	= 10,
    
    parameter integer MEM_LENGTH	= 2048,
    parameter integer ADDR_BYTE_OFFSET = AXI_DATA_WIDTH / 8,
    parameter integer ADDR_LSB = $clog2(ADDR_BYTE_OFFSET), //2
   
    parameter AXI_BASE_ADDR     = 32'h00000000,
    parameter NPU_CORE_CONFIG_ADDR_ST     = AXI_BASE_ADDR,
    parameter NPU_WRAP_CONFIG_ADDR_ST     = AXI_BASE_ADDR + 'h200,
    parameter NPU_WRAP_STATUS_ADDR_ST     = AXI_BASE_ADDR + 'h300,
    parameter AXI_OUT_DATA_ADDR_ST   = AXI_BASE_ADDR + 'h400,

    
    parameter TB_RESET_VALUE = 0
);


    //wire
    //NPU v2 signals 
    //{{{
    wire [5:0] DOUT;
    wire [7:0] DIN;
    wire [8:0] ADDR;//v2_256
    wire CLKDAC;
    wire [3:0] CLKREG; // ring switch clk; v2_256
    wire [3:0] DINSWREG; // ring switch data; v2_256
    wire DACBL_SW; // BL overall sw; only SETRESET use it
    wire DACBL_SW2; // TIA overall sw
    wire DACSEL_SW; // SEL overall sw
    wire DACWL_SW; // WL overall sw        
    wire SET; // WL ground enable
    wire RESET; // BL ground enable
    wire CLKADCSW;
    wire CLKADC;
    wire DACWLREFSW; // WL voltage provider     
    
    wire DISCHG;
    wire ARST_ENREG;
    wire ARST_WLREG;
    wire ASET_ENREG;
    wire ASET_WLREG;   
    //}}}

    //reg    
    reg reset;
    reg clk = 1'b0;


    //sim use


    //axi_full_master_interface
    //{{{
    AXI_BUS_MASTER #(
        .AXI_ADDR_WIDTH ( AXI_ADDR_WIDTH     ),
        .AXI_DATA_WIDTH ( AXI_DATA_WIDTH     ),
        .AXI_ID_WIDTH   ( AXI_ID_WIDTH ),
        .AXI_USER_WIDTH ( AXI_USER_WIDTH     )
    ) axi_full_master_interface();

    axi_bus_master_driver_class #(
		.DATA_WIDTH	       (AXI_DATA_WIDTH	     ),
        .MEM_LENGTH        (MEM_LENGTH),
		.ADDR_WIDTH	       (AXI_ADDR_WIDTH	     ),
        .ADDR_BYTE_OFFSET  (1) 
    ) axi_bus_master_driver = new (
        axi_full_master_interface
    );
    //}}}

    //Instantiation of NPU_v2_wrap_mingyi_gen
    //{{{
   NPU_v2_wrap_mingyi_gen  #(

		.AXI_ID_WIDTH	       (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	       (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	       (AXI_ADDR_WIDTH	     ), 
		.AXI_USER_WIDTH	       (AXI_USER_WIDTH	 ), 
        .RESET_VALUE           (TB_RESET_VALUE)

    ) (


        //axi 
        //{{{
		.awid         (axi_full_master_interface.aw_id    ),
		.awaddr       (axi_full_master_interface.aw_addr  ),
		.awlen        (axi_full_master_interface.aw_len   ),
		.awsize       (axi_full_master_interface.aw_size  ),
		.awburst      (axi_full_master_interface.aw_burst ),
		.awlock       (axi_full_master_interface.aw_lock  ),
		.awcache      (axi_full_master_interface.aw_cache ),
		.awprot       (axi_full_master_interface.aw_prot  ),
		.awqos        (axi_full_master_interface.aw_qos   ),
		.awregion     (axi_full_master_interface.aw_region),
		.awuser       (axi_full_master_interface.aw_user  ),
		.awvalid      (axi_full_master_interface.aw_valid ),
		.awready      (axi_full_master_interface.aw_ready ),

		.wdata        (axi_full_master_interface.w_data    ),
		.wstrb        (axi_full_master_interface.w_strb    ),
		.wlast        (axi_full_master_interface.w_last    ),
		.wuser        (axi_full_master_interface.w_user    ),
		.wvalid	      (axi_full_master_interface.w_valid   ),
		.wready	      (axi_full_master_interface.w_ready   ),

		.bid		    (axi_full_master_interface.b_id	    ),
		.bresp		    (axi_full_master_interface.b_resp	),
		.buser		    (axi_full_master_interface.b_user	),
		.bvalid	        (axi_full_master_interface.b_valid   ),
		.bready	        (axi_full_master_interface.b_ready   ),

		.arid		    (axi_full_master_interface.ar_id	),
		.araddr	        (axi_full_master_interface.ar_addr   ),
		.arlen		    (axi_full_master_interface.ar_len	),
		.arsize	        (axi_full_master_interface.ar_size   ),
		.arburst	    (axi_full_master_interface.ar_burst  ),
		.arlock	        (axi_full_master_interface.ar_lock   ),
		.arcache	    (axi_full_master_interface.ar_cache  ),
		.arprot	        (axi_full_master_interface.ar_prot   ),
		.arqos		    (axi_full_master_interface.ar_qos	),
		.arregion	    (axi_full_master_interface.ar_region ),
		.aruser	        (axi_full_master_interface.ar_user   ),
		.arvalid	    (axi_full_master_interface.ar_valid  ),
		.arready	    (axi_full_master_interface.ar_ready  ),

		.rid		    (axi_full_master_interface.r_id	    ),
		.rdata		    (axi_full_master_interface.r_data	),
		.rresp		    (axi_full_master_interface.r_resp	),
		.rlast		    (axi_full_master_interface.r_last	),
		.ruser		    (axi_full_master_interface.r_user	),
		.rvalid	        (axi_full_master_interface.r_valid   ),
		.rready	        (axi_full_master_interface.r_ready   ),
        //}}}
        
        //NPU v2 signals
        //{{{
        .DOUT       (DOUT       ),
        .DIN        (DIN        ),
        .ADDR       (ADDR       ),
        .CLKDAC     (CLKDAC     ),
        .CLKREG     (CLKREG     ), 
        .DINSWREG   (DINSWREG   ), 
        .DACBL_SW   (DACBL_SW   ), 
        .DACBL_SW2  (DACBL_SW2  ), 
        .DACSEL_SW  (DACSEL_SW  ), 
        .DACWL_SW   (DACWL_SW   ),         
        .SET        (SET        ), 
        .RESET      (RESET      ), 
        .CLKADCSW   (CLKADCSW   ),
        .CLKADC     (CLKADC     ),
        .DACWLREFSW (DACWLREFSW ),      
        .DISCHG     (DISCHG     ),
        .ARST_ENREG (ARST_ENREG ),
        .ARST_WLREG (ARST_WLREG ),
        .ASET_ENREG (ASET_ENREG ),
        .ASET_WLREG (ASET_WLREG ),   
        //}}}

		.clk         (clk),
		.rst_n        (reset)
    ); 
    //}}}
  
 


    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] output_list [256];
    
    assign DOUT = (CLKADC == 1) ? ADDR[5:0] : 0;
    
    localparam WL_ST = 0;
    localparam WL_END = 0;
    localparam BL_ST = 0;
    localparam BL_END = 7;
    localparam L0_single_point_opt_loop = 0;
    localparam L1_single_point_loop = 1;
    localparam L4_whole_range_loop = 1;

 


initial begin
    
    int i, j;
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;
    
    string input_hex_file;


    while (reset == TB_RESET_VALUE) begin
        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);
    write_NPU_CORE();
    write_NPU_WRAP_config();
    read_NPU_CORE();


    start_trigger (1);//dac write config
    #200;
    start_trigger (4);//start
    
    while (1) begin    
        for (i =0 ; i < 1000; i++) begin
            @(posedge clk);
        end    
        
        axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, 'h300 + 8*4, 5);
        
        for (i =0 ; i < 5; i++) begin
            $display ("status: %d, %d", i, output_list[i]);
        end    


        if (output_list[1] == BL_END &&
            output_list[3] == L1_single_point_loop &&
            output_list[4] == L4_whole_range_loop
            ) begin
            break;
        end

    end




    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, 'h400, 2);
    for (i = 0; i < 2; i ++) begin
        $display ("read out: %d, %x", i, output_list[i]);
    end 








end

task start_trigger (int mode);
//{{{
begin
    
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;
    
    input_list[0] = mode; //HERE!
    

    write_addr = 0;
    write_addr[9:8] = 2'd2;

    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, 'h300, 1);
end
endtask    
//}}}

task stop_trigger ();
//{{{
begin
    input_list[0] = 1; //HERE!

    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, 'h300 + 4, 1);
end
endtask    
//}}}

task write_NPU_CORE ();
//{{{
begin
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;


    int i;

    input_list[0]  = 16'ha0f0;//testmode_ctrl1
    input_list[1]  = 16'ha1f1;//testmode_ctrl2
    input_list[2]  = 16'ha2f2;//testmode_ctrl3
    input_list[3]  = 16'hb0f3;//data_testmode
    input_list[4]  = 16'hf0f4;//din_seldel
    input_list[5]  = 16'hf1f5;//delay_ctrl1
    input_list[6]  = 16'hf2f6;//adc_ctrl1
    input_list[7]  = 16'hf3f7;//adc_ctrl2
    input_list[8]  = 16'hf4f8;//adc_ctrl3_pre
    input_list[9]  = 16'hf4f9;//adc_ctrl3
    input_list[10] = 16'hf5fa;//data_tia_gain
    input_list[11] = 16'hf6fb;//wlg_ctrl1
    input_list[12] = 16'hf7fc;//wlg_ctrl2
    input_list[13] = 16'hf8fd;//v_gate
    input_list[14] = 16'hf9fe;//1f9
    input_list[15] = 16'hfaff;//v_srref2

    //burst
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, 0, 16);
end
endtask
//}}}

task read_NPU_CORE ();
//{{{
begin
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;
    int i;


    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, 'h000, 1);

    
    for (i = 0; i < 1; i ++) begin
        $display ("NPU core_config: %d, %x", i, output_list[i]);
    end 


end
endtask
//}}}

task write_NPU_WRAP_config ();
//{{{
//by default, this is for vmm/read mem, NPU_WRAP_setreset_mode[1] = 1
begin
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    bit [AXI_DATA_WIDTH - 1 : 0] NPU_WRAP_config_data [32];

    int i;

    for (i=0; i<16; i++) begin
        input_list[i] = 0;
    end

    //1
    input_list[1][7 : 0] = WL_ST; //WL_ST L2_wl_pos
    input_list[1][15: 8] = WL_END; //WL_END
    input_list[1][23:16] = BL_ST; //BL_ST L3_bl_pos
    input_list[1][31:24] = BL_END; //BL_END
    //2
    input_list[2][7 : 0] = 'd0; //NPU_WRAP_CONFIG_0_ST
    input_list[2][15: 8] = 'd6; //NPU_WRAP_CONFIG_0_END
    input_list[2][23:16] = 'd4; //NPU_WRAP_CONFIG_1_ST
    input_list[2][31:24] = 'd7; //NPU_WRAP_CONFIG_1_END
    
    //3
    input_list[3][7 : 0] = 'd8; //NPU_WRAP_CONFIG_2_ST
    input_list[3][15: 8] = 'd15;//NPU_WRAP_CONFIG_2_END
    //4 default 0 
    //5
    input_list[5][15: 0] = 'd19;//NPU_WRAP_set_pulse_width
    input_list[5][31:16] = 'd39;//NPU_WRAP_reset_pulse_width

    //6
    input_list[6][15: 0] = 'd1; //NPU_WRAP_WL_pulsewidth_set_st
    input_list[6][31:16] = 'd18;//NPU_WRAP_WL_pulsewidth_set_end
    //7
    input_list[7][15: 0] = 'd3; //NPU_WRAP_SEL_pulsewidth_set_st
    input_list[7][31:16] = 'd16;//NPU_WRAP_SEL_pulsewidth_set_end
    //8
    input_list[8][15: 0] = 'd5; //NPU_WRAP_BL_pulsewidth_set_st
    input_list[8][31:16] = 'd14;//NPU_WRAP_BL_pulsewidth_set_end

    //9
    input_list[9][15: 0] = 'd11; //NPU_WRAP_WL_pulsewidth_reset_st
    input_list[9][31:16] = 'd28;//NPU_WRAP_WL_pulsewidth_reset_end
    //10
    input_list[10][15: 0] = 'd13; //NPU_WRAP_SEL_pulsewidth_reset_st
    input_list[10][31:16] = 'd26;//NPU_WRAP_SEL_pulsewidth_reset_end
    //11
    input_list[11][15: 0] = 'd15; //NPU_WRAP_BL_pulsewidth_reset_st
    input_list[11][31:16] = 'd24;//NPU_WRAP_BL_pulsewidth_reset_end

    //12
    input_list[12][3 : 0] = 4'd5;     //SETDAC_INTERNAL_STATE_LIMIT
    input_list[12][7 : 4] = 4'd2;     //SETDAC_INTERNAL_VALID_STATE_ST
    input_list[12][11: 8] = 4'd3;     //SETDAC_INTERNAL_VALID_STATE_END

    //13
    input_list[13][7 : 0] = 8'hf1; //reset_srref0
    input_list[13][15: 8] = 8'hf2; //reset_srref1
    input_list[13][23:16] = 8'hf3; //reset_srref2

    //14
    input_list[14][1 : 0] = 2'h2; //READMEM
    input_list[14][18:16] = 3'd0; //L0_single_point_opt_loop

    //15
    input_list[15][31: 0] = L1_single_point_loop;
    
    //16
    input_list[16][31: 0] = L4_whole_range_loop;
    
    //17
    input_list[17][15: 0] = 16'd19;//NPU_WRAP_readmem_pulse_width
    input_list[17][31:16] = 16'd0; //NPU_WRAP_BL_pulsewidth_readmem_st
    //18
    input_list[18][15: 0] = 16'd0; //NPU_WRAP_WL_pulsewidth_readmem_st
    input_list[18][31:16] = 16'd0; //NPU_WRAP_SEL_pulsewidth_readmem_st
    
    //19
    input_list[19][31:20] = 8'd50; //adc_first_delay
    input_list[19][19: 8] = 8'd30; //adc_high_delay
    input_list[19][7 : 0] = 8'd10; //adc_low_delay
    
    //input_list[19][31:0] = 32'h10e00a00; //default, comment this to switch different values

    //20
    input_list[20][7 : 0] = 8'he1; //set_srref0
    input_list[20][15: 8] = 8'he2; //set_srref1
    input_list[20][23:16] = 8'he3; //set_srref2
    //21
    input_list[21][7 : 0] = 8'hd1; //readmem_srref0
    input_list[21][15: 8] = 8'hd2; //readmem_srref1
    input_list[21][23:16] = 8'hd3; //readmem_srref2
    
 
    write_addr[9:8] = 2'd2;
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 22);

end
endtask
//}}}

//reset
//{{{
initial begin
    reset = TB_RESET_VALUE;
    #20;
    reset = ~TB_RESET_VALUE;
    //messager.dump_message("sim start");
    #100000;
    //messager.dump_message("sim end");
    $finish;
end
//}}}

//clk
//{{{
initial begin
    clk = 0;
    clock_counter = 0;
    ns_counter = 0;
    forever begin
        #5 clk ^= 1;
        ns_counter += 5;
        #5 clk ^= 1;
        ns_counter += 5;
        clock_counter += 1;
    end
end
//}}}

//waveform
//{{{
initial begin
    $vcdplusfile("waveforms.vpd");
    $vcdpluson();
    $vcdplusmemon();
end
//}}}


endmodule
