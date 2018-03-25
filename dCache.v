module dCache 
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
	output logic busy,

	//To and From Memory
	output logic [BLOCK_SIZE-1:0] rdAddrMem,
	output logic [BLOCK_SIZE-1:0] wrAddrMem,
	output logic [BLOCK_SIZE-1:0] wrDataMem,
	output logic rdEnMem,
	output logic wrEnMem,
	input logic [DATA_SIZE-1:0] dataMem
		);


	//parameter BLOCK_SIZE=32; //For Address
	//parameter DATA_SIZE=32;
	//parameter INDEX_SIZE=8;
	//parameter TAG_SIZE=BLOCK_SIZE-INDEX_SIZE;
	//parameter CACHE_ROWS=2**INDEX_SIZE;

	//Initialize Memory
	logic [DATA_SIZE-1:0] cacheMem [CACHE_ROWS-1:0];

	//Initialize other data (tag, valid, dirty)
	//tag = 24 bits [25:2], valid = 1 bit [1], dirty = 1 bit [0]
	logic [TAG_SIZE-1+1+1:0] metadata [CACHE_ROWS-1:0];

	//Counter for misses
	logic [2:0] cnt_rdmiss, cnt_wrmiss;

	//Temp variables for tag and index
	logic [INDEX_SIZE-1:0] index, index_r, index_w;
	logic [TAG_SIZE-1:0] tag, tag_r, tag_w;

	//Flop for holding writedata
	logic [DATA_SIZE-1:0] wrData_f;

	//Cache checks
	logic inCache_r, inCache_w;

	//Initialize States
	parameter SIZE = 3;
	parameter S0=3'b000, S1=3'b001, S2=3'b010, S3=3'b011, S4=3'b100, S5=3'b101;

	//Next_State, Current state variable
	logic [SIZE-1:0] state;
	logic [SIZE-1:0] next_state;

	assign index_r = rdAddr[INDEX_SIZE-1:0];
	assign tag_r = rdAddr[BLOCK_SIZE-1:INDEX_SIZE];
	assign index_w = wrAddr[INDEX_SIZE-1:0];
	assign tag_w = wrAddr[BLOCK_SIZE-1:INDEX_SIZE];

	//Outputs and flops
	always_ff @(posedge clk) begin
		if (~rst) begin
			cnt_rdmiss <= 5;
			cnt_wrmiss <= 5;
		end
		else begin
			unique case (state)
			S0: begin
				cnt_rdmiss <= 5;
				cnt_wrmiss <= 5;
				index <= 0;
				tag <= 0;
				//Turn off the memory reads and writes
				wrEnMem <= 0;
				rdEnMem <= 0;
			end
			//S1: You have initiated a read
			S1: begin
				//Turn off the memory reads and writes
				wrEnMem <= 0;
				rdEnMem <= 0;
				//Initialize the counters
				cnt_rdmiss <= 5;
				cnt_wrmiss <= 5;
				//This stores the value of index and tag to be used in the future if needed
				index <= index_r;
				tag <= tag_r;
				//Here, the index is occupied (ie. tag is not in cache) AND it's not dirty
				if (inCache_r == 0 && metadata[{index_r}][0]!== 0) begin
					wrEnMem <= 0;
					rdEnMem <= 1;
					rdAddrMem <= rdAddr;
				end
				//Here, the index is occupied (ie. tag is not in cache) and it is dirty
				else if (inCache_r == 0 && metadata[{index_r}][0] === 0) begin
					wrEnMem <= 1;
					rdEnMem <= 0;
					//The Address sent is concatenation of metadata's tag and index
					wrAddrMem <= {metadata[{index_r}][TAG_SIZE-1+1+1:2], {index_r}};
					//The data sent is the current index's data
					wrDataMem <= cacheMem[{index_r}];
				end
			end
			//S2: The data was not in the cache and the index you are replacing is not dirty
			S2: begin
				//Here, you need to count down until cacheMemory ahs given data, so you do so
				if (cnt_rdmiss != 0) begin
					cnt_rdmiss <= cnt_rdmiss -  1;
					wrEnMem <= 0;
					rdEnMem <= 1;
					rdAddrMem <= rdAddrMem;
				end
				else begin
					//Here the count is finished, and the Memory has responded with the data
					//Populate Cache with the data retrieved from Memory
					cacheMem[{index}] <= dataMem;	
					//Populate metadata at the correct index with {tag,valid,dirty}
					metadata[{index}] <= {tag,1'b1,1'b0};
				end
				//Make sure to keep supplying the correct address to the cacheMemory
			end
			//S3: You have initiated a write
			S3: begin
				index <= index_w;
				tag <= tag_w;
				wrData_f <= wrData;
				// !(TAG DOESNT EXIST AND DIRTY), you c an just overwrite the current index
				if ( !(metadata[{index_w}][TAG_SIZE-1+1+1:2] !== tag_w && metadata[{index_w}][0] === 1) ) begin
					cacheMem[{index_w}] <= wrData;
					//You have to set the tag, valid; it is dirty if it was not x's before
					if (metadata[{index_w}][0] !== 1'bx) begin
						metadata[{index_w}] <= {tag_w,2'b11}; 
					end
					else begin
						metadata[{index_w}] <= {tag_w,2'b10}; 
					end	
				end
				else begin
					//Here, you need to store the current data into memory
					wrEnMem <= 1;
					rdEnMem <= 0;
					wrAddrMem <= {metadata[{index_w}][TAG_SIZE-1+1+1:2], {index_w}};
					wrDataMem <= cacheMem[{index_w}];
				end
			end
			//S4: The data you need to write to needs to be written back to cache
			S4: begin
				if (cnt_wrmiss != 0) begin
					cnt_wrmiss <= cnt_wrmiss - 1;
					wrEnMem <= 1;
					rdEnMem <= 0;
					wrAddrMem <= wrAddrMem;
					wrDataMem <= cacheMem[{index}];
					wrData_f <= wrData_f;
				end
				else begin
					//Here, the memory has finished writing the dirty row sent by the cache into memory
					//Now, you need to overwrite the cache with the data that was sent
					cacheMem[{index}] <= wrData_f;
					metadata[{index}] <= {tag, 1'b1,1'b1};
					wrEnMem <= 0;
					rdEnMem <= 0;
				end
			end
			//This is for a conflict dirty read miss - you have to write back data
			S5: begin
				//Here, you need to count down until you have written to cacheMemory 
				if (cnt_wrmiss != 0) begin
					cnt_wrmiss <= cnt_wrmiss - 1;
					wrEnMem <= 1;
					rdEnMem <= 0;
					wrAddrMem <= wrAddrMem;
					wrDataMem <= cacheMem[{index}];
				end
				else begin
					//Now that you have written it back to cacheMemory, you can remove the dirty bit in metadata
					metadata[{index}] <= {metadata[{index}][TAG_SIZE-1+1+1:1],1'b0};
					wrEnMem <= 0;
					rdEnMem <= 0;
				end
			end
			endcase
		end
	end

	always_comb begin
		unique case (state)
		S0: begin
			data = {DATA_SIZE{1'bx}};
			busy = 0;
			inCache_r = 0;
			inCache_w = 0;
			if (rdEn && !wrEn) begin
				next_state = S1;	
			end	
			else if (wrEn && !rdEn) begin
				next_state = S3;
			end
			else begin
				next_state = S0;
			end
		end
		S1: begin
			//Check if the upper 24 bits of metadata's index is the tag and the data is valid
			if (metadata[{index_r}][TAG_SIZE-1+1+1:2] === tag_r && metadata[{index_r}][1] === 1) begin
				data = cacheMem[{index_r}];
				inCache_r = 1;
				next_state = S0;
				//busy = 0;
			end
			else begin
				busy = 1;
				inCache_r = 0;
				//This is a miss, check if the block is dirty - if so, we need to write
				if (metadata[{index_r}][0] === 1'b1) begin
					next_state = S5;
				end
				else begin
					//Here it's not dirty so we can just overwrite the current data
					next_state = S2;
				end
				data = {DATA_SIZE{1'bx}};
			end
		end
		S2: begin
			if (cnt_rdmiss == 0) begin
				//At this point, the cacheMemory has put the correct data on the dataline for output
				//busy = 0;
				data = dataMem;
				next_state = S0;
			end
			else begin
				busy = 1;
				data = {DATA_SIZE{1'bx}};
				next_state = S2;
			end
		end
		S3: begin
			data = {DATA_SIZE{1'bx}};
			// (TAG DOESNT EXIST AND DIRTY)
			if ( (metadata[{index_w}][TAG_SIZE-1+1+1:2] !== tag_w && metadata[{index_w}][0] === 1) ) begin
				//Here, you need to write back the current item to memory	
				next_state = S4;
				busy = 1;
			end
			else begin
				//In this case, you can just overwrite the current element
				next_state = S0;	
				//busy = 0;
			end
		end
		S4: begin
			data = {DATA_SIZE{1'bx}};
			if (cnt_wrmiss == 0) begin
				next_state = S0;
				//busy = 0;
			end
			else begin
				busy = 1;
				next_state = S4;
			end
		end
		S5: begin
			busy = 1;
			data = {DATA_SIZE{1'bx}};
			if (cnt_wrmiss == 0) begin
				//Here, you want to go back to S1 to read from cache again 
				next_state = S1;	
			end
			else begin
				next_state = S5;
			end
		end
		endcase
	end

    //Flip Flop for state
    always_ff @ (posedge clk) begin
        if (~rst) begin
            state <= S0;
        end
        else begin
            state <= next_state;
        end
    end

//Empty module
endmodule: dCache
