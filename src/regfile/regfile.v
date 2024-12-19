// This file implements register file with 'x' registers
module regfile(
    input clk,
    input rst,
    input dependency_rst,
    input write_en,
    input [4:0] write_dependency,
    input [4:0] write_id,
    input [31:0] write_val,
    input [4:0] query1_id,
    input [4:0] query2_id,
    input dependency_set_en,
    input [4:0] dependency_reg,
    input [4:0] dependency_dependency,
    output reg query1_has_dependency,
    output reg [4:0] query1_dependency,
    output reg [31:0] query1_val,
    output reg query2_has_dependency,
    output reg [4:0] query2_dependency,
    output reg [31:0] query2_val
);
    reg [31:0] reg_value[31:0];
    reg reg_has_dependency[31:0];
    reg [4:0] reg_dependency[31:0];
    always @(*) begin
        query1_has_dependency = dependency_set_en && dependency_reg == query1_id ? 1 : 
            (write_en && write_dependency == reg_dependency[query1_id]) ? 0 : reg_has_dependency[query1_id];
        query1_dependency = 
            dependency_set_en && dependency_reg == query1_id ? dependency_dependency : reg_dependency[query1_id];
        query1_val = 
            (write_en && 
                reg_has_dependency[query1_id] && 
                write_dependency == reg_dependency[query1_id]) ? 
            write_val : reg_value[query1_id];
        query2_has_dependency = dependency_set_en && dependency_reg == query2_id ? 1 : 
            (write_en && write_dependency == reg_dependency[query2_id]) ? 0 : reg_has_dependency[query2_id];
        query2_dependency = 
            dependency_set_en && dependency_reg == query2_id ? dependency_dependency : reg_dependency[query2_id];
        query2_val = 
            (write_en && 
                reg_has_dependency[query2_id] && 
                write_dependency == reg_dependency[query2_id]) ? 
            write_val : reg_value[query2_id];
    end
    always @(posedge clk) begin
        if (rst) begin
            for (int i = 0; i < 32; ++i) begin
                reg_has_dependency[i] <= 0;
                reg_value[i] <= 0;
                reg_dependency[i] <= 0;
            end
        end else if (dependency_rst) begin
            for (int i = 0; i < 32; ++i) begin
                reg_has_dependency[i] <= 0;
            end
        end else begin
            if (write_en && dependency_set_en && dependency_reg == write_id && write_id != 0) begin
                reg_value[write_id] <= write_val;
                reg_dependency[write_id] <= dependency_dependency;
            end else begin
                if (write_en && write_id != 0) begin
                    reg_has_dependency[write_id] <= (write_dependency == reg_dependency[write_id]) ? 0 : 1;
                    reg_value[write_id] <= write_val;
                end
                if (dependency_set_en && dependency_reg != 0) begin
                    reg_has_dependency[dependency_reg] <= 1;
                    reg_dependency[dependency_reg] <= dependency_dependency;
                end
            end
        end
    end
endmodule