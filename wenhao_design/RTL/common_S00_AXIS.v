
`timescale 1 ns / 1 ps

	module common_S00_AXIS #
	(
		// AXI4Stream Data Width
		parameter integer C_S_AXIS_TDATA_WIDTH = 8,
		// Total number of data
		parameter integer NUMBER_OF_INPUT_WORDS  = 128
	)
	(
		// Users ports
        output reg  [C_S_AXIS_TDATA_WIDTH * NUMBER_OF_INPUT_WORDS -1 : 0] data_received, 
        output reg writes_done,
        
		// AXI4Stream sink: Clock
		input wire  S_AXIS_ACLK,
		// AXI4Stream sink: Reset
		input wire  S_AXIS_ARESETN,
		// Ready to accept data in
		output wire  S_AXIS_TREADY,
		// Data in
		input wire [C_S_AXIS_TDATA_WIDTH-1 : 0] S_AXIS_TDATA,
		// Byte qualifier
		input wire [(C_S_AXIS_TDATA_WIDTH/8)-1 : 0] S_AXIS_TSTRB,
		// Indicates boundary of last packet
		input wire  S_AXIS_TLAST,
		// Data is in valid
		input wire  S_AXIS_TVALID
	);
	
	// function called clogb2 that returns an integer which has the 
	// value of the ceiling of the log base 2.
	function integer clogb2 (input integer bit_depth);
	  begin
	    for(clogb2=1; bit_depth>0; clogb2=clogb2+1) // clogb2 = 0 bad for the case NUM_OF_INPUT_WORDS = 1
	      bit_depth = bit_depth >> 1;
	  end
	endfunction

	// bit_num gives the minimum number of bits needed to address 'NUMBER_OF_INPUT_WORDS' size of FIFO.
	localparam bit_num  = clogb2(NUMBER_OF_INPUT_WORDS-1);
     
    // I/O Connections assignments	                 
	wire axis_tready;
	assign S_AXIS_TREADY = axis_tready;

	// FIFO write pointer
	reg [bit_num - 1:0] write_pointer;
	
    // State variable and states
    reg mst_exec_state;
	localparam [1:0] IDLE = 1'b0,        // Initial state, or idle state 
	                 WRITE_FIFO  = 1'b1; // Write to FIFO
 
	// Control state machine implementation
    always @(posedge S_AXIS_ACLK) 
    begin  
        if (!S_AXIS_ARESETN) 
            begin
                mst_exec_state <= IDLE;
            end
        else
            case (mst_exec_state)
                IDLE: // The sink starts accepting tdata when tvalid
                    if (S_AXIS_TVALID && (!writes_done))
                        begin
                            mst_exec_state <= WRITE_FIFO;
                        end
                    else
                        begin
                            mst_exec_state <= IDLE;
                        end
                WRITE_FIFO:    
                    if (writes_done)
                        begin
                            mst_exec_state <= IDLE;
                        end
                    else
                        begin
                            mst_exec_state <= WRITE_FIFO;
                        end
	    endcase
	end
	
	// AXI tready (to the sender) is 1 if (1) in writing (2) not filled with NUMBER_OF_INPUT_WORDS input words.
	assign axis_tready = ((mst_exec_state == WRITE_FIFO) && (!writes_done));
	
    // FIFO write enable generation
	wire fifo_wren;
	assign fifo_wren = S_AXIS_TVALID && axis_tready;
	
    // write_pointer and write_done flag control;
	always@(posedge S_AXIS_ACLK)
	begin
	  if(!S_AXIS_ARESETN)
	    begin
	      write_pointer <= 0;
	      writes_done <= 1'b0;
	    end  
	  else
	    if (write_pointer <= NUMBER_OF_INPUT_WORDS-1)
	      begin
	        if (fifo_wren) begin
	            write_pointer <= write_pointer + 1;
	            writes_done <= 1'b0;
	        end
            if (mst_exec_state == WRITE_FIFO) begin // Otherwise NUM_OF_INPUT_WORDS = 1 will flag "writes_done".
                if ((write_pointer == NUMBER_OF_INPUT_WORDS-1)|| S_AXIS_TLAST) begin
                    writes_done <= 1'b1;
                end
            end
	      end  
	end


	// FIFO copy
    always @( posedge S_AXIS_ACLK )
	begin
	  if (fifo_wren)
	    begin
	      data_received[ ((write_pointer + 1) * C_S_AXIS_TDATA_WIDTH -1) -: C_S_AXIS_TDATA_WIDTH] <= S_AXIS_TDATA;
	    end    
	end		

endmodule
