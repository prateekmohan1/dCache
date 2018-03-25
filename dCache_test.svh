`ifndef dCache_BASE_TEST_SV
`define dCache_BASE_TEST_SV

//--------------------------------------------------------
//Top level Test class that instantiates env, configures and starts stimulus
//--------------------------------------------------------
class dCache_base_test extends uvm_test;

  //Register with factory
  `uvm_component_utils(dCache_base_test);
  
  dCache_env  env;
  dCache_config cfg;
  virtual dCache_if dCachevif;
  virtual mem_if memvif;
  
  function new(string name = "dCache_base_test", uvm_component parent = null);
    super.new(name, parent);
  endfunction

  //Build phase - Construct the cfg and env class using factory
  //Get the virtual interface handle from Test and then set it config db for the env component
  function void build_phase(uvm_phase phase);
    env = dCache_env::type_id::create("env",this);
    cfg = dCache_config::type_id::create("cfg",this);
    
    if(!uvm_config_db#(virtual dCache_if)::get(this,"","dCachevif",dCachevif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
    end
    
    if(!uvm_config_db#(virtual mem_if)::get(this,"","memvif",memvif)) begin
      `uvm_fatal("NOVIF", {"virtual interface must be set for: ", get_full_name(),".vif"});
    end

    //Passes down virtual interface to env
    uvm_config_db#(virtual dCache_if)::set(this, "env", "dCachevif", dCachevif);
    uvm_config_db#(virtual mem_if)::set(this, "env", "memvif", memvif);
    
  endfunction

  //Run phase - Create an abp_sequence and start it on the dCache_sequencer
  task run_phase( uvm_phase phase );
    dCache_base_seq dCache_seq;
    dCache_seq = dCache_base_seq::type_id::create("dCache_seq",this);

    //Starts the sequence on the sequencer
    dCache_seq.start(env.agt.sqr);
  endtask: run_phase

  virtual function void end_of_elaboration_phase (uvm_phase phase);
    super.end_of_elaboration_phase (phase);
    uvm_top.set_timeout (10000ns);
  endfunction
  
  
endclass


`endif
