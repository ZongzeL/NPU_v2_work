`timescale 1ns/1ns

//{{{
/*
    output [5:0] DOUT,
    input [7:0] DIN,
    input [8:0] ADDR,//v2_256
    input CLKDAC,
    input [3:0] CLKREG, // ring switch clk, v2_256
    input [3:0] DINSWREG, // ring switch data, v2_256
    input DACBL_SW, // BL overall sw, only SETRESET use it
    input DACBL_SW2, // TIA overall sw
    input DACSEL_SW, // SEL overall sw
    input DACWL_SW, // WL overall sw        
    input SET, // WL ground enable
    input RESET, // BL ground enable
    input CLKADCSW,
    input CLKADC,
    input DACWLREFSW, // WL voltage provider     
    
    input DISCHG,
    input ARST_ENREG,
    input ARST_WLREG,
    input ASET_ENREG,
    input ASET_WLREG,        
*/
//}}}

module NPU_v2_module #
(
    parameter MAX_NUM_BL = 256,
    parameter MAX_NUM_WL = 256,
    parameter INPUT_DATAWIDTH = 8,
    parameter OUTPUT_DATAWIDTH = 6,
    parameter RESET_VALUE = 0,
    parameter NUM_WL = 32,
    parameter NUM_BL = 32,
    parameter Q_INTERVAL = 906,
    parameter Q_DEDUCT = 0 // This is only used for simulation. The value can set in TB, not here.  
)
(
    input [7:0] DIN,
    input [8:0] ADDR,
    input CLKDAC,

    
    input CLKADC,
    output reg [5:0] DOUT,
    
    input SET, 
    input RESET, 

    input [3:0] CLKREG, // ring switch clk, v2_256
    input [3:0] DINSWREG, // ring switch data, v2_256
    input DACBL_SW, // BL overall sw, only SETRESET use it
    input DACBL_SW2, // TIA overall sw 
    input DACSEL_SW, // SEL overall sw
    input DACWL_SW, // WL overall sw        
    input CLKADCSW,
    input DACWLREFSW, // WL voltage provider     
    
    input DISCHG,
    input ARST_ENREG,
    input ARST_WLREG,
    input ASET_ENREG,
    input ASET_WLREG,        

    input [31:0] NPU_model_Q_values,

    input clk_all,
    input reset_all
);

    //parameter
    //{{{
    localparam OUTPUT_MAX = 2 ** OUTPUT_DATAWIDTH - 1;
 
    localparam DIN_ADDR_MIN = 0;
    localparam DIN_ADDR_MAX = MAX_NUM_WL - 1;
    
    localparam DOUT_ADDR_MIN = 0;
    localparam DOUT_ADDR_MAX = MAX_NUM_BL- 1;
    
    

    //calculation layers
    
    localparam MULTIPLY_LAYER_SIZE = 256; 
    localparam ADD_LAYER_0_SIZE = 64; 
    localparam ADD_LAYER_1_SIZE = 16;
    localparam ADD_LAYER_2_SIZE = 4; 
    //}}}

    //integer
    //{{{
    integer i, j;
    integer result_beforeQ;
    integer result_afterQ;
    integer weight_cal_WL_pos, weight_cal_BL_pos;
    genvar multiply_layer_i;
    //}}}    

    //reg
    //{{{
    reg [OUTPUT_DATAWIDTH - 1 : 0] Weight [MAX_NUM_WL - 1 : 0];
    reg [INPUT_DATAWIDTH - 1  : 0] Input_buffer [MAX_NUM_WL - 1 : 0];
    reg [INPUT_DATAWIDTH - 1 : 0] Config_Reg [MAX_NUM_WL - 1 : 0];
    reg [8:0] DIN_rec_count = 0; //count could be 256
    reg [8:0] DOUT_read_count; // if select 256 BL, counter must support 256

    reg [OUTPUT_DATAWIDTH - 1 : 0] Output_buffer [MAX_NUM_BL - 1 : 0];

    //WL BL select
    reg [MAX_NUM_WL - 1 : 0] WL_sel;
    reg [MAX_NUM_BL - 1 : 0] TIA_sel;
    reg [MAX_NUM_BL - 1 : 0] BL_sel;
        //CLKREG_0: WL, CLKREG_2: TIA, CLKREG_3: BL
    reg [7:0] DINSWREG_WL_count, DINSWREG_BL_count, DINSWREG_TIA_count;
    reg [7:0] DINSWREG_WL_count_tmp, DINSWREG_BL_count_tmp, DINSWREG_TIA_count_tmp;
    reg [8:0] WL_st,WL_end,BL_st,BL_end,TIA_st,TIA_end;
    
    reg set_reset_done;
    //}}}

    //wire
    //{{{
    wire CLKREG_WL    = CLKREG[0];
    wire CLKREG_TIA   = CLKREG[2];
    wire CLKREG_BL    = CLKREG[3];
    wire DINSWREG_WL  = DINSWREG[0];
    wire DINSWREG_TIA = DINSWREG[2];
    wire DINSWREG_BL  = DINSWREG[3];
    //}}}

    //assign
    //{{{
    //}}}


    `ifdef VCS_SIM 
        string tmp, s, tmp_beforeQ;
    `else
    `endif

