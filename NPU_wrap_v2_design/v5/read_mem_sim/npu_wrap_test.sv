
`timescale 1 ns / 1 ps
longint unsigned ns_counter;
longint unsigned clock_counter;

module NPU_wrap_test_tb #(
    // Parameters of Axi Slave Bus Interface AXI
    parameter integer AXI_ID_WIDTH	= 1,
    parameter integer AXI_DATA_WIDTH	= 32,
    parameter integer AXI_ADDR_WIDTH	= 32,
    parameter integer AXI_USER_WIDTH	= 10,
    
    parameter integer AXI_MEM_LENGTH	= 16,
    
    parameter ADDR_BYTE_OFFSET = AXI_DATA_WIDTH / 8,
   
    //Parameters of NPU
    parameter integer NPU_DATA_WIDTH = 32,
    parameter integer NPU_BYTEEN_WIDTH = NPU_DATA_WIDTH / 8,
    parameter integer NPU_ADDR_WIDTH = 9,
    parameter integer NPU_AOUT_WIDTH = 8,



    //NPU module
    parameter string weight_file = "../../../DATA/weight/weight_32_32.mem",
    parameter Q_DEDUCT = 0,
    parameter Q_INTERVAL = 1024,

 
    parameter TB_RESET_VALUE = 0
);
    
    //localparam NPU_TARGET = 1;
    //TODO, if sim target is SC, the target should be 0, or, SC BASE_ADDR should add offset.
    //SV TB cannot change SC rtl's local parameter
    `ifdef SYSTEMC
        localparam NPU_TARGET = 0;
    `else
        localparam NPU_TARGET = 1;
    `endif    

    localparam CONFIG_ADDR_OFFSET = 0;
    localparam INPUT_DATA_ADDR_OFFSET = 'h400;
    localparam OUTPUT_DATA_ADDR_OFFSET = 'h800;
    localparam NPU_AXI_BASE_ADDR     = 32'h1200_0000 + 32'h4000_0000;
	localparam NPU_MEM_START_ADDR    =   20'h4_0000;

    int VMM_WL_ST = 0;
    int VMM_WL_END = 255;
    int VMM_BL_ST = VMM_WL_ST;
    int VMM_BL_END = VMM_WL_END;
    int VMM_start_addr = 0;
    

    //NPU signals 
    //{{{
    wire [5 : 0] npu_dout;
    wire [7 : 0] npu_din;
    wire [NPU_ADDR_WIDTH - 1 : 0] npu_addr;
    wire npu_clkdac      ;
    wire npu_clkadc      ;
    wire npu_clkadc_sw   ;
    wire npu_set         ;
    wire npu_reset       ;
    
    wire [3 : 0] npu_clkreg;
    //wire npu_clkreg_sel  ;
    //wire npu_clkreg_bl   ;
    //wire npu_clkreg_wl   ;
    //wire npu_clkreg_tia  ;
     
    wire [3 : 0] npu_dinswreg;
    //wire npu_dinswreg_sel;
    //wire npu_dinswreg_bl ;
    //wire npu_dinswreg_wl ;
    //wire npu_dinswreg_tia;
    
    wire npu_dacbl_sw    ;
    wire npu_dactia_sw   ;
    wire npu_dacsel_sw   ;
    wire npu_dacwl_sw    ;
    wire npu_dacwlrefsw  ;
    
    wire npu_dischg      ;
    wire npu_arst_enreg  ;
    wire npu_arst_wlreg  ;
    wire npu_aset_enreg  ;
    wire npu_aset_wlreg  ;

    //}}}

    wire [5:0] NPU_wrap_CS;
    wire NPU_wrap_irq;
    
    //reg    
    reg reset;
    reg clk = 1'b0;


    //sim use
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] data_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] output_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] golden_list [256];
    bit [AXI_DATA_WIDTH - 1 : 0] tmp;
    bit [AXI_DATA_WIDTH - 1 : 0] golden_read_mem_result;
    bit [7 : 0] Weight [256];
    bit [7:0] WL,TIA,BL;
    



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
        .MEM_LENGTH        (AXI_MEM_LENGTH),
		.ADDR_WIDTH	       (AXI_ADDR_WIDTH	     ),
        .ADDR_BYTE_OFFSET (1) //xilinx ip 时写aw_addr 要有个ADDR_BYTE_OFFSET的偏移量，是DATA_WIDTH / 8，在这里不需要这个偏移。
    ) axi_bus_master_driver = new (
        axi_full_master_interface
    );
    //}}}

    //Instantiation of NPU_v2_wrap
    //{{{
    NPU_v2_wrap #(
		.AXI_ID_WIDTH	        (AXI_ID_WIDTH	     ), 
		.AXI_DATA_WIDTH	        (AXI_DATA_WIDTH	     ), 
		.AXI_ADDR_WIDTH	        (AXI_ADDR_WIDTH	     ), 
		.AXI_AWUSER_WIDTH	    (AXI_USER_WIDTH	 ), 
        .NPU_AXI_BASE_ADDR      (NPU_AXI_BASE_ADDR + NPU_TARGET * 'h8_0000)

    ) NPU_WRAP (
		.clk                    (clk),
		.rst_n                  (reset),
        
        .CS_ILA             (NPU_wrap_CS),
        .irq_o              (NPU_wrap_irq),
        
        //NPU signals
        //{{{ 
        .NPU_DIN        (npu_din),      
        .NPU_ADDR       (npu_addr),
        .NPU_CLKDAC     (npu_clkdac),
        .NPU_CLKADC_SW  (npu_clkadc_sw),
        .NPU_CLKADC     (npu_clkadc),
        .NPU_DOUT       (npu_dout),
        .NPU_SET        (npu_set),
        .NPU_RESET      (npu_reset),
        .NPU_CLKREG     (npu_clkreg),
        .NPU_DINSWREG   (npu_dinswreg), 

        .NPU_DACBL_SW   (npu_dacbl_sw),
        .NPU_DACTIA_SW  (npu_dactia_sw), //TODO ???
        .NPU_DACSEL_SW  (npu_dacsel_sw),
        .NPU_DACWL_SW   (npu_dacwl_sw),
        .NPU_DACWLREFSW (npu_dacwlrefsw),

        .NPU_DISCHG     (npu_dischg),
        .NPU_ARST_ENREG (npu_arst_enreg),
        .NPU_ARST_WLREG (npu_arst_wlreg),
        .NPU_ASET_ENREG (npu_aset_enreg),
        .NPU_ASET_WLREG (npu_aset_wlreg),
        //}}}
        
        //axi full data
        //{{{
		.awid           (axi_full_master_interface.aw_id    ),
		.awaddr         (axi_full_master_interface.aw_addr),
		.awlen          (axi_full_master_interface.aw_len   ),
		.awsize         (axi_full_master_interface.aw_size  ),
		.awburst        (axi_full_master_interface.aw_burst ),
		.awlock         (axi_full_master_interface.aw_lock  ),
		.awcache        (axi_full_master_interface.aw_cache ),
		.awprot         (axi_full_master_interface.aw_prot  ),
		.awqos          (axi_full_master_interface.aw_qos   ),
		.awregion       (axi_full_master_interface.aw_region),
		.awuser         (axi_full_master_interface.aw_user  ),
		.awvalid        (axi_full_master_interface.aw_valid ),
		.awready        (axi_full_master_interface.aw_ready ),
		.wdata          (axi_full_master_interface.w_data    ),
		.wstrb          (axi_full_master_interface.w_strb    ),
		.wlast          (axi_full_master_interface.w_last    ),
		.wuser          (axi_full_master_interface.w_user    ),
		.wvalid	        (axi_full_master_interface.w_valid   ),
		.wready	        (axi_full_master_interface.w_ready   ),
		.bid		    (axi_full_master_interface.b_id	    ),
		.bresp		    (axi_full_master_interface.b_resp	),
		.buser		    (axi_full_master_interface.b_user	),
		.bvalid	        (axi_full_master_interface.b_valid   ),
		.bready	        (axi_full_master_interface.b_ready   ),
		.arid		    (axi_full_master_interface.ar_id	    ),
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
		.rready	        (axi_full_master_interface.r_ready   )
        //}}}
        
    ); 
    //}}}

    //Instantiation of NPU_v2_module
    //{{{
    NPU_v2_module #(
    ) NPU_v2_module_inst (
        .DIN        (npu_din),      
        .ADDR       (npu_addr),
        .CLKDAC     (npu_clkdac),
        .CLKADCSW   (npu_clkadc_sw),
        .CLKADC     (npu_clkadc),
        .DOUT       (npu_dout),
        .SET        (npu_set),
        .RESET      (npu_reset),
        .CLKREG     (npu_clkreg),
        .DINSWREG   (npu_dinswreg), 

        .DACBL_SW   (npu_dacbl_sw),
        .DACBL_SW2  (npu_dactia_sw), //TODO ???
        .DACSEL_SW  (npu_dacsel_sw),
        .DACWL_SW   (npu_dacwl_sw),
        .DACWLREFSW (npu_dacwlrefsw),

        .DISCHG     (npu_dischg),
        .ARST_ENREG (npu_arst_enreg),
        .ARST_WLREG (npu_arst_wlreg),
        .ASET_ENREG (npu_aset_enreg),
        .ASET_WLREG (npu_aset_wlreg),

        .clk_all            (clk),
        .reset_all          (reset)
    );
    //}}}

    //Instantiation of NPU_pro_driver, just want to use its member tasks
    //{{{
    NPU_pro_master_interface #(
        .NPU_DATA_WIDTH   (NPU_DATA_WIDTH   ), 
        .NPU_BYTEEN_WIDTH (NPU_BYTEEN_WIDTH ), 
        .NPU_ADDR_WIDTH   (NPU_ADDR_WIDTH   ), 
        .NPU_AOUT_WIDTH   (NPU_AOUT_WIDTH   ) 
    ) NPU_pro_driver_interface(
        .clk                (clk),
        .reset              (reset)
    );

    NPU_pro_driver_class #(
        .NPU_DATA_WIDTH   (NPU_DATA_WIDTH   ), 
        .NPU_BYTEEN_WIDTH (NPU_BYTEEN_WIDTH ), 
        .NPU_ADDR_WIDTH   (NPU_ADDR_WIDTH   ), 
        .NPU_AOUT_WIDTH   (NPU_AOUT_WIDTH   ) 
    ) NPU_pro_driver = new (
        NPU_pro_driver_interface
    );
    //}}}

