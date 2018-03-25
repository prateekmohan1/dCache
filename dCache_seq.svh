//------------------------------------
// Basic dCache  Read/Write Transaction class definition
//  This transaction will be used by Sequences, Drivers and Monitors
//------------------------------------
`ifndef dCache_RW_SV
`define dCache_RW_SV



//dCache_rw sequence item derived from base uvm_sequence_item
class dCache_seq extends uvm_sequence_item;
 
  parameter BLOCK_SIZE=10;
  parameter DATA_SIZE=32;
  parameter INDEX_SIZE=5;
  parameter TAG_SIZE=BLOCK_SIZE-INDEX_SIZE;
  parameter CACHE_ROWS=2**INDEX_SIZE;
  parameter MEM_ROWS=2**BLOCK_SIZE;

  rand logic [BLOCK_SIZE-1:0] if_rdAddr;
  rand logic [BLOCK_SIZE-1:0] if_wrAddr;
  rand logic [DATA_SIZE-1:0] if_wrData;

  //This adds a constraint for the address
  constraint rdAddr_range { if_rdAddr inside {[0:MEM_ROWS-1]}; }
  constraint wrAddr_range { if_wrAddr inside {[0:MEM_ROWS-1]}; }
  constraint wrData_range { if_wrData inside {[0:100]}; }

  rand logic if_rdEn;
  logic if_wrEn;

  logic if_clk;
  logic if_rst;
  logic [DATA_SIZE-1:0] if_cacheMem_Out [CACHE_ROWS-1:0];
  logic [1:0] if_set_offset_Out;

  logic [DATA_SIZE-1:0] if_act_readData;

  logic [DATA_SIZE-1:0] if_data;
  logic if_busy;
  logic if_valid;

  //To and From Memory
  logic [BLOCK_SIZE-1:0] if_rdAddrMem;
  logic [BLOCK_SIZE-1:0] if_wrAddrMem;
  logic [DATA_SIZE-1:0] if_wrDataMem;
  logic if_rdEnMem;
  logic if_wrEnMem;
  logic [DATA_SIZE-1:0] if_dataMem; 

  //Register with factory for dynamic creation
  `uvm_object_utils(dCache_seq)
  
   function new (string name = "dCache_seq");
      super.new(name);
   endfunction

   //function bit do_compare (uvm_object rhs, uvm_comparer comparer);
   //  dCache_seq seq1;
   //  bit eq;

   //  if(!$cast(seq1, rhs)) `uvm_fatal("seq1ans1", "ILLEGAL do_compare() cast")
   //  eq = super.do_compare(rhs, comparer);
   //  eq &= (z === seq1.z);
   //  return(eq);
   //endfunction

   //function string convert2string();
   //  string s;
   //  s = super.convert2string();
   //  $sformat(s, "%s\n Type \t%0h\n Addr \t%0h\n Data \t%0h\n Rand \t%0h\n", s, addr, data, dCache_cmd);
   //  return s;
   //endfunction
  

endclass: dCache_seq

`endif
