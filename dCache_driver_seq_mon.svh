//----------------------------------------------------
// This file contains the dCache Driver, Sequencer and Monitor component classes defined
//----------------------------------------------------
`ifndef dCache_DRV_SEQ_MON_SV
`define dCache_DRV_SEQ_MON_SV

typedef dCache_config;
typedef dCache_agent;

//---------------------------------------------
// dCache master driver Class  
//---------------------------------------------
class dCache_master_drv extends uvm_driver#(dCache_seq);
  
  `uvm_component_utils(dCache_master_drv)
   
   virtual dCache_if dCachevif;
   dCache_config cfg;

   function new(string name,uvm_component parent = null);
      super.new(name,parent);
   endfunction

   //Build Phase
   //Get the virtual interface handle form the agent (parent ) or from config_db
   function void build_phase(uvm_phase phase);
     super.build_phase(phase);
     if(!uvm_config_db#(virtual dCache_if)::get(this,"","dCachevif",dCachevif)) begin
       `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
     end
   endfunction

  task pre_reset_phase(uvm_phase phase);
    phase.raise_objection(this);
    uvm_report_info(get_full_name(), "PRERESET_BEG", UVM_LOW);
    //uvm_report_info("CLK1", $sformatf("%0b", this.dCachevif.sig_clk));
    dCachevif.if_rst = 1'b1;
    #10;
    phase.drop_objection(this);
    uvm_report_info(get_full_name(), "PRERESET_END", UVM_LOW);
    //uvm_report_info("CLK2", $sformatf("%0b", this.dCachevif.sig_clk));
  endtask:pre_reset_phase
  
  task reset_phase(uvm_phase phase);
    phase.raise_objection(this);
    uvm_report_info(get_full_name(), "RESET_BEG", UVM_LOW);
    //uvm_report_info("CLK3", $sformatf("%0b", this.dCachevif.sig_clk));
    //uvm_report_info("ab_ready 1", $sformatf("%0b", this.dCachevif.sig_ab_ready));
    dCachevif.if_rst = 1'b0;
    #11;
    dCachevif.if_rst = 1'b1;
    //#6;
    //uvm_report_info("CLK4", $sformatf("%0b", this.dCachevif.sig_clk));
    //uvm_report_info("ab_ready 2", $sformatf("%0b", this.dCachevif.sig_ab_ready));
    phase.drop_objection(this);
    uvm_report_info(get_full_name(), "RESET_END", UVM_LOW);
  endtask:reset_phase
  
   //Run Phase
   //Implement the Driver -Sequencer API to get an item
   //Based on if it is Read/Write - drive on dCache interface the corresponding pins
   virtual task main_phase(uvm_phase phase);
     dCache_seq seq_item;
     int addr;
     addr = 0;
     super.run_phase(phase);
     forever begin
       phase.raise_objection( .obj( this ), .description( get_name() ) );
       //uvm_report_info(get_full_name(), "This is a Test.", UVM_LOW);
       
       //seq_item_port.get_next_item(seq_item);  //Communicates with the Sequencer

       
       //uvm_report_info(get_full_name(), "This is a Test 2.", UVM_LOW);
       //uvm_report_info("rdAddr", $sformatf("%0d", seq_item.if_rdAddr));
       //uvm_report_info("wrAddr", $sformatf("%0d", seq_item.if_wrAddr));
       //uvm_report_info("rd_En", $sformatf("%0d", seq_item.if_rdEn));
       //uvm_report_info("busy", $sformatf("%0d", dCachevif.if_busy));
       
       //uvm_report_info("CLK5", $sformatf("%0b", this.dCachevif.sig_clk));
      
	   @(posedge this.dCachevif.if_clk) 
	   begin 
	     if (!this.dCachevif.if_busy) 
	     begin
           seq_item_port.get_next_item(seq_item);  //Communicates with the Sequencer
	       this.dCachevif.if_rdAddr = seq_item.if_rdAddr;
	       //this.dCachevif.if_rdAddr = addr;
	       this.dCachevif.if_wrAddr = seq_item.if_wrAddr;
	       this.dCachevif.if_wrData = seq_item.if_wrData;
	       //this.dCachevif.if_rdEn = seq_item.if_rdEn;
	       this.dCachevif.if_rdEn = 1;
	       this.dCachevif.if_wrEn = !this.dCachevif.if_rdEn;
           seq_item_port.item_done();
		   addr = addr + 1;
	       if (addr == 10) begin
		     addr = 1;
		   end
	     end
       end

		#10;
       //@(negedge this.dCachevif.sig_clk) 
       //begin
       //    uvm_report_info(get_full_name(), "This is a Test 3.", UVM_LOW);
           //this.dCachevif.sig_a = seq_item.a;
           //this.dCachevif.sig_ab_valid = seq_item.ab_valid;
           //this.dCachevif.sig_b = seq_item.b;
       //end
       //@(posedge this.dCachevif.sig_clk) 
       //begin
       //	   uvm_report_info(get_full_name(), "This is a Test 4.", UVM_LOW);
       //  if (this.dCachevif.sig_ab_valid && this.dCachevif.sig_ab_ready) begin
       //      this.dCachevif.sig_a_real = dCachevif.sig_a;
       //      this.dCachevif.sig_b_real = dCachevif.sig_b;
       //  end
       //end
       //phase.drop_objection( .obj( this ), .description( get_name() ) );
       //seq_item_port.item_done();
     end
   endtask: main_phase