initial begin
    
    int i, j,k;
    string all_input_hex_file = "../../../DATA/pnet1/pnetconv1_input_hex.mem";
    bit [31:0] input_addr;
    bit [31:0] output_addr;

    bit npu_wrap_set = 1;    
    
    /*
    WL = 8'd31;
    TIA = 8'd30;
    BL = 8'd30;
    */

    WL = 8'd254;
    TIA = 8'd254;
    BL = 8'd254;

    //reference data
    //{{{ 
    for (i = 0; i < 8; i ++) begin
        //npu model default data
        //input_list[i] = i;
        //vmm input data
        for (j = 0; j < 32; j ++) begin 
            data_list[i*32 + j] = j;
        end
    end

    for (i = 0; i < 256; i = i + 1) begin
        Weight[i] = 6'd4;
    end
    //}}}



    while (reset == TB_RESET_VALUE) begin
        @(posedge clk);
    end

    @(posedge clk);
    @(posedge clk);
   

    $display ("********STEP 1 write config");
    //{{{
    write_NPU_CORE_read_mem_config();
    #200;
    write_NPU_CORE_VMM_config();
    #200;
    write_NPU_CORE_SET_RESET_config();
    #200;
    write_NPU_WRAP_config_vmm_read_mem(npu_wrap_set);
    #200;
    //}}}
   

    //read first
    #25000; //wait for VMM to finish. This one can be closed to see send read request in the middle of VMM.
    $display ("\n********STEP 4 wait 2500 cycle, read mem %d, %d", WL, TIA);
    NPU_wrap_read_mem ( WL, TIA);
    for (i = 0; i < 4; i ++) begin
        golden_read_mem_result [8*(i+1) - 1 -: 8] = Weight[TIA[7:2]*4+i];
    end
    
    $display ("golden read mem result: %h", golden_read_mem_result);
    #200;

    /* 
    //open set_reset_mode 
    $display ("\n********STEP 4 open set reset mode: %d", npu_wrap_set);
    write_NPU_WRAP_config_0_write_mem(0, npu_wrap_set);
    #200;
 
    //reset 
    //{{{ 
    $display ("\n********STEP 5 do reset");
    NPU_wrap_write_mem (WL, BL, 32'hffffa070);
    #200;
    //}}}
    
    //reset Weight
    if (npu_wrap_set == 1) begin
        Weight[BL] += 1;
    end
    else begin
        Weight[BL] -= 1;
    end

    //close set_reset_mode, open read mode
    $display ("\n********STEP 6 close set reset mode");
    write_NPU_WRAP_config_0_write_mem(1, npu_wrap_set);
    #200;
    
    //read second 
    $display ("\n********STEP 7 read mem %d, %d", WL, TIA);
    NPU_wrap_read_mem ( WL, TIA);

    for (i = 0; i < 4; i ++) begin
        golden_read_mem_result [8*(i+1) - 1 -: 8] = Weight[TIA[7:2]*4+i] + data_list[TIA[7:2]*4+i];
    end
    $display ("golden read mem result: %h", golden_read_mem_result);
    */
