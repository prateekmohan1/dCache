//------------------------------------
//mem (Advanced peripheral Bus) Interface 
//
//------------------------------------
`ifndef mem_IF_SV
`define mem_IF_SV

interface mem_if;

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
  logic if_clk;
  logic if_rst;

  logic [DATA_SIZE-1:0] if_data;


endinterface: mem_if

`endif
