module mem 
	#(parameter BLOCK_SIZE=10,
	parameter DATA_SIZE=32,
	parameter INDEX_SIZE=5,
	parameter TAG_SIZE=BLOCK_SIZE-INDEX_SIZE,
	parameter CACHE_ROWS=2**INDEX_SIZE)
	(
	input logic [BLOCK_SIZE-1:0] rdAddr,
	input logic [BLOCK_SIZE-1:0] wrAddr,
	input logic [DATA_SIZE-1:0] wrData,
	input logic rdEn,
	input logic wrEn,

	input logic clk,
	input logic rst,

	output logic [DATA_SIZE-1:0] data,
	output logic [DATA_SIZE-1:0] mem_data_Out [2**BLOCK_SIZE-1:0]
		);

	//Initialize Memory
	logic [DATA_SIZE-1:0] mem_data [2**BLOCK_SIZE-1:0];

    //Flip Flop for state
    always_ff @ (posedge clk) begin
		if (wrEn) begin
			mem_data[wrAddr] <= wrData;
		end
    end

	always_comb begin
		if (rdEn) begin
			data = mem_data[rdAddr];
		end
	end

//Empty module
endmodule: mem