end

task write_NPU_CORE_VMM_config ();
//{{{
begin
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    bit [7 : 0] NPU_CORE_config_data [64];
    bit [7 : 0] NPU_CORE_config_data_addr [64];

    int i;

    NPU_CORE_config_data[0]  = 8'b0000_0000;//testmode_ctrl1
    NPU_CORE_config_data[1]  = 8'b0000_0000;//testmode_ctrl2
    NPU_CORE_config_data[2]  = 8'b0000_0000;//testmode_ctrl3
    NPU_CORE_config_data[3]  = 8'b1000_0000;//data_testmode
    NPU_CORE_config_data[4]  = 8'b1000_0000;//din_seldel
    NPU_CORE_config_data[5]  = 8'b0111_0111;//delay_ctrl1
    NPU_CORE_config_data[6]  = 8'b0110_0010;//adc_ctrl1
    NPU_CORE_config_data[7]  = 8'b0011_0100;//adc_ctrl2
    NPU_CORE_config_data[8]  = 8'b0001_1100;//adc_ctrl3_pre //1c
    NPU_CORE_config_data[9]  = 8'b0000_0010;//adc_ctrl3
    NPU_CORE_config_data[10] = 8'b0000_0001;//data_tia_gain
    NPU_CORE_config_data[11] = 8'b0000_0010;//wlg_ctrl1 //TODO set preload for vmm
    NPU_CORE_config_data[12] = 8'b0000_0000;//wlg_ctrl2
    NPU_CORE_config_data[13] = 8'b1111_0000;//v_gate
    NPU_CORE_config_data[14] = 8'b0000_0000;//1f9
    NPU_CORE_config_data[15] = 8'b0000_0000;//v_srref2
    NPU_CORE_config_data[16] = 8'b1100_1010;//v_refh
    NPU_CORE_config_data[17] = 8'b1001_1111;//v_refl
    NPU_CORE_config_data[18] = 8'b1111_1111;//seldac_refh
    NPU_CORE_config_data[19] = 8'b1100_1100;//seldac_refl
    NPU_CORE_config_data[20] = 8'b1111_1111;//ref_h_adc
    NPU_CORE_config_data[21] = 8'b0000_0000;//ref_l_adc

    NPU_CORE_config_data_addr[0]  = 8'ha0;//testmode_ctrl1
    NPU_CORE_config_data_addr[1]  = 8'ha1;//testmode_ctrl2
    NPU_CORE_config_data_addr[2]  = 8'ha2;//testmode_ctrl3
    NPU_CORE_config_data_addr[3]  = 8'hb0;//data_testmode
    NPU_CORE_config_data_addr[4]  = 8'hf0;//din_seldel
    NPU_CORE_config_data_addr[5]  = 8'hf1;//delay_ctrl1
    NPU_CORE_config_data_addr[6]  = 8'hf2;//adc_ctrl1
    NPU_CORE_config_data_addr[7]  = 8'hf3;//adc_ctrl2
    NPU_CORE_config_data_addr[8]  = 8'hf4;//adc_ctrl3_pre
    NPU_CORE_config_data_addr[9]  = 8'hf4;//adc_ctrl3
    NPU_CORE_config_data_addr[10] = 8'hf5;//data_tia_gain
    NPU_CORE_config_data_addr[11] = 8'hf6;//wlg_ctrl1
    NPU_CORE_config_data_addr[12] = 8'hf7;//wlg_ctrl2
    NPU_CORE_config_data_addr[13] = 8'hf8;//v_gate
    NPU_CORE_config_data_addr[14] = 8'hf9;//1f9
    NPU_CORE_config_data_addr[15] = 8'hfa;//v_srref2
    NPU_CORE_config_data_addr[16] = 8'hfb;//v_refh
    NPU_CORE_config_data_addr[17] = 8'hfc;//v_refl
    NPU_CORE_config_data_addr[18] = 8'hfd;//seldac_refh
    NPU_CORE_config_data_addr[19] = 8'hff;//seldac_refl
    NPU_CORE_config_data_addr[20] = 8'hc0;//ref_h_adc
    NPU_CORE_config_data_addr[21] = 8'hc1;//ref_l_adc

    //single
    /*
    for (i = 0; i < 22; i ++ ) begin
        input_list[0][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
        NPU_wrap_addr_convert (write_addr, i, 0);
        axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);
    end
    */
    //burst
    for (i = 0; i < 22; i ++ ) begin
        input_list[i][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
    end
    NPU_wrap_addr_convert (write_addr, 0, 0);
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 22);
    

    NPU_CORE_config_data[0]  = 8'b0110_0010;//adc_ctrl1
    NPU_CORE_config_data[1]  = 8'b0011_0100;//adc_ctrl2
    NPU_CORE_config_data[2]  = 8'b0001_1100;//adc_ctrl3_pre //1c
    

    NPU_CORE_config_data_addr[0]  = 8'hf2;//adc_ctrl1
    NPU_CORE_config_data_addr[1]  = 8'hf3;//adc_ctrl2
    NPU_CORE_config_data_addr[2]  = 8'hf4;//adc_ctrl3

    for (i = 0; i < 3; i ++ ) begin
        input_list[i][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
    end
    NPU_wrap_addr_convert (write_addr, 22 * 2 + 14, 0);
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 3);
end
endtask
//}}}

