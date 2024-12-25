// A simple reorder buffer with 32 slots
// For B instructions, address_info stores branch address. 
// For jal/jalr instructions, address_info stores PC + 4.
module reorder_buffer(
    input clk,
    input rst,
    input append_en,
    input [2:0] append_type,
    input append_c_instruction,
    input [4:0] append_dest_regid,
    input [16:0] append_address_info,
    input [16:0] append_address_predict,
    input append_branch_prediction,
    input [16:0] append_address,
    input writeback1_en,
    input [4:0] writeback1_vregid,
    input [31:0] writeback1_val,
    input writeback2_en,
    input [4:0] writeback2_vregid,
    input [31:0] writeback2_val,
    input writeback3_en,
    input [4:0] writeback3_vregid,
    input [31:0] writeback3_val,
    input [4:0] query_vregid1,
    input [4:0] query_vregid2,
    output reg query_dependency1,
    output reg [31:0] query_val1,
    output reg query_dependency2,
    output reg [31:0] query_val2,
    output reg reset_en,
    output reg [16:0] reset_new_pc,
    output reg predictor_input_en,
    output reg [16:0] predictor_addr,
    output reg branch_take,
    output reg stack_input_en,
    output reg stack_push_mode,
    output reg [16:0] stack_push_addr,
    output reg [4:0] next_id,
    output reg full,
    output reg commit_en,
    output reg register_writeback_en,
    output reg [4:0] register_writeback_id,
    output reg [4:0] register_writeback_dependency,
    output reg [31:0] register_writeback_val
);
    reg [4:0] head, tail;
    reg [4:0] dest[31:0];
    // 0 - normal writeback ops; 1 - store ops; 2 - branch ops; 3 - jal ops; 4 - jalr ops
    reg [2:0] op_type[31:0];
    // For normal ops, val1 stores writeback value
    // For S/J ops, val1 stores nothing
    // For jalr ops, val1 stores new PC if it's ready; o.w. it stores predicted PC.
    reg val1_rdy[31:0];
    reg [31:0] val1[31:0];
    // For B ops, val2 stores branch destination
    // For J/jalr ops, val2 stores PC + 4
    reg [16:0] val2[31:0];
    reg [16:0] addr[31:0];
    reg predict[31:0];
    reg compressed[31:0];

    reg check_val1_rdy;

    always @(*) begin
        check_val1_rdy = val1_rdy[5'ha];
        if (tail == query_vregid1) begin
            query_dependency1 = append_type == 3'b11 ? 0 : 1;
            query_val1 = append_address_info;
        end else if (!val1_rdy[query_vregid1]) begin
            if (writeback1_en && writeback1_vregid == query_vregid1) begin
                query_dependency1 = 0;
                query_val1 = writeback1_val;
            end else if (writeback2_en && writeback2_vregid == query_vregid1) begin
                query_dependency1 = 0;
                query_val1 = writeback2_val;
            end else if (writeback3_en && writeback3_vregid == query_vregid1) begin
                query_dependency1 = 0;
                query_val1 = writeback3_val;
            end else begin
                query_dependency1 = 1;
                query_val1 = 0;
            end
        end else begin
            query_dependency1 = 0;
            query_val1 = op_type[query_vregid1] == 3'b011 ? val2[query_vregid1] : val1[query_vregid1];
        end
    end

    always @(*) begin
        if (tail == query_vregid2) begin
            query_dependency2 = append_type == 3'b11 ? 0 : 1;
            query_val2 = append_address_info;
        end else if (!val1_rdy[query_vregid2]) begin
            if (writeback1_en && writeback1_vregid == query_vregid2) begin
                query_dependency2 = 0;
                query_val2 = writeback1_val;
            end else if (writeback2_en && writeback2_vregid == query_vregid2) begin
                query_dependency2 = 0;
                query_val2 = writeback2_val;
            end else if (writeback3_en && writeback3_vregid == query_vregid2) begin
                query_dependency2 = 0;
                query_val2 = writeback3_val;
            end else begin
                query_dependency2 = 1;
                query_val2 = 0;
            end
        end else begin
            query_dependency2 = 0;
            query_val2 = op_type[query_vregid2] == 3'b011 ? val2[query_vregid2] : val1[query_vregid2];
        end
    end

    always @(*) begin
        full = tail + append_en + 5'd1 == head || tail + append_en + 5'd2 == head;
        next_id = tail + append_en;
    end

    always @(posedge clk) begin
        if (rst || reset_en) begin
            head <= 0;
            tail <= 0;
            reset_en <= 0;
            predictor_input_en <= 0;
            stack_input_en <= 0;
            commit_en <= 0;
            register_writeback_en <= 0;
        end else begin
            if (append_en) begin
                op_type[tail] <= append_type;
                compressed[tail] <= append_c_instruction;
                val1_rdy[tail] <= append_type == 3'd1 || append_type == 3'd3;
                val1[tail] <= append_address_predict;
                val2[tail] <= append_address_info;
                predict[tail] <= append_branch_prediction;
                dest[tail] <= append_dest_regid;
                addr[tail] <= append_address;
                tail <= tail + 5'd1;
                if (tail + 5'd1 == head) begin
                    $fatal(1, "Trying to append to Rob while it is full");
                end
            end
            if (head != tail && val1_rdy[head]) begin
                case (op_type[head])
                    3'b000: begin
                        register_writeback_en <= dest[head] != 0;
                        commit_en <= 0;
                        predictor_input_en <= 0;
                        stack_input_en <= 0;
                        register_writeback_id <= dest[head];
                        register_writeback_dependency <= head;
                        register_writeback_val <= val1[head];
                    end
                    3'b001: begin
                        register_writeback_en <= 0;
                        commit_en <= 1;
                        predictor_input_en <= 0;
                        stack_input_en <= 0;
                    end
                    3'b010: begin
                        register_writeback_en <= 0;
                        commit_en <= 0;
                        predictor_input_en <= 1;
                        stack_input_en <= 0;
                        if (predict[head] != val1[head][0]) begin
                            reset_en <= 1;
                            reset_new_pc <= val1[head][0] ? val2[head] : addr[head] + (compressed[head] ? 17'd2 : 17'd4);
                        end
                        predictor_addr <= addr[head];
                        branch_take <= val1[head][0];
                    end
                    3'b011: begin
                        register_writeback_en <= dest[head] != 5'b0;
                        commit_en <= 0;
                        predictor_input_en <= 0;
                        stack_input_en <= dest[head] != 5'b0;
                        register_writeback_id <= dest[head];
                        register_writeback_dependency <= head;
                        register_writeback_val <= val2[head];
                        stack_push_mode <= 1;
                        stack_push_addr <= val2[head];
                    end
                    3'b100: begin
                        register_writeback_en <= dest[head] != 0;
                        commit_en <= 0;
                        predictor_input_en <= 0;
                        stack_input_en <= 1;
                        register_writeback_id <= dest[head];
                        register_writeback_dependency <= head;
                        register_writeback_val <= val2[head];
                        stack_push_mode <= 0;
                        if (!predict[head]) begin
                            reset_en <= 1;
                            reset_new_pc <= val1[head];
                        end
                    end
                endcase
                head <= head + 1;
                if (head == tail) begin
                    $fatal(1, "Trying to pop from RoB while it is empty");
                end
            end else begin
                register_writeback_en <= 0;
                commit_en <= 0;
                predictor_input_en <= 0;
                stack_input_en <= 0;
            end
            if (writeback1_en) begin
                if (op_type[writeback1_vregid] == 3'b100) begin
                    predict[writeback1_vregid] <= writeback1_val[17:0] == val1[writeback1_vregid][17:0];
                end
                val1_rdy[writeback1_vregid] <= 1;
                val1[writeback1_vregid] <= writeback1_val;
            end
            if (writeback2_en) begin
                if (op_type[writeback2_vregid] == 3'b100) begin
                    predict[writeback2_vregid] <= writeback2_val[17:0] == val1[writeback2_vregid][17:0];
                end
                val1_rdy[writeback2_vregid] <= 1;
                val1[writeback2_vregid] <= writeback2_val;
            end
            if (writeback3_en) begin
                if (op_type[writeback3_vregid] == 3'b100) begin
                    predict[writeback3_vregid] <= writeback3_val[17:0] == val1[writeback3_vregid][17:0];
                end
                val1_rdy[writeback3_vregid] <= 1;
                val1[writeback3_vregid] <= writeback3_val;
            end
        end
    end
endmodule