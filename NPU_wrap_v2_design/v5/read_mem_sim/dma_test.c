#include "dma.h"
#include "npu.h"
#include "bench.h"
#include "pulpino.h"
#include "int.h"
#include "uart.h"
#include "utils.h"

int lock;


/////////////////////////////////////////////////////////////////////////////////////
//  1. This code will be trigured when there is an interrupt from DMA
//  2. It will do some work, now it is npu_write_mem, will be removed
//  3. Clear the event pending bit and disable the interrupt handler
/////////////////////////////////////////////////////////////////////////////////////
void ISR_DMA(void) {
//	npu_write_mem( 0,  0x00, 0xdeadbeef );	// Test use, will be removed
//	npu_write_mem( 0,  0x04, 0xfeed0000 );	// Test use, will be removed
	
	ECP = 0x1;	// Event clear pending 
	int_disable();

  	printf( "ISR_DMA \n" ); 
	uart_wait_tx_done();
	
	lock = 0;
}



/////////////////////////////////////////////////////////////////////////////////////
//  1. Initialize the memory in serial
//	2. Enable the DMA interrupt
//	3. Enable the DMA by writing to DMA registers, DMA will read data from DMA mem to NPU input
//	4. Read the NPU input area data in serial
/////////////////////////////////////////////////////////////////////////////////////
void test_DMA_NPU_INPUT() {
  	int i, j;

	unsigned int row, col;
	unsigned int addr;
	unsigned int data, data32;
	unsigned int res;

	// These program NPU config resiters. 
	// The values may need to be updated but do not impact correct toggling of signals
	npu_write_config( 0,  0x00, 0x0780ccff );
	npu_write_config( 0,  0x04, 0xf09fca80 );
	npu_write_config( 0,  0x08, 0x010301e7 ); 
	npu_write_config( 0,  0x0c, 0x00000000 );
	npu_write_config( 0,  0x10, 0x00300030 );
	npu_write_config( 0,  0x14, 0x00300030 );
	npu_write_config( 0,  0x18, 0x00300201 );
	npu_write_config( 0,  0x1c, 0x00023462 );
	npu_write_config( 0,  0x20, 0x02770000 );
	npu_write_config( 0,  0x24, 0x00300030 );
	npu_write_config( 0,  0x28, 0x000000ff );

	// These are 16 reset operations for different corner device
	// Reset operation is differentiated by SETRESET_MODE register; setreset_mode = config_data[2][25:24]; 
	// If == 0, do reset; if == 1, do set; 
	npu_write_mem( 0, 0x0000, 0xdeada0f0);
	npu_write_mem( 0, 0x0004, 0xdeadbeef);
	npu_write_mem( 0, 0x0008, 0xdeadbeef);
	npu_write_mem( 0, 0x000c, 0xdeadbeef);

	npu_write_mem( 0, 0x0400, 0xdeadbeef);
	npu_write_mem( 0, 0x0404, 0xdeadbeef);
	npu_write_mem( 0, 0x0408, 0xdeadbeef);
	npu_write_mem( 0, 0x040c, 0xdeadbeef);

	npu_write_mem( 0, 0x0800, 0xdeadbeef);
	npu_write_mem( 0, 0x0804, 0xdeadbeef);
	npu_write_mem( 0, 0x0808, 0xdeadbeef);
	npu_write_mem( 0, 0x080c, 0xdeadbeef);

	npu_write_mem( 0, 0x0c00, 0xdeadbeef);
	npu_write_mem( 0, 0x0c04, 0xdeadbeef);
	npu_write_mem( 0, 0x0c08, 0xdeadbeef);
	npu_write_mem( 0, 0x0c0c, 0xdeadbeef);

	// These are 16 read operations for the same device set above
	res = npu_read_mem(0, 0x0000);
	res = npu_read_mem(0, 0x0004);
	res = npu_read_mem(0, 0x0008);
	res = npu_read_mem(0, 0x000c);

	res = npu_read_mem(0, 0x0400);
	res = npu_read_mem(0, 0x0404);
	res = npu_read_mem(0, 0x0408);
	res = npu_read_mem(0, 0x040c);

	res = npu_read_mem(0, 0x0800);
	res = npu_read_mem(0, 0x0804);
	res = npu_read_mem(0, 0x0808);
	res = npu_read_mem(0, 0x080c);

	res = npu_read_mem(0, 0x0c00);
	res = npu_read_mem(0, 0x0c04);
	res = npu_read_mem(0, 0x0c08);
	res = npu_read_mem(0, 0x0c0c);

	// Change register to set mode
	npu_write_config( 0,  0x08, 0x020301e7 );

	// Do 16 set operations
	npu_write_mem( 0, 0x0000, 0xdeadc3f0);
	npu_write_mem( 0, 0x0004, 0xdeadbeef);
	npu_write_mem( 0, 0x0008, 0xdeadbeef);
	npu_write_mem( 0, 0x000c, 0xdeadbeef);

	npu_write_mem( 0, 0x0400, 0xdeadbeef);
	npu_write_mem( 0, 0x0404, 0xdeadbeef);
	npu_write_mem( 0, 0x0408, 0xdeadbeef);
	npu_write_mem( 0, 0x040c, 0xdeadbeef);

	npu_write_mem( 0, 0x0800, 0xdeadbeef);
	npu_write_mem( 0, 0x0804, 0xdeadbeef);
	npu_write_mem( 0, 0x0808, 0xdeadbeef);
	npu_write_mem( 0, 0x080c, 0xdeadbeef);

	npu_write_mem( 0, 0x0c00, 0xdeadbeef);
	npu_write_mem( 0, 0x0c04, 0xdeadbeef);
	npu_write_mem( 0, 0x0c08, 0xdeadbeef);
	npu_write_mem( 0, 0x0c0c, 0xdeadbeef);

	// Do 16 read operations for different set corners
	res = npu_read_mem(0, 0x0000);
	res = npu_read_mem(0, 0x0004);
	res = npu_read_mem(0, 0x0008);
	res = npu_read_mem(0, 0x000c);

	res = npu_read_mem(0, 0x0400);
	res = npu_read_mem(0, 0x0404);
	res = npu_read_mem(0, 0x0408);
	res = npu_read_mem(0, 0x040c);

	res = npu_read_mem(0, 0x0800);
	res = npu_read_mem(0, 0x0804);
	res = npu_read_mem(0, 0x0808);
	res = npu_read_mem(0, 0x080c);

	res = npu_read_mem(0, 0x0c00);
	res = npu_read_mem(0, 0x0c04);
	res = npu_read_mem(0, 0x0c08);
	res = npu_read_mem(0, 0x0c0c);

	// Use DMA to write to NPU input data
	write_dma_mem(0x00, 0xdeadbeef);
	write_dma_mem(0x04, 0xbeefdead);
	write_dma_mem(0x08, 0xdeaddead);
	write_dma_mem(0x0c, 0xdeaddead);
	write_dma_mem(0x10, 0xdeadbeef);
	write_dma_mem(0x14, 0xbeefdead);
	write_dma_mem(0x18, 0xdeaddead);
	write_dma_mem(0x1c, 0xdeaddead);
	write_dma_mem(0x20, 0xdeadbeef);
	write_dma_mem(0x24, 0xbeefdead);
	write_dma_mem(0x28, 0xdeaddead);
	write_dma_mem(0x2c, 0xdeaddead);
	write_dma_mem(0x30, 0xdeadbeef);
	write_dma_mem(0x34, 0xbeefdead);
	write_dma_mem(0x38, 0xdeaddead);
	write_dma_mem(0x3c, 0xdeaddead);
	write_dma_mem(0x40, 0xdeadbeef);
	write_dma_mem(0x44, 0xbeefdead);
	write_dma_mem(0x48, 0xdeaddead);
	write_dma_mem(0x4c, 0xdeaddead);
	write_dma_mem(0x50, 0xdeadbeef);
	write_dma_mem(0x54, 0xbeefdead);
	write_dma_mem(0x58, 0xdeaddead);
	write_dma_mem(0x5c, 0xdeaddead);
	write_dma_mem(0x60, 0xdeadbeef);
	write_dma_mem(0x64, 0xbeefdead);
	write_dma_mem(0x68, 0xdeaddead);
	write_dma_mem(0x6c, 0xdeaddead);
	write_dma_mem(0x70, 0xdeadbeef);
	write_dma_mem(0x74, 0xbeefdead);
	write_dma_mem(0x78, 0xdeaddead);
	write_dma_mem(0x7c, 0xdeaddead);
	write_dma_mem(0x80, 0xdeadbeef);
	write_dma_mem(0x84, 0xbeefdead);
	write_dma_mem(0x88, 0xdeaddead);
	write_dma_mem(0x8c, 0xdeaddead);
	write_dma_mem(0x90, 0xdeadbeef);
	write_dma_mem(0x94, 0xbeefdead);
	write_dma_mem(0x98, 0xdeaddead);
	write_dma_mem(0x9c, 0xdeaddead);
	write_dma_mem(0xa0, 0xdeadbeef);
	write_dma_mem(0xa4, 0xbeefdead);
	write_dma_mem(0xa8, 0xdeaddead);
	write_dma_mem(0xac, 0xdeaddead);
	write_dma_mem(0xb0, 0xdeadbeef);
	write_dma_mem(0xb4, 0xbeefdead);
	write_dma_mem(0xb8, 0xdeaddead);
	write_dma_mem(0xbc, 0xdeaddead);
	write_dma_mem(0xc0, 0xdeadbeef);
	write_dma_mem(0xc4, 0xbeefdead);
	write_dma_mem(0xc8, 0xdeaddead);
	write_dma_mem(0xcc, 0xdeaddead);
	write_dma_mem(0xd0, 0xdeadbeef);
	write_dma_mem(0xd4, 0xbeefdead);
	write_dma_mem(0xd8, 0xdeaddead);
	write_dma_mem(0xdc, 0xdeaddead);
	write_dma_mem(0xe0, 0xdeadbeef);
	write_dma_mem(0xe4, 0xbeefdead);
	write_dma_mem(0xe8, 0xdeaddead);
	write_dma_mem(0xec, 0xdeaddead);
	write_dma_mem(0xf0, 0xdeadbeef);
	write_dma_mem(0xf4, 0xbeefdead);
	write_dma_mem(0xf8, 0xdeaddead);
	write_dma_mem(0xfc, 0xdeaddead);


	// VMM operation
	set_dma_src_addr(  0x80000000 	);
	set_dma_dst_addr(  0x12000400	);
	set_dma_size(  0	);	//VMM_num -1
	set_dma_trigger();

	// Set skip_mode = 1, then do VMM skip mode operation
	npu_write_config( 0,  0x0c, 0x0001ffff );

	write_dma_mem(0, 0xdeadbeef);
	write_dma_mem(4, 0xbeefdead);
	write_dma_mem(8, 0xdeaddead);


	set_dma_src_addr(  0x80000000 	);
	set_dma_dst_addr(  0x12000400	);
	set_dma_size(  255	);	
	set_dma_trigger();

	data32 = get_dma_src_addr();
	print_int32( data32 );

	data32 = get_dma_dst_addr();
	print_int32( data32 );

	data32 = get_dma_size();
	print_int32( data32 );

/*
config_npu_vmm(
	int npu_index,
	int BL_start,
	int BL_end,
	int WL_start,
	int WL_end	
) {
	int data;
	npu_write_config(npu_index, 0x0c, BL_start<<? | BL_end<< ? | );
}
*/

/*
  	printf( "Start dump DMA_mem data \n" );
	addr = 0;
	for(addr=0; addr<256; ) {
		res = read_dma_mem(   addr );
		addr = addr + 4;

		print_int32( res );
	}
  	printf( "End dump DMA_mem data \n" );



  	printf( "Start dump Input data \n" );
	addr = 0;
	for(addr=0; addr<256; ) {
		res = npu_read_input( 0,  addr );
		addr = addr + 4;

		print_int32( res );
	}
  	printf( "End dump Input data \n" );
	  */

/*
  	printf( "P02\n" );
	set_dma_src_addr(  0x80000000 	);
	set_dma_dst_addr(  0x12000400	);
	set_dma_size(  255	);	
	set_dma_trigger();

  	printf( "Start dump Input data \n" );
	addr = 0;
	for(addr=0; addr<256; ) {
		res = npu_read_input( 0,  addr );
		addr = addr + 4;

		print_int32( res );
	}
  	printf( "End dump Input data \n" );



  	printf( "P03\n" );
	set_dma_src_addr(  0x80000000 	);
	set_dma_dst_addr(  0x12000400	);
	set_dma_size(  255	);	
	set_dma_trigger();

  	printf( "Start dump Input data \n" );
	addr = 0;
	for(addr=0; addr<256; ) {
		res = npu_read_input( 0,  addr );
		addr = addr + 4;

		print_int32( res );
	}
  	printf( "End dump Input data \n" );
*/
}