task write_NPU_CORE_read_mem_config ();
//{{{
begin
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    bit [7 : 0] NPU_CORE_config_data [64];
    bit [7 : 0] NPU_CORE_config_data_addr [64];

    int i;

    NPU_CORE_config_data[0]  = 8'b0000_0000;//testmode_ctrl1
    NPU_CORE_config_data[1]  = 8'b0000_0000;//testmode_ctrl2
    NPU_CORE_config_data[2]  = 8'b0000_0000;//testmode_ctrl3
    NPU_CORE_config_data[3]  = 8'b1000_0000;//data_testmode
    NPU_CORE_config_data[4]  = 8'b0000_0111;//din_seldel
    NPU_CORE_config_data[5]  = 8'b0111_0111;//delay_ctrl1
    NPU_CORE_config_data[6]  = 8'b0111_1011;//adc_ctrl1
    NPU_CORE_config_data[7]  = 8'b0001_1010;//adc_ctrl2
    NPU_CORE_config_data[8]  = 8'b0001_1100;//adc_ctrl3_pre //1c
    NPU_CORE_config_data[9]  = 8'b0000_0000;//adc_ctrl3
    NPU_CORE_config_data[10] = 8'b0000_0010;//data_tia_gain
    NPU_CORE_config_data[11] = 8'b0000_0000;//wlg_ctrl1
    NPU_CORE_config_data[12] = 8'b0000_0000;//wlg_ctrl2
    NPU_CORE_config_data[13] = 8'b1111_1111;//v_gate
    NPU_CORE_config_data[14] = 8'b0000_0000;//1f9
    NPU_CORE_config_data[15] = 8'b1000_0100;//v_srref2
    NPU_CORE_config_data[16] = 8'b1100_1010;//v_refh
    NPU_CORE_config_data[17] = 8'b1000_0000;//v_refl
    NPU_CORE_config_data[18] = 8'b1111_1111;//seldac_refh
    NPU_CORE_config_data[19] = 8'b1000_0000;//seldac_refl
    NPU_CORE_config_data[20] = 8'b0000_0000;//ref_h_adc
    NPU_CORE_config_data[21] = 8'b0000_0000;//ref_l_adc

    NPU_CORE_config_data_addr[0]  = 8'ha0;//testmode_ctrl1
    NPU_CORE_config_data_addr[1]  = 8'ha1;//testmode_ctrl2
    NPU_CORE_config_data_addr[2]  = 8'ha2;//testmode_ctrl3
    NPU_CORE_config_data_addr[3]  = 8'hb0;//data_testmode
    NPU_CORE_config_data_addr[4]  = 8'hf0;//din_seldel
    NPU_CORE_config_data_addr[5]  = 8'hf1;//delay_ctrl1
    NPU_CORE_config_data_addr[6]  = 8'hf2;//adc_ctrl1
    NPU_CORE_config_data_addr[7]  = 8'hf3;//adc_ctrl2
    NPU_CORE_config_data_addr[8]  = 8'hf4;//adc_ctrl3_pre
    NPU_CORE_config_data_addr[9]  = 8'hf4;//adc_ctrl3
    NPU_CORE_config_data_addr[10] = 8'hf5;//data_tia_gain
    NPU_CORE_config_data_addr[11] = 8'hf6;//wlg_ctrl1
    NPU_CORE_config_data_addr[12] = 8'hf7;//wlg_ctrl2
    NPU_CORE_config_data_addr[13] = 8'hf8;//v_gate
    NPU_CORE_config_data_addr[14] = 8'hf9;//1f9
    NPU_CORE_config_data_addr[15] = 8'hfa;//v_srref2
    NPU_CORE_config_data_addr[16] = 8'hfb;//v_refh
    NPU_CORE_config_data_addr[17] = 8'hfc;//v_refl
    NPU_CORE_config_data_addr[18] = 8'hfd;//seldac_refh
    NPU_CORE_config_data_addr[19] = 8'hff;//seldac_refl
    NPU_CORE_config_data_addr[20] = 8'hc0;//ref_h_adc
    NPU_CORE_config_data_addr[21] = 8'hc1;//ref_l_adc

    //single
    /*
    for (i = 0; i < 22; i ++ ) begin
        input_list[0][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
        NPU_wrap_addr_convert (write_addr, 22 + i, 0);
        axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);
    end
    */
    //burst
    for (i = 0; i < 22; i ++ ) begin
        input_list[i][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
    end
    NPU_wrap_addr_convert (write_addr, 22, 0);
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 22);
end
endtask
//}}}

