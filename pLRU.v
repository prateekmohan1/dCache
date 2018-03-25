module pLRU 
	#(
	parameter SETWAY=4,		//"n"-way set
	parameter BITS_SETWAY=$clog2(SETWAY)	//Number of bits needed to represent ever line in a set
	)
	(
	input logic [BITS_SETWAY-1:0] line_num,
	input logic [SETWAY-2:0] bTree_in,
	input logic hit, 
	input logic miss,
	input logic [BITS_SETWAY:0] linesInSet_in,
	input logic clk, 
	input logic rst,
	output logic [SETWAY-2:0] bTree_out,
	output logic bTree_valid,
	output logic [BITS_SETWAY-1:0] index_out,
	output logic busy
		);

	//Initialize States
	parameter SIZE = 3;
	parameter S0=3'b000, S1=3'b001, S2=3'b010, S3=3'b011, S4=3'b100, S5=3'b101;

	//Next_State, Current state variable
	logic [SIZE-1:0] state;
	logic [SIZE-1:0] next_state;

	//Internal variable for bTree, setway
	logic [SETWAY-2:0] bTree;
	logic [BITS_SETWAY:0] linesInSet;

	//Temp variables for miss states
	logic [BITS_SETWAY-1:0] parent_pos;
	logic [BITS_SETWAY:0] cnt_track;

	//Temp variable for hit
	logic modCheck;

	always_ff @(posedge clk) begin
		if (~rst) begin
			bTree_valid <= 0;
			cnt_track <= 0;
			parent_pos <= 0;
			index_out <= 0;
			modCheck <= 0;
		end
		else begin
			unique case (state)
				S0: begin
					bTree_valid <= 0;
					cnt_track <= 0;
					parent_pos <= 0;	
					bTree <= bTree_in;
					linesInSet <= linesInSet_in;
					if (hit) begin
						parent_pos <= (line_num + linesInSet_in - 2) >> 1;
						modCheck <= (line_num + linesInSet_in - 2) % 2;
						//If the current values is pointing to the right and the hit index is on the right then flip
						if ((((line_num + linesInSet_in - 2) % 2) == 1) && (line_num % 2 == 1)) begin
							bTree[(line_num + linesInSet_in - 2) >> 1] <= 0;
						end
						//Otherwise, if my parent is pointing to the left and my line_num is on the left then flip
						else if ((((line_num + linesInSet_in - 2) % 2) == 0) && (line_num % 2 == 0)) begin
							bTree[(line_num + linesInSet_in - 2) >> 1] <= 1;
						end
					end
				end
				S1: begin
					//Here, you have a miss in the set so you need to choose something to evict
					if (bTree[parent_pos] === 0) begin
						if (linesInSet-1 > (2*parent_pos+1)) begin
							parent_pos <= 2*parent_pos + 1;
							//bTree[parent_pos] <= 1;
						end		
						cnt_track <= 2*parent_pos + 1;
							bTree[parent_pos] <= 1;
					end
					else if (bTree[parent_pos] === 1) begin
						if (linesInSet-1 > (2*parent_pos+2)) begin
							parent_pos <= 2*parent_pos + 2;
							//bTree[parent_pos] <= 0;
						end		
						cnt_track <= 2*parent_pos + 2;
							bTree[parent_pos] <= 0;
					end
					else begin
						if (linesInSet-1 > (2*parent_pos+1)) begin
							parent_pos <= 2*parent_pos + 1;
							//bTree[parent_pos] <= 1;
						end		
						cnt_track <= 2*parent_pos + 1;
							bTree[parent_pos] <= 1;
					end
				end
				S2: begin
					//Here, you have a hit so you need to traverse up the tree 
					parent_pos <= (parent_pos - 1) >> 1;
					modCheck <= (parent_pos - 1) % 2;
					//If your parent one above is pointing to right and your current parent is on the right then flip
					if ((parent_pos-1)%2 == 1 && (parent_pos % 2 == 0)) begin
						bTree[(parent_pos-1) >> 1] <= 0;
					end
					//If your parent one above is point to the left and your current parent is on the left
					else if ((parent_pos-1)%2 == 0 && (parent_pos % 2 == 1)) begin
						bTree[(parent_pos-1) >> 1] <= 1;
					end
				end
				S3: begin
					//At this point, the parent_pos is equal to the bit position of the parent 
					if (bTree[parent_pos] == 0) begin
						//Here, you want to kick out the left segment but your bTree[parent_pos] has
						//already been flipped to the right so you need to reverse it. Your '0' here 
						//means kick out the right, because the previous entry was kicking out the left
						index_out <= 2*parent_pos+2-linesInSet+1;
						//index_out <= 2*parent_pos+2-linesInSet;
						//bTree[parent_pos] <= 1;
					end
					else begin
						index_out <= 2*parent_pos+2-linesInSet;
						//index_out <= 2*parent_pos+2-linesInSet+1;
						//bTree[parent_pos] <= 0;
					end
					bTree_out <= bTree;
					bTree_valid <= 1;
				end
				S4: begin
					//At this point we have finished populating the bTree
					bTree_out <= bTree;
					bTree_valid <= 1;
				end
			endcase
		end
	end

	always_comb begin
		unique case (state)
		S0: begin
			busy = 0;
			if (miss & !hit) next_state = S1;
			else if (!miss & hit) next_state = S2;
			else next_state = S0;
		end
		S1: begin
			busy = 1;
			if (cnt_track >= (linesInSet-1)/2) begin
				next_state = S3;
			end
			else begin
				next_state = S1;
			end
		end
		S2: begin
			busy = 1;
			if (parent_pos == 1 || parent_pos == 2) begin
				next_state = S4;
			end
			else begin
				next_state = S2;
			end
		end
		S3: begin
			busy = 1;
			next_state = S0;
		end
		S4: begin
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
endmodule: pLRU
