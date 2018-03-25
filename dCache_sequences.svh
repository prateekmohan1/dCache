
//A few flavours of dCache sequences

`ifndef dCache_SEQUENCES_SV
`define dCache_SEQUENCES_SV

//------------------------
//Base dCache sequence derived from uvm_sequence and parameterized with sequence item of type dCache_rw
//------------------------
class dCache_base_seq extends uvm_sequence#(dCache_seq);

  `uvm_object_utils(dCache_base_seq)

  function new(string name ="");
    super.new(name);
  endfunction


  //Main Body method that gets executed once sequence is started
  task body();
    dCache_seq seq_item;
    forever begin
      seq_item = dCache_seq::type_id::create("dCache_seq");
      start_item(seq_item);
      assert ( seq_item.randomize() );
      finish_item(seq_item);
    end
  endtask
  
endclass



`endif