task write_NPU_CORE_SET_RESET_config ();
//{{{
begin
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    bit [7 : 0] NPU_CORE_config_data [64];
    bit [7 : 0] NPU_CORE_config_data_addr [64];

    int i;




    NPU_CORE_config_data[0] = 8'b1111_1111;//seldac_refh
    NPU_CORE_config_data[1] = 8'b1100_1100;//seldac_refl
    NPU_CORE_config_data[2] = 8'b1000_0000;//data_testmode
    NPU_CORE_config_data[3] = 8'b1000_0000;//din_seldel
    NPU_CORE_config_data[4]  = 8'b0000_0000;//testmode_ctrl1
    NPU_CORE_config_data[5]  = 8'b0000_0000;//testmode_ctrl2
    NPU_CORE_config_data[6]  = 8'b0111_0111;//delay_ctrl1
    NPU_CORE_config_data[7]  = 8'b0000_0000;//testmode_ctrl3




    NPU_CORE_config_data_addr[0] = 8'hfd;//seldac_refh
    NPU_CORE_config_data_addr[1] = 8'hff;//seldac_refl
    NPU_CORE_config_data_addr[2] = 8'hb0;//data_testmode
    NPU_CORE_config_data_addr[3] = 8'hf0;//din_seldel
    NPU_CORE_config_data_addr[4]  = 8'ha0;//testmode_ctrl1
    NPU_CORE_config_data_addr[5]  = 8'ha1;//testmode_ctrl2
    NPU_CORE_config_data_addr[6]  = 8'hf1;//delay_ctrl1
    NPU_CORE_config_data_addr[7]  = 8'ha2;//testmode_ctrl3



    //single
    /*
    for (i = 0; i < 22; i ++ ) begin
        input_list[0][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
        NPU_wrap_addr_convert (write_addr, i, 0);
        axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);
    end
    */
    //burst
    for (i = 0; i < 8; i ++ ) begin
        input_list[i][31:0] = {16'b0, NPU_CORE_config_data_addr[i][7:0], NPU_CORE_config_data[i][7:0]}; 
    end
    NPU_wrap_addr_convert (write_addr, 44, 0);
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 8);
end
endtask
//}}}

task write_VMM_input_data_list (
//{{{
    input bit [AXI_DATA_WIDTH - 1 : 0] out_input_list [256],
    input int WL_start, 
    input int WL_end
    );
begin
        
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    int i, j;
    int NPU_WL_start_addr, NPU_WL_end_addr;
    bit [31:0] group_input_data_list[64]; 
    bit [3 : 0] strb_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    NPU_pro_driver.VMM_INPUT_DATA_GROUP (out_input_list, WL_start, WL_end, group_input_data_list, NPU_WL_start_addr, NPU_WL_end_addr);
    
    for (i = NPU_WL_start_addr; i < NPU_WL_end_addr; i ++) begin 
        input_list[i - NPU_WL_start_addr] = group_input_data_list[i];
        strb_list[i - NPU_WL_start_addr] = 4'hf;
        //$display ("group input data list: %d, %x", i, group_input_data_list[i]);
    end

    //CHN: 第四步，burst方式写入AXI
    NPU_wrap_addr_convert (write_addr, NPU_WL_start_addr, 1);
   
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND_strb(clk, input_list, strb_list, write_addr, NPU_WL_end_addr - NPU_WL_start_addr);
end
endtask
//}}}