/////////////////////////////////////////////////////////////////////////////////////
//  1. Initialize the memory in serial
//	2. Enable the DMA interrupt
//	3. Enable the DMA by writing to DMA registers, DMA will read data from DMA mem to NPU output
//	4. Read the NPU output area data in serial
/////////////////////////////////////////////////////////////////////////////////////
void test_DMA_NPU_OUTPUT() {
  	int i, j;

	unsigned int row, col;
	unsigned int addr;
	unsigned int data, data32;
	unsigned int res;

/*
	addr = 0;
	data = 0;
	for(addr=0; addr<256; ) {
		data32 = ((data+3)<<24) | ((data+2)<<16) | ((data+1)<<8) | data;
		write_dma_mem(addr, data32);
		addr = addr + 4;
		data = data + 4;
	}
*/



	
	set_dma_src_addr(  0x80000000  	);
	set_dma_dst_addr(  0x12000800	);
	set_dma_size(  12-1	);	
	set_dma_trigger();




  	printf( "Start dump Output data \n" );
	uart_wait_tx_done();

	addr = 0;
	for(addr=0; addr<256; ) {
		res = npu_read_output( 0,  addr );
		addr = addr + 4;

		print_int32( res );
	}

  	printf( "End dump Output data \n" );
	uart_wait_tx_done();
}



