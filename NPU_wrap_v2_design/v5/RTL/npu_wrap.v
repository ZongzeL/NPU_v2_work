
`timescale 1 ns / 1 ps

module NPU_v2_wrap #
(
    //important parameters
	parameter integer AXI_ID_WIDTH	= 1,
	parameter integer AXI_DATA_WIDTH	= 32,
    parameter integer ADDR_BYTE_OFFSET = AXI_DATA_WIDTH / 8,
    parameter integer AXI_STRB_WIDTH        = AXI_DATA_WIDTH/8,
	parameter integer AXI_ADDR_WIDTH	= 32, 
    parameter integer AXI_USER_WIDTH        = 10,
    parameter integer NPU_CONFIG_DATA_MEM_LENGTH       = 64,
    parameter integer NPU_WRAP_CONFIG_DATA_MEM_LENGTH       = 32,
    parameter integer NPU_WRAP_CONFIG_DATA_VMM_INST       = 14,
    parameter integer VMM_MEM_LENGTH       = 256,
    parameter integer DATA_MEM_LENGTH      = VMM_MEM_LENGTH / 4,
   

    //calculated parameters
    parameter integer OPT_MEM_ADDR_BITS     = $clog2(DATA_MEM_LENGTH),
    parameter integer ADDR_LSB = $clog2(ADDR_BYTE_OFFSET), //2
   
    parameter NPU_AXI_BASE_ADDR     = 32'h12000000 + 32'h4000_0000 //32'h4000_0000 is zc702's address offset
    //parameter NPU_AXI_BASE_ADDR     = 32'h0
)
(
    input wire  clk,
	input wire  rst_n,

    output wire irq_o,
    //`include "AXI_IO_define.svh"
    //{{{
    input [AXI_ID_WIDTH-1:0]   awid,
    input [AXI_ADDR_WIDTH-1:0] awaddr,
    input [7:0]                awlen,
    input [2:0]                awsize,
    input [1:0]                awburst,
    input                      awlock,
    input [3:0]                awcache,
    input [2:0]                awprot,
    input [3:0]                awqos,
    input [3:0]                awregion,
    input [AXI_USER_WIDTH-1:0] awuser,
    input                      awvalid,
    output                     awready,

    input [AXI_DATA_WIDTH-1:0] wdata,
    input [AXI_STRB_WIDTH-1:0] wstrb,
    input                      wlast,
    input [AXI_USER_WIDTH-1:0] wuser,
    input                      wvalid,
    output                     wready,
    input [AXI_ID_WIDTH-1:0]   wid,
    
    output [AXI_ID_WIDTH-1:0]   bid,
    output [1:0]                bresp,
    output [AXI_USER_WIDTH-1:0] buser,
    output                      bvalid,
    input                       bready,

    input [AXI_ID_WIDTH-1:0]   arid,
    input [AXI_ADDR_WIDTH-1:0] araddr,
    input [7:0]                arlen,
    input [2:0]                arsize,
    input [1:0]                arburst,
    input                      arlock,
    input [3:0]                arcache,
    input [2:0]                arprot,
    input [3:0]                arqos,
    input [3:0]                arregion,
    input [AXI_USER_WIDTH-1:0] aruser,
    input                      arvalid,
    output                     arready,


    output [AXI_ID_WIDTH-1:0]   rid,
    output [AXI_DATA_WIDTH-1:0] rdata,
    output [1:0]                rresp,
    output                      rlast,
    output [AXI_USER_WIDTH-1:0] ruser,
    output                      rvalid,
    input                       rready, 

    //}}}
    
    output wire [5:0] CS_ILA,

    //`include "DAC_IO_define.svh"
    //{{{
    input          [  5 :0]  NPU_DOUT          , 
    output  reg    [  7 :0]  NPU_DIN           , 
    output  reg    [   8:0]  NPU_ADDR          , 
    output  reg              NPU_CLKDAC        , 
	output  reg              NPU_CLKADC        , 
	output  reg              NPU_CLKADC_SW     , 
	
    output  reg              NPU_SET           , 
    output  reg              NPU_RESET         , 
    
    output  reg    [3:0]     NPU_CLKREG        , 
    output  reg    [3:0]     NPU_DINSWREG      , 
	
    output  reg              NPU_DACBL_SW      , 
    output  reg              NPU_DACTIA_SW     , 
    output  reg              NPU_DACSEL_SW     , 
    output  reg              NPU_DACWL_SW      , 
    output  reg              NPU_DACWLREFSW    , 
		    
    
	output  wire             NPU_DISCHG        , 
    output  wire             NPU_ARST_ENREG    , 
    output  wire             NPU_ARST_WLREG    , 
    output  wire             NPU_ASET_ENREG    , 
    output  wire             NPU_ASET_WLREG     
    //}}}
    
);
    //integer
    integer i;


    //localparam
    //{{{
    //address
    //{{{ 
    //config
	localparam NPU_CONFIG_START_ADDR =   20'h0_0000;
	localparam NPU_CONFIG_SIZE       =   20'h0_0400;
	localparam NPU_CONFIG_END_ADDR   =   (NPU_CONFIG_START_ADDR + NPU_CONFIG_SIZE);

    //input data
	localparam NPU_VMM_INPUT_START_ADDR  =   20'h0_0400;
	localparam NPU_VMM_INPUT_END_ADDR    =   (NPU_VMM_INPUT_START_ADDR + NPU_CONFIG_SIZE); // 400-4ff: input, 500-5ff: norm_a, 600-6ff: norm_b, use axi_w_opt_addr[7:6] == 0, 1, 2 to identify

    //output data
	localparam NPU_VMM_OUTPUT_START_ADDR =   20'h0_0800;
	localparam NPU_VMM_OUTPUT_END_ADDR   =   (NPU_VMM_OUTPUT_START_ADDR + NPU_CONFIG_SIZE);

	// Extend to 20-bit to avoid overflow
    //read mem
	localparam NPU_MEM_START_ADDR    =   20'h4_0000;
	localparam NPU_MEM_SIZE          =   20'h4_0000;
	localparam NPU_MEM_END_ADDR      =   (NPU_MEM_START_ADDR + NPU_MEM_SIZE);
    //}}}
   

    //state machine
    //{{{ 
    localparam [5:0] IDLE                   = 6'd0;
    localparam [5:0] SETDACTIACONFIG        = 6'd1;
    localparam [5:0] SETSW                  = 6'd2;
    localparam [5:0] SETDAC_KERNEL          = 6'd3;
    localparam [5:0] VMM_SETPRELOAD         = 6'd4;
    localparam [5:0] SET_RESET_DAC_WRITE_V  = 6'd5;
    localparam [5:0] VMM_PRELOAD            = 6'd6;
    localparam [5:0] APPLY_V                = 6'd7;
    localparam [5:0] READADC_PRELOAD_0      = 6'd8;
    localparam [5:0] READADC_PRELOAD_WRITE_DAC= 6'd9;
    localparam [5:0] READADC_PRELOAD_1      = 6'd10;
    localparam [5:0] READADC_KERNEL         = 6'd11;

    localparam [3:0] SET_RESET_DAC_WRITE_V_LIMIT = 4'd2;
    //}}}
    


    //}}}


    //AXI signals
    //{{{
    wire [AXI_ID_WIDTH-1:0]   AXI_awid;
    wire [AXI_ADDR_WIDTH-1:0] AXI_awaddr;
    wire [7:0]                AXI_awlen;
    wire [2:0]                AXI_awsize;
    wire [1:0]                AXI_awburst;
    wire                      AXI_awlock;
    wire [3:0]                AXI_awcache;
    wire [2:0]                AXI_awprot;
    wire [3:0]                AXI_awqos;
    wire [3:0]                AXI_awregion;
    wire [AXI_USER_WIDTH-1:0] AXI_awuser;
    wire                      AXI_awvalid;
    reg                       AXI_awready;

    wire [AXI_DATA_WIDTH-1:0] AXI_wdata;
    wire [AXI_STRB_WIDTH-1:0] AXI_wstrb;
    wire                      AXI_wlast;
    wire [AXI_USER_WIDTH-1:0] AXI_wuser;
    wire                      AXI_wvalid;
    reg                       AXI_wready;
    wire [AXI_ID_WIDTH-1:0]   AXI_wid;
    
    reg [AXI_ID_WIDTH-1:0]    AXI_bid;
    reg [1:0]                 AXI_bresp;
    reg [AXI_USER_WIDTH-1:0]  AXI_buser;
    reg                       AXI_bvalid;
    wire                      AXI_bready;

    wire [AXI_ID_WIDTH-1:0]   AXI_arid;
    wire [AXI_ADDR_WIDTH-1:0] AXI_araddr;
    wire [7:0]                AXI_arlen;
    wire [2:0]                AXI_arsize;
    wire [1:0]                AXI_arburst;
    wire                      AXI_arlock;
    wire [3:0]                AXI_arcache;
    wire [2:0]                AXI_arprot;
    wire [3:0]                AXI_arqos;
    wire [3:0]                AXI_arregion;
    wire [AXI_USER_WIDTH-1:0] AXI_aruser;
    wire                      AXI_arvalid;
    reg                       AXI_arready;

    reg [AXI_ID_WIDTH-1:0]    AXI_rid;
    reg [AXI_DATA_WIDTH-1:0]  AXI_rdata;
    reg [1:0]                 AXI_rresp;
    reg                       AXI_rlast;
    reg [AXI_USER_WIDTH-1:0]  AXI_ruser;
    reg                       AXI_rvalid;
    wire                      AXI_rready; 

    assign  AXI_awid     =  awid;
    assign  AXI_awaddr   =  awaddr;
    assign  AXI_awlen    =  awlen;
    assign  AXI_awsize   =  awsize;
    assign  AXI_awburst  =  awburst;
    assign  AXI_awlock   =  awlock;
    assign  AXI_awcache  =  awcache;
    assign  AXI_awprot   =  awprot;
    assign  AXI_awqos    =  awqos;
    assign  AXI_awregion =  awregion;
    assign  AXI_awuser   =  awuser;
    assign  AXI_awvalid  =  awvalid;
    assign  awready      =  AXI_awready;

    assign  AXI_wdata   = wdata;
    assign  AXI_wstrb   = wstrb;
    assign  AXI_wlast   = wlast;
    assign  AXI_wuser   = wuser;
    assign  AXI_wvalid  = wvalid;
    assign  wready      = AXI_wready;
    assign  AXI_wid     = wid;
    
    assign  bid         = AXI_awid;
    assign  bresp       = AXI_bresp;
    assign  buser       = AXI_buser;
    assign  bvalid      = AXI_bvalid;
    assign  AXI_bready  = bready;

    assign  AXI_arid    = arid; 
    assign  AXI_araddr  = araddr; 
    assign  AXI_arlen   = arlen; 
    assign  AXI_arsize  = arsize; 
    assign  AXI_arburst = arburst; 
    assign  AXI_arlock  = arlock; 
    assign  AXI_arcache = arcache; 
    assign  AXI_arprot  = arprot; 
    assign  AXI_arqos   = arqos; 
    assign  AXI_arregion= arregion; 
    assign  AXI_aruser  = aruser; 
    assign  AXI_arvalid = arvalid; 
    assign  arready     = AXI_arready;

    assign  rid         = AXI_arid;
    assign  rdata       = AXI_rdata;
    assign  rresp       = AXI_rresp;
    assign  rlast       = AXI_rlast;
    assign  ruser       = AXI_ruser;
    assign  rvalid      = AXI_rvalid;
    assign  AXI_rready  = rready;
    //}}}

    //wire
    //{{{

    //AXI related
    //{{{
    wire axi_aw_wrap_en;
    wire axi_wr_wrap_en;
    wire [31:0]  axi_aw_wrap_size ; 
    wire [31:0]  axi_ar_wrap_size ;
    wire axi_aw_instr_valid; 
    wire axi_ar_instr_valid; 
    wire axi_aw_VMM_in_data_instr_valid; 
    wire axi_ar_VMM_data_instr_valid; 
    //}}}

    //NPU_WRAP_config_data
    //{{{
    //0
    wire [1:0]              NPU_WRAP_setreset_mode;
    wire                    NPU_WRAP_vmm_config_again_skip;
    wire                    NPU_WRAP_disable_access_data_anytime;
    //1
    wire [7:0]              NPU_WRAP_WL_ST;
    wire [7:0]              NPU_WRAP_WL_LEN;
    wire [7:0]              NPU_WRAP_WL_END;
    wire [7:0]              NPU_WRAP_BL_ST;
    //2
    wire [7:0]              NPU_WRAP_VMM_CONFIG_ST;
    wire [7:0]              NPU_WRAP_VMM_CONFIG_END;
    wire [7:0]              NPU_WRAP_READ_MEM_CONFIG_ST;
    wire [7:0]              NPU_WRAP_READ_MEM_CONFIG_END;
    //3
    wire [7:0]              NPU_WRAP_SET_RESET_CONFIG_ST;
    wire [7:0]              NPU_WRAP_SET_RESET_CONFIG_END;
    wire [7:0]              READADC_PRELOAD_COUNT_LIMIT_0;
    wire [7:0]              READADC_PRELOAD_COUNT_LIMIT_1;
    //4
    wire [15:0]             NPU_WRAP_pulse_width;
    wire [15:0]             NPU_WRAP_WL_pulsewidth;
    //5
    wire [15:0]             NPU_WRAP_SEL_pulsewidth;
    wire [15:0]             NPU_WRAP_TIA_pulsewidth;
    //6
    wire [15:0]             NPU_WRAP_WL_pulsewidth_read ;
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_read;
    //7
    wire [15:0]             NPU_WRAP_TIA_pulsewidth_read;
    wire [7 :0]             NPU_WRAP_wlg_ctrl1;
    wire [7 :0]             READ_MEM_repeat_time;
    //8
    wire [15:0]             NPU_WRAP_adcrst1_delay;
    wire [15:0]             NPU_WRAP_adcrst2_delay;
    //9
    wire [7:0]              READADC_PRELOAD_DAC_CONFIG_ST; 
    wire [7:0]              READADC_PRELOAD_DAC_CONFIG_END; 
    wire [3:0]              SETDAC_INTERNAL_STATE_LIMIT_v2;
    wire [3:0]              SETDAC_INTERNAL_VALID_STATE_ST_v2;
    wire [3:0]              SETDAC_INTERNAL_VALID_STATE_END_v2;

    //10 
    wire [11:0]             adc_first_delay_v2;
    wire [11:0]             adc_high_period_v2;
    wire [7:0]              adc_low_period_v2;
    wire [19:0]             READADC_INTERNAL_STATE_LIMIT_v2;

    //11
    wire [15:0]             NPU_WRAP_WL_pulsewidth_set_st;
    wire [15:0]             NPU_WRAP_WL_pulsewidth_set_end;

    //12
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_set_st;
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_set_end;

    //13
    wire [15:0]             NPU_WRAP_BL_pulsewidth_set_st;
    wire [15:0]             NPU_WRAP_BL_pulsewidth_set_end;

    //14
    wire [7:0]              VMM_start_addr; //npu addr use WL_ST, len use WL_LEN
    
    //30 SOC 
    //31 CS
     
    


    wire [7:0]              NPU_WRAP_BL_LEN;
    wire [7:0]              NPU_WRAP_BL_END;

    wire [7:0]              READADC_PRELOAD_DAC_CONFIG_LEN;

    wire [15:0]             NPU_WRAP_m1_pulsewidth;
    wire [15:0]             NPU_WRAP_m2_pulsewidth;
    wire [15:0]             NPU_WRAP_vmm_pulsewidth;
    wire [15:0]             NPU_WRAP_SEL_SWST;
    wire [15:0]             NPU_WRAP_WL_SWST;
    wire [15:0]             NPU_WRAP_TIA_SWST;
    wire [15:0]             NPU_WRAP_m1_pulsewidth_read;
    wire [15:0]             NPU_WRAP_m2_pulsewidth_read;
    wire [15:0]             NPU_WRAP_read_pulsewidth;
    wire [15:0]             NPU_WRAP_SEL_SWST_read;
    wire [15:0]             NPU_WRAP_WL_SWST_read;
    wire [15:0]             NPU_WRAP_TIA_SWST_read;

    




    //wire [7:0]              din_testmode_debug; //same as data_testmode, useless
    //}}}

    //}}}
    
    //reg	
    //{{{

    //AXI related
    //{{{
    reg [AXI_ADDR_WIDTH - 1 : 0] 	axi_instr_awaddr;
    reg [AXI_ADDR_WIDTH - 1 : 0] 	axi_instr_araddr;
    
    reg [AXI_ADDR_WIDTH - 1 : 0]   axi_w_opt_addr; //TODO width can change
    reg [AXI_ADDR_WIDTH - 1 : 0]   axi_r_opt_addr;
    
    reg axi_aw_flag;    //writing 
    reg axi_ar_flag;    //reading
    
    reg axi_aw_write_config_flag; //write config
    reg axi_aw_write_vmm_input_data_flag; //write vmm input data
    reg axi_aw_set_reset_write_mem_flag; //write set reset data
 
    reg axi_ar_read_config_flag; //read config
    reg axi_ar_read_vmm_input_data_flag; //read vmm input data
    reg axi_ar_read_vmm_output_data_flag; //read vmm output data
    reg axi_ar_read_mem_flag; //read mem 
    
    reg [7:0] axi_instr_awlen_cntr;
    reg [7:0] axi_instr_arlen_cntr;
    reg [1:0] axi_instr_arburst;
    reg [1:0] axi_instr_awburst;
    reg [7:0] axi_instr_arlen;
    reg [7:0] axi_instr_awlen;
    //}}}

    //NPU related
    //{{{

    reg    [  7 :0]  NPU_DIN_w           ;
    reg    [   8:0]  NPU_ADDR_w          ;
    reg              NPU_CLKDAC_w        ;
	reg              NPU_CLKADC_w        ;
	reg              NPU_CLKADC_SW_w      ;
	
    reg              NPU_SET_w           ;
    reg              NPU_RESET_w         ;
    
    reg              NPU_CLKREG_SEL_w    ;
	reg              NPU_CLKREG_BL_w     ;
	reg              NPU_CLKREG_WL_w     ;
	reg              NPU_CLKREG_TIA_w    ;
	
    reg              NPU_DINSWREG_SEL_w  ;
	reg              NPU_DINSWREG_BL_w   ;
	reg              NPU_DINSWREG_WL_w   ;
	reg              NPU_DINSWREG_TIA_w  ;
	
    reg              NPU_DACBL_SW_w      ;
    reg              NPU_DACTIA_SW_w     ;
    reg              NPU_DACSEL_SW_w     ;
    reg              NPU_DACWL_SW_w      ;
    reg              NPU_DACWLREFSW_w    ;
	
    //}}}

    //data memory related
    //{{{
    //ARES input data address from 400 to 800, totally 10 bit, axi is 4 byte, first 2 bits are 0.
    //so, memory length can only have 8 bits, input/output memory can totally hold 256 * 32 bits.
    //config data: 000 to 400 
        //000 to 0ff is NPU_CORE_config_data  
        //100 to 1ff is NPU_CORE_config_data_addr
        //200 to 2ff is NPU_WRAP_config_data
        //300 to 3ff not used.  
    //reg [AXI_DATA_WIDTH-1:0] VMM_in_data[0 : DATA_MEM_LENGTH - 1];
    reg [7:0] VMM_in_data[0 : VMM_MEM_LENGTH - 1];
    reg [7:0] VMM_out_data[0 : VMM_MEM_LENGTH - 1];
    
    reg [7:0]               NPU_CORE_config_data[0 : NPU_CONFIG_DATA_MEM_LENGTH - 1];
    reg [7:0]               NPU_CORE_config_data_addr [0 : NPU_CONFIG_DATA_MEM_LENGTH - 1];
    reg [31:0]              NPU_WRAP_config_data [0 : NPU_WRAP_CONFIG_DATA_MEM_LENGTH - 1];
    //}}}

    //VMM valid
    //{{{
    wire VMM_valid;
    //}}}

    //state machine related
    //{{{
    reg [5:0] CS;
    //reg VMM_config_done;
    reg VMM_running;
    //reg READ_MEM_config_done;
    reg READ_MEM_running;
    //reg SET_RESET_config_done;
    reg SET_RESET_running;
    reg [31:0] state_machine_one_hot_indexer;

    //}}}

    //operation states 
    //{{{
    reg [3:0] setdac_internal_state;
    reg [3:0] readadc_internal_state;

    reg [7:0] setdactiaconfig_end_addr;
    reg [7:0] setdactiaconfig_run_addr;

    reg [8:0] setsw_count; 
    reg [7:0] setsw_WL_ST;   
    reg [7:0] setsw_WL_END;   
    reg [7:0] setsw_BL_ST;   
    reg [7:0] setsw_BL_END;   

 
    reg [7:0] setdac_kernel_run_addr;       //for NPU core addr use
    reg [7:0] setdac_kernel_internal_addr;  //for internal VMM_in_data use

    reg [7:0] readadc_kernel_run_addr;
    reg [7:0] readadc_kernel_end_addr;
    
    reg [3:0] vmm_preload_run_addr; //not acturally an addr, just 0 and 1.

    reg [15:0] readadc_preload_count;

    reg [15:0] pulse_count;
    reg [15:0] apply_v_pulse_count_limit;

    
    reg [7:0] read_mem_wl;
    reg [7:0] read_mem_bl;
    reg [7:0] read_mem_readadc_count;
    reg read_mem_instr_valid;
   
    //set reset is write mem 
    reg [7:0] set_reset_wl;
    reg [7:0] set_reset_bl;
    reg [7:0] set_reset_v_sel; //1f8
    reg [7:0] set_reset_v_bl;   //1f9 //setreset_mode == 01
    reg [7:0] set_reset_v_wl;   //1fa //setreset_mode != 01
    reg set_reset_instr_valid;
    reg [3:0] set_reset_dac_write_v_count;

    reg irq_ff;

    //}}}
    


    //}}}

    //assign
    //{{{


    //NPU_WRAP_config_data
    //{{{
    //0
    assign NPU_ARST_ENREG                      = NPU_WRAP_config_data[0][0];   
    assign NPU_ARST_WLREG                      = NPU_WRAP_config_data[0][1];        
    assign NPU_ASET_ENREG                      = NPU_WRAP_config_data[0][2]; 
    assign NPU_ASET_WLREG                      = NPU_WRAP_config_data[0][3];  
    assign NPU_WRAP_setreset_mode              = NPU_WRAP_config_data[0][5:4]; 
    assign NPU_WRAP_vmm_config_again_skip      = NPU_WRAP_config_data[0][6];
    assign NPU_DISCHG                          = NPU_WRAP_config_data[0][7];
    assign NPU_WRAP_disable_access_data_anytime= NPU_WRAP_config_data[0][8]; 
    //1 
    assign NPU_WRAP_WL_ST                      = NPU_WRAP_config_data[1][7 : 0]; 
    assign NPU_WRAP_WL_LEN                     = NPU_WRAP_config_data[1][15: 8]; 
    assign NPU_WRAP_BL_ST                      = NPU_WRAP_config_data[1][23:16]; 
    assign NPU_WRAP_BL_LEN                     = NPU_WRAP_config_data[1][31:24];
 
    //2
    assign NPU_WRAP_VMM_CONFIG_ST              = NPU_WRAP_config_data[2][7 : 0]; 
    assign NPU_WRAP_VMM_CONFIG_END             = NPU_WRAP_config_data[2][15: 8]; 
    assign NPU_WRAP_READ_MEM_CONFIG_ST         = NPU_WRAP_config_data[2][23:16]; 
    assign NPU_WRAP_READ_MEM_CONFIG_END        = NPU_WRAP_config_data[2][31:24]; 
    //3
    assign NPU_WRAP_SET_RESET_CONFIG_ST        = NPU_WRAP_config_data[3][7 : 0]; 
    assign NPU_WRAP_SET_RESET_CONFIG_END       = NPU_WRAP_config_data[3][15: 8]; 
    assign READADC_PRELOAD_COUNT_LIMIT_0       = NPU_WRAP_config_data[3][23: 16]; 
    assign READADC_PRELOAD_COUNT_LIMIT_1       = NPU_WRAP_config_data[3][31: 24]; 
    //4
    assign NPU_WRAP_pulse_width                = NPU_WRAP_config_data[4][15: 0]; 
    assign NPU_WRAP_WL_pulsewidth              = NPU_WRAP_config_data[4][31:16]; 
    //5
    assign NPU_WRAP_SEL_pulsewidth             = NPU_WRAP_config_data[5][15: 0]; 
    assign NPU_WRAP_TIA_pulsewidth             = NPU_WRAP_config_data[5][31:16]; 
    //6
    assign NPU_WRAP_WL_pulsewidth_read         = NPU_WRAP_config_data[6][15: 0]; 
    assign NPU_WRAP_SEL_pulsewidth_read        = NPU_WRAP_config_data[6][31:16]; 
    //7
    assign NPU_WRAP_TIA_pulsewidth_read        = NPU_WRAP_config_data[7][15: 0]; 
    assign NPU_WRAP_wlg_ctrl1                  = NPU_WRAP_config_data[7][23:16];
    assign READ_MEM_repeat_time                = NPU_WRAP_config_data[7][31:24];
 
    //8
    assign NPU_WRAP_adcrst1_delay              = NPU_WRAP_config_data[8][15: 0]; 
    assign NPU_WRAP_adcrst2_delay              = NPU_WRAP_config_data[8][31:16]; 

    //9
    assign READADC_PRELOAD_DAC_CONFIG_ST       = NPU_WRAP_config_data[9][7 : 0]; 
    assign READADC_PRELOAD_DAC_CONFIG_END      = NPU_WRAP_config_data[9][15: 8]; 
    assign SETDAC_INTERNAL_STATE_LIMIT_v2      = NPU_WRAP_config_data[9][19:16];
    assign SETDAC_INTERNAL_VALID_STATE_ST_v2   = NPU_WRAP_config_data[9][23:20];
    assign SETDAC_INTERNAL_VALID_STATE_END_v2  = NPU_WRAP_config_data[9][27:24];

    //10
    assign adc_first_delay_v2                  = NPU_WRAP_config_data[10][31:20]; //use READADC_PRELOAD_COUNT_LIMIT_0 + READADC_PRELOAD_COUNT_LIMIT_1 to replace it
    assign adc_high_period_v2                  = NPU_WRAP_config_data[10][19:8]; 
    assign adc_low_period_v2                   = NPU_WRAP_config_data[10][7:0];
    assign READADC_INTERNAL_STATE_LIMIT_v2      = adc_high_period_v2 + adc_low_period_v2;

    //11
    assign NPU_WRAP_WL_pulsewidth_set_st       = NPU_WRAP_config_data[11][15: 0];
    assign NPU_WRAP_WL_pulsewidth_set_end      = NPU_WRAP_config_data[11][31:16];

    //12
    assign NPU_WRAP_SEL_pulsewidth_set_st      = NPU_WRAP_config_data[12][15: 0];
    assign NPU_WRAP_SEL_pulsewidth_set_end     = NPU_WRAP_config_data[12][31:16];

    //13
    assign NPU_WRAP_BL_pulsewidth_set_st       = NPU_WRAP_config_data[13][15: 0];
    assign NPU_WRAP_BL_pulsewidth_set_end      = NPU_WRAP_config_data[13][31:16];

    //14
    assign VMM_start_addr                      = NPU_WRAP_config_data[NPU_WRAP_CONFIG_DATA_VMM_INST][7: 0];

    //31
    //CS
 
 
    assign NPU_WRAP_WL_END                     = NPU_WRAP_WL_ST + NPU_WRAP_WL_LEN;
    assign NPU_WRAP_BL_END                     = NPU_WRAP_BL_ST + NPU_WRAP_BL_LEN;

    assign NPU_WRAP_m1_pulsewidth              = (NPU_WRAP_WL_pulsewidth >= NPU_WRAP_SEL_pulsewidth) ? NPU_WRAP_WL_pulsewidth : NPU_WRAP_SEL_pulsewidth;
    assign NPU_WRAP_m2_pulsewidth              = (NPU_WRAP_TIA_pulsewidth >= NPU_WRAP_SEL_pulsewidth) ? NPU_WRAP_TIA_pulsewidth : NPU_WRAP_SEL_pulsewidth; 
    assign NPU_WRAP_vmm_pulsewidth             = (NPU_WRAP_m1_pulsewidth >= NPU_WRAP_m2_pulsewidth) ? NPU_WRAP_m1_pulsewidth : NPU_WRAP_m2_pulsewidth; 
    assign NPU_WRAP_WL_SWST                    = NPU_WRAP_vmm_pulsewidth - NPU_WRAP_WL_pulsewidth;
    assign NPU_WRAP_SEL_SWST                   = NPU_WRAP_vmm_pulsewidth - NPU_WRAP_SEL_pulsewidth;
    assign NPU_WRAP_TIA_SWST                   = NPU_WRAP_vmm_pulsewidth - NPU_WRAP_TIA_pulsewidth;
    
    assign NPU_WRAP_m1_pulsewidth_read         = (NPU_WRAP_WL_pulsewidth_read >= NPU_WRAP_SEL_pulsewidth_read) ? NPU_WRAP_WL_pulsewidth_read : NPU_WRAP_SEL_pulsewidth_read;
    assign NPU_WRAP_m2_pulsewidth_read         = (NPU_WRAP_TIA_pulsewidth_read >= NPU_WRAP_SEL_pulsewidth_read) ? NPU_WRAP_TIA_pulsewidth_read : NPU_WRAP_SEL_pulsewidth_read; 
    assign NPU_WRAP_read_pulsewidth            = (NPU_WRAP_m1_pulsewidth_read >= NPU_WRAP_m2_pulsewidth_read) ? NPU_WRAP_m1_pulsewidth_read : NPU_WRAP_m2_pulsewidth_read; 
    assign NPU_WRAP_WL_SWST_read               = NPU_WRAP_read_pulsewidth - NPU_WRAP_WL_pulsewidth_read;
    assign NPU_WRAP_SEL_SWST_read              = NPU_WRAP_read_pulsewidth - NPU_WRAP_SEL_pulsewidth_read;
    assign NPU_WRAP_TIA_SWST_read              = NPU_WRAP_read_pulsewidth - NPU_WRAP_TIA_pulsewidth_read;

    assign READADC_PRELOAD_DAC_CONFIG_LEN      = READADC_PRELOAD_DAC_CONFIG_END - READADC_PRELOAD_DAC_CONFIG_ST + 1;
    //}}}

 
    //assign  VMM_valid = (((VMM_input_indexer & VMM_input_counter) == VMM_input_indexer) && VMM_input_indexer != 256'b0 && NPU_WRAP_setreset_mode[1] == 1'b1) ? 1 : 0;
    assign  VMM_valid = NPU_WRAP_config_data[NPU_WRAP_CONFIG_DATA_VMM_INST][31:31];

    assign CS_ILA = CS;
    //assign irq_o = (CS == IDLE) ? 1 : 0;
    assign irq_o = (CS == IDLE) & ~irq_ff;
    //}}}








//AXI
`include "AXI.svh"

//data memory 
`include "Data_memory.svh"

//state machine
`include "state_machine.svh"

//NPU signals
`include "NPU_signals.svh"

//triggers
`include "triggers.svh"



endmodule