task VMM_golden_cal ();
//{{{
begin
    int i, j,k;
    j = VMM_WL_ST;
    k=VMM_start_addr;
    //k=VMM_WL_ST;
    //现有的NPU model方式是，WL BL是必须一样的，或者说，根本不看WL，只用BL做运算，假如WL和BL不同，那么必然导致结果不对。
    //本来NPU wrap里面的VMM_in_data用的那个VMM_start_addr 其实和VMM_WL_ST是一一对应的。然而马上要变的不一样了，那么其实是把VMM_start_addr开始的WL_LEN那么多数写到了NPU core的WL_ST开始的WL_LEN位上去。
    //假如VMM_start_addr 和 VMM_WL_ST相等，那就和以前方法一样。假如不同，那就必须分开判断。
    //不过好在，LEN是一样的。都是WL_LEN
    for (i = VMM_BL_ST; i <= VMM_BL_END; i ++) begin
        golden_list[i] = data_list[k] + Weight[j]; 
        //$display ("BL: %d, WL: %d, input: %d, Weight: %d", i, j, input_list[j], Weight[j]);
        j++;
        k++;
        if (k == 256) begin
            k = 0;
        end
    end
end
endtask
//}}}

task NPU_wrap_read_output_VMM_data (bit [AXI_DATA_WIDTH - 1 : 0] golden_output_list[256], int BL_start, int BL_end);
//{{{
begin
    int i, j;
    bit [AXI_ADDR_WIDTH - 1 : 0] read_addr;
    int NPU_BL_start_addr, NPU_BL_end_addr;
    bit [AXI_DATA_WIDTH - 1 : 0] group_output_data_list [256];
        //CHN:其实length 64就够用了，但是通用函数OUTPUT_DATA_ONE_ROUND的argument要求长度256
        //ENG Acturally length = 64 is enouth, but general propose function OUTPUT_DATA_ONE_ROUND's "input_list" argument requires length = 256.
    bit match = 1;
   
    int output_read_count = 0;

    //CHN: 第一步，把要读的对应8bit的 BL地址转成对应32bit的AXI地址NPU_BL_start_addr
    //ENG: First step, convert pointing 8 bits address "BL" into pointing 32 bits address "NPU_BL_start_addr".
    NPU_pro_driver.NPU_DATA_ADDR_CONVERT(NPU_BL_start_addr, NPU_BL_end_addr, BL_start, BL_end);

    //CHN: 第二步，转化成NPU wrap 用的地址
    //ENG: Second step, convert NPU_BL_start_addr into NPU wrap format address.
    NPU_wrap_addr_convert (read_addr, NPU_BL_start_addr, 2);

    //CHN: 第三步，把值读出来，这是32bit的值
    //ENG: Third step, read output data, this data is 32 bits. 
    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, group_output_data_list, read_addr, NPU_BL_end_addr - NPU_BL_start_addr);
    axi_bus_master_driver.OUTPUT_DATA_MOVE_BL (group_output_data_list, group_output_data_list, NPU_BL_start_addr, NPU_BL_end_addr);
    //CHN: 第四步，把3 个 32bit的值 转回到10个8bit的值
    //ENG: Forth step, convert 3 of 32 bits data into 10 of 8 bits value.
    for (i = NPU_BL_start_addr; i < NPU_BL_end_addr; i ++) begin
        $display ("read data: %d, %x,", i, group_output_data_list[i]);
    end

    NPU_pro_driver.VMM_OUTPUT_DATA_DEGROUP (group_output_data_list, BL_start, BL_end, output_list, NPU_BL_start_addr, NPU_BL_end_addr);
    
    show_list_four_byte (output_list, BL_start, BL_end, "output_list");

    show_list_four_byte (golden_output_list, BL_start, BL_end, "g_output_list");
    
end
endtask
//}}}