/////////////////////////////////////////////////////////////////////////////////////
// 	1. Initialize DMA memory by writing to it in serial
//	2. Read the DMA memory in serial and display
/////////////////////////////////////////////////////////////////////////////////////
void test_DMA_mem() {
  	int i, j;

	unsigned int row, col;
	unsigned int addr;
	unsigned int data;
	unsigned int res;



	addr = 0;
	for(i=0; i<256; i++) {
		write_dma_mem(addr, 255-i);
		addr = addr + 4;
	}

  	printf( "Start dump data \n" );
	uart_wait_tx_done();

	addr = 0;

	for(i=0; i<256; i++) {
		res = read_dma_mem( addr );
		addr = addr + 4;

		print_int32( res );
	}

  	printf( "End dump data \n" );
	uart_wait_tx_done();
}


/////////////////////////////////////////////////////////////////////////////////////
// 	This program tests multiple parts of DMA/NPU
/////////////////////////////////////////////////////////////////////////////////////
void test_DMA_NPU() {
  	unsigned int i, j;

	unsigned int row, col;
	unsigned int res, addr, data, data32;

	addr = 0;
	data = 0;
	for(addr=0; addr<256; ) {
		data32 = ((data+3)<<24) | ((data+2)<<16) | ((data+1)<<8) | data;
		write_dma_mem(addr, data32);
		addr = addr + 4;
		data = data + 4;
	}

	lock = 1;

	// Interrupt settings
	ECP = 0xFFFFFFFF;	
	IER = 1 << 22;	// interrupt enable register	#define IER __PE__(REG_IRQ_ENABLE)
	int_enable();

	npu_write_config( 0,  0x00, 0x075c00ff );
	npu_write_config( 0,  0x04, 0x7f95bfdc );
	npu_write_config( 0,  0x08, 0x010304e7 ); 
	npu_write_config( 0,  0x0c, 0x00000007 );


	set_dma_src_addr(  0x80000000 );
	set_dma_dst_addr(  0x12000400 );
	set_dma_size(  255 	);		// Change to 64, which is the capacity
	set_dma_trigger();

	// while(lock) {;}

	set_dma_src_addr(  0x12000400 );
	set_dma_dst_addr(  0x12000800 );
	set_dma_size(  255 	);		// Change to 64, which is the capacity
	set_dma_trigger();


	uart_send( "P01\n", 4 ); 

	set_dma_src_addr(  0x12000400 );
	set_dma_dst_addr(  0x12000810 );
	set_dma_size(  7 	);		// Change to 64, which is the capacity
	set_dma_trigger();

	uart_send( "P02\n", 4 ); 

	set_dma_src_addr(  0x12000400 );
	set_dma_dst_addr(  0x12000820 );
	set_dma_size(  9 	);		// Change to 64, which is the capacity
	set_dma_trigger();

	uart_send( "P03\n", 4 ); 

	set_dma_src_addr(  0x12000400 );
	set_dma_dst_addr(  0x12000830 );
	set_dma_size(  10 	);		// Change to 64, which is the capacity
	set_dma_trigger();

	uart_send( "P04\n", 4 ); 

	uart_send( "Start dump Input data.\n", 23 ); 

	addr = 0;
	for(addr=0; addr<256; ) {
		res = npu_read_output( 0,  addr );
		addr = addr + 4;

		print_int32(res);
	}
	uart_send( "End dump Input data.\n", 21 ); 
}