endclass: dCache_master_drv

//---------------------------------------------
// dCache Sequencer Class  
//  Derive form uvm_sequencer and parameterize to dCache_rw sequence item
//---------------------------------------------
class dCache_sequencer extends uvm_sequencer #(dCache_seq);

   `uvm_component_utils(dCache_sequencer)
 
   function new(input string name, uvm_component parent=null);
      super.new(name, parent);
   endfunction : new

endclass : dCache_sequencer

//-----------------------------------------
// dCache Monitor class  
//-----------------------------------------
class dCache_monitor extends uvm_monitor;

  virtual dCache_if dCachevif;

  //Analysis port -parameterized to dCache_rw transaction
  ///Monitor writes transaction objects to this port once detected on interface
  //The ap_inp refers to the signal monitor is sending to the left side of scoreboard (to predictor)
  //The ap_out refers to the signal monitor is sending to the right side of scoreboard (to comparator)
  uvm_analysis_export#(dCache_seq) dCache_ap_inp;
  //This is the output for the DUT
  uvm_analysis_export#(dCache_seq) dCache_ap_out;

  //config class handle
  `uvm_component_utils(dCache_monitor)

   function new(string name, uvm_component parent = null);
     super.new(name, parent);
   endfunction: new

   //Build Phase - Get handle to virtual if from agent/config_db
   virtual function void build_phase(uvm_phase phase);
     super.build_phase(phase);
     if(!uvm_config_db#(virtual dCache_if)::get(this,"","dCachevif",dCachevif)) begin
       `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
     end
     dCache_ap_inp = new( .name( "dCache_ap_inp" ), .parent( this ) );
     dCache_ap_out = new( .name( "dCache_ap_out" ), .parent( this ) );
   endfunction

   virtual task main_phase(uvm_phase phase);
     forever begin
       dCache_seq seq_item;

       @(posedge this.dCachevif.if_clk)
       begin
		//If your dCache is not busy
         if (!dCachevif.if_busy && (dCachevif.if_rdEn || !dCachevif.if_rdEn || dCachevif.if_wrEn || !dCachevif.if_wrEn)) begin
           seq_item = dCache_seq::type_id::create( .name( "seq_item" ) );
           seq_item.if_rdAddr = dCachevif.if_rdAddr;
           seq_item.if_wrAddr = dCachevif.if_wrAddr;
           seq_item.if_wrData = dCachevif.if_wrData;
           seq_item.if_rdEn = dCachevif.if_rdEn;
		   seq_item.if_wrEn = dCachevif.if_wrEn;
		   //seq_item.if_cacheMem_Out = dCachevif.if_cacheMem_Out;
		   //seq_item.if_set_offset_Out = dCachevif.if_set_offset_Out;
           dCache_ap_inp.write(seq_item);
         end
	     if (dCachevif.if_valid) begin
           seq_item = dCache_seq::type_id::create( .name( "seq_item" ) );
           seq_item.if_cacheMem_Out = dCachevif.if_cacheMem_Out;
           seq_item.if_rdAddr = dCachevif.if_rdAddr;
           seq_item.if_wrAddr = dCachevif.if_wrAddr;
		   seq_item.if_set_offset_Out = dCachevif.if_set_offset_Out;
       	   //uvm_report_info(get_full_name(), "Valid signal seen by driver. Sending the cache data", UVM_LOW);
	  	   //uvm_report_info("seq_item.if_rdAddr", $sformatf("%0h",seq_item.if_rdAddr));
	  	   //uvm_report_info("seq_item.if_cacheMem_Out", $sformatf("%0h",seq_item.if_cacheMem_Out[{seq_item.if_rdAddr[2:0],seq_item.if_set_offset_Out}]));
	  	   //uvm_report_info("seq_item.if_cacheMem_Out", $sformatf("%0h",seq_item.if_cacheMem_Out[seq_item.if_rdAddr]));
           dCache_ap_out.write(seq_item);
         end
       end

     end
   endtask : main_phase

endclass: dCache_monitor

class sb_comparator extends uvm_component;

  `uvm_component_utils(sb_comparator)
  uvm_analysis_export #(dCache_seq) axp_in;
  uvm_analysis_export #(dCache_seq) axp_out;
  uvm_tlm_analysis_fifo #(dCache_seq) expfifo;
  uvm_tlm_analysis_fifo #(dCache_seq) outfifo;

  int VEC_CNT, PASS_CNT, FAIL_CNT, ERROR_CNT;

  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    axp_in = new("axp_in", this);
    axp_out = new("axp_out", this);
    expfifo = new("expfifo", this);
    outfifo = new("outfifo", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    axp_in.connect (expfifo.analysis_export);
    axp_out.connect(outfifo.analysis_export);
  endfunction

  task run_phase(uvm_phase phase);
    dCache_seq exp_tr, out_tr;
    forever begin
      uvm_report_info("sb_comparator run task", "WAITING for expected output", UVM_LOW);
      expfifo.get(exp_tr);
      uvm_report_info("sb_comparator run task", "ACQUIRED expected output", UVM_LOW);
	  uvm_report_info("exp_tr.if_act_readData", $sformatf("%0h",exp_tr.if_act_readData));
	  //uvm_report_info("exp_tr.if_cacheMem_Out[exp_tr.if_rdAddr]", $sformatf("%0h",exp_tr.if_cacheMem_Out[{exp_tr.if_rdAddr[2:0],exp_tr.if_set_offset_Out}]));
      uvm_report_info("sb_comparator run task", "WAITING for actual output", UVM_LOW);
      outfifo.get(out_tr);
      uvm_report_info("sb_comparator run task", "ACQUIRED actual output", UVM_LOW);
      uvm_report_info("exp_tr.if_rdAddr[2:0]", $sformatf("%0b", exp_tr.if_rdAddr[2:0]));
      uvm_report_info("out_tr.if_set_offset_Out", $sformatf("%0b", out_tr.if_set_offset_Out));
      uvm_report_info("if_cacheMem_Out[{if_rdAddr, if_set_offset_Out}]", $sformatf("%0h", out_tr.if_cacheMem_Out[{exp_tr.if_rdAddr[2:0],out_tr.if_set_offset_Out}]));
      //uvm_report_info("out_tr.if_rdAddr", $sformatf("%0h", out_tr.if_rdAddr));
      //if (out_tr.compare(exp_tr)) begin
      //  uvm_report_info ("PASS ", $sformatf("Actual=%0d Expected=%0d \n", out_tr.z, exp_tr.z), UVM_LOW);
	  //  PASS();
      //end
      //else begin
      //  ERROR();
    end
  endtask

  function void PASS();
    VEC_CNT++;
    PASS_CNT++;
  endfunction

  function void ERROR();
    VEC_CNT++;
    ERROR_CNT++;
  endfunction

endclass: sb_comparator

class sb_predictor extends uvm_subscriber #(dCache_seq);
  `uvm_component_utils(sb_predictor)

  uvm_analysis_port #(dCache_seq) results_ap;
  int val [2047];

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    results_ap = new("results_ap", this);

	//Variables to store data in memory
	//int val[2047];

    fill_val();

  endfunction

  task fill_val();

    $readmemh("mem_data.list",val);

  endtask


  function void write(dCache_seq t);
	//Variables to store data in memory
	//$readmemh("mem_data.list",val);
    dCache_seq exp_tr = dCache_seq::type_id::create("exp_tr");
    exp_tr = t;
    //uvm_report_info(get_full_name(), "WRITE_PREDICTOR", UVM_LOW);
	if (exp_tr.if_rdEn) begin
    	//uvm_report_info("rdAddr", $sformatf("%0d", exp_tr.if_rdAddr));
		exp_tr.if_act_readData = val[exp_tr.if_rdAddr];
    	//exp_tr.if_cacheMem_Out[{exp_tr.if_rdAddr[2:0],exp_tr.if_set_offset_Out}] = val[exp_tr.if_rdAddr];
    	//uvm_report_info("if_cacheMem_Out[exp_tr.if_rdAddr]", $sformatf("%0h", exp_tr.if_cacheMem_Out[exp_tr.if_rdAddr]));
    	//uvm_report_info("val[exp_tr.if_rdAddr]", $sformatf("%0h",val[exp_tr.if_rdAddr]));
	end
	if (exp_tr.if_wrEn) begin
    	//uvm_report_info("wrAddr", $sformatf("%0d", exp_tr.if_wrAddr));
		exp_tr.if_cacheMem_Out[exp_tr.if_wrAddr] = val[exp_tr.if_wrAddr];
	end
    //---------------------------
    //exp_tr = sb_calc_exp(t);
    results_ap.write(exp_tr);
  endfunction

endclass: sb_predictor

//----------------------------------------------
// dCache Scoreboard class
//----------------------------------------------
class dCache_scoreboard extends uvm_scoreboard;
  `uvm_component_utils(dCache_scoreboard)

  //These are ports that are coming in from outside monitors
  uvm_analysis_export #(dCache_seq) axp_in;
  uvm_analysis_export #(dCache_seq) axp_out;
  sb_predictor prd;
  sb_comparator cmp;
  virtual mem_if memvif;


  // new - constructor
  function new (string name, uvm_component parent);
    super.new(name, parent);
  endfunction : new

  function void build_phase(uvm_phase phase);
     super.build_phase(phase);
     axp_in = new("axp_in", this);
     axp_out = new("axp_out", this);
     prd = sb_predictor::type_id::create("prd", this);
     cmp = sb_comparator::type_id::create("cmp", this);

     if(!uvm_config_db#(virtual mem_if)::get(this,"","memvif",memvif)) begin
       `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
     end

     uvm_config_db#(virtual mem_if)::set( this, "prd", "memvif", memvif);
     uvm_config_db#(virtual mem_if)::set( this, "cmp", "memvif", memvif);

  endfunction
  
  function void connect_phase( uvm_phase phase );
    axp_in.connect (prd.analysis_export);
    axp_out.connect (cmp.axp_out);
    //uvm_report_info("axp_out.if_cacheMem_Out[axp_out.if_rdAddr]", $sformatf("%0h", axp_out.if_cacheMem_Out[4]));
    prd.results_ap.connect(cmp.axp_in);
  endfunction

  task run_phase (uvm_phase phase);
    //uvm_report_info("axp_out.if_cacheMem_Out[axp_out.if_rdAddr]", $sformatf("%0h", axp_out.if_rdAddr));
  endtask

endclass


`endif
