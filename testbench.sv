
//-------------------------------------------
// Top level Test module
//  Includes all env component and sequences files 
//-------------------------------------------
 import uvm_pkg::*;
`include "uvm_macros.svh"

`include "dCache.v"
`include "pLRU.v"
`include "dCache_set.v"
`include "mem.v"
`include "dCache_if.svh"
`include "mem_if.svh"
`include "dCache_seq.svh"
`include "dCache_driver_seq_mon.svh"
`include "dCache_agent_env_config.svh"
`include "dCache_sequences.svh"
`include "dCache_test.svh"

//--------------------------------------------------------
//Top level module that instantiates  just a physical dCache interface
//No real DUT or dCache slave as of now
//--------------------------------------------------------
module test;

  import uvm_pkg::*;

  //Instantiate the dCache
  dCache_if dCachevif();

  //Instantiate the mem
  mem_if memvif();

  //Start the clock
  initial begin
    dCachevif.if_clk = 0;
    memvif.if_clk = 0;
  end

  //Generate the clock
  initial begin
    forever #5 dCachevif.if_clk = ~dCachevif.if_clk; memvif.if_clk = ~memvif.if_clk;
  end

  //Attach VIF to actual DUT
	dCache_set my_Cache(.rdAddr(dCachevif.if_rdAddr),
					.wrAddr(dCachevif.if_wrAddr),
					.wrData(dCachevif.if_wrData),
					.rdEn(dCachevif.if_rdEn),
					.wrEn(dCachevif.if_wrEn),
					.clk(dCachevif.if_clk),
					.rst(dCachevif.if_rst),
					.data(dCachevif.if_data),
					.rdAddrMem(dCachevif.if_rdAddrMem),
					.wrAddrMem(dCachevif.if_wrAddrMem),
					.wrDataMem(dCachevif.if_wrDataMem),
					.rdEnMem(dCachevif.if_rdEnMem),
					.wrEnMem(dCachevif.if_wrEnMem),
					.dataMem(dCachevif.if_dataMem),
					.busy (dCachevif.if_busy),
					.valid (dCachevif.if_valid),
					.cacheMem_Out (dCachevif.if_cacheMem_Out),
					.set_offset_Out(dCachevif.if_set_offset_Out)
					);

	mem my_mem(.rdAddr(dCachevif.if_rdAddrMem),
			   .wrAddr(dCachevif.if_wrAddrMem),
			   .wrData(dCachevif.if_wrDataMem),
			   .rdEn(dCachevif.if_rdEnMem),
			   .wrEn(dCachevif.if_wrEnMem),
			   .data(dCachevif.if_dataMem),
			   .clk(dCachevif.if_clk),
			   .rst(dCachevif.if_rst),
			   .data(memvif.if_data)
			  );

  initial begin


    //Start by filling up the memory
    $readmemh("mem_data.list", my_mem.mem_data);
    //$readmemh("cache_data.list", my_Cache.cacheMem);

    //Pass above physical interface to test top
    //(which will further pass it down to env->agent->drv/sqr/mon
    uvm_config_db#(virtual dCache_if)::set(uvm_root::get(), "uvm_test_top", "dCachevif", dCachevif);
    uvm_config_db#(virtual mem_if)::set(uvm_root::get(), "uvm_test_top", "memvif", memvif);
  
    //Call the run_test - but passing run_test argument as test class name
    run_test("dCache_base_test");
    $finish();
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0, test);
  end  

  
  //initial begin
		
//	#1 rst = 1;
//	#6 rst = 0;

//	#13 rst = 1;

//	#10;
	//for (int i = 0; i < 1000; i++) begin
	//	if (busy == 0) begin
	//		rdEn = $random();
	//		wrEn = !rdEn;
	//		wrAddr = $urandom%2048;
	//		rdAddr = $urandom%2048;
	//		wrData = $random();	
	//	end
	//	#10;
	//end
	

	//#4 rdEn = 0; wrEn = 1; wrAddr[31:8] = 4'b1111; wrAddr[7:0] = 3'b1011; wrData = 25;

	//#5 rdEn = 0; wrEn = 0;

	//#10 rdEn = 0; wrEn = 1; wrAddr = 352; wrData = 56;
	//#10 rdEn = 0; wrEn = 0;
	//#10 rdEn = 1; wrEn = 0; rdAddr = 265;
	//#10 rdEn = 0; wrEn = 0;
	//#10 rdEn = 0; wrEn = 1; wrAddr[31:8] = 4'b1111; wrAddr[7:0] = 3'b1011; wrData = 125;
	//#10 rdEn = 0; wrEn = 0;

	//$finish();
  //end
  
  //initial begin
  //  $dumpfile("dump.vcd");
  //  $dumpvars(0, test);
  //end  
  
endmodule
