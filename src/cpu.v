// RISCV32 CPU top module
// port modification allowed for debugging purposes

module cpu(
    input  wire                 clk_in,			// system clock signal
    input  wire                 rst_in,			// reset signal
	  input  wire					        rdy_in,			// ready signal, pause cpu when low

    input  wire [ 7:0]          mem_din,		// data input bus
    output wire [ 7:0]          mem_dout,		// data output bus
    output wire [31:0]          mem_a,			// address bus (only 17:0 is used)
    output wire                 mem_wr,			// write/read signal (1 for write)
	
	  input  wire                 io_buffer_full, // 1 if uart buffer is full
	
	  output wire [31:0]			dbgreg_dout		// cpu register output (debugging demo)
);

    wire dcache_memory_rw_en;
    wire dcache_memory_write_mode;
    wire [17:0] dcache_memory_addr;
    wire [7:0] dcache_memory_data;
    wire icache_memory_rw_en;
    wire [17:0] icache_memory_addr;
    wire dcache_memory_out_en;
    wire [7:0] dcache_memory_out_data;
    wire icache_memory_out_en;
    wire [7:0] icache_memory_out_data;

    memory_controller memory_controller(
        .clk(clk_in),
        .rst(rst_in),
        .dcache_rw_en(dcache_memory_rw_en),
        .dcache_write_mode(dcache_memory_write_mode),
        .dcache_addr(dcache_memory_addr),
        .dcache_data(dcache_memory_data),
        .icache_rw_en(icache_memory_rw_en),
        .icache_addr(icache_memory_addr),
        .mem_din(mem_din),
        .dcache_out_en(dcache_memory_out_en),
        .dcache_out_data(dcache_memory_out_data),
        .icache_out_en(icache_memory_out_en),
        .icache_out_data(icache_memory_out_data),
        .mem_write_mode(mem_wr),
        .mem_addr(mem_a),
        .mem_dout(mem_dout)
    );

    wire dcache_rw_en;
    wire dcache_write_mode;
    wire [1:0] dcache_width;
    wire dcache_sign_ext;
    wire [17:0] dcache_rw_addr;
    wire [31:0] dcache_write_data;
    wire dcache_feedback_en;
    wire [31:0] dcache_load_data;
    wire dcache_idle;

    dcache dcache(
        .clk(clk_in),
        .rst(rst_in),
        .rw_en(dcache_rw_en),
        .write_mode(dcache_write_mode),
        .width(dcache_width),
        .sign_ext(dcache_sign_ext),
        .rw_addr(dcache_rw_addr),
        .write_data(dcache_write_data),
        .io_buffer_full(io_buffer_full),
        .memory_out_en(dcache_memory_out_en),
        .memory_content(dcache_memory_out_data),
        .rw_feedback_en(dcache_feedback_en),
        .load_data(dcache_load_data),
        .memory_get_en(dcache_memory_rw_en),
        .memory_write_mode(dcache_memory_write_mode),
        .memory_addr(dcache_memory_addr),
        .memory_data(dcache_memory_data),
        .idle(dcache_idle)
    );

    wire instruction_get_en;
    wire [16:0] instruction_addr;
    wire instruction_out_en;
    wire [31:0] icache_instruction;
    wire c_instruction;
    
    icache icache(
        .clk(clk_in),
        .rst(rst_in),
        .instruction_get_en(instruction_get_en),
        .instruction_addr(instruction_addr),
        .memory_out_en(icache_memory_out_en),
        .memory_content(icache_memory_out_data),
        .instruction_out_en(instruction_out_en),
        .instruction(icache_instruction),
        .c_instruction(c_instruction),
        .memory_get_en(icache_memory_rw_en),
        .memory_addr(icache_memory_addr)
    );

    wire writeback1_en;
    wire [4:0] writeback1_vregid;
    wire [31:0] writeback1_val;
    wire writeback2_en;
    wire [4:0] writeback2_vregid;
    wire [31:0] writeback2_val;
    wire writeback3_en;
    wire [4:0] writeback3_vregid;
    wire [31:0] writeback3_val;
    wire rob_rst;
    wire lsb_rw_en;
    wire lsb_write_mode;
    wire lsb_addr_ready;
    wire [17:0] lsb_rw_addr;
    wire [4:0] lsb_addr_dependency;
    wire lsb_value_ready;
    wire [31:0] lsb_write_value;
    wire [4:0] vdest;
    wire lsb_rw_sign_ext;
    wire [1:0] lsb_rw_width;
    wire lsb_commit_en;
    wire lsb_full;
    
    load_store_buffer load_store_buffer(
        .clk(clk_in),
        .rst(rst_in),
        .rob_rst(rob_rst),
        .rw_en(lsb_rw_en),
        .write_mode(lsb_write_mode),
        .addr_ready(lsb_addr_ready),
        .rw_addr(lsb_rw_addr),
        .addr_dependency(lsb_addr_dependency),
        .value_ready(lsb_value_ready),
        .write_value(lsb_write_value),
        .read_vdest(vdest),
        .rw_sign_ext(lsb_rw_sign_ext),
        .rw_width(lsb_rw_width),
        .commit_en(lsb_commit_en),
        .writeback1_en(writeback1_en),
        .writeback1_vregid(writeback1_vregid),
        .writeback1_val(writeback1_val),
        .writeback2_en(writeback2_en),
        .writeback2_vregid(writeback2_vregid),
        .writeback2_val(writeback2_val),
        .writeback3_en(writeback3_en),
        .writeback3_vregid(writeback3_vregid),
        .writeback3_val(writeback3_val),
        .dcache_idle(dcache_idle),
        .dcache_rw_feedback_en(dcache_feedback_en),
        .dcache_load_val(dcache_load_data),
        .writeback_en(writeback2_en),
        .writeback_vregid(writeback2_vregid),
        .writeback_val(writeback2_val),
        .full(lsb_full),
        .dcache_rw_en(dcache_rw_en),
        .dcache_write_mode(dcache_write_mode),
        .dcache_width(dcache_width),
        .dcache_sign_ext(dcache_sign_ext),
        .dcache_addr(dcache_rw_addr),
        .dcache_value(dcache_write_data)
    );

    wire alu_in_en;
    wire [4:0] alu_op_type;
    wire op1_dependent;
    wire [31:0] op1;
    wire op2_dependent;
    wire [31:0] op2;
    wire alu_full;

    reservation_station_alu rs_alu(
        .clk(clk_in),
        .rst(rst_in || rob_rst),
        .in_en(alu_in_en),
        .op_type(alu_op_type),
        .vdest_id(vdest),
        .op1_dependent(op1_dependent),
        .op1(op1),
        .op2_dependent(op2_dependent),
        .op2(op2),
        .writeback2_en(writeback2_en),
        .writeback2_vregid(writeback2_vregid),
        .writeback2_val(writeback2_val),
        .writeback3_en(writeback3_en),
        .writeback3_vregid(writeback3_vregid),
        .writeback3_val(writeback3_val),
        .writeback1_en(writeback1_en),
        .writeback1_vregid(writeback1_vregid),
        .writeback1_val(writeback1_val),
        .full(alu_full)
    );

    wire mul_in_en;
    wire [2:0] muldiv_op_type;
    wire mul_full;
    wire writeback_mul_en;
    wire [4:0] writeback_mul_vregid;
    wire [31:0] writeback_mul_val;

    reservation_station_mul rs_mul(
        .clk(clk_in),
        .rst(rst_in || rob_rst),
        .in_en(mul_in_en),
        .op_type(muldiv_op_type),
        .vdest_id(vdest),
        .op1_dependent(op1_dependent),
        .op1(op1),
        .op2_dependent(op2_dependent),
        .op2(op2),
        .writeback1_en(writeback1_en),
        .writeback1_vregid(writeback1_vregid),
        .writeback1_val(writeback1_val),
        .writeback2_en(writeback2_en),
        .writeback2_vregid(writeback2_vregid),
        .writeback2_val(writeback2_val),
        .writeback3_en(writeback3_en),
        .writeback3_vregid(writeback3_vregid),
        .writeback3_val(writeback3_val),
        .writeback_en(writeback_mul_en),
        .writeback_vregid(writeback_mul_vregid),
        .writeback_val(writeback_mul_val),
        .full(mul_full)
    );

    wire div_in_en;
    wire div_full;
    wire writeback_div_en;
    wire [4:0] writeback_div_vregid;
    wire [31:0] writeback_div_val;
    
    reservation_station_div rs_div(
        .clk(clk_in),
        .rst(rst_in || rob_rst),
        .in_en(div_in_en),
        .op_type(muldiv_op_type),
        .vdest_id(vdest),
        .op1_dependent(op1_dependent),
        .op1(op1),
        .op2_dependent(op2_dependent),
        .op2(op2),
        .writeback1_en(writeback1_en),
        .writeback1_vregid(writeback1_vregid),
        .writeback1_val(writeback1_val),
        .writeback2_en(writeback2_en),
        .writeback2_vregid(writeback2_vregid),
        .writeback2_val(writeback2_val),
        .writeback3_en(writeback3_en),
        .writeback3_vregid(writeback3_vregid),
        .writeback3_val(writeback3_val),
        .writeback_en(writeback_div_en),
        .writeback_vregid(writeback_div_vregid),
        .writeback_val(writeback_div_val),
        .full(div_full)
    );

    writeback_controller writeback_controller(
        .clk(clk_in),
        .rst(rst_in | rob_rst),
        .writeback_en1(writeback_mul_en),
        .writeback_vregid1(writeback_mul_vregid),
        .writeback_val1(writeback_mul_val),
        .writeback_en2(writeback_div_en),
        .writeback_vregid2(writeback_div_vregid),
        .writeback_val2(writeback_div_val),
        .writeback_en3(1'b0),
        .writeback3_en(writeback3_en),
        .writeback3_vregid(writeback3_vregid),
        .writeback3_val(writeback3_val)
    );

    wire regfile_write_en;
    wire [4:0] regfile_write_dependency;
    wire [4:0] regfile_write_id;
    wire [31:0] regfile_write_val;
    wire [4:0] regfile_query1_id;
    wire [4:0] regfile_query2_id;
    wire regfile_dependency_set_en;
    wire [4:0] dest;
    wire [4:0] rob_next_id;
    wire regfile_query1_has_dependency;
    wire [4:0] regfile_query1_dependency;
    wire [31:0] regfile_query1_val;
    wire regfile_query2_has_dependency;
    wire [4:0] regfile_query2_dependency;
    wire [31:0] regfile_query2_val;

    regfile regfile(
        .clk(clk_in),
        .rst(rst_in),
        .dependency_rst(rob_rst),
        .write_en(regfile_write_en),
        .write_dependency(regfile_write_dependency),
        .write_id(regfile_write_id),
        .write_val(regfile_write_val),
        .query1_id(regfile_query1_id),
        .query2_id(regfile_query2_id),
        .dependency_set_en(regfile_dependency_set_en),
        .dependency_reg(dest),
        .dependency_dependency(vdest),
        .query1_has_dependency(regfile_query1_has_dependency),
        .query1_dependency(regfile_query1_dependency),
        .query1_val(regfile_query1_val),
        .query2_has_dependency(regfile_query2_has_dependency),
        .query2_dependency(regfile_query2_dependency),
        .query2_val(regfile_query2_val)
    );

    wire [4:0] rob_query1;
    wire [4:0] rob_query2;
    wire rob_query_dependency1;
    wire [31:0] rob_query_val1;
    wire rob_query_dependency2;
    wire [31:0] rob_query_val2;
    wire rob_append_en;
    wire rob_append_c_instruction;
    wire [2:0] rob_append_type;
    wire [16:0] rob_append_address_info;
    wire [16:0] rob_append_address_prediction;
    wire rob_append_branch_prediction;
    wire [16:0] rob_append_address;
    wire [16:0] rob_reset_new_pc;
    wire predictor_input_en;
    wire [16:0] predictor_addr;
    wire predictor_branch_take;
    wire stack_input_en;
    wire stack_push_mode;
    wire [16:0] stack_push_addr;
    wire rob_full;
    
    reorder_buffer reorder_buffer(
        .clk(clk_in),
        .rst(rst_in),
        .append_en(rob_append_en),
        .append_type(rob_append_type),
        .append_c_instruction(rob_append_c_instruction),
        .append_dest_regid(dest),
        .append_address_info(rob_append_address_info),
        .append_address_predict(rob_append_address_prediction),
        .append_branch_prediction(rob_append_branch_prediction),
        .append_address(rob_append_address),
        .writeback1_en(writeback1_en),
        .writeback1_vregid(writeback1_vregid),
        .writeback1_val(writeback1_val),
        .writeback2_en(writeback2_en),
        .writeback2_vregid(writeback2_vregid),
        .writeback2_val(writeback2_val),
        .writeback3_en(writeback3_en),
        .writeback3_vregid(writeback3_vregid),
        .writeback3_val(writeback3_val),
        .query_vregid1(rob_query1),
        .query_vregid2(rob_query2),
        .query_dependency1(rob_query_dependency1),
        .query_val1(rob_query_val1),
        .query_dependency2(rob_query_dependency2),
        .query_val2(rob_query_val2),
        .reset_en(rob_rst),
        .reset_new_pc(rob_reset_new_pc),
        .predictor_input_en(predictor_input_en),
        .predictor_addr(predictor_addr),
        .branch_take(predictor_branch_take),
        .stack_input_en(stack_input_en),
        .stack_push_mode(stack_push_mode),
        .stack_push_addr(stack_push_addr),
        .next_id(rob_next_id),
        .full(rob_full),
        .commit_en(lsb_commit_en),
        .register_writeback_en(regfile_write_en),
        .register_writeback_id(regfile_write_id),
        .register_writeback_dependency(regfile_write_dependency),
        .register_writeback_val(regfile_write_val)
    );
    
    wire [16:0] stack_top;
    call_stack call_stack(
        .clk(clk_in),
        .rst(rst_in),
        .in_en(stack_input_en),
        .push_mode(stack_push_mode),
        .push_addr(stack_push_addr),
        .top(stack_top)
    );

    wire [16:0] predictor_query;
    wire predictor_query_take;
    predictor predictor(
        .clk(clk_in),
        .rst(rst_in),
        .branch_record_en(predictor_input_en),
        .branch_address(predictor_addr),
        .branch_take(predictor_branch_take),
        .q_address(predictor_query),
        .q_take(predictor_query_take)
    );

    wire decoder_idle;
    wire instruction_decode_en;
    wire [31:0] instruction;
    wire cinstruction_decode;
    wire [16:0] program_counter;
    wire [16:0] instruction_addr_prediction;
    wire instruction_br_prediction;

    instruction_queue instruction_queue(
        .clk(clk_in),
        .rst(rst_in),
        .pc_rst(rob_rst),
        .new_pc(rob_reset_new_pc),
        .branch_query_prediction(predictor_query_take),
        .stack_top(stack_top),
        .icache_out_en(instruction_out_en),
        .icache_cinstruction(c_instruction),
        .icache_instruction(icache_instruction),
        .decoder_idle(decoder_idle),
        .branch_query_addr(predictor_query),
        .instruction_en(instruction_decode_en),
        .instruction(instruction),
        .c_instruction(cinstruction_decode),
        .pc_out(program_counter),
        .instruction_addr_prediction(instruction_addr_prediction),
        .instruction_br_prediction(instruction_br_prediction),
        .icache_fetch_en(instruction_get_en),
        .icache_fetch_addr(instruction_addr)
    );

    decoder decoder(
        .clk(clk_in),
        .rob_rst(rob_rst),
        .instruction_in(instruction_decode_en),
        .instruction(instruction),
        .c_instruction(cinstruction_decode),
        .pc(program_counter),
        .jalr_prediction(instruction_addr_prediction),
        .br_prediction(instruction_br_prediction),
        .reg1_has_dependency(regfile_query1_has_dependency),
        .reg1_dependency(regfile_query1_dependency),
        .reg1_val(regfile_query1_val),
        .reg2_has_dependency(regfile_query2_has_dependency),
        .reg2_dependency(regfile_query2_dependency),
        .reg2_val(regfile_query2_val),
        .vreg1_dependency(rob_query_dependency1),
        .vreg1_val(rob_query_val1),
        .vreg2_dependency(rob_query_dependency2),
        .vreg2_val(rob_query_val2),
        .rob_nextid(rob_next_id),
        .lsb_full(lsb_full),
        .rs_alu_full(alu_full),
        .rs_mul_full(mul_full),
        .rs_div_full(div_full),
        .rob_full(rob_full),
        .idle(decoder_idle),
        .reg1_query(regfile_query1_id),
        .reg2_query(regfile_query2_id),
        .vreg1_query(rob_query1),
        .vreg2_query(rob_query2),
        .dependency_set_en(regfile_dependency_set_en),
        .alu_in_en(alu_in_en),
        .alu_op_type(alu_op_type),
        .mul_in_en(mul_in_en),
        .div_in_en(div_in_en),
        .muldiv_op_type(muldiv_op_type),
        .vdest_id(vdest),
        .op1_dependent(op1_dependent),
        .op1(op1),
        .op2_dependent(op2_dependent),
        .op2(op2),
        .lsb_rw_en(lsb_rw_en),
        .lsb_write(lsb_write_mode),
        .lsb_addr_ready(lsb_addr_ready),
        .lsb_addr(lsb_rw_addr),
        .lsb_addr_dependency(lsb_addr_dependency),
        .lsb_value_ready(lsb_value_ready),
        .lsb_value(lsb_write_value),
        .lsb_sign_ext(lsb_rw_sign_ext),
        .lsb_width(lsb_rw_width),
        .rob_in_en(rob_append_en),
        .rob_type(rob_append_type),
        .rob_compressed_instruction(rob_append_c_instruction),
        .rob_destid(dest),
        .rob_addr_info(rob_append_address_info),
        .rob_addr_predict(rob_append_address_prediction),
        .rob_br_predict(rob_append_branch_prediction),
        .rob_addr(rob_append_address)
    );

// Specifications:
// - Pause cpu(freeze pc, registers, etc.) when rdy_in is low
// - Memory read result will be returned in the next cycle. Write takes 1 cycle(no need to wait)
// - Memory is of size 128KB, with valid address ranging from 0x0 to 0x20000
// - I/O port is mapped to address higher than 0x30000 (mem_a[17:16]==2'b11)
// - 0x30000 read: read a byte from input
// - 0x30000 write: write a byte to output (write 0x00 is ignored)
// - 0x30004 read: read clocks passed since cpu starts (in dword, 4 bytes)
// - 0x30004 write: indicates program stop (will output '\0' through uart tx)

always @(posedge clk_in)
  begin
    if (rst_in)
      begin
      
      end
    else if (!rdy_in)
      begin
      
      end
    else
      begin
      
      end
  end

endmodule