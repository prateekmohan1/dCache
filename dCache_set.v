module dCache_set 
	#(parameter BLOCK_SIZE=10,
	parameter DATA_SIZE=32,
	parameter SETWAY=4,			//"n"-way set
	parameter SET_SIZE=3,		//Number of bits needed to represent total number of sets
	parameter NUM_SETS=2**SET_SIZE,		//Total number of sets
	parameter BITS_SETWAY=$clog2(SETWAY),
	parameter TAG_SIZE=BLOCK_SIZE-SET_SIZE,
	parameter CACHE_ROWS=SETWAY*(2**SET_SIZE))
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
	output logic valid,

	//To and From Memory
	output logic [BLOCK_SIZE-1:0] rdAddrMem,
	output logic [BLOCK_SIZE-1:0] wrAddrMem,
	output logic [BLOCK_SIZE-1:0] wrDataMem,
	output logic rdEnMem,
	output logic wrEnMem,
	input logic [DATA_SIZE-1:0] dataMem,
	output logic [DATA_SIZE-1:0] cacheMem_Out [CACHE_ROWS-1:0],
	output logic [BITS_SETWAY-1:0] set_offset_Out
		);


	//parameter BLOCK_SIZE=32; //For Address
	//parameter DATA_SIZE=32;
	//parameter SET_SIZE=8;
	//parameter TAG_SIZE=BLOCK_SIZE-SET_SIZE;
	//parameter CACHE_ROWS=2**SET_SIZE;

	//Initialize Memory
	logic [DATA_SIZE-1:0] cacheMem [CACHE_ROWS-1:0];

	//Initialize other data (tag, valid, dirty)
	//tag = 24 bits [25:2], valid = 1 bit [1], dirty = 1 bit [0]
	logic [TAG_SIZE-1+1+1:0] metadata [CACHE_ROWS-1:0];

	//Counter for misses
	logic [2:0] cnt_rdmiss, cnt_wrmiss;

	//Temp variables for tag and set_num
	logic [BITS_SETWAY-1:0] set_offset;			//This is needed to pick which line in the current set
	logic [SET_SIZE-1:0] set_num, set_num_r, set_num_w;
	logic [TAG_SIZE-1:0] tag, tag_r, tag_w;

	//PLRU tracker
	logic [SETWAY-2:0] bTree_PLRU [NUM_SETS-1:0];

	//Flop for holding writedata
	logic [DATA_SIZE-1:0] wrData_f;

	//Cache checks
	logic inCache_r, inCache_w;

	//Initialize States
	parameter SIZE = 4;
	parameter S0=4'b0000, S1=4'b0001, S2=4'b0010, S3=4'b0011, S4=4'b0100, S5=4'b0101, S6=4'b0110, S7=4'b0111, S8=4'b1000, S9=4'b1001, S10=4'b1010;

	assign cacheMem_Out = cacheMem;
	assign set_offset_Out = set_offset;

	//Next_State, Current state variable
	logic [SIZE-1:0] state;
	logic [SIZE-1:0] next_state;

	//PLRU elements
	logic [BITS_SETWAY-1:0] line_num;
	logic [SETWAY-2:0] bTree_in;
	logic hit; 
	logic miss;
	logic [BITS_SETWAY:0] linesInSet_in;
	logic [SETWAY-2:0] bTree_out;
	logic bTree_valid;
	logic [BITS_SETWAY-1:0] index_out;
	logic busy_PLRU;

	assign set_num_r = rdAddr[SET_SIZE-1:0];
	assign tag_r = rdAddr[BLOCK_SIZE-1:SET_SIZE];
	assign set_num_w = wrAddr[SET_SIZE-1:0];
	assign tag_w = wrAddr[BLOCK_SIZE-1:SET_SIZE];

	//Instntiate the PLRU 
    pLRU my_pLRU(.line_num(line_num),
				.bTree_in(bTree_in),
				.hit(hit),
				.miss(miss),
				.linesInSet_in(linesInSet_in),
				.clk(clk),
				.rst(rst),
				.bTree_out(bTree_out),
				.bTree_valid(bTree_valid),
				.index_out(index_out),
				.busy(busy_PLRU)); 


	assign linesInSet_in = SETWAY;

	//Outputs and flops
	always_ff @(posedge clk) begin
		if (~rst) begin
			cnt_rdmiss <= 5;
			cnt_wrmiss <= 5;
			bTree_PLRU[0] <= 0;
			bTree_PLRU[1] <= 0;
			bTree_PLRU[2] <= 0;
			bTree_PLRU[3] <= 0;
			bTree_PLRU[4] <= 0;
			bTree_PLRU[5] <= 0;
			bTree_PLRU[6] <= 0;
			bTree_PLRU[7] <= 0;
			valid <= 0;
		end
		else begin
			unique case (state)
			S0: begin
				cnt_rdmiss <= 5;
				cnt_wrmiss <= 5;
				set_num <= 0;
				tag <= 0;
				//Turn off the memory reads and writes
				wrEnMem <= 0;
				rdEnMem <= 0;
				valid <= 0;
				//Initialize the bTree to 0
				if (rdEn && !wrEn) begin
					set_num <= set_num_r;
					tag <= tag_r;
					rdAddrMem <= rdAddr;
				end	
				else if (wrEn && !rdEn) begin
					set_num <= set_num_w;
					tag <= tag_w;
					//wrAddrMem <= wrAddr;
				end

			end
			//S1: You have initiated a read
			S1: begin
				//Turn off the memory reads and writes
				wrEnMem <= 0;
				rdEnMem <= 0;
				//Initialize the counters
				cnt_rdmiss <= 5;
				cnt_wrmiss <= 5;
				//This stores the value of set_num and tag to be used in the future if needed
				//set_num <= set_num_r;
				//tag <= tag_r;
				valid <= 0;
				////Here, the set_num is occupied (ie. tag is not in cache) AND it's not dirty
				//if (inCache_r == 0 && metadata[{set_num_r}][0]!== 0) begin
				//	wrEnMem <= 0;
				//	rdEnMem <= 1;
				//	rdAddrMem <= rdAddr;
				//end
				////Here, the set_num is occupied (ie. tag is not in cache) and it is dirty
				//else if (inCache_r == 0 && metadata[{set_num_r}][0] === 0) begin
				//	wrEnMem <= 1;
				//	rdEnMem <= 0;
				//	//The Address sent is concatenation of metadata's tag and set_num
				//	wrAddrMem <= {metadata[{set_num_r}][TAG_SIZE-1+1+1:2], {set_num_r}};
				//	//The data sent is the current set_num's data
				//	wrDataMem <= cacheMem[{set_num_r}];
				//end
			end
			//S2: Here, you have finished going through all indices and you have not found an empty slot
			//	  So, you have to now go through the bTree and find an index to kick out
			S2: begin
				//You have to store the correct index to use for the future cycles, but you have to wait
				//until the PLRU has finished finding the index
				if (busy_PLRU == 0) begin
					if (metadata[{set_num, index_out}][0] === 1'b1) begin
						//Here, your index is dirty so you need to write it back to memory
						wrEnMem <= 1;
						rdEnMem <= 0;
						//The Address sent is concatenation of metadata's tag and set_num
						wrAddrMem <= {metadata[{set_num, index_out}][TAG_SIZE-1+1+1:2], {index_out}};
						//The data sent is the current set_num's data
						wrDataMem <= cacheMem[{set_num, index_out}];
					end
					else begin
						wrEnMem <= 0;
						rdEnMem <= 1;
						//rdAddrMem <= rdAddrMem;
					end
					set_offset <= index_out;
					bTree_PLRU[set_num] <= bTree_out;
				end
				else begin
					set_offset <= set_offset;
				end
				valid <= 0;
				//if (cnt_rdmiss != 0) begin
				//	cnt_rdmiss <= cnt_rdmiss -  1;
				//	wrEnMem <= 0;
				//	rdEnMem <= 1;
				//	rdAddrMem <= rdAddrMem;
				//end
				//else begin
				//	//Here the count is finished, and the Memory has responded with the data
				//	//Populate Cache with the data retrieved from Memory
				//	cacheMem[{set_num}] <= dataMem;	
				//	//Populate metadata at the correct set_num with {tag,valid,dirty}
				//	metadata[{set_num}] <= {tag,1'b1,1'b0};
				//end
				//Make sure to keep supplying the correct address to the cacheMemory
			end
			//S3: Here, you have found the index, but it is not dirty so you do not have to write it to memory.
			//	  However, you have to read the index that you want from memory
			S3: begin
				if (cnt_rdmiss != 0) begin
					cnt_rdmiss <= cnt_rdmiss -  1;
					valid <= 0;
					wrEnMem <= 0;
					rdEnMem <= 1;
					rdAddrMem <= rdAddrMem;
				end
				else begin
					//Here the count is finished, and the Memory has responded with the data
					valid <= 1;
					//Populate Cache with the data retrieved from Memory
					cacheMem[{set_num, set_offset}] <= dataMem;	
					//Populate metadata at the correct set_num with {tag,valid,dirty}
					metadata[{set_num, set_offset}] <= {tag,1'b1,1'b0};
				end

				//set_num <= set_num_w;
				//tag <= tag_w;
				//wrData_f <= wrData;
				//// !(TAG DOESNT EXIST AND DIRTY), you c an just overwrite the current set_num
				//if ( !(metadata[{set_num_w}][TAG_SIZE-1+1+1:2] !== tag_w && metadata[{set_num_w}][0] === 1) ) begin
				//	cacheMem[{set_num_w}] <= wrData;
				//	//You have to set the tag, valid; it is dirty if it was not x's before
				//	if (metadata[{set_num_w}][0] !== 1'bx) begin
				//		metadata[{set_num_w}] <= {tag_w,2'b11}; 
				//	end
				//	else begin
				//		metadata[{set_num_w}] <= {tag_w,2'b10}; 
				//	end	
				//end
				//else begin
				//	//Here, you need to store the current data into memory
				//	wrEnMem <= 1;
				//	rdEnMem <= 0;
				//	wrAddrMem <= {metadata[{set_num_w}][TAG_SIZE-1+1+1:2], {set_num_w}};
				//	wrDataMem <= cacheMem[{set_num_w}];
				//end
			end
			//S4: The data you need to write to needs to be written back to cache
			S4: begin
				//Turn off the memory reads and writes
				wrEnMem <= 0;
				rdEnMem <= 0;
				valid <= 0;
				//Initialize the counters
				cnt_rdmiss <= 5;
				cnt_wrmiss <= 5;
				//This stores the value of set_num and tag to be used in the future if needed
				//set_num <= set_num_w;
				//tag <= tag_w;

				wrData_f <= wrData;

				if (metadata[{set_num,2'b00}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b00}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
					//Here, you have a hit on the index or the index is empty
					cacheMem[{set_num, 2'b00}] <= wrData;

					metadata[{set_num, 2'b00}] <= {tag,2'b11}; 
				end
				else if (metadata[{set_num,2'b01}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b01}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
					//Here, you have a hit on the index or the index is empty
					cacheMem[{set_num, 2'b01}] <= wrData;

					metadata[{set_num, 2'b01}] <= {tag,2'b11}; 
				end
				else if (metadata[{set_num,2'b10}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b10}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
					//Here, you have a hit on the index or the index is empty
					cacheMem[{set_num, 2'b10}] <= wrData;

					metadata[{set_num, 2'b10}] <= {tag,2'b11}; 
				end
				else if (metadata[{set_num,2'b11}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b11}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
					//Here, you have a hit on the index or the index is empty
					cacheMem[{set_num, 2'b11}] <= wrData;

					metadata[{set_num, 2'b11}] <= {tag,2'b11}; 
				end
				//if (cnt_wrmiss == 0) begin



				//if (cnt_wrmiss != 0) begin
				//	cnt_wrmiss <= cnt_wrmiss - 1;
				//	wrEnMem <= 1;
				//	rdEnMem <= 0;
				//	wrAddrMem <= wrAddrMem;
				//	wrDataMem <= cacheMem[{set_num}];
				//	wrData_f <= wrData_f;
				//end
				//else begin
				//	//Here, the memory has finished writing the dirty row sent by the cache into memory
				//	//Now, you need to overwrite the cache with the data that was sent
				//	cacheMem[{set_num}] <= wrData_f;
				//	metadata[{set_num}] <= {tag, 1'b1,1'b1};
				//	wrEnMem <= 0;
				//	rdEnMem <= 0;
				//end
			end
			//This is for a conflict dirty read miss - you have to write back data
			S5: begin
				//Here, you need to count down until you have written to cacheMemory 
				valid <= 0;
				if (cnt_wrmiss != 0) begin
					cnt_wrmiss <= cnt_wrmiss - 1;
					wrEnMem <= 1;
					rdEnMem <= 0;
					wrAddrMem <= wrAddrMem;
					wrDataMem <= cacheMem[{set_num, set_offset}];
				end
				else begin
					//Now that you have written it back to cacheMemory, you can remove the dirty bit in metadata
					metadata[{set_num, set_offset}] <= {metadata[{set_num, set_offset}][TAG_SIZE-1+1+1:1],1'b0};
					wrEnMem <= 0;
					rdEnMem <= 1;
					//rdAddrMem <= rdAddr;
				end
			end
			S6: begin
				if (busy_PLRU == 0) begin
					bTree_PLRU[set_num] <= bTree_out;
					valid <= 1;
					set_offset <= line_num;
				end
				else begin
					bTree_PLRU[set_num] <= bTree_PLRU[set_num];
				end
			end
			S7: begin
				if (busy_PLRU == 0) begin
					bTree_PLRU[set_num] <= bTree_out;
					valid <= 1;
					set_offset <= line_num;
				end
				else begin
					bTree_PLRU[set_num] <= bTree_PLRU[set_num];
				end
			end
			S8: begin
				//You have to store the correct index to use for the future cycles, but you have to wait
				//until the PLRU has finished finding the index
				valid <= 0;
				if (busy_PLRU == 0) begin

					if (metadata[{set_num, index_out}][0] === 1'b1) begin
						//Here, your index is dirty so you need to write it back to memory
						wrEnMem <= 1;
						rdEnMem <= 0;
						//The Address sent is concatenation of metadata's tag and set_num
						wrAddrMem <= {metadata[{set_num, index_out}][TAG_SIZE-1+1+1:2], {index_out}};
						//The data sent is the current set_num's data
						wrDataMem <= cacheMem[{set_num, index_out}];
					end

					set_offset <= index_out;
				end
				else begin
					set_offset <= set_offset;
				end
			end
			S9: begin
				if (cnt_wrmiss != 0) begin
					cnt_wrmiss <= cnt_wrmiss - 1;
					valid <= 0;
					wrEnMem <= 1;
					rdEnMem <= 0;
					wrAddrMem <= wrAddrMem;
					wrDataMem <= cacheMem[{set_num, set_offset}];
				end
				else begin
					//Now that you have written it back to cacheMemory, you can overwrite the data 
					cacheMem[{set_num, set_offset}] <= wrData_f;
					valid <= 1;
					metadata[{set_num, set_offset}] <= {metadata[{set_num, set_offset}][TAG_SIZE-1+1+1:2],2'b11};
					wrEnMem <= 0;
					rdEnMem <= 0;
				end
			end
			S10: begin
				//Here, your set_offset is not dirty so you can just overwrite it
				cacheMem[{set_num, set_offset}] <= wrData_f;
				metadata[{set_num, set_offset}] <= {metadata[{set_num, set_offset}][TAG_SIZE-1+1+1:2],2'b11};
				valid <= 1;
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
			miss = 0;
			hit = 0;
			inCache_w = 0;
			if (rdEn && !wrEn) begin
				next_state = S1;	
			end	
			else if (wrEn && !rdEn) begin
				next_state = S4;
			end
			else begin
				next_state = S0;
			end
		end
		S1: begin
			//Check if the upper 24 bits of metadata's set_num is the tag and the data is valid
			if (metadata[{set_num,2'b00}][TAG_SIZE-1+1+1:2] === tag && metadata[{set_num,2'b00}][1] === 1) begin
				data = cacheMem[{set_num,2'b00}];
				inCache_r = 1;

				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b00;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S7;
				busy = 1;
				//busy = 0;
			end
			else if (metadata[{set_num,2'b01}][TAG_SIZE-1+1+1:2] === tag && metadata[{set_num,2'b01}][1] === 1) begin
				data = cacheMem[{set_num,2'b01}];
				inCache_r = 1;

				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b01;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S7;
				busy = 1;
				//busy = 0;
			end
			else if (metadata[{set_num,2'b10}][TAG_SIZE-1+1+1:2] === tag && metadata[{set_num,2'b10}][1] === 1) begin
				data = cacheMem[{set_num,2'b10}];
				inCache_r = 1;

				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b10;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S7;
				busy = 1;
				//busy = 0;
			end
			else if (metadata[{set_num,2'b11}][TAG_SIZE-1+1+1:2] === tag && metadata[{set_num,2'b11}][1] === 1) begin
				data = cacheMem[{set_num,2'b11}];
				inCache_r = 1;

				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b11;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S7;
				busy = 1;
				//busy = 0;
			end
			else begin
				//Here, you don't see the data in any of the 4 elements so there are two cases here:
				//i)  The indexes are all full, and you need to evict something
				//ii) There are empty spaces (the tag is xxxx)
				//You also need to delete one entry in the set
				busy = 1;
				inCache_r = 0;

				//LRU Method: PLRU 
				miss = 1;
				hit = 0;
				bTree_in = bTree_PLRU[set_num];				
				//line_num doesn't matter for misses
				line_num = 0;

				next_state = S2;

				//This is a miss, check if the block is dirty - if so, we need to write
				//if (metadata[{set_num}][0] === 1'b1) begin
				//	next_state = S5;
				//end
				//else begin
				//	//Here it's not dirty so we can just overwrite the current data
				//	next_state = S2;
				//end
				data = {DATA_SIZE{1'bx}};
			end
		end
		S2: begin
			busy = 1;
			//At ths point, you have established a miss on a read, so the bTreePLRU needs
			//to respond with an index
			if (busy_PLRU != 0) begin
				next_state = S2;
			end
			else begin
				//At this point, you have an index_out sent by the PLRU saying what to evict

				//You have to check if the current index is dirty. If so, you need to write
				//it to memory before you can use it
				if (metadata[{set_num, index_out}][0] === 1'b1) begin
					//Here, your index is dirty so you need to write it back to memory
					next_state = S5;
				end
				else begin
					next_state = S3;
				end

				//Turn off the PLRU
				miss = 0;
				hit = 0;

			end
			//if (cnt_rdmiss == 0) begin
			//	//At this point, the cacheMemory has put the correct data on the dataline for output
			//	//busy = 0;
			//	data = dataMem;
			//	next_state = S0;
			//end
			//else begin
			//	busy = 1;
			//	data = {DATA_SIZE{1'bx}};
			//	next_state = S2;
			//end
		end
		S3: begin
			if (cnt_rdmiss == 0) begin
				//At this point, the cacheMemory has put the correct data on the dataline for output
				//busy = 0;
				data = dataMem;
				next_state = S0;
			end
			else begin
				busy = 1;
				data = {DATA_SIZE{1'bx}};
				next_state = S3;
			end
			//data = {DATA_SIZE{1'bx}};
			//// (TAG DOESNT EXIST AND DIRTY)
			//if ( (metadata[{set_num_w}][TAG_SIZE-1+1+1:2] !== tag_w && metadata[{set_num_w}][0] === 1) ) begin
			//	//Here, you need to write back the current item to memory	
			//	next_state = S4;
			//	busy = 1;
			//end
			//else begin
			//	//In this case, you can just overwrite the current element
			//	next_state = S0;	
			//	//busy = 0;
			//end
		end
		S4: begin
			data = {DATA_SIZE{1'bx}};
			if (metadata[{set_num,2'b00}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b00}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
				//Here, you have a hit on the index or the index is empty

				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b00;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S6;
				busy = 1;
				//busy = 0;
				
			end
			else if (metadata[{set_num,2'b01}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b01}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
				//Here, you have a hit on the index or the index is empty
				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b01;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S6;
				busy = 1;
			end
			else if (metadata[{set_num,2'b10}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b10}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
				//Here, you have a hit on the index or the index is empty
				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b10;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S6;
				busy = 1;
			end
			else if (metadata[{set_num,2'b11}][TAG_SIZE-1+1+1:2] === tag || metadata[{set_num,2'b11}][TAG_SIZE-1+1+1:2] === {TAG_SIZE{1'bx}}) begin
				//Here, you have a hit on the index or the index is empty
				//The set_offset bits represent the index
				//LRU Method: PLRU 
				miss = 0;
				hit = 1;
				//line_num is set through set_offset
				line_num = 2'b11;
				bTree_in = bTree_PLRU[set_num];				

				next_state = S6;
				busy = 1;
			end
			else begin
				//At this point, all the entries in the set are full, so you need to find something to evict 

				busy = 1;
				//LRU Method: PLRU 
				miss = 1;
				hit = 0;
				bTree_in = bTree_PLRU[set_num];				
				//line_num doesn't matter for misses
				line_num = 0;

				next_state = S8;
			end
			//if (cnt_wrmiss == 0) begin
			//	next_state = S0;
			//	//busy = 0;
			//end
			//else begin
			//	busy = 1;
			//	next_state = S4;
			//end
		end
		S5: begin
			//Here, you went to read something and it wasn't in the cache so you want to evict something. 
			//You found out what that index was, but it was dirty so you need to write it to cache
			busy = 1;
			data = {DATA_SIZE{1'bx}};
			if (cnt_wrmiss == 0) begin
				//Here, you want to go back to S1 to read from cache again 
				next_state = S3;	
			end
			else begin
				next_state = S5;
			end
		end
		S6: begin
			//You are here because you found something to overwrite or write in the cache
			//Now, you have to wait until the bLRU is finished working (ie, flipping the necessary bits)	
			busy = 1;
			if (busy_PLRU != 0) begin
				next_state = S6;
			end
			else begin
				//bTree_PLRU[set_num] = bTree_out;
				next_state = S0;
				//Turn off the PLRU
				miss = 0;
				hit = 0;
			end
		end
		S7: begin
			//In this state, you have had a hit from a read , so you need to flip the 
			//bTree_PLRU bits for the hit that occurred
			data = data;
			busy = 1;
			if (busy_PLRU != 0) begin
				next_state = S7;
			end
			else begin
				//bTree_PLRU[set_num] = bTree_out;
				next_state = S0;
				//Turn off the PLRU
				miss = 0;
				hit = 0;
			end
		end
		S8: begin
			//You are in this state because you want to write, but all the spots in the set have been taken
			//So, you have to wait for the PLRU to send an index out to you
			if (busy_PLRU != 0) begin
				busy = 1;
				next_state = S8;
			end
			else begin
				//At this point, you have an index_out sent by the PLRU saying what to evict

				//You have to check if the current index is dirty. If so, you need to write
				//it to memory before you can use it
				if (metadata[{set_num, index_out}][0] === 1'b1) begin
					//Here, your index is dirty so you need to write it back to memory
					next_state = S9;
				end
				else begin
					next_state = S10;
				end
				//Turn off the PLRU
				miss = 0;
				hit = 0;
			end
		end
		S9: begin
			//Here, you need to write something to memory because your set is full 
			if (cnt_wrmiss == 0) begin
				next_state = S0;
				//busy = 0;
			end
			else begin
				busy = 1;
				next_state = S9;
			end
		end
		S10: begin
			//Here, you are just overwriting an index in a set, so you can just go to the next state
			busy = 1;
			next_state = S0;
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
endmodule: dCache_set