//WL/BL/TIA select
//{{{
//BL是倒着设的。code上看，好像BL是正着的，但其实WL是先设255，后设0，但是BL是先设0后设255.

//This time can only select continuously WL and BL
//WL(0) 从255 到0反着推
//{{{
always @(posedge CLKREG_WL or negedge reset_all) begin
    if (reset_all == RESET_VALUE) begin
        //TODO, need a no reset but reconfig WL/BL, count reset feature
        //If controller's max_num_wl == 256, it will totally rise 256 times of CLKREG, so CLKREG_0_count will become 0.
        //But this is not safe.
        DINSWREG_WL_count = 0;
        DINSWREG_WL_count_tmp = 0;
        WL_st = 9'd256;
        WL_end = 9'd256;
    end
    else begin
        if (CLKREG_WL == 1) begin
            DINSWREG_WL_count_tmp = MAX_NUM_WL - 1 - DINSWREG_WL_count;
            WL_sel[DINSWREG_WL_count_tmp] = DINSWREG_WL;
            
            if (DINSWREG_WL_count == 0) begin //first one
                if (DINSWREG_WL == 1) begin 
                    //if first one is selected, set them as 255
                    WL_end  = DINSWREG_WL_count_tmp; //255
                    WL_st = DINSWREG_WL_count_tmp; //255
                end 
                else begin
                    WL_end  = 9'd256;
                    WL_st = 9'd256;
                end
            end
            else begin
                if (DINSWREG_WL == 1'b1) begin
                    if (WL_end == 9'd256) begin
                        WL_end  = DINSWREG_WL_count_tmp;
                    end
                    if (WL_st == 9'd256) begin
                        WL_st = DINSWREG_WL_count_tmp;
                    end
                    else begin 
                        //already start, counting.
                        WL_st = WL_st - 1;
                    end
                end
            end
            DINSWREG_WL_count = DINSWREG_WL_count + 1;
        end
    end
end
//}}}

//TIA(2) 从0 到255 正着推
//{{{
always @(posedge CLKREG_TIA or negedge reset_all) begin
    if (reset_all == RESET_VALUE) begin
        //TODO, need a no reset but reconfig TIA/BL, count reset feature
        //If controller's max_num_wl == 256, it will totally rise 256 times of CLKREG, so CLKREG_0_count will become 0.
        //But this is not safe.
        DINSWREG_TIA_count = 0;
        DINSWREG_TIA_count_tmp = 0;
        TIA_st = 9'd256;
        TIA_end = 9'd256;
    end
    else begin
        if (CLKREG_TIA == 1) begin
            DINSWREG_TIA_count_tmp = DINSWREG_TIA_count;
            TIA_sel[DINSWREG_TIA_count_tmp] = DINSWREG_TIA;
            
            if (DINSWREG_TIA_count == 0) begin //first one
                if (DINSWREG_TIA == 1) begin 
                    //if first one is selected, set them as 255
                    TIA_end  = DINSWREG_TIA_count_tmp; 
                    TIA_st = DINSWREG_TIA_count_tmp; 
                end 
                else begin
                    TIA_end  = 9'd256;
                    TIA_st = 9'd256;
                end
            end
            else begin
                if (DINSWREG_TIA == 1'b1) begin
                    if (TIA_end == 9'd256) begin
                        TIA_end  = DINSWREG_TIA_count_tmp;
                    end
                    if (TIA_st == 9'd256) begin
                        TIA_st = DINSWREG_TIA_count_tmp;
                    end
                    else begin 
                        //already start, counting.
                        TIA_end = TIA_end + 1;
                    end
                end
            end
            DINSWREG_TIA_count = DINSWREG_TIA_count + 1;
        end
    end
end
//}}}

//BL(3) 255到0 反着推（不同TIA，同WL）
//{{{
always @(posedge CLKREG_BL or negedge reset_all) begin
    if (reset_all == RESET_VALUE) begin
        //TODO, need a no reset but reconfig BL/BL, count reset feature
        //If controller's max_num_wl == 256, it will totally rise 256 times of CLKREG, so CLKREG_0_count will become 0.
        //But this is not safe.
        DINSWREG_BL_count = 0;
        DINSWREG_BL_count_tmp = 0;
        BL_st = 9'd256;
        BL_end = 9'd256;
    end
    else begin
        if (CLKREG_BL == 1) begin
            DINSWREG_BL_count_tmp = MAX_NUM_BL - 1 - DINSWREG_BL_count;
            BL_sel[DINSWREG_BL_count_tmp] = DINSWREG_BL;
            
            if (DINSWREG_BL_count == 0) begin //first one
                if (DINSWREG_BL == 1) begin 
                    //if first one is selected, set them as 255
                    BL_end  = DINSWREG_BL_count_tmp;
                    BL_st = DINSWREG_BL_count_tmp; 
                end 
                else begin
                    BL_end  = 9'd256;
                    BL_st = 9'd256;
                end
            end
            else begin
                if (DINSWREG_BL == 1'b1) begin
                    if (BL_end == 9'd256) begin
                        BL_end  = DINSWREG_BL_count_tmp;
                    end
                    if (BL_st == 9'd256) begin
                        BL_st = DINSWREG_BL_count_tmp;
                    end
                    else begin 
                        //already start, counting.
                        BL_end = BL_end + 1;
                    end
                end
            end
            DINSWREG_BL_count = DINSWREG_BL_count + 1;
        end
    end
end
//}}}

always @(posedge DACBL_SW2) begin
    if (DACBL_SW2 == 1) begin
        `ifdef VCS_SIM  begin
            $display ("DACTIA WL_sel: %h, WL_st: %h, WL_end: %h", WL_sel, WL_st, WL_end); 
            $display ("DACTIA TIA_sel: %h, TIA_st: %h, TIA_end: %h", TIA_sel, TIA_st, TIA_end); 
        end
        `endif
    end
end

always @(posedge SET or posedge RESET) begin
    //if (NPU_DACTIA_SW == 1 && DIN_rec_count != 0) begin
    if (SET == 1 || RESET == 1) begin
        //NPU_DACTIA_SW == 1 means reading dout time
        `ifdef VCS_SIM  begin
            $display ("SET RESET WL_sel: %h, WL_st: %h, WL_end: %h", WL_sel, WL_st, WL_end); 
            $display ("SET RESET BL_sel: %h, BL_st: %h, BL_end: %h", BL_sel, BL_st, BL_end); 
        end
        `endif
    end
end
//}}}

//Input receive
//{{{
always @(posedge CLKDAC or negedge reset_all) begin
    if (reset_all == RESET_VALUE) begin
        for (i = 0; i < MAX_NUM_WL; i = i + 1) begin
            Input_buffer[i] = 7;
        end
    end
    else if (CLKDAC == 1 && ADDR <= DIN_ADDR_MAX && ADDR >= DIN_ADDR_MIN) begin
        //Data
        Input_buffer [ADDR] = DIN[7:0];
    end
    else if (CLKDAC == 1 && ADDR[8] == 1) begin
        Config_Reg [ADDR[7:0]] = DIN[7:0];
    end
end
//}}}

//DIN receive counter
//{{{ 
//TODO
//Now, the DIN_rec_count reset to 0 condition is CLKADC rise. Means when outside request read DOUT, the DIN_rec_count can reset to 0.
//I am not sure if this is correct, but this is the only solution I can find.
//Do not use posedge of DACBL_SW2 to reset DIN_rec_count, because DACBL_SW2 is the tragger of doing calculation.
//The DIN_rec_count is a very important reference to do calculation. If reset it to 0, module will not do calculation any more.
always @(CLKDAC or CLKADC) begin
    if (CLKADC == 1 && CLKDAC == 0) begin
        //This is output section, reset count
        DIN_rec_count = 0;
    end
    else if (CLKDAC == 1 && CLKADC == 0 && ADDR <= DIN_ADDR_MAX && ADDR >= DIN_ADDR_MIN) begin
        DIN_rec_count = DIN_rec_count + 1;
    end
end
//}}}

//DOUT read counter
//{{{
always @(CLKADC or CLKDAC) begin
    if (CLKADC == 0 && CLKDAC == 1) begin
        //This is input section, reset count
        DOUT_read_count  = 0;
    end
    else if (CLKADC == 1 && CLKDAC == 0 && ADDR <= DOUT_ADDR_MAX && ADDR >= DOUT_ADDR_MIN) begin
        DOUT_read_count = DOUT_read_count + 1;
    end
end
//}}}

//DOUT
//{{{
always @(CLKADC) begin
    if ((CLKADC == 1 || CLKADCSW) && ADDR <= DOUT_ADDR_MAX && ADDR >= DOUT_ADDR_MIN) begin
        //DOUT = Output_buffer[ADDR][5:0];
        DOUT = Weight[ADDR];
    end
    //文博说config读不出来，这段代码暂留
    /*
    else if (CLKADC == 1 && ADDR[8] == 1) begin
        //Config, ADDR 第9bit == 1
        DOUT = {24'b0, Config_Reg[ADDR[7:0]]};
    end
    */
    else begin
        DOUT = 8'b0;
    end
end
//}}}

//Calculation
//{{{
always @(negedge reset_all or posedge clk_all)  begin
    if (reset_all == RESET_VALUE) begin
        for (i = 0; i < MAX_NUM_BL; i = i + 1) begin 
            Output_buffer[i] <= 6'd5;
        end
    end
    else begin
        if (DACBL_SW2 == 1) begin
            //this is only an SV style code, not suitable for synthesis!
            for (i = TIA_st; i <= TIA_end; i = i + 1) begin
                //Output_buffer[i] <= Weight[i] + Input_buffer[i];
                Output_buffer[i] <= Weight[i];
            end
        end
    end
end
//}}}

//Weight_load
//{{{
always @(negedge reset_all or posedge clk_all) begin
    if (reset_all == RESET_VALUE) begin
        //$readmemh(weight_file, Weight);
        for (i = 0; i < MAX_NUM_WL; i = i + 1) begin
            Weight[i] = 6'd4;
        end
        set_reset_done <= 0;
    end
    else begin
        if (DACBL_SW == 1) begin
            if (set_reset_done == 0) begin
                if (SET == 1 && Weight[BL_st] != 8'hff) begin
                    Weight[BL_st] = Weight[BL_st] + 1;

                end
                else if (RESET == 1 && Weight[BL_st] != 8'h00) begin
                    Weight[BL_st] = Weight[BL_st] - 1;
                end
                set_reset_done <= 1;
            end
        end
        else begin
            set_reset_done <= 0;
        end
    end
end
//}}}

endmodule