task write_NPU_WRAP_config_vmm_read_mem (bit set = 0, bit skip = 0);
//{{{
//by default, this is for vmm/read mem, NPU_WRAP_setreset_mode[1] = 1
begin
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    bit [AXI_DATA_WIDTH - 1 : 0] NPU_WRAP_config_data [32];

    int i;
    //0 
    NPU_WRAP_config_data[0][0]     = 0;        //NPU_ARST_ENREG      
    NPU_WRAP_config_data[0][1]     = 0;        //NPU_ARST_WLREG    
    NPU_WRAP_config_data[0][2]     = 0;        //NPU_ASET_ENREG    
    NPU_WRAP_config_data[0][3]     = 0;        //NPU_ASET_WLREG
    NPU_WRAP_config_data[0][5:4]   = {1'b1, set};    //NPU_WRAP_setreset_mode set
    NPU_WRAP_config_data[0][6]     = 0;        //NPU_WRAP_vmm_config_again_skip
    NPU_WRAP_config_data[0][7]     = 0;        //NPU_DISCHG
    //1
    NPU_WRAP_config_data[1][7 : 0] = VMM_WL_ST;   //NPU_WRAP_WL_ST
    NPU_WRAP_config_data[1][15: 8] = VMM_WL_END - VMM_WL_ST;     //NPU_WRAP_WL_LEN
    NPU_WRAP_config_data[1][23:16] = VMM_BL_ST;   //NPU_WRAP_BL_ST
    NPU_WRAP_config_data[1][31:24] = VMM_BL_END - VMM_BL_ST;     //NPU_WRAP_BL_LEN
    //2
    NPU_WRAP_config_data[2][7 : 0] = 8'd0;     //NPU_WRAP_VMM_CONFIG_ST
    NPU_WRAP_config_data[2][15: 8] = 8'd21;    //NPU_WRAP_VMM_CONFIG_END
    NPU_WRAP_config_data[2][23:16] = 8'd22;    //NPU_WRAP_READ_MEM_CONFIG_ST
    NPU_WRAP_config_data[2][31:24] = 8'd43;    //NPU_WRAP_READ_MEM_CONFIG_END
    //3
    NPU_WRAP_config_data[3][7 : 0] = 8'd44;    //NPU_WRAP_SET_RESET_CONFIG_ST
    NPU_WRAP_config_data[3][15: 8] = 8'd51;    //NPU_WRAP_SET_RESET_CONFIG_END
    NPU_WRAP_config_data[3][23:16] = 8'd0;    //READADC_PRELOAD_COUNT_LIMIT_0
    NPU_WRAP_config_data[3][31:24] = 8'd0;    //READADC_PRELOAD_COUNT_LIMIT_1
    //4
    NPU_WRAP_config_data[4][15 :0] = 16'h270;  //NPU_WRAP_pulse_width
    NPU_WRAP_config_data[4][31:16] = 16'h270;  //NPU_WRAP_WL_pulsewidth
    //5
    NPU_WRAP_config_data[5][15 :0] = 16'h270;  //NPU_WRAP_SEL_pulsewidth
    NPU_WRAP_config_data[5][31:16] = 16'h270;  //NPU_WRAP_TIA_pulsewidth
    //6
    NPU_WRAP_config_data[6][15 :0] = 16'h270;  //NPU_WRAP_WL_pulsewidth_read //TODO
    NPU_WRAP_config_data[6][31:16] = 16'h270;  //NPU_WRAP_SEL_pulsewidth_read  //TODO
    //7
    NPU_WRAP_config_data[7][15 :0] = 16'h270;  //NPU_WRAP_TIA_pulsewidth_read    //TODO
    NPU_WRAP_config_data[7][23:16] = 8'h0;     //NPU_WRAP_wlg_ctrl1    
    NPU_WRAP_config_data[7][31:24] = 8'h5;     //READ_MEM_repeat_time, 0 = 1 times, 5 = 6 times
    //8
    NPU_WRAP_config_data[8][15: 0] = 16'd255;     //NPU_WRAP_adcrst1_delay
    NPU_WRAP_config_data[8][31:16] = 16'd255;     //NPU_WRAP_adcrst2_delay
    //9
    NPU_WRAP_config_data[9][7 : 0] = 8'd58;     //READADC_PRELOAD_DAC_CONFIG_ST
    NPU_WRAP_config_data[9][15: 8] = 8'd60;     //READADC_PRELOAD_DAC_CONFIG_END
    NPU_WRAP_config_data[9][19:16] = 4'd5;     //SETDAC_INTERNAL_STATE_LIMIT
    NPU_WRAP_config_data[9][23:20] = 4'd2;     //SETDAC_INTERNAL_VALID_STATE_ST
    NPU_WRAP_config_data[9][27:24] = 4'd3;     //SETDAC_INTERNAL_VALID_STATE_END
    //10
    NPU_WRAP_config_data[10][31:20] = 12'h10e;  //adc_first_delay_v2 //useless
    NPU_WRAP_config_data[10][19 :8] = 12'h002;  //adc_high_period_v2
    NPU_WRAP_config_data[10][7 : 0] = 8'd0;     //adc_low_period_v2
    //11
    NPU_WRAP_config_data[11][15: 0] = 16'd10;   //NPU_WRAP_WL_pulsewidth_set_st
    NPU_WRAP_config_data[11][31:16] = 16'd260;  //NPU_WRAP_WL_pulsewidth_set_end
    //12
    NPU_WRAP_config_data[12][15: 0] = 16'd10;   //NPU_WRAP_SEL_pulsewidth_set_st
    NPU_WRAP_config_data[12][31:16] = 16'd260;  //NPU_WRAP_SEL_pulsewidth_set_end
    //13
    NPU_WRAP_config_data[13][15: 0] = 16'd10;   //NPU_WRAP_BL_pulsewidth_set_st
    NPU_WRAP_config_data[13][31:16] = 16'd260;  //NPU_WRAP_BL_pulsewidth_set_end

    //single
    /*
    for (i = 0; i < 9; i ++ ) begin
        input_list[0] = NPU_WRAP_config_data[i]; 
        NPU_wrap_addr_convert (write_addr, i, 0);
        write_addr[9:8] = 2'd2;
        axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);
    end
    */
    //burst
    for (i = 0; i < 14; i ++ ) begin
        input_list[i] = NPU_WRAP_config_data[i]; 
    end
    NPU_wrap_addr_convert (write_addr, 0, 0);
    write_addr[9:8] = 2'd2;
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 14);

end
endtask
//}}}

