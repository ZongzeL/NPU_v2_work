
`timescale 1 ns / 1 ps

module NPU_v2_wrap_mingyi_gen #
(
    //important parameters
	parameter integer AXI_ID_WIDTH	= 1,
	parameter integer AXI_DATA_WIDTH	= 32,
    parameter integer ADDR_BYTE_OFFSET = AXI_DATA_WIDTH / 8,
    parameter integer AXI_STRB_WIDTH        = AXI_DATA_WIDTH/8,
	parameter integer AXI_ADDR_WIDTH	= 16, 
    parameter integer AXI_USER_WIDTH        = 10,
    parameter integer CONFIG_LENGTH    = 32,
    parameter integer DATA_LENGTH    = 64,
    parameter integer STATUS_LENGTH    = 32,
    parameter integer CONTROL_LENGTH    = 16,

    //calculated parameters
    parameter integer ADDR_LSB = $clog2(ADDR_BYTE_OFFSET), //2
 
    parameter AXI_BASE_ADDR     = 32'h00000000,
    parameter NPU_CORE_CONFIG_ADDR_ST     = AXI_BASE_ADDR,
    parameter NPU_WRAP_CONFIG_ADDR_ST     = AXI_BASE_ADDR + 'h200,
    parameter NPU_WRAP_CONTROL_ADDR_ST     = AXI_BASE_ADDR + 'h300,
    parameter AXI_OUT_DATA_ADDR_ST   = AXI_BASE_ADDR + 'h400,
   
    parameter WLBL_LENGTH = 256,
 
    parameter TB_RESET_VALUE = 0

)
(
    input wire  clk,
	input wire  rst_n,
   
 
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

    output wire [3:0] CS_ILA,
    output wire [15:0] dac_adc_internal_state_ILA,

    //NPU v2 signals
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
    output reg DACWLREFSW, // WL voltage provider     
    
    output wire DISCHG,
    output wire ARST_ENREG,
    output wire ARST_WLREG,
    output wire ASET_ENREG,
    output wire ASET_WLREG   
    //}}}
   
     

); 

    //integer
    integer i;



    //localparam
    localparam IDLE = 4'b0;
    localparam DAC_CONFIG = 4'd1;
    localparam DAC_SRREF_V = 4'd2;
    localparam START = 4'd3; //single point single opt start
    localparam SETSW = 4'd5;
    localparam APPLY_V = 4'd6;
    localparam FINISH = 4'd7; //single point single opt finish
    localparam ADC_KERNEL = 4'd8; 


 
    localparam RUN_SET   = 2'b00;
    localparam RUN_RESET = 2'b01;
    localparam RUN_READMEM = 2'b10;
    
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

    wire [2:0] start_trigger;
    wire stop_trigger;

    //wire
    //NPU_WRAP_config
    //{{{ 
    //0
    
    //1
    wire [7:0] WL_ST; 
    wire [7:0] WL_END; 
    wire [7:0] BL_ST; 
    wire [7:0] BL_END; 
    //2
    wire [7:0]              NPU_WRAP_CONFIG_0_ST;
    wire [7:0]              NPU_WRAP_CONFIG_0_END;
    wire [7:0]              NPU_WRAP_CONFIG_1_ST;
    wire [7:0]              NPU_WRAP_CONFIG_1_END;
    //3
    wire [7:0]              NPU_WRAP_CONFIG_2_ST;
    wire [7:0]              NPU_WRAP_CONFIG_2_END;
    //wire [7:0]              NPU_WRAP_wlg_ctrl1;
    //wire [7:0]              READ_MEM_repeat_time;
    
    //4 is DISCHG, ARST_ENREG, ARST_WLREG, ASET_ENREG, ASET_WLREG

    //5
    wire [15:0]             NPU_WRAP_set_pulse_width;
    wire [15:0]             NPU_WRAP_reset_pulse_width;

    //6
    wire [15:0]             NPU_WRAP_WL_pulsewidth_set_st;
    wire [15:0]             NPU_WRAP_WL_pulsewidth_set_end;
    //7
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_set_st;
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_set_end;
    //8
    wire [15:0]             NPU_WRAP_BL_pulsewidth_set_st;
    wire [15:0]             NPU_WRAP_BL_pulsewidth_set_end;
    
    //9
    wire [15:0]             NPU_WRAP_WL_pulsewidth_reset_st;
    wire [15:0]             NPU_WRAP_WL_pulsewidth_reset_end;
    //10
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_reset_st;
    wire [15:0]             NPU_WRAP_SEL_pulsewidth_reset_end;
    //11
    wire [15:0]             NPU_WRAP_BL_pulsewidth_reset_st;
    wire [15:0]             NPU_WRAP_BL_pulsewidth_reset_end;

    //12
    wire [3:0]              SETDAC_INTERNAL_STATE_LIMIT;
    wire [3:0]              SETDAC_INTERNAL_VALID_STATE_ST; //which state rise DAC
    wire [3:0]              SETDAC_INTERNAL_VALID_STATE_END; //which state rise DAC

    
    //13 
    wire [7:0]  reset_srref0; //1f8
    wire [7:0]  reset_srref1; //1f9
    wire [7:0]  reset_srref2; //1fa

    //14
    wire [1:0] single_point_opt_list[7:0]; //SET, RESET, READMEM, use two bits
    wire [2:0] L0_single_point_opt_loop; //loops in the opt_list, max = 7 (8)
    wire [1:0] current_opt;
    
    //15
    wire [31:0] L1_single_point_loop;
    
    //16
    wire [31:0] L4_whole_range_loop;
  
    //17 
    wire [15:0] NPU_WRAP_readmem_pulse_width;
    wire [15:0] NPU_WRAP_BL_pulsewidth_readmem_st;
    
    //18
    wire [15:0] NPU_WRAP_WL_pulsewidth_readmem_st;
    wire [15:0] NPU_WRAP_SEL_pulsewidth_readmem_st;
    
    //19
    wire [11:0] adc_first_delay;
    wire [11:0] adc_high_delay;
    wire [7:0]  adc_low_delay;

    //20 
    wire [7:0]  set_srref0; //1f8
    wire [7:0]  set_srref1; //1f9
    wire [7:0]  set_srref2; //1fa
    
    //21 
    wire [7:0]  readmem_srref0; //1f8
    wire [7:0]  readmem_srref1; //1f9
    wire [7:0]  readmem_srref2; //1fa


    //}}}



    //reg

    //state machine
    reg [3:0] CS;
    reg set_running;	
    reg reset_running;	
    reg read_mem_running;

    reg [2:0]  L0_single_point_opt_loop_pos; //level 0, L0_single_point_opt_loop
    reg [31:0] L1_single_point_loop_pos; //level 1, L1_single_point_loop
    reg [7:0]  L3_wl_pos; //WL_ST, WL_END
    reg [7:0]  L2_bl_pos; //BL_ST, BL_END
    reg [31:0] L4_whole_range_loop_pos; //level 5, L4_whole_range_loop_pos
    reg [31:0] CS_PASS;    
    reg [1:0] last_opt;
    reg [8:0] setsw_count;
    
    reg [15:0] pulse_count;


    reg [15:0] dac_adc_internal_state;    
    reg [7:0] dac_config_run_addr;
    reg [7:0] dac_config_end_addr;
    reg [3:0] readmem_adc_count;
 
    //config
    reg [AXI_DATA_WIDTH - 1 : 0] NPU_WRAP_config [CONFIG_LENGTH - 1 : 0];
    reg [AXI_DATA_WIDTH - 1 : 0] NPU_WRAP_control [CONTROL_LENGTH - 1 : 0];
    reg [AXI_DATA_WIDTH - 1 : 0] NPU_core_config [63 : 0];
    reg [AXI_DATA_WIDTH - 1 : 0] data_mem [DATA_LENGTH - 1 : 0];
   
    //NPU related
    //{{{
    reg [7:0] DIN_w;
    reg [8:0] ADDR_w;
    reg CLKDAC_w;

    reg CLKREG_w;
    reg DINSWREG_SEL_w;
    reg DINSWREG_BL_w;
    reg DINSWREG_WL_w;
    reg DINSWREG_TIA_w;

    reg DACBL_SW_w; 
    reg DACBL_SW2_w;
    reg DACSEL_SW_w;
    reg DACWL_SW_w; 
    reg SET_w; 
    reg RESET_w; 
    reg CLKADCSW_w;
    reg CLKADC_w;
    reg DACWLREFSW_w;      
    //}}}


    assign start_trigger[2:0] = NPU_WRAP_control[0][2:0];
    assign stop_trigger = NPU_WRAP_control[1][0:0];

    assign CS_ILA[3:0] = CS[3:0];
    assign dac_adc_internal_state_ILA[15:0] = dac_adc_internal_state[15:0];
 
    //assign
    //{{{ 
    //0
    
    //1
    assign WL_ST  = NPU_WRAP_config[1][7 : 0]; 
    assign WL_END = NPU_WRAP_config[1][15: 8]; 
    assign BL_ST  = NPU_WRAP_config[1][23:16]; 
    assign BL_END = NPU_WRAP_config[1][31:24]; 
    //2
    assign NPU_WRAP_CONFIG_0_ST         = NPU_WRAP_config[2][7 : 0];
    assign NPU_WRAP_CONFIG_0_END        = NPU_WRAP_config[2][15: 8];
    assign NPU_WRAP_CONFIG_1_ST         = NPU_WRAP_config[2][23:16];
    assign NPU_WRAP_CONFIG_1_END        = NPU_WRAP_config[2][31:24];
    //3
    assign NPU_WRAP_CONFIG_2_ST         = NPU_WRAP_config[3][7 : 0];
    assign NPU_WRAP_CONFIG_2_END        = NPU_WRAP_config[3][15: 8];
    
    //4
    assign DISCHG                       = NPU_WRAP_config[4][0 : 0];
    assign ARST_ENREG                   = NPU_WRAP_config[4][1 : 1];
    assign ARST_WLREG                   = NPU_WRAP_config[4][2 : 2];
    assign ASET_ENREG                   = NPU_WRAP_config[4][3 : 3];
    assign ASET_WLREG                   = NPU_WRAP_config[4][4 : 4];

    //5
    assign NPU_WRAP_set_pulse_width         = NPU_WRAP_config[5][15: 0];
    assign NPU_WRAP_reset_pulse_width       = NPU_WRAP_config[5][31: 16];

    //6
    assign NPU_WRAP_WL_pulsewidth_set_st    = NPU_WRAP_config[6][15:0];
    assign NPU_WRAP_WL_pulsewidth_set_end   = NPU_WRAP_config[6][31:16];
    //7
    assign NPU_WRAP_SEL_pulsewidth_set_st   = NPU_WRAP_config[7][15:0];
    assign NPU_WRAP_SEL_pulsewidth_set_end  = NPU_WRAP_config[7][31:16];
    //8
    assign NPU_WRAP_BL_pulsewidth_set_st    = NPU_WRAP_config[8][15:0];
    assign NPU_WRAP_BL_pulsewidth_set_end   = NPU_WRAP_config[8][31:16];
    
    //9
    assign NPU_WRAP_WL_pulsewidth_reset_st    = NPU_WRAP_config[9][15:0];
    assign NPU_WRAP_WL_pulsewidth_reset_end   = NPU_WRAP_config[9][31:16];
    //10
    assign NPU_WRAP_SEL_pulsewidth_reset_st   = NPU_WRAP_config[10][15:0];
    assign NPU_WRAP_SEL_pulsewidth_reset_end  = NPU_WRAP_config[10][31:16];
    //11
    assign NPU_WRAP_BL_pulsewidth_reset_st    = NPU_WRAP_config[11][15:0];
    assign NPU_WRAP_BL_pulsewidth_reset_end   = NPU_WRAP_config[11][31:16];

    //12 
    assign SETDAC_INTERNAL_STATE_LIMIT      = NPU_WRAP_config[12][3 : 0];
    assign SETDAC_INTERNAL_VALID_STATE_ST   = NPU_WRAP_config[12][7 : 4]; 
    assign SETDAC_INTERNAL_VALID_STATE_END  = NPU_WRAP_config[12][11: 8]; 

    //13
    assign reset_srref0                      = NPU_WRAP_config[13][7:0];
    assign reset_srref1                       = NPU_WRAP_config[13][15:8];
    assign reset_srref2                       = NPU_WRAP_config[13][23:16];


    //14
    assign single_point_opt_list[0][1:0]    = NPU_WRAP_config[14][1: 0];
    assign single_point_opt_list[1][1:0]    = NPU_WRAP_config[14][3: 2];
    assign single_point_opt_list[2][1:0]    = NPU_WRAP_config[14][5: 4];
    assign single_point_opt_list[3][1:0]    = NPU_WRAP_config[14][7: 6];
    assign single_point_opt_list[4][1:0]    = NPU_WRAP_config[14][9: 8];
    assign single_point_opt_list[5][1:0]    = NPU_WRAP_config[14][11:10];
    assign single_point_opt_list[6][1:0]    = NPU_WRAP_config[14][13:12];
    assign single_point_opt_list[7][1:0]    = NPU_WRAP_config[14][15:14];
    assign L0_single_point_opt_loop         = NPU_WRAP_config[14][18:16];

    assign current_opt[1:0]                 = single_point_opt_list[L0_single_point_opt_loop_pos][1:0];

    //15
    assign L1_single_point_loop             = NPU_WRAP_config[15][31:0];
    
    //16
    assign L4_whole_range_loop              = NPU_WRAP_config[16][31:0];
    
    //17
    assign NPU_WRAP_readmem_pulse_width[15:0] = (NPU_WRAP_config[17][15: 0] > NPU_WRAP_config[19][31:20]) ? NPU_WRAP_config[17][15: 0] : NPU_WRAP_config[19][31:20];
    assign NPU_WRAP_BL_pulsewidth_readmem_st= NPU_WRAP_config[17][31:16];
    //18
    assign NPU_WRAP_WL_pulsewidth_readmem_st    = NPU_WRAP_config[18][15:0];
    assign NPU_WRAP_SEL_pulsewidth_readmem_st   = NPU_WRAP_config[18][31:16];
    //19
    assign adc_first_delay                 = NPU_WRAP_config[19][31:20];
    assign adc_high_delay                  = NPU_WRAP_config[19][19:8];
    assign adc_low_delay                   = NPU_WRAP_config[19][7:0];
    //20
    assign set_srref0                       = NPU_WRAP_config[20][7:0];
    assign set_srref1                       = NPU_WRAP_config[20][15:8];
    assign set_srref2                       = NPU_WRAP_config[20][23:16];
    //21
    assign readmem_srref0                   = NPU_WRAP_config[21][7:0];
    assign readmem_srref1                   = NPU_WRAP_config[21][15:8];
    assign readmem_srref2                   = NPU_WRAP_config[21][23:16];


    //}}}




`include "AXI.svh"
`include "state_machine.svh"
`include "memory.svh"
`include "NPU_signals.svh"




endmodule
