//-----------------------------
// This file contains dCache config, dCache_agent and dCache_env class components
//-----------------------------
`ifndef dCache_AGENT_ENV_CFG__SV
`define dCache_AGENT_ENV_CFG__SV

//---------------------------------------
// dCache Config class
//   -Not really done anything as of now
//---------------------------------------
class dCache_config extends uvm_object;

   `uvm_object_utils(dCache_config)
   virtual dCache_if dCachevif;

  function new(string name="dCache_config");
     super.new(name);
  endfunction

endclass

//----------------------------------------------
// dCache Env class
//----------------------------------------------
class dCache_env  extends uvm_env;
 
   `uvm_component_utils(dCache_env);

   //ENV class will have agent as its sub component
   dCache_agent  agt;
   //virtual interface for dCache interface
   virtual dCache_if  dCachevif;
   virtual mem_if memvif;


   function new(string name, uvm_component parent = null);
      super.new(name, parent);
   endfunction

   //Build phase - Construct agent and get virtual interface handle from test  and pass it down to agent
   function void build_phase(uvm_phase phase);
     agt = dCache_agent::type_id::create("agt",this);
     
     if (!uvm_config_db#(virtual dCache_if)::get(this, "", "dCachevif", dCachevif)) begin
       `uvm_fatal("dCache/AGT/NOVIF", "No virtual interface specified for this env instance");
     end

     if(!uvm_config_db#(virtual mem_if)::get(this,"","memvif",memvif)) begin
       `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
     end
    
     //Passes down the virtual interface to agent
     uvm_config_db#(virtual dCache_if)::set(this, "agt", "dCachevif", dCachevif);
     uvm_config_db#(virtual mem_if)::set(this, "agt", "memvif", memvif);

     
   endfunction
  
endclass : dCache_env  

//---------------------------------------
// dCache Agent class
//---------------------------------------
class dCache_agent extends uvm_agent;

   //Agent will have the sequencer, driver and monitor components for the dCache interface
   dCache_sequencer sqr;
   dCache_master_drv drv;
   dCache_monitor mon;
   dCache_scoreboard scb;

   virtual dCache_if  dCachevif;
   virtual mem_if memvif;


   `uvm_component_utils(dCache_agent);
      
   function new(string name, uvm_component parent = null);
      super.new(name, parent);
   endfunction

   //Build phase of agent - construct sequencer, driver and monitor
   //get handle to virtual interface from env (parent) config_db
   //and pass handle down to srq/driver/monitor
   virtual function void build_phase(uvm_phase phase);
     mon = dCache_monitor::type_id::create("mon",this);
     drv = dCache_master_drv::type_id::create("drv",this);
     sqr = dCache_sequencer::type_id::create("sqr",this);
     scb = dCache_scoreboard::type_id::create("scb",this);
     
     if (!uvm_config_db#(virtual dCache_if)::get(this, "", "dCachevif", dCachevif)) begin
       `uvm_fatal("dCache/AGT/NOVIF", "No virtual interface specified for this agent instance")
     end

     if(!uvm_config_db#(virtual mem_if)::get(this,"","memvif",memvif)) begin
       `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
     end
     
     //Passes down virtual interface to sqr, drv, mon
     uvm_config_db#(virtual dCache_if)::set( this, "sqr", "dCachevif", dCachevif);
     uvm_config_db#(virtual dCache_if)::set( this, "drv", "dCachevif", dCachevif);
     uvm_config_db#(virtual dCache_if)::set( this, "mon", "dCachevif", dCachevif);

     uvm_config_db#(virtual mem_if)::set( this, "sqr", "memvif", memvif);
     uvm_config_db#(virtual mem_if)::set( this, "drv", "memvif", memvif);
     uvm_config_db#(virtual mem_if)::set( this, "mon", "memvif", memvif);
     uvm_config_db#(virtual mem_if)::set( this, "scb", "memvif", memvif);
   endfunction: build_phase

   //Connect - driver and sequencer port to export
   virtual function void connect_phase(uvm_phase phase);
     drv.seq_item_port.connect(sqr.seq_item_export);
     //The mon's export connects to scp's export
     mon.dCache_ap_inp.connect(scb.axp_in);
     mon.dCache_ap_out.connect(scb.axp_out);
     uvm_report_info("dCache_agent::", "connect_phase, Connected driver to sequencer");
   endfunction
endclass: dCache_agent


 

`endif
