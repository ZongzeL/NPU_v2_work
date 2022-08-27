module top_main #
(
    // NPU
    parameter integer NUM_BL = 256,  
                NUM_WL = 256,
                PARALLEL_RINGSW = 1,//0: 1 lane Ring Switches; 1: 4 lanes Ring Switches
    // Parameters of Axi Slave Bus Interface S00_AXI
                AXIL_S_DATA_WIDTH	= 32,
                AXIL_S_ADDR_WIDTH	= 6,
    // Parameters of Axi Slave / Master Bus Interface S00_AXIS / M00_AXIS
                AXIS_DATA_WIDTH = 16,
                AXIS_M_START_CUNT	= 1
)
(
    // Global input
    input wire clk,
    input wire rstn,
    
    // NPU IOs
    //{{{
    input wire [5:0] DOUT,
    output reg [7:0] DIN,
    output reg [8:0] ADDR,//v2_256
    output reg CLKDAC,
    output reg [3:0] CLKREG, // ring switch clk, v2_256
    output reg [3:0] DINSWREG, // ring switch data, v2_256
    output reg DACBL_SW, // BL overall sw, only SETRESET use it
    output reg DACBL_SW2, // TIA overall sw
    output reg DACSEL_SW, // SEL overall sw
    output reg DACWL_SW, // WL overall sw        
    output reg SET, // WL ground enable
    output reg RESET, // BL ground enable
    output reg CLKADCSW,
    output reg CLKADC,
    output wire DACWLREFSW, // WL voltage provider     
    
    output wire DISCHG,
    output wire ARST_ENREG,
    output wire ARST_WLREG,
    output wire ASET_ENREG,
    output wire ASET_WLREG,   
    //}}}     

    // Ports of Axi Slave Bus Interface S00_AXI
    //{{{
    input wire [AXIL_S_ADDR_WIDTH - 1 : 0] s00_axi_awaddr,
    input wire [2 : 0] s00_axi_awprot,
    input wire s00_axi_awvalid,
    output wire s00_axi_awready,
    input wire [AXIL_S_DATA_WIDTH - 1 : 0] s00_axi_wdata,
    input wire [(AXIL_S_DATA_WIDTH / 8) - 1 : 0] s00_axi_wstrb,
    input wire s00_axi_wvalid,
    output wire s00_axi_wready,
    output wire [1 : 0] s00_axi_bresp,
    output wire s00_axi_bvalid,
    input wire s00_axi_bready,
    input wire [AXIL_S_ADDR_WIDTH - 1 : 0] s00_axi_araddr,
    input wire [2 : 0] s00_axi_arprot,
    input wire s00_axi_arvalid,
    output wire s00_axi_arready,
    output wire [AXIL_S_DATA_WIDTH - 1 : 0] s00_axi_rdata,
    output wire [1 : 0] s00_axi_rresp,
    output wire s00_axi_rvalid,
    input wire s00_axi_rready,
    //}}}

    // Ports of Axi Slave Bus Interface
    //{{{
    output wire s00_axis_tready,
    input wire [AXIS_DATA_WIDTH - 1 : 0] s00_axis_tdata,
    input wire [(AXIS_DATA_WIDTH / 8) - 1 : 0] s00_axis_tstrb,
    input wire s00_axis_tlast,
    input wire s00_axis_tvalid,
    //}}}

    // Ports of Axi Master Bus Interface
    //{{{
    output wire m00_axis_tvalid,
    output wire [AXIS_DATA_WIDTH - 1 : 0] m00_axis_tdata,
    output wire [(AXIS_DATA_WIDTH/8)-1 : 0] m00_axis_tstrb,
    output wire m00_axis_tlast,
    input wire m00_axis_tready
    //}}}
);

	integer cnt;
	integer i_wl; // 0-127->v2_256
	integer i_bl; // 0-63->v2_256
    
    //localparam
    //{{{
    localparam MAX_WL_BL = (NUM_WL>NUM_BL)?NUM_WL:NUM_BL;//maximum of WL and BL
    
	//Constants in operating NPU chip, some may become configurable reg in the future
    localparam [8:0] addr_testmode = 9'b110110000, // MON1, 2, 3 and ENREF
                    addr_refh = 9'b111111011, // REF_H
                    addr_refl = 9'b111111100, // REF_L
                    addr_srref0 = 9'b111111000, // SEL or gate
                    addr_srref1 = 9'b111111001, // BL or column
                    addr_srref2 = 9'b111111010, // WL or row
                    addr_tia_gain = 9'b111111101, // TIA gain
                    addr_seldel = 9'b111110000,// SEL delay ctrl for SETRESET
                    addr_wldel = 9'b111110001,// WL delay ctrl for SETRESET
                    addr_bldel = 9'b111110010; // BL delay ctrl for SETRESET
    
    localparam NUM_SW_CYCLE = PARALLEL_RINGSW ? MAX_WL_BL : (NUM_WL+NUM_BL)*2;

    localparam [4:0] IDLE = 5'd0, // Idle state               	                                                                                     
	                 DATA_RECEIVE = 5'd1, // Master AXIS receives data 
	                 GLOBAL_DAC = 5'd2, //SET Global modes and voltages                                                                                   
                     RINGSW = 5'd3, // Set 384 ring switches             
                     READ_ADC = 5'd4, // Read 64 TIA with ADC	          
	                 DATA_SEND = 5'd5, // Slave AXIS sends data 		 
	               // states for VMM   
                     WL_DAC = 7, // SET 128 WL voltages  	                                                                                               
                     ADC_VMM = 8, // Read 64 TIA with ADC
	                 // states for setreset
                     SRREF_DAC = 9,
                     APPLY_V          = 10;

    //}}}

    //Declare regs
    //{{{
    reg finish_setreset, finish_vmm, finish_read;
	reg [AXIS_DATA_WIDTH * MAX_WL_BL - 1 : 0] data_to_send; //Current read from each BL
	
	// State variable, sub-module enablers, sub-module finish flags
    reg [11:0] cnt_adc_first_delay;
	reg [4:0] curr_state; 
	reg [9:0] batch_cunt;
    // number of words to send for current cycle
	reg [31:0] n_words;
	reg [11:0] i_phase = 0;
    //}}}   
 
    //Declare wires
    //{{{
    // Configuration Registers, received from AXI Lite Slave
    wire [AXIL_S_DATA_WIDTH - 1 : 0] mode_sel, //0:idle, 1:setreset, 2:vmm, 3:read
                                    din_testmode,  // din for testmode, usually 8'b11000000; // SEL_BLREF, ENREF 
                                    setreset_pulse_width,  // Pulse Width in SETRESET
                                    vmmread_refh, // REF_H in VMM or Read
                                    vmmread_refl, // REF_L in VMM or Read
                                    vmmread_srref0, // SR_REF<0> in VMM or Read
                                    read_srref2, // SR_REF<2> in Read
                                    vmmread_tiagain, // TIA_GAIN in VMM or Read
                                    din_seldel,   //F_TIABIAS, NaN, F_RSTMAX2, F_SETMAX, F_RSTMAX, F_SELDEL<2:0>, 8'b00000111
                                    din_wldel,    //F_WLDEL<2:0>, 8'b110
                                    din_bldel,    //F_DACBLDEL<2:0>, 8'b110
                                    DACWL_word,
                                    DACBL_word,
                                    DACSEL_word,
                                    batch_size_vmm; //How many vectors to multiply in one VMM call

    wire [15:0] WL_pulsewidth_set_st, WL_pulsewidth_set_end;
    wire [15:0] BL_pulsewidth_set_st, BL_pulsewidth_set_end;
    wire [15:0] SEL_pulsewidth_set_st, SEL_pulsewidth_set_end;


    // WL/BL selection registers
    //Big endian is more convenient here... So that wl[i] represents i_th wl is selected or not.
    //On the writer side, it could use small endian to write memory,[31-0],then [63-32], etc.
    //as the order is reversed in AXI Lite Slave side.