/////////////////////////////////////////////////////////////////////////////////////
// 	This program initialize the memory, and then read the data one by one for verification
/////////////////////////////////////////////////////////////////////////////////////
void test_NPU_MEM() {
  	int i, j;

	unsigned int row, col;
	unsigned int addr;
	unsigned int data;
	unsigned int res;


	addr = 0;
	data = 0;
	for(i=0; i<256; i++) {
		npu_write_mem( 0, addr, data);
		addr = addr + 4;
		data = data + 1;
	}

	npu_write_mem( 0, 0, 1);
	npu_write_mem( 0, 256, 1);
	npu_write_mem( 0, 260, 1);

  	printf( "Start dump MEM data \n" );
	uart_wait_tx_done();

	addr = 0;
	for(i=0; i<256; i++) {
		res = npu_read_mem( 0, addr);
		addr = addr + 4;

		print_int32(res);
	}
  	printf( "End dump MEM data \n" );
	uart_wait_tx_done();


  	printf( "Start dump OUTPUT Data \n" );
	uart_wait_tx_done();

	addr = 0;
	for(i=0; i<32; i++) {
		res	= npu_read_output( 0,  addr );
		addr = addr + 1;

		print_int32(res);
	}
  	printf( "End dump OUTPUT Data \n" );
	uart_wait_tx_done();
}


int main() {
	init_npu_address();
	// 200,000,000/16 = 12,500,000/115200 = 108.51
  	
	// Comment this one for FPGA emulation
	//uart_set_cfg(0, 107);



	test_DMA_NPU_INPUT();
//	test_DMA_NPU_OUTPUT();
//	test_DMA_NPU();
//	test_NPU_MEM();
	return 0;
}
