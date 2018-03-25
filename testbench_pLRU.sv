
//-------------------------------------------
// Top level Test module
//  Includes all env component and sequences files 
//-------------------------------------------
`include "pLRU.v"

//--------------------------------------------------------
//Top level module that instantiates  just a physical apb interface
//No real DUT or APB slave as of now
//--------------------------------------------------------
module test;

	parameter SETWAY=4;		//"n"-way set
	parameter BITS_SETWAY=$clog2(SETWAY);	//Number of bits needed to represent ever line in a set

	logic [BITS_SETWAY-1:0] line_num;
	logic [SETWAY-2:0] bTree_in;
	logic [SETWAY-2:0] bTree;
	logic hit; 
	logic miss;
	logic [BITS_SETWAY:0] linesInSet_in;
	logic clk; 
	logic rst;
	logic [SETWAY-2:0] bTree_out;
	logic bTree_valid;
	logic [BITS_SETWAY-1:0] index_out;
	logic busy;

	logic [SETWAY-2:0] bTreeGold;
	logic [BITS_SETWAY-1:0]indexGold;

   initial begin
      clk=0;
   end

    //Generate a clock
   always begin
      forever #5 clk = ~clk;
   end
 
  //Attach VIF to actual DUT
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
				.busy(busy)); 


  initial begin
    for (int i = 0; i < 10000; i++) begin
		@(posedge clk) begin
			#1;
			if (bTree_valid === 1) begin
				//if (miss && !hit) begin
				//	indexGold = 0;
				//	for (int k = 0; k < 3; k++) begin
				//		if (bTreeGold[indexGold] == 0) begin
				//			bTreeGold[indexGold] = 1;
				//			indexGold = 2*indexGold + 1;
				//		end
				//		else begin
				//			bTreeGold[indexGold] = 0;
				//			indexGold = 2*indexGold + 2;
				//		end
				//	end
				//end
				//else if (hit && !miss) begin

				//end
				bTree = bTree_out;
			end
			//else begin
			//	bTree = bTree;
			//end
		end
	end
  end

  initial begin
		
	$display("Here2 %t",$time );
	#1 rst = 1; bTree = {{SETWAY-2}{1'b0}}; bTreeGold = {{SETWAY-2}{1'b0}};
	#6 rst = 0;

	#13 rst = 1;

    #10;

	for (int j = 0 ;j < 10000; j++) begin
		if (!busy) begin
			linesInSet_in = SETWAY; hit = $random(); miss = !hit; bTree_in = bTree; line_num = $random();//4 way associative - hit
		end
		#10;
	end

	//#10;
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
	#10000;
	$finish();
  end
  
  initial begin
    $dumpfile("dump_PLRU.vcd");
    $dumpvars(0, test);
  end  
  
endmodule
