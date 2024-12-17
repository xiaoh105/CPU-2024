// A decoder that decodes and issues instructions
module decoder(
    input clk,
    input rob_rst,
    input instruction_in,
    input [31:0] instruction,
    input c_instruction,
    input [16:0] pc,
    input [16:0] jalr_prediction,
    input br_prediction,
    input reg1_has_dependency,
    input [4:0] reg1_dependency,
    input [31:0] reg1_val,
    input reg2_has_dependency,
    input [4:0] reg2_dependency,
    input [31:0] reg2_val,
    input vreg1_dependency,
    input [31:0] vreg1_val,
    input vreg2_dependency,
    input [31:0] vreg2_val,
    input [4:0] rob_nextid,
    input lsb_full,
    input rs_alu_full,
    input rs_mul_full,
    input rs_div_full,
    input rob_full,
    output reg idle,
    output reg [4:0] reg1_query,
    output reg [4:0] reg2_query,
    output reg [4:0] vreg1_query,
    output reg [4:0] vreg2_query,
    output reg dependency_set_en,
    output reg alu_in_en,
    output reg [4:0] alu_op_type,
    output reg mul_in_en,
    output reg div_in_en,
    output reg [2:0] muldiv_op_type,
    output reg [4:0] vdest_id,
    output reg op1_dependent,
    output reg [31:0] op1,
    output reg op2_dependent,
    output reg [31:0] op2,
    output reg lsb_rw_en,
    output reg lsb_write,
    output reg lsb_addr_ready,
    output reg [17:0] lsb_addr,
    output reg [4:0] lsb_addr_dependency,
    output reg lsb_value_ready,
    output reg [31:0] lsb_value,
    output reg lsb_sign_ext,
    output reg [1:0] lsb_width,
    output reg rob_in_en,
    output reg [2:0] rob_type,
    output reg rob_compressed_instruction,
    output reg [4:0] rob_destid,
    output reg [16:0] rob_addr_info,
    output reg [16:0] rob_addr_predict,
    output reg rob_br_predict,
    output reg [16:0] rob_addr
);
    always @(*) begin
        if (instruction_in && !rob_full) begin
            casez (instruction[6:0])
                7'b0z10011: begin
                    idle = instruction[25] ? 
                        (instruction[14] ? !rs_div_full : !rs_mul_full) : 
                        !rs_alu_full;
                end
                7'b0z00011: begin
                    idle = !lsb_full;
                end
                7'b1100011: begin
                    idle = !rs_alu_full;
                end
                7'b1101111: begin
                    idle = 1;
                end
                7'b1100111: begin
                    idle = !rs_alu_full;
                end
                7'b0x10111: begin
                    idle = !rs_alu_full;
                end
            endcase
        end else if (rob_full) begin
            idle = 0;
        end else begin
            idle = 1;
        end
    end
    always @(*) begin
        reg1_query = instruction[19:15];
        reg2_query = instruction[24:20];
    end
    always @(*) begin
        vreg1_query = reg1_dependency[4:0];
        vreg2_query = reg2_dependency[4:0];
    end
    always @(posedge clk) begin
        muldiv_op_type <= instruction[14:12];
        vdest_id <= rob_nextid;
        lsb_write <= instruction[5];
        lsb_addr_ready <= reg1_has_dependency ? !vreg1_dependency : 1;
        lsb_addr_dependency <= reg1_dependency;
        lsb_sign_ext <= !instruction[14];
        lsb_width <= instruction[13:12];
        rob_destid <= instruction[11:7];
        rob_addr_predict <= jalr_prediction;
        rob_br_predict <= br_prediction;
        rob_addr <= pc;
    end
    always @(posedge clk) begin
        reg [6:0] opcode;
        opcode = instruction[6:0];
        if (instruction_in && !rob_rst) begin
            rob_in_en <= 1;
            alu_in_en <= opcode == 7'b0010011 || 
                opcode == 7'b0110011 && !instruction[25] || 
                opcode == 7'b1100011 || 
                opcode == 7'b1100111 || 
                opcode == 7'b0110111 ||
                opcode == 7'b0010111;
            mul_in_en <= opcode == 7'b0110011 && instruction[25] && !instruction[14];
            div_in_en <= opcode == 7'b0110011 && instruction[25] && instruction[14];
            lsb_rw_en <= opcode == 7'b0000011 || opcode == 7'b0100011;
            rob_compressed_instruction <= c_instruction;
            dependency_set_en <= opcode != 7'b0100011 && opcode != 7'b1100011;
            op1_dependent <= opcode == 7'b0010111 || opcode == 7'b0110111 ? 0 : (reg1_has_dependency ? vreg1_dependency : 0);
            op2_dependent <= opcode == 7'b0110011 || opcode == 7'b1100011 ? (reg2_has_dependency ? vreg2_dependency : 0) : 0;
            case (opcode)
                7'b0110011: begin
                    op1 <= reg1_has_dependency ? (vreg1_dependency ? reg1_dependency : vreg1_val) : reg1_val;
                    op2 <= reg2_has_dependency ? (vreg2_dependency ? reg2_dependency : vreg2_val) : reg2_val;
                    alu_op_type <= {instruction[6], instruction[30], instruction[14:12]};
                    rob_type <= 0;
                end
                7'b0010011: begin
                    op1 <= reg1_has_dependency ? (vreg1_dependency ? reg1_dependency : vreg1_val) : reg1_val;
                    op2 <= {{20{instruction[31]}}, instruction[31:20]};
                    alu_op_type <= {instruction[6], 1'b0, instruction[14:12]};
                    rob_type <= 0;
                end
                7'b0000011: begin
                    rob_type <= 0;
                    lsb_addr <= reg1_has_dependency ? 
                        (vreg1_dependency ? {{20{instruction[31]}}, instruction[31:20]} : 
                            vreg1_val + {{20{instruction[31]}}, instruction[31:20]}) : 
                        reg1_val + {{20{instruction[31]}}, instruction[31:20]};
                end
                7'b0100011: begin
                    rob_type <= 3'b1;
                    lsb_addr <= reg1_has_dependency ? 
                        (vreg1_dependency ? {{20{instruction[31]}}, instruction[31:25], instruction[11:7]} : 
                            vreg1_val + {{20{instruction[31]}}, instruction[31:25], instruction[11:7]}) : 
                        reg1_val + {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
                    lsb_value_ready <= reg2_has_dependency ? !vreg2_dependency : 1;
                    lsb_value <= reg2_has_dependency ? (vreg2_dependency ? reg2_dependency : vreg2_val) : reg2_val;
                end
                7'b1100011: begin
                    op1 <= reg1_has_dependency ? (vreg1_dependency ? reg1_dependency : vreg1_val) : reg1_val;
                    op2 <= reg2_has_dependency ? (vreg2_dependency ? reg2_dependency : vreg2_val) : reg2_val;
                    alu_op_type <= {instruction[6], 1'b0, instruction[14:12]};
                    rob_type <= 3'd2;
                    rob_addr_info <= pc + {
                        {4{instruction[31]}}, instruction[31], 
                        instruction[7], instruction[30:25], 
                        instruction[11:8], 1'b0
                    };
                end
                7'b1101111: begin
                    rob_type <= 3'd3;
                    rob_addr_info <= pc + (c_instruction ? 17'd2 : 17'd4);
                end
                7'b1100111: begin
                    op1 <= reg1_has_dependency ? (vreg1_dependency ? reg1_dependency : vreg1_val) : reg1_val;
                    op2 <= {{20{instruction[31]}}, instruction[31:20]};
                    alu_op_type <= 5'b0;
                    rob_type <= 3'd4;
                    rob_addr_info <= pc + (c_instruction ? 17'd2 : 17'd4);
                end
                7'b0010111: begin
                    op1 <= pc;
                    op2 <= {instruction[31:12], 12'b0};
                    alu_op_type <= 5'b0;
                    rob_type <= 0;
                end
                7'b0110111: begin
                    op1 <= 0;
                    op2 <= {instruction[31:12], 12'b0};
                    alu_op_type <= 5'b0;
                    rob_type <= 0;
                end
            endcase
        end else begin
            rob_in_en <= 0;
            alu_in_en <= 0;
            mul_in_en <= 0;
            div_in_en <= 0;
            lsb_rw_en <= 0;
            dependency_set_en <= 0;
        end
    end
endmodule