//    reg [NUM_WL-1 :0] wl_selection;
//    reg [NUM_BL-1 :0] bl_selection;
    wire [AXIL_S_DATA_WIDTH*8-1:0] wl_selection;
    wire [AXIL_S_DATA_WIDTH*8-1:0] bl_selection;
    // Status Registers
    wire [AXIL_S_DATA_WIDTH - 1 : 0] finish_flag; //1:setreset, 2:vmm, 3:read.
	// Sub-module Enablers
	wire enable_setreset = rstn == 1 && mode_sel == 1;
	wire enable_vmm = rstn == 1 && mode_sel == 2; 
    wire enable_read = rstn == 1 && mode_sel == 3;

    // TIA gain of vmm and read, input could be 0,1,2,3
    wire [7:0] data_tia_gain = (vmmread_tiagain[1:0] == 2'b00)? 8'b00000001: // TIA gain DIN
                                (vmmread_tiagain[1:0] == 2'b01)? 8'b00000010:
                                 (vmmread_tiagain[1:0] == 2'b10)? 8'b00000100: 8'b00001000;

	// Output (64 * 16) and Input (128 * 16)
	wire [AXIS_DATA_WIDTH * NUM_WL - 1 : 0] data_received;//128*16 -1
//	reg [AXIS_DATA_WIDTH * NUM_BL - 1 : 0] data_to_send; //Current read from each BL

    wire [AXIL_S_DATA_WIDTH-1:0] adc_word;// from n_regs+2 to fixed address
    wire [11:0] adc_first_delay = adc_word[31:20];
    wire [11:0] adc_high_period = adc_word[19:8];
    wire [7:0] adc_low_period = adc_word[7:0];

    wire data_reci_done;
    wire data_sent_done;

    //16bit data syntax: mode(2-bit)-srref0(6-bit)-XX-srref1/2(6-bit);
    wire [1:0] mode_sr = data_received[ (i_wl + 1) * AXIS_DATA_WIDTH - 1 -: 2]; // !!! 16-bit AXIS !!!   ; // 00: skip; 01: analog SET; 10: RESET;	

    // Only last sample in the batch signal tlast
    wire single_sample_tlast; // tlast of each sample of the batch

    wire [5:0] setreset_srref0 = data_received[ (i_wl + 1) * AXIS_DATA_WIDTH - 3 -: 6]; // !!! 16-bit AXIS !!!; // SEL DAC
    wire [5:0] setreset_srref1 = (mode_sr == 2'b01) ? data_received[ (i_wl + 1) * AXIS_DATA_WIDTH - 11 -: 6] : 6'b000000; // !!! 16-bit AXIS !!!; // BL DAC
    wire [5:0] setreset_srref2 = (mode_sr == 2'b10) ? data_received[ (i_wl + 1) * AXIS_DATA_WIDTH - 11 -: 6] : 6'b000000; // !!! 16-bit AXIS !!!; // WL DAC
	wire last_global_dac = (curr_state==GLOBAL_DAC && cnt==10);

	wire last_srref_dac = (curr_state==SRREF_DAC && cnt==3);

	wire last_wl_dac = (curr_state==WL_DAC && cnt==NUM_WL);

	wire last_sw = (curr_state==RINGSW && cnt==NUM_SW_CYCLE); // use the additional transition cycle to reset its outputs 
	wire last_adc_vmm = (curr_state==ADC_VMM && cnt==(NUM_BL));
	wire last_adc_read = (curr_state==READ_ADC && cnt==1); 
    //}}}

    //Signals assign
    //{{{
    //Input Data Parser of SETRESET
	assign finish_flag = {29'b0, finish_setreset, finish_vmm, finish_read}; //!!! For 32-bit AXI-Lite data width !!!
	
	// NPU constant IOs
    assign DISCHG = 1'b0;
    assign ARST_ENREG = 1'b0;
    assign ARST_WLREG = 1'b0;
    assign ASET_ENREG = 1'b0;
    assign ASET_WLREG = 1'b0;    

    
	//Only VMM now uses inline WL DAC
    assign DACWLREFSW = enable_vmm;  // 0 : WL voltage provider SR_REF1; 1 : WL voltage provider inline DAC

    assign m00_axis_tlast = single_sample_tlast && (
                                    (enable_vmm&&(batch_cunt == (batch_size_vmm - 1)))
                                || (enable_read && (i_wl == (NUM_WL - 1)))
                                || (enable_setreset && (i_bl == (NUM_BL - 1))));

    assign WL_pulsewidth_set_st = DACWL_word[15:0];
    assign WL_pulsewidth_set_end = DACWL_word[31:16];
    assign BL_pulsewidth_set_st = DACBL_word[15:0];
    assign BL_pulsewidth_set_end = DACBL_word[31:16];
    assign SEL_pulsewidth_set_st = DACSEL_word[15:0];
    assign SEL_pulsewidth_set_end = DACSEL_word[31:16];

    //}}}

    //Module connection
    //{{{
	// Configuration Reg Receiver
    //{{{
    // Instantiation of Axi Bus Interface S00_AXI
	top_S00_AXI # ( 
		.C_S_AXI_DATA_WIDTH(AXIL_S_DATA_WIDTH),
		.C_S_AXI_ADDR_WIDTH(AXIL_S_ADDR_WIDTH)
	) top_S00_AXI_inst (
	    .mode_sel(mode_sel),
	    .finish_flag(finish_flag),
        .testmode(din_testmode),
        .setreset_pulse_width(setreset_pulse_width),
        .vmmread_refh(vmmread_refh),
        .vmmread_refl(vmmread_refl),
        .vmmread_srref0(vmmread_srref0),
        .read_srref2(read_srref2),
        .vmmread_tiagain(vmmread_tiagain),
        .din_seldel(din_seldel),
        .din_wldel(din_wldel),
        .din_bldel(din_bldel),
        .DACWL_word(DACWL_word),
        .DACBL_word(DACBL_word),
        .DACSEL_word(DACSEL_word),
        .adc_word(adc_word),
        .batch_size(batch_size_vmm),
        .wl_selection(wl_selection),
        .bl_selection(bl_selection),
		.S_AXI_ACLK(clk),
		.S_AXI_ARESETN(rstn),
		.S_AXI_AWADDR(s00_axi_awaddr),
		.S_AXI_AWPROT(s00_axi_awprot),
		.S_AXI_AWVALID(s00_axi_awvalid),
		.S_AXI_AWREADY(s00_axi_awready),
		.S_AXI_WDATA(s00_axi_wdata),
		.S_AXI_WSTRB(s00_axi_wstrb),
		.S_AXI_WVALID(s00_axi_wvalid),
		.S_AXI_WREADY(s00_axi_wready),
		.S_AXI_BRESP(s00_axi_bresp),
		.S_AXI_BVALID(s00_axi_bvalid),
		.S_AXI_BREADY(s00_axi_bready),
		.S_AXI_ARADDR(s00_axi_araddr),
		.S_AXI_ARPROT(s00_axi_arprot),
		.S_AXI_ARVALID(s00_axi_arvalid),
		.S_AXI_ARREADY(s00_axi_arready),
		.S_AXI_RDATA(s00_axi_rdata),
		.S_AXI_RRESP(s00_axi_rresp),
		.S_AXI_RVALID(s00_axi_rvalid),
		.S_AXI_RREADY(s00_axi_rready)
	);
    //}}}
    
    // Instantiation of AXIS slave (data receiver)
    //{{{
	common_S00_AXIS # ( 
		.C_S_AXIS_TDATA_WIDTH(AXIS_DATA_WIDTH),
		.NUMBER_OF_INPUT_WORDS(NUM_WL)
	) S00_AXIS_inst (
	    .data_received(data_received),
	    .writes_done(data_reci_done), // Finish flag
		.S_AXIS_ACLK(clk),
		.S_AXIS_ARESETN(curr_state == DATA_RECEIVE), // Enabler
		.S_AXIS_TREADY(s00_axis_tready),
		.S_AXIS_TDATA(s00_axis_tdata),
		.S_AXIS_TSTRB(s00_axis_tstrb),
		.S_AXIS_TLAST(s00_axis_tlast),
		.S_AXIS_TVALID(s00_axis_tvalid)
	);
    //}}}

	// Instantiation of AXIS master (data sender)
    //{{{
	// For READ and VMM, max NUM_BL words are sent each time (BL output)
	// For SETRESET, max NUM_WL words are sent each time (echo input)
	common_M00_AXIS # ( 
		.C_M_AXIS_TDATA_WIDTH(AXIS_DATA_WIDTH),
		.C_M_START_COUNT(AXIS_M_START_CUNT),
		.NUMBER_OF_OUTPUT_WORDS(MAX_WL_BL)//this is the hardware size limit
    ) M00_AXIS_inst (
        .n_words(n_words),// this is the actual number of words to send each time 
		.data_to_sent(data_to_send),
	    .tx_done(data_sent_done), // Finish flag
		.M_AXIS_ACLK(clk),
		.M_AXIS_ARESETN(curr_state == DATA_SEND), // Enabler
		.M_AXIS_TVALID(m00_axis_tvalid),
		.M_AXIS_TDATA(m00_axis_tdata),
		.M_AXIS_TSTRB(m00_axis_tstrb),
		.M_AXIS_TLAST(single_sample_tlast),
		.M_AXIS_TREADY(m00_axis_tready)
	);	// Instantiation of AXIS master (data sender)
    //}}}
    //}}}

    //Main state machine
    //{{{
    always @(posedge clk) 
    begin  
        if (~rstn) begin
//            state_running <= 0;
//            state_done <= 0;
            curr_state <= IDLE;
            IDLE_OUT;
        end else
            case (mode_sel)
            1://SETRESET
            //{{{
                case (curr_state)
                IDLE:begin
//                        IDLE_OUT;
                    if (~finish_setreset) begin
                        curr_state <= GLOBAL_DAC;
                    end
                    end
                GLOBAL_DAC: begin
                    GLOBAL_DAC_VMM_OUT;
                    if (last_global_dac)
                        curr_state <= DATA_RECEIVE;
                    else
                        curr_state <= curr_state;
                    end
                DATA_RECEIVE:
                    if (data_reci_done) begin
                        n_words <= NUM_WL;
                        curr_state <= SRREF_DAC;
                    end else begin
                        curr_state <= curr_state;
                    end
                SRREF_DAC: begin
                    if (mode_sr == 2'b00) // 00: skip; 01: analog SET; 10: RESET;
                        if (i_wl == NUM_WL - 1) // Last dev of the column
                            curr_state <= DATA_SEND;
                        else begin
                            curr_state <= curr_state;
                            i_wl <= i_wl + 1;
                        end
                    else begin
                        SRREF_DAC_OUT;
                        if (last_srref_dac)
                            curr_state <= RINGSW;
                        else
                            curr_state <= curr_state;
                        end
                    end
                RINGSW: begin
                        RINGSW_OUT;
                        if(last_sw) begin
                            curr_state <= APPLY_V;
                        end else begin
                            curr_state <= curr_state;
                        end
                    end
                APPLY_V: 
                    if (cnt == setreset_pulse_width) begin
                        cnt <= 0;
                        {DACBL_SW, DACSEL_SW, DACWL_SW, SET, RESET} <= 0;
                        if (i_wl == NUM_WL - 1) // Last WL                   
                            curr_state <= DATA_SEND;
                        else begin // Not the last WL
                            curr_state <= SRREF_DAC;
                            i_wl <= i_wl + 1;
                        end
                    end else begin
                        APPLY_V_OUT;
                        curr_state <= curr_state;
                    end
                DATA_SEND:
                    if (data_sent_done) begin
                        if (i_bl == NUM_BL - 1) begin // Last BL
                            i_wl <= 0;
                            i_bl <= 0;                    
                            curr_state <= IDLE;
                            finish_setreset <= 1'b1;
                        end else begin // Not the last BL
                            curr_state <= DATA_RECEIVE;//go to next BL
                            i_wl <= 0;
                            i_bl <= i_bl + 1;                                               
                        end
                    end else begin
                        curr_state <= curr_state;
                    end
	            endcase
            //}}}
            2://VMM
            //{{{
                case (curr_state)
                    IDLE:begin
//                        IDLE_OUT;
                        if (~finish_vmm) begin
                            n_words <= NUM_BL;// to be determined by Gloabl Configuration in the future
                            curr_state <= GLOBAL_DAC;
                        end
                        end
                    GLOBAL_DAC: begin
                        GLOBAL_DAC_VMM_OUT;
                        if (last_global_dac) begin
                            curr_state <= RINGSW;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    RINGSW: begin
                        RINGSW_OUT;
                        if (last_sw) begin
                            curr_state <= DATA_RECEIVE;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    DATA_RECEIVE:
                        if (data_reci_done) begin
                            curr_state <= WL_DAC;
                        end else begin
                            curr_state <= curr_state;
                        end
                    WL_DAC: begin //7
                        WL_DAC_OUT;
                        if (last_wl_dac) begin
                            curr_state <= ADC_VMM;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    ADC_VMM: begin //8
                        ADC_VMM_OUT;
                        if (last_adc_vmm) begin
                            curr_state <= DATA_SEND;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    DATA_SEND:
                        if (data_sent_done) begin
                            if (batch_cunt == batch_size_vmm - 1) begin
                                batch_cunt <= 0;//Fixed the problem that counter not reset
                                curr_state <= IDLE;
                                finish_vmm <= 1'b1;
                                DACSEL_SW <= 0;//TODO temp fix, should use IDLE out;
                            end else begin
                                curr_state <= DATA_RECEIVE;
                                batch_cunt <= batch_cunt + 1;  
                            end
                        end else begin
                            curr_state <= curr_state;
                        end
                endcase
            //}}}
            3://READ
            //{{{
                case (curr_state)
                    IDLE:begin
//                        IDLE_OUT;
                        if (~finish_read) begin
                            n_words <= NUM_BL;// to be determined by Global Configuration in the future
                            curr_state <= GLOBAL_DAC;
                        end
                        end
                    GLOBAL_DAC: begin
                        GLOBAL_DAC_VMM_OUT;
                        if (last_global_dac) begin
                            curr_state <= RINGSW;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    RINGSW: begin
                        RINGSW_OUT;
                        if (last_sw) begin
                            curr_state <= READ_ADC;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    READ_ADC: begin
                        ADC_READ_OUT;
                        if (last_adc_read) begin
                            i_bl <= (i_bl + 1) % NUM_BL;
                            if (i_bl == NUM_BL - 1) begin
                                curr_state <= DATA_SEND;
                            end else
                                curr_state <= RINGSW;
                        end else begin
                            curr_state <= curr_state;
                        end
                        end
                    DATA_SEND:
                        if (data_sent_done) begin
                            i_wl <= (i_wl + 1) % NUM_WL;
                            if (i_wl == NUM_WL - 1) begin
                                i_wl <= 0;
                                i_bl <= 0;
                                finish_read <= 1'b1;
                                curr_state <= IDLE;
                            end else begin
                                curr_state <= RINGSW;
                            end
                        end else begin
                            curr_state <= curr_state;
                        end
                   endcase
            //}}}
            0: begin
                curr_state <= IDLE;
                IDLE_OUT;
            end
            default: curr_state <= curr_state;
            endcase
	end
    //}}}
	
    //Tasks used in the state machine
	task IDLE_OUT;
    //{{{
	begin
        //loop variable
        cnt <= 0;
        cnt_adc_first_delay <= 0;
        i_wl <= 0;
        i_bl <= 0;
        n_words <= 0;
        batch_cunt <= 0;//loop variable of VMM
    //            wl_selection <= {NUM_WL{1'b1}};
    //            bl_selection <= {NUM_BL{1'b1}};
        finish_setreset <= 1'b0;
        finish_vmm <= 1'b0;
        finish_read <= 1'b0;
        DIN <= 0;
        ADDR <= 0;
        CLKDAC <= 0;
        CLKADCSW <= 1'b0;
        CLKADC <= 1'b0;
        DACBL_SW <= 1'b0;//SETRESET uses it
        DACBL_SW2 <=1'b0;
        DACSEL_SW <= 1'b0;
        DACWL_SW <= 1'b0;
        CLKREG <= 0;
        DINSWREG <= 0;
        SET <= 1'b0;
        RESET <= 1'b0;
    end
    endtask
    //}}}

    // Gloabl registers setup task
    // setup TESTMODE, REFH/L, SEL/WL/BLDEL, SRREF012, TIAGAIN
	//configures: TESTMODE, REFHL, SRREF012, TIAGAIN(VMM&READ) or SELSPEED(SETRESET);
    task GLOBAL_DAC_VMM_OUT;
    //{{{
	begin
	    if (last_global_dac) begin
            cnt <= 0; i_phase <= 0;
            {DIN, ADDR, CLKDAC} <= 0;
	    end else begin
            //cnt represents i_cycle here, increases when last phase was reached.
            //each cycle consists of two phases for rings switches
            i_phase <= (i_phase +1)%3;
            cnt <= cnt + (i_phase==2);
            //generate output DIN, ADDR, CLKDAC
            CLKDAC <= (i_phase==1);
            case (cnt)  
            0: begin DIN <= din_testmode[8:0]; ADDR <= addr_testmode; end // Disable test mode after debugging.                              
            1: begin DIN <= vmmread_refh[5:0]; ADDR <= addr_refh; end//TODO REFH/L could be 0 for setreset as before
            2: begin DIN <= vmmread_refl[5:0]; ADDR <= addr_refl; end
            3: begin DIN <= din_seldel[7:0]; ADDR <= addr_seldel; end
            4: begin DIN <= din_wldel[7:0]; ADDR <= addr_wldel; end
            5: begin DIN <= din_bldel[7:0]; ADDR <= addr_bldel; end
            6: begin DIN <= vmmread_srref0[5:0]; ADDR <= addr_srref0; end// SR_REF0 gate
            7: begin DIN <= 8'b0; ADDR <= addr_srref1; end// SR_REF1 BL
            8: begin DIN <= enable_read?read_srref2[5:0]:8'b0; ADDR <= addr_srref2; end// SR_REF2 WL  
            9: begin DIN <= data_tia_gain; ADDR <= addr_tia_gain; end
            default:begin DIN <=0; ADDR <=0; end
            endcase
            //Turn on SEL_SW in advance when do VMM.other side switches turned on in adc block.
            //TODO: seperate these signals into dedicated blocks.
            DACSEL_SW <= enable_vmm;
        end
    end
    endtask
    //}}}
    
    task SRREF_DAC_OUT;
    //{{{
	begin
	    if (last_srref_dac) begin
            cnt <= 0; i_phase <= 0;
            {DIN, ADDR, CLKDAC} <= 0;
	    end else begin
            //cnt represents i_cycle here, increases when last phase was reached.
            //each cycle consists of two phases for rings switches
            i_phase <= (i_phase +1)%3;
            cnt <= cnt + (i_phase==2);
            //generate output DIN, ADDR, CLKDAC
            CLKDAC <= (i_phase==1);
            case (cnt)
            0: begin DIN <= setreset_srref0; ADDR <= addr_srref0; end// SR_REF0 gate
            1: begin DIN <= setreset_srref1; ADDR <= addr_srref1; end// SR_REF1 BL
            2: begin
                DIN <= setreset_srref2; 
                ADDR <= addr_srref2; 
                end// SR_REF2 WL
            default:begin DIN <=0; ADDR <=0; end
            endcase
        end
    end
    endtask
    //}}}
    
	task WL_DAC_OUT;
    //{{{
	begin
	    if (last_wl_dac) begin
            cnt <= 0; i_phase <= 0;
            {DIN, ADDR, CLKDAC} <= 0;
	    end else begin
            i_phase <= (i_phase +1)%3;
            cnt <= cnt + (i_phase==2);
            //generate output DIN, ADDR, CLKDAC
            CLKDAC <= (i_phase==1);
            //add wl_selection here
            ADDR <= cnt;
            DIN <= wl_selection[cnt]?data_received[(cnt + 1) * AXIS_DATA_WIDTH - 9 -: 8]:0; //!!! For 16-bit case only !!!
        end
    end
	endtask
    //}}}

    task APPLY_V_OUT;
    //{{{
    begin
        cnt <= cnt + 1;
        if (cnt >= BL_pulsewidth_set_st && cnt <= BL_pulsewidth_set_end) begin
            DACBL_SW <= 1'b1;
        end
        else begin
            DACBL_SW <= 1'b0;
        end
        if (cnt >= WL_pulsewidth_set_st && cnt <= WL_pulsewidth_set_end) begin
            DACWL_SW <= 1'b1;
        end
        else begin
            DACWL_SW <= 1'b0;
        end
        if (cnt >= SEL_pulsewidth_set_st && cnt <= SEL_pulsewidth_set_end) begin
            DACSEL_SW <= 1'b1;
        end
        else begin
            DACSEL_SW <= 1'b0;
        end
        if (mode_sr == 2'b01) // RESET = 10, SET = 01
            SET <= 1'b1;
        else
            RESET <= 1'b1;
    end
    endtask
    //}}}

    // Ring Switch tasks
    // calculate the number of cycles for flashing ring switches
	task RINGSW_OUT;
    //{{{
    begin
        if (last_sw) begin
            cnt <= 0;
            i_phase <= 0;//not necessary, should reach 0 by itself with the cnt/phase logic
            {CLKREG, DINSWREG} <= 0;
        end else begin
            //cnt represents i_cycle here, increases when last phase was reached.
            //each cycle consists of two phases for rings switches
            i_phase <= (i_phase +1)%2;
            cnt <= cnt + (i_phase==1);
            // outputs are delayed by one cycle, compared with i_phase and cnt.
            // To turn on device (WL=i,BL=j):
            // TIA: cnt = j
            // SEL: cnt = i
            // BL: cnt = NBL-1 - j
            // WL: cnt = NWL-1 - i
            if (PARALLEL_RINGSW) begin
                CLKREG <= {i_phase && cnt<=(NUM_BL-1),//TIA
                            i_phase && cnt<=(NUM_WL-1),//SEL
                            i_phase && cnt<=(NUM_BL-1),//BL
                            i_phase && cnt<=(NUM_WL-1)};//WL
                /*
                DINSWREG <= {cnt<=(NUM_BL-1) &&enable_vmm &&bl_selection[cnt] || cnt==i_bl &&enable_read,
                            cnt<=(NUM_WL-1) &&enable_vmm &&wl_selection[cnt] || cnt==i_wl&&(enable_read||enable_setreset),
                            cnt==(NUM_BL-1-i_bl) &&enable_setreset,
                            cnt<=(NUM_WL-1) &&enable_vmm &&wl_selection[NUM_WL-1-cnt] || cnt==(NUM_WL-1 - i_wl)&&(enable_read||enable_setreset)};
                */

                DINSWREG[3] <= cnt<=(NUM_BL-1) &&enable_vmm || cnt==i_bl &&enable_read;
                DINSWREG[2] <= cnt<=(NUM_WL-1) &&enable_vmm &&wl_selection[cnt] || cnt==i_wl&&(enable_read||enable_setreset);
                DINSWREG[1] <= cnt==(NUM_BL-1-i_bl) &&enable_setreset;
                DINSWREG[0] <= cnt<=(NUM_WL-1) &&enable_vmm &&wl_selection[NUM_WL-1-cnt] || cnt==(NUM_WL-1 - i_wl)&&(enable_read||enable_setreset);



            end else begin
                // CLKREG[0] follows i_phase
                CLKREG[0] <= i_phase;
            // To turn on device (WL=i,BL=j):
            // TIA: cnt = j
            // SEL: cnt = NBL + i
            // BL: cnt = NWL+NBL +(NBL-1- j)
            // WL: cnt = 2(NWL+NBL)-1 - i
                DINSWREG[0] <= ((cnt <= (NUM_BL-1))&&(bl_selection[cnt])//TIA
                    ||(NUM_BL<=cnt &&cnt<=(NUM_WL+NUM_BL-1) &&wl_selection[cnt-NUM_BL])//SEL 
                    || cnt >= (NUM_WL+NUM_BL*2)&&wl_selection[NUM_SW_CYCLE-1-cnt]//WL, 
                    )&&enable_vmm //the selection should completely fall into the non-selection range, y.e. A&B=B
                    ||cnt==i_bl &&enable_read //TIA
                    ||cnt==NUM_BL+i_wl &&(enable_read||enable_setreset) //SEL
                    ||cnt==(NUM_WL+2*NUM_BL-1 - i_bl) &&enable_setreset//BL
                    ||cnt==(NUM_SW_CYCLE-1-i_wl) &&(enable_read||enable_setreset);//WL
            end
        end
	end
	endtask
    //}}}

    //ADC tasks
    // 200 ns ADC settle time
    // TODO: add a configerable reg to control delay here.
    // all TIA settle at the same time, so
    // first cycle can open CLKADC,CLKADCSW,ADDR
    // CLKADC raising edge gives DOUT, so receive DOUT and provide new addr at falling edge,
    // then 
	task ADC_VMM_OUT;
    //{{{
	begin
	    if (last_adc_vmm) begin
            cnt <= 0;
            i_phase <= 0;
            cnt_adc_first_delay <= 0;
            {ADDR, CLKADCSW, CLKADC} <= 0;
            // The side switches. DACSEL_SW turned on in advance and turned off after all VMM is done
            {DACBL_SW2, DACWL_SW} <=0;
	    end else begin
            CLKADCSW <= 1'b1;
	        DACBL_SW2 <= 1'b1;
            DACWL_SW <= 1'b1;

	        if (bl_selection[cnt]) begin
                if (cnt_adc_first_delay == adc_first_delay) begin  
                    cnt <= cnt + (i_phase==adc_high_period+adc_low_period);
                    i_phase <= (i_phase + 1) % (1 + adc_high_period + adc_low_period);
                    
                    ADDR <= cnt;//XXX: once changed to index-based, use selectedBL[cnt] 
                    CLKADC <= (i_phase>0 && i_phase < adc_high_period+1 );
                    if (i_phase==(adc_high_period)) begin
                        data_to_send[(cnt + 1) * AXIS_DATA_WIDTH - 1  -: 16] <= {10'b0, DOUT};
                    end
                end else begin
                    cnt_adc_first_delay <= cnt_adc_first_delay +1;
                end
	        end else begin
	           cnt <= cnt + 1;
	           data_to_send[(cnt + 1) * AXIS_DATA_WIDTH - 1  -: 16] <= 16'd255;
	        end
        end 
	end
	endtask
    //}}}

    task ADC_READ_OUT;
    //{{{
    // only read one device, but still use phase to count.
    begin
        if (last_adc_read) begin
            cnt <= 0;
            i_phase <= 0;
            cnt_adc_first_delay <= 0;
            {ADDR, CLKADCSW, CLKADC} <= 0;
            {DACBL_SW2, DACSEL_SW, DACWL_SW}<=0;
        end else begin
            // The side switches
            CLKADCSW <= 1'b1;
            if (cnt >= BL_pulsewidth_set_st && cnt <= BL_pulsewidth_set_end) begin
                DACBL_SW2 <= 1'b1;
            end
            else begin
                DACBL_SW2 <= 1'b0;
            end
            if (cnt >= WL_pulsewidth_set_st && cnt <= WL_pulsewidth_set_end) begin
                DACWL_SW <= 1'b1;
            end
            else begin
                DACWL_SW <= 1'b0;
            end
            if (cnt >= SEL_pulsewidth_set_st && cnt <= SEL_pulsewidth_set_end) begin
                DACSEL_SW <= 1'b1;
            end
            else begin
                DACSEL_SW <= 1'b0;
            end

            if (cnt_adc_first_delay == adc_first_delay) begin
                cnt <= cnt + (i_phase==adc_high_period+adc_low_period);
                i_phase <= (i_phase + 1) % (1 + adc_high_period + adc_low_period);
                
                CLKADC <= (i_phase>0 && i_phase < adc_high_period+1 );
                if (i_phase==(adc_high_period)) begin
                    data_to_send[(i_bl + 1) * AXIS_DATA_WIDTH - 1  -: 16] <= {10'b0, DOUT};
                end
            end else begin
                cnt_adc_first_delay <= cnt_adc_first_delay +1;
            end
            ADDR <= i_bl;//XXX: once changed to index-based, use selectedBL[cnt] 
        end
    end
    endtask
    //}}}
endmodule
