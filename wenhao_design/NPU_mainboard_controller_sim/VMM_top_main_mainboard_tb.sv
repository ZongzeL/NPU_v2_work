`timescale 1 ns / 1 ns


longint unsigned ns_counter;
longint unsigned clock_counter;


module top_main_tb(

    );
    // local parameters
    localparam AXIL_S_ADDR_WIDTH = 8; //addr width AXI Lite
    localparam C_M00_AXI_DATA_WIDTH = 32; //data width AXI Lite
    localparam AXIS_DATA_WIDTH = 16;//data width AXI Stream. changed from 8
                                    // 0: sequential ring switch design (128x64 chip)
                                    // 1: 4 parallel ring switch lane design (256x256 chip)
    localparam PARALLEL_RINGSW = 1;

    localparam MAX_NUM_BL = 256; 
    localparam MAX_NUM_WL = 256;
    localparam MODEL_WEIGHT_BL = 32; 
    localparam MODEL_WEIGHT_WL = 32;

    localparam [C_M00_AXI_DATA_WIDTH-1:0] MODE_SETRESET = 32'h1,
                                        MODE_VMM = 32'h2,
                                        MODE_READ = 32'h3;


    localparam BATCH_SIZE_VMM = 2;

    //for NPU module
    //{{{
    parameter TB_RESET_VALUE = 0;
    //parameter Q_INTERVAL = 63 * 13;
    parameter Q_DEDUCT = 0;
    parameter Q_INTERVAL = 906;
    //parameter Q_DEDUCT = 10000;
    //外面输入的数据偏差太小，造成module运算结果偏差也太小，看不出区别，例如output全是0。因此要加一个偏移量并缩小区间。
    //TODO 此偏移量和区间仅适用于27 * 10， 语法先这样以后再改
    //一定要保证结果要能小于63
    //这两个量在TB里随便设，但是在可综合的module里一定要小心。
    //}}}


    //SIM use
    string tmp;
    string s;

    reg [C_M00_AXI_DATA_WIDTH-1:0] mode_sel = MODE_VMM;
    //reg [C_M00_AXI_DATA_WIDTH-1:0] mode_sel = MODE_READ;
    reg resetn;//in
    reg clk = 1'b0;//in
    
    bit [5:0] all_input_list [32][32];
    

    // NPU IOs
    //{{{
    wire [5:0] NPU1DOUT;
    wire [7:0] NPU1DIN;
    

    wire [8:0] ADDR;
    wire CLKDAC;
    wire [3:0] CLKREG; // ring switch clk
    wire [3:0] DINSWREG; // ring switch data
    wire DACBL_SW; // BL overall sw
    wire DACBL_SW2; // TIA overall sw
    wire DACSEL_SW; // SEL overall sw
    wire DACWL_SW; // WL overall sw
    wire DACWLREFSW; // WL voltage provider             
    wire SET; // WL ground enable
    wire RESET; // BL ground enable
    wire CLKADCSW;
    wire CLKADC;
    
    wire DISCHG;
    wire ARST_ENREG;
    wire ARST_WLREG;
    wire ASET_ENREG;
    wire ASET_WLREG;  
    //}}}          
    
    //NPU model debug   
    wire [31:0] NPU_model_Q_values; 
 
    //// 3 interfaces
    // AxiS Interface between testbench(Master) and NPUC (Slave)
    //{{{
    wire s00_axis_tready;
    wire [AXIS_DATA_WIDTH - 1 : 0] s00_axis_tdata;
    wire [(AXIS_DATA_WIDTH / 8) - 1 : 0] s00_axis_tstrb;
    wire s00_axis_tlast;
    wire s00_axis_tvalid;
    //}}}

    // Axi Stream Interface between teshbench(Slave) and NPU controller(Master)
    //{{{
    wire m00_axis_tvalid;
    wire [AXIS_DATA_WIDTH - 1 : 0] m00_axis_tdata;
    wire [(AXIS_DATA_WIDTH/8)-1 : 0] m00_axis_tstrb;
    wire m00_axis_tlast;
    wire m00_axis_tready;
    //}}}

    // AXI Lite Interface between testbench(Master) and NPU controller
    //{{{
    wire [AXIL_S_ADDR_WIDTH-1 : 0] m2s_axi_awaddr;
    wire [2 : 0] m2s_axi_awprot;
    wire  m2s_axi_awvalid;
    wire  s2m_axi_awready;
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] m2s_axi_wdata;
    wire [C_M00_AXI_DATA_WIDTH/8-1 : 0] m2s_axi_wstrb;
    wire  m2s_axi_wvalid;
    wire  s2m_axi_wready;
    wire [1 : 0] s2m_axi_bresp;
    wire  s2m_axi_bvalid;
    wire  m2s_axi_bready;
    wire [AXIL_S_ADDR_WIDTH-1 : 0] m2s_axi_araddr;
    wire [2 : 0] m2s_axi_arprot;
    wire  m2s_axi_arvalid;
    wire  s2m_axi_arready;
    wire [C_M00_AXI_DATA_WIDTH-1 : 0] s2m_axi_rdata;
    wire [1 : 0] s2m_axi_rresp;
    wire  s2m_axi_rvalid;
    wire  m2s_axi_rready;
    //}}}
    
    //DUT CONNECTION
    //NPU module
    //{{{
    NPU_v2_module # (
        .RESET_VALUE(TB_RESET_VALUE),
        .MAX_NUM_BL(MAX_NUM_BL),
        .MAX_NUM_WL(MAX_NUM_WL),
        .MODEL_WEIGHT_BL(MODEL_WEIGHT_BL),
        .MODEL_WEIGHT_WL(MODEL_WEIGHT_WL),
        .Q_INTERVAL(Q_INTERVAL),
        .Q_DEDUCT(Q_DEDUCT)
    ) NPU (
        .DIN(NPU1DIN),
        .ADDR(ADDR),
        .CLKDAC(CLKDAC),
        .CLKADC(CLKADC),
        .DOUT(NPU1DOUT),
        .SET(SET), 
        .RESET(RESET), 
        .CLKREG(CLKREG),
        .DINSWREG(DINSWREG),
        .DACBL_SW(DACBL_SW),
        .DACBL_SW2(DACBL_SW2),
        .DACSEL_SW(DACSEL_SW),
        .DACWL_SW(DACWL_SW),
        .CLKADCSW(CLKADCSW),
        .DACWLREFSW(DACWLREFSW),
        .DISCHG(DISCHG),
        .ARST_ENREG(ARST_ENREG),
        .ARST_WLREG(ARST_WLREG),
        .ASET_ENREG(ASET_ENREG),
        .ASET_WLREG(ASET_WLREG),
        .NPU_model_Q_values(NPU_model_Q_values),
        .clk_all(clk),
        .reset_all(resetn)
    );
    //}}}

    //NPU controller
    //{{{
    // the NPU controller module has 
    // one AXI Lite Slave to receive configurations, (m2s or s2m, could use t2s or s2t)
    // one AXI Stream Slave to receive input data, (t2s or s2t)
    // and one AXI Stream Master to send output data. (m2t or t2m)
    // t means testbench here.
    top_main # (
        .NUM_BL(MAX_NUM_BL),  
        .NUM_WL(MAX_NUM_WL),
        .PARALLEL_RINGSW(PARALLEL_RINGSW),
        
        // Parameters of Axi Slave Bus Interface S00_AXI
        .AXIL_S_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
        .AXIL_S_ADDR_WIDTH(AXIL_S_ADDR_WIDTH),
    
        // Parameters of Axi Slave / Master Bus Interface S00_AXIS / M00_AXIS
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH),
        .AXIS_M_START_CUNT(1)
    ) top_main_inst
    (
        // Global input
        .clk(clk),
        .rstn(resetn),
        
        // NPU IOs
        .DOUT(NPU1DOUT),
        
        .DIN(NPU1DIN),

        .ADDR(ADDR),
        .CLKDAC(CLKDAC),
        .CLKREG(CLKREG), // ring switch clk
        .DINSWREG(DINSWREG), // ring switch data
        .DACBL_SW(DACBL_SW), // BL overall sw
        .DACBL_SW2(DACBL_SW2), // TIA overall sw
        .DACSEL_SW(DACSEL_SW), // SEL overall sw
        .DACWL_SW(DACWL_SW), // WL overall sw
        .DACWLREFSW(DACWLREFSW), // WL voltage provider             
        .SET(SET), // WL ground enable
        .RESET(RESET), // BL ground enable
        .CLKADCSW(CLKADCSW),
        .CLKADC(CLKADC),
        
        .DISCHG(DISCHG),
        .ARST_ENREG(ARST_ENREG),
        .ARST_WLREG(ARST_WLREG),
        .ASET_ENREG(ASET_ENREG),
        .ASET_WLREG(ASET_WLREG),                
 
        // Ports of Axi Slave Bus Interface S00_AXI
        .s00_axi_awaddr(m2s_axi_awaddr),
        .s00_axi_awprot(m2s_axi_awprot),
        .s00_axi_awvalid(m2s_axi_awvalid),
        .s00_axi_awready(s2m_axi_awready),
        .s00_axi_wdata(m2s_axi_wdata),
        .s00_axi_wstrb(m2s_axi_wstrb),
        .s00_axi_wvalid(m2s_axi_wvalid),
        .s00_axi_wready(s2m_axi_wready),
        .s00_axi_bresp(s2m_axi_bresp),
        .s00_axi_bvalid(s2m_axi_bvalid),
        .s00_axi_bready(m2s_axi_bready),
        .s00_axi_araddr(m2s_axi_araddr),
        .s00_axi_arprot(m2s_axi_arprot),
        .s00_axi_arvalid(m2s_axi_arvalid),
        .s00_axi_arready(s2m_axi_arready),
        .s00_axi_rdata(s2m_axi_rdata),
        .s00_axi_rresp(s2m_axi_rresp),
        .s00_axi_rvalid(s2m_axi_rvalid),
        .s00_axi_rready(m2s_axi_rready),
    
        // Ports of AxiS Slave Bus Interface
        .s00_axis_tready(s00_axis_tready),
        .s00_axis_tdata(s00_axis_tdata),
        .s00_axis_tstrb(s00_axis_tstrb),
        .s00_axis_tlast(s00_axis_tlast),
        .s00_axis_tvalid(s00_axis_tvalid),
    
        // Ports of AxiS Master Bus Interface
        .m00_axis_tvalid(m00_axis_tvalid),
        .m00_axis_tdata(m00_axis_tdata),
        .m00_axis_tstrb(m00_axis_tstrb),
        .m00_axis_tlast(m00_axis_tlast),
        .m00_axis_tready(m00_axis_tready)
    );
    //}}}
   

    //Drivers and monitors
    //Axi lite driver 
    //{{{
	axi_lite_slave_driver_class_interface # ( 
        .C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
        .C_M_AXI_ADDR_WIDTH(AXIL_S_ADDR_WIDTH)
	) axi_lite_slave_driver_interface (
		.clk(clk),
		.reset(resetn),
		.M_AXI_AWADDR(m2s_axi_awaddr),
		.M_AXI_AWPROT(m2s_axi_awprot),
		.M_AXI_AWVALID(m2s_axi_awvalid),
		.M_AXI_AWREADY(s2m_axi_awready),
		.M_AXI_WDATA(m2s_axi_wdata),
		.M_AXI_WSTRB(m2s_axi_wstrb),
		.M_AXI_WVALID(m2s_axi_wvalid),
		.M_AXI_WREADY(s2m_axi_wready),
		.M_AXI_BRESP(s2m_axi_bresp),
		.M_AXI_BVALID(s2m_axi_bvalid),
		.M_AXI_BREADY(m2s_axi_bready),
		.M_AXI_ARADDR(m2s_axi_araddr),
		.M_AXI_ARPROT(m2s_axi_arprot),
		.M_AXI_ARVALID(m2s_axi_arvalid),
		.M_AXI_ARREADY(s2m_axi_arready),
		.M_AXI_RDATA(s2m_axi_rdata),
		.M_AXI_RRESP(s2m_axi_rresp),
		.M_AXI_RVALID(s2m_axi_rvalid),
		.M_AXI_RREADY(m2s_axi_rready)
	);	

    axi_lite_slave_driver_class #(
        .C_M_AXI_DATA_WIDTH(C_M00_AXI_DATA_WIDTH),
        .C_M_AXI_ADDR_WIDTH(AXIL_S_ADDR_WIDTH),
        .BATCH_SIZE_VMM(BATCH_SIZE_VMM)
    ) axi_lite_slave_driver = new (
        axi_lite_slave_driver_interface
    );

    //}}}
    
    //AXI stream master
    //{{{
    axi_stream_master_interface #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH)

    ) axi_stream_master_driver_interface (
		.clk(clk),
		.reset(resetn),
        .tready(m00_axis_tready),
        .tdata(m00_axis_tdata),
        .tstrb(m00_axis_tstrb),
        .tlast(m00_axis_tlast),
        .tvalid(m00_axis_tvalid)    
    );

    axi_stream_master_driver_class #(
    ) axi_stream_master_driver = new (
        axi_stream_master_driver_interface
    );
    //}}}

    //AXI stream slave
    //{{{
    axi_stream_slave_interface #(
        .AXIS_DATA_WIDTH(AXIS_DATA_WIDTH)
    ) axi_stream_slave_driver_interface (
		.clk(clk),
		.reset(resetn),
        .tready(s00_axis_tready),
        .tdata(s00_axis_tdata),
        .tstrb(s00_axis_tstrb),
        .tlast(s00_axis_tlast),
        .tvalid(s00_axis_tvalid)    
    );

    axi_stream_slave_driver_class #(
    ) axi_stream_slave_driver = new (
        axi_stream_slave_driver_interface
    );
    //}}}

    //VMM cal class
    //{{{
    VMM_calculate_class #(
        .MODEL_WEIGHT_BL(MODEL_WEIGHT_BL),
        .MODEL_WEIGHT_WL(MODEL_WEIGHT_WL),
        .MAX_NUM_BL(MAX_NUM_BL),
        .MAX_NUM_WL(MAX_NUM_WL),
        .weight_file("../NPU_module/tmp/weight_256_256.mem")
        //.weight_file("weight.mem")
    ) VMM_cal_API = new();
    //}}}


task one_round_vmm_loop (int round, int WL_start, int WL_end, int BL_start, int BL_end);
begin
//{{{
    int i, j;
    bit [5:0] input_list [256];
    bit [31:0] output_list_0 [256];
    bit [31:0] output_list_1 [256];
    bit [31:0] output_list_2 [256];
    bit [31:0] golden_output_list [256];
    int NPU_NUM = 8;
    int VALID_NPU_NUM = 2;
    int test_NPU_NUM = 0;

    int CAL_BL, CAL_WL;

    CAL_BL = BL_end - BL_start;
    CAL_WL = WL_end - WL_start;
    $display ("one round loop data");

     
    for (i = 0; i < WL_start; i ++) begin
        input_list[i] = 0;
    end
    for (i = WL_end; i < MAX_NUM_WL; i ++) begin
        input_list[i] = 0;
    end

    for (i = 0; i < NPU_NUM; i ++) begin
        for (j = WL_start; j < WL_end; j ++) begin
            input_list[j] = (round + i * 5 + j) % 63;
        end
        axi_stream_slave_driver.VMM_input_data(32, input_list);
    end
    

    //compare NPU1 output data
    for (i = test_NPU_NUM; i <= test_NPU_NUM + 1; i ++) begin
        $display ("NPU: %d",i); 
        for (j = WL_start; j < WL_end; j ++) begin
            input_list[j] = (round + i * 5 + j) % 63;
        end
    end

    //other NPUs
    //show_list (output_list_2, 0, 6 * CAL_BL, "other NPUs", CAL_BL);
        
    //wait all axis master data read out
    for (i = 0; i < 300; i ++) begin
        @(posedge clk); 
    end
    
    //show_list (axi_stream_master_monitor.data_receive_list, 0, 256, "rec_list", CAL_BL);

end
endtask
//}}}

task one_round_vmm_file (int round, int WL_start, int WL_end, int BL_start, int BL_end);
begin
//{{{

    int i, j;
    bit [5:0] input_list [256];
    bit [31:0] output_list_0 [256];
    bit [31:0] output_list_1 [256];
    bit [31:0] output_list_2 [256];
    bit [31:0] golden_output_list [256];
    int NPU_NUM = 8;
    int VALID_NPU_NUM = 2;
    int test_NPU_NUM = 0;


    int CAL_BL, CAL_WL;


    CAL_BL = BL_end - BL_start;
    CAL_WL = WL_end - WL_start;
    $display ("one round file data");
   

     
    for (i = 0; i < WL_start; i ++) begin
        input_list[i] = 0;
    end
    for (i = WL_end; i < MAX_NUM_WL; i ++) begin
        input_list[i] = 0;
    end

    for (i = 0; i < VALID_NPU_NUM; i ++) begin
        for (j = WL_start; j < WL_end; j ++) begin
            input_list[j] = all_input_list[round * VALID_NPU_NUM + i][j];
        end
        axi_stream_slave_driver.VMM_input_data(32, input_list);
    end
    
    for (i = VALID_NPU_NUM; i < NPU_NUM; i ++) begin
        for (j = WL_start; j < WL_end; j ++) begin
            input_list[j] = 0;
        end
        axi_stream_slave_driver.VMM_input_data(32, input_list);
    end
    
    //show_list (input_list, WL_start, WL_end, "input_list");
   
     
    //compare NPU1 output data
    for (i = test_NPU_NUM; i <= test_NPU_NUM + 1; i ++) begin
        $display ("NPU: %d",i); 
        for (j = WL_start; j < WL_end; j ++) begin
            input_list[j] = all_input_list[round * 2 + i][j];
        end
    end

    //other NPUs
    //show_list (output_list_2, 0, 6 * CAL_BL, "other NPUs", CAL_BL);
        
    //wait all axis master data read out
    for (i = 0; i < 300; i ++) begin
        @(posedge clk); 
    end
    
    //show_list (axi_stream_master_monitor.data_receive_list, 0, 256, "rec_list", CAL_BL);

end
endtask
//}}}


initial begin //this is INITIAL_OUT
    int WL_start = 0;
    int WL_end = 32;
    int BL_start = 0;
    int BL_end = 10;


    int i, j;
    int CAL_WL = WL_end - WL_start;
    int CAL_BL = BL_end - BL_start;

    int round = 0;


    string all_input_hex_file = "../data/pnet1/pnetconv1_input_hex.mem";
    $readmemh(all_input_hex_file, all_input_list);

    @(posedge clk);
    while (resetn == TB_RESET_VALUE) begin
        @(posedge clk);
    end


    axi_lite_slave_driver.WRITE_Q_VALUES_TASK (Q_INTERVAL - 100, Q_DEDUCT);
    axi_lite_slave_driver.WRITE_ARGUMENTS_TASK(mode_sel, WL_start, WL_end, BL_start, BL_end, 0);
    @(posedge clk);
    for (i = 0; i < 900; i ++) begin
        //this wait time should be read from waveform
        @(posedge clk); //#(9000);
    end

    for (int round = 0; round < BATCH_SIZE_VMM; round ++) begin
        $display ("test round: %d", round);
        //one_round_vmm_loop(round, WL_start, WL_end, BL_start, BL_end);
        one_round_vmm_file(round, WL_start, WL_end, BL_start, BL_end);
    end

end


//reset
//{{{
initial begin
    resetn = TB_RESET_VALUE;
    #20;
    resetn = ~TB_RESET_VALUE;
    #500000;
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
