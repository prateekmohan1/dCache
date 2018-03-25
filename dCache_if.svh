//------------------------------------
//dCache (Advanced peripheral Bus) Interface 
//
//------------------------------------
`ifndef dCache_IF_SV
`define dCache_IF_SV

interface dCache_if;

  parameter BLOCK_SIZE=10;
  parameter DATA_SIZE=32;
  parameter INDEX_SIZE=5;
  parameter TAG_SIZE=BLOCK_SIZE-INDEX_SIZE;
  parameter CACHE_ROWS=2**INDEX_SIZE;

  logic [BLOCK_SIZE-1:0] if_rdAddr;
  logic [BLOCK_SIZE-1:0] if_wrAddr;
  logic [DATA_SIZE-1:0] if_wrData;
  logic if_rdEn;
  logic if_wrEn;
  logic [DATA_SIZE-1:0] if_cacheMem_Out [CACHE_ROWS-1:0];
  logic [1:0] if_set_offset_Out;
  
  logic if_clk;
  logic if_rst;
  
  logic [DATA_SIZE-1:0] if_data;
  logic if_busy;
  logic if_valid;
  
  logic [BLOCK_SIZE-1:0] if_rdAddrMem;
  logic [BLOCK_SIZE-1:0] if_wrAddrMem;
  logic [BLOCK_SIZE-1:0] if_wrDataMem;
  logic if_rdEnMem;
  logic if_wrEnMem;
  logic [DATA_SIZE-1:0] if_dataMem;

endinterface: dCache_if

`endif
