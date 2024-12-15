// An instruction queue that fetches instructions and passes it to decoder.
module instruction_queue(
    input clk,
    input rst,
    input pc_rst,
    input [16:0] new_pc,
    input branch_query_prediction,
    input [16:0] stack_top,
    input icache_out_en,
    input icache_cinstruction,
    input [31:0] icache_instruction,
    input decoder_idle,
    output reg [16:0] branch_query_addr,
    output reg instruction_en,
    output reg [31:0] instruction,
    output reg [16:0] pc_out,
    output reg [16:0] instruction_addr_prediction,
    output reg instruction_br_prediction,
    output reg icache_fetch_en,
    output reg [16:0] icache_fetch_addr
);
    reg [16:0] program_counter;
    reg prediction;
    reg instruction_rdy;
    reg reset_block_drop;
    reg bootstrap;

    reg [16:0] next_program_counter;
    reg branch_take;
    reg [16:0] jalr_prediction;

    always @(*) begin
        branch_query_addr = program_counter;
        branch_take = branch_query_prediction;
        jalr_prediction = stack_top;
    end

    always @(*) begin
        if (icache_instruction[6:0] == 7'b1100011) begin
            next_program_counter = branch_query_prediction ? 
                program_counter + $signed({
                    icache_instruction[31], 
                    icache_instruction[7], 
                    icache_instruction[30:25], 
                    icache_instruction[11:8], 1'b0
                    }) : 
                icache_cinstruction ? program_counter + 2 : program_counter + 4;
        end else if (icache_instruction[6:0] == 7'b1100111) begin
            next_program_counter = stack_top;
        end else if (icache_instruction[6:0] == 7'b1101111) begin
            next_program_counter = program_counter + $signed({
                icache_instruction[31],
                icache_instruction[19:12],
                icache_instruction[20],
                icache_instruction[30:21],
                1'b0
            });
        end else begin
            next_program_counter = icache_cinstruction ? program_counter + 2 : program_counter + 4;
        end
    end

    always @(*) begin
        if (bootstrap) begin
            icache_fetch_en = 1;
            icache_fetch_addr = program_counter;
        end else if (!rst && (icache_out_en || instruction_rdy) && decoder_idle) begin
            icache_fetch_en = 1;
            icache_fetch_addr = next_program_counter;
        end else begin
            icache_fetch_en = 0;
        end
    end

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            program_counter <= 0;
            reset_block_drop <= 0;
            bootstrap <= 1;
        end else if (pc_rst) begin
            program_counter <= new_pc;
            if (!instruction_rdy && !icache_out_en) begin
                reset_block_drop <= 1;
            end else begin
                bootstrap <= 1;
            end
        end else if (reset_block_drop) begin
            if (icache_out_en <= 1) begin
                reset_block_drop <= 0;
                bootstrap <= 1;
            end
        end else begin
            bootstrap <= 0;
            if (instruction_rdy && decoder_idle) begin
                instruction_rdy <= 0;
                program_counter <= next_program_counter;
                instruction_en <= 1;
                instruction <= icache_instruction;
                instruction_addr_prediction <= jalr_prediction;
                instruction_br_prediction <= branch_take;
                pc_out <= program_counter;
            end else if (icache_out_en) begin
                if (!decoder_idle) begin
                    instruction_en <= 0;
                    instruction_rdy <= 1;
                end else begin
                    program_counter <= next_program_counter;
                    instruction_en <= 1;
                    instruction <= icache_instruction;
                    instruction_addr_prediction <= jalr_prediction;
                    instruction_br_prediction <= branch_take;
                    pc_out <= program_counter;
                end
            end else begin
                instruction_en <= 0;
            end
        end
    end
endmodule