task write_NPU_WRAP_config_0_write_mem (bit read = 1, bit set = 0, bit skip = 0);
//{{{
//only write NPU_WRAP_config_data[0], change NPU_WRAP_setreset_mode[1] to run vmm/read mem or set/reset
begin
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    bit [AXI_DATA_WIDTH - 1 : 0] NPU_WRAP_config_data;

    int i;
    //0 
    NPU_WRAP_config_data[0]     = 0;        //NPU_ARST_ENREG      
    NPU_WRAP_config_data[1]     = 0;        //NPU_ARST_WLREG    
    NPU_WRAP_config_data[2]     = 0;        //NPU_ASET_ENREG    
    NPU_WRAP_config_data[3]     = 0;        //NPU_ASET_WLREG
    NPU_WRAP_config_data[5:4]   = {read, set};    //NPU_WRAP_setreset_mode set
    NPU_WRAP_config_data[6]     = 0;        //NPU_WRAP_vmm_config_again_skip
    NPU_WRAP_config_data[7]     = 0;        //NPU_DISCHG

    //single
    /*
    for (i = 0; i < 9; i ++ ) begin
        input_list[0] = NPU_WRAP_config_data[i]; 
        NPU_wrap_addr_convert (write_addr, i, 0);
        write_addr[9:8] = 2'd2;
        axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);
    end
    */
    //burst
    input_list[0] = NPU_WRAP_config_data; 
    NPU_wrap_addr_convert (write_addr, 0, 0);
    write_addr[9:8] = 2'd2;
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);

end
endtask
//}}}

task write_NPU_WRAP_config_vmm_start_trigger (bit [7:0] st_addr);
//{{{
//by default, this is for vmm/read mem, NPU_WRAP_setreset_mode[1] = 1
begin
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
    bit [AXI_ADDR_WIDTH - 1 : 0] write_addr;

    int i;
    
    input_list[0][7:0] = st_addr; 
    input_list[0][31:31] = 1'b1; 
    NPU_wrap_addr_convert (write_addr, 14, 0); //VMM_start_addr is on 14
    write_addr[9:8] = 2'd2;
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, write_addr, 1);

end
endtask
//}}}

task NPU_wrap_addr_convert(
//{{{ 
    output bit [AXI_ADDR_WIDTH - 1 : 0] axi_addr,
    input bit [AXI_ADDR_WIDTH - 1 : 0] orig_addr,
    input int mode
);
begin
    axi_addr = NPU_AXI_BASE_ADDR;
    
    axi_addr += NPU_TARGET * 'h8_0000;
    axi_addr += orig_addr[7 : 0] * ADDR_BYTE_OFFSET;
   
    if (mode == 0) begin
        //mode 0 是写config的地址
        axi_addr += CONFIG_ADDR_OFFSET;
    end
    if (mode == 1) begin
        //mode 1 是写data的地址
        axi_addr += INPUT_DATA_ADDR_OFFSET;
    end
    if (mode == 2) begin
        //mode 2 是读data的地址
        axi_addr += OUTPUT_DATA_ADDR_OFFSET;
    end
end
endtask
//}}}

task NPU_wrap_mem_opt_addr_convert(
//{{{ 
    output bit [AXI_ADDR_WIDTH - 1 : 0] axi_addr,
    input bit [8 - 1 : 0] BL_NUM_addr,
    input bit [8 - 1 : 0] WL_NUM_addr
);
begin

    axi_addr = WL_NUM_addr;
    axi_addr += BL_NUM_addr << 8;
    
    axi_addr =  axi_addr << 2;

    axi_addr += NPU_MEM_START_ADDR;
    axi_addr += NPU_TARGET * 'h8_0000;
    axi_addr += NPU_AXI_BASE_ADDR;
end
endtask
//}}}

task NPU_wrap_read_mem (
//{{{
    input bit [AXI_ADDR_WIDTH - 1 : 0] WL_NUM_addr, 
    input bit [AXI_ADDR_WIDTH - 1 : 0] TIA_NUM_addr
);
begin
    int i, j;
    bit [AXI_ADDR_WIDTH - 1 : 0] axi_addr;
    bit [AXI_DATA_WIDTH - 1 : 0] output_list [256];
   
    int output_read_count = 0;

    NPU_wrap_mem_opt_addr_convert (axi_addr, TIA_NUM_addr, WL_NUM_addr);
    
    $display("NPU wrap read mem axi_addr: %x", axi_addr);
    axi_bus_master_driver.OUTPUT_DATA_ONE_ROUND(clk, output_list, axi_addr, 1);
    $display ("read data: WL: %d, TIA: %d, %x,", WL_NUM_addr, TIA_NUM_addr, output_list[0]);

end
endtask
//}}}

task NPU_wrap_write_mem (bit [AXI_ADDR_WIDTH - 1 : 0] WL, bit [AXI_ADDR_WIDTH - 1 : 0] BL, bit [AXI_DATA_WIDTH - 1 : 0] write_data);
//{{{
begin
    int i, j;
    bit [AXI_ADDR_WIDTH - 1 : 0] axi_addr;
    bit [AXI_DATA_WIDTH - 1 : 0] input_list [256];
   
    int output_read_count = 0;

    NPU_wrap_mem_opt_addr_convert (axi_addr, BL, WL);
    
    input_list[0] = write_data;
    
    $display("NPU wrap write mem axi_addr: WL: %d, BL: %d", WL, BL);
    axi_bus_master_driver.INPUT_DATA_ONE_ROUND(clk, input_list, axi_addr, 1);
    

    


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
    //#500000;
    #150000;
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
