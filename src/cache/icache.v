// This file implements a simple ICache.
/* 
    A 1KB, 2-way set-associative ICache
    Since halfword instruction exists (and may be misaligned), 1 instruction fetch is split into two operations.
    If the instruction is a halfword, it'll be automatically converted to uncompressed form.
 */
module icache(
    input clk,
    input rst,
    input instruction_get_en,
    input [16:0] instruction_addr,
    input memory_out_en,
    input [7:0] memory_content,
    output reg instruction_out_en,
    output [31:0] instruction,
    output reg c_instruction,
    output reg memory_get_en,
    output reg [16:0] memory_addr
);
    reg busy[127:0][1:0];
    reg [7:0] tag[127:0][1:0];
    reg lru_tag[127:0][1:0];
    reg [7:0] data[127:0][1:0][3:0];

    reg [31:0] raw_instruction;
    decompress decompression(
        .instr(raw_instruction),
        .instr_out(instruction)
    );

    reg [16:0] current_read_addr;
    reg [16:0] current_read_addr_offset;
    // State: 2'b11-idle; 2'b00-Loading 1st halfword; 2'b01-Loading 2nd halfword
    // State: 2'b10-preparing instruction and converting it to 32-bit form
    reg [1:0] current_read_state;
    reg [1:0] block_fill_state;
    reg [31:0] current_read_data;
    reg replace_index1, replace_index2;
    reg [6:0] addr_index1, addr_index2;
    reg [7:0] addr_tag1, addr_tag2;
    always @(*) begin
        case (current_read_state)
            2'b00: begin
                if (block_fill_state == 2'b11 && memory_out_en) begin
                    memory_get_en = 0;
                end else begin
                    memory_get_en = 1;
                    memory_addr = {current_read_addr[16:2], block_fill_state + memory_out_en};
                end
            end
            2'b01: begin
                if (block_fill_state == 2'b11 && memory_out_en) begin
                    memory_get_en = 0;
                end else begin
                    memory_get_en = 1;
                    memory_addr = {current_read_addr_offset[16:2], block_fill_state + memory_out_en};
                end
            end
            default: begin
                memory_get_en = 0;
            end
        endcase
    end
    reg checkpoint;
    always @(posedge clk) begin
        if (rst) begin
            instruction_out_en <= 0;
            memory_get_en <= 0;
            current_read_state <= 3'b111;
            for (int i = 0; i < 128; ++i) begin
                for (int j = 0; j < 2; ++j) begin
                    busy[i][j] <= 0;
                    lru_tag[i][j] <= 2'b00;
                    tag[i][j] <= 0;
                end
            end
        end else begin
            reg [6:0] index1, index2;
            reg [7:0] tag1, tag2;
            reg [16:0] addr_tmp;
            reg nready1, nready2, nready;
            case (current_read_state)
                2'b11: begin
                    if (instruction_get_en) begin
                        current_read_addr <= instruction_addr;
                        block_fill_state <= 0;
                        addr_tmp = instruction_addr + 17'd2;
                        index1 = instruction_addr[8:2];
                        index2 = addr_tmp[8:2];
                        tag1 = instruction_addr[16:9];
                        tag2 = addr_tmp[16:9];
                        addr_index1 <= index1;
                        addr_index2 <= index2;
                        addr_tag1 <= tag1;
                        addr_tag2 <= tag2;
                        current_read_addr_offset <= addr_tmp;
                        nready1 = (!busy[index1][0] || tag[index1][0] != tag1) && (!busy[index1][1] || tag[index1][1] != tag1);
                        nready2 = (!busy[index2][0] || tag[index2][0] != tag2) && (!busy[index2][1] || tag[index2][1] != tag2);
                        current_read_state <= nready1 ? 2'b00 : (nready2 ? 2'b01 : 2'b11);
                        if (!nready1 && !nready2) begin
                            instruction_out_en <= 1;
                            if (index1 == index2) begin
                                current_read_data = (busy[index1][0] && tag[index1][0] == tag1) ? 
                                    {data[index1][0][3], data[index1][0][2], data[index1][0][1], data[index1][0][0]} : 
                                    {data[index1][1][3], data[index1][1][2], data[index1][1][1], data[index1][1][0]};
                            end else begin
                                current_read_data[15:0] = (busy[index1][0] && tag[index1][0] == tag1) ? 
                                    {data[index1][0][3], data[index1][0][2]} : 
                                    {data[index1][1][3], data[index1][1][2]};
                                current_read_data[31:16] = (busy[index2][0] && tag[index2][0] == tag2) ? 
                                    {data[index2][0][1], data[index2][0][0]} : 
                                    {data[index2][1][1], data[index2][1][0]};
                            end
                            c_instruction <= current_read_data[1:0] != 2'b11;
                            raw_instruction <= current_read_data;
                        end else begin
                            instruction_out_en <= 0;
                        end
                        replace_index1 <= !busy[index1][1] || busy[index1][0] && !lru_tag[index1][1];
                        replace_index2 <= !busy[index2][1] || busy[index2][0] && !lru_tag[index2][1];
                    end else begin
                        instruction_out_en <= 0;
                    end
                end
                2'b00: begin
                    case (block_fill_state)
                        2'b00: begin
                            if (memory_out_en) begin
                                busy[addr_index1][replace_index1] <= 1;
                                tag[addr_index1][replace_index1] <= tag1;
                                lru_tag[addr_index1][replace_index1] <= 1;
                                lru_tag[addr_index1][!replace_index1] <= 0;
                                data[addr_index1][replace_index1][0] <= memory_content;
                                block_fill_state <= 2'b01;
                            end
                        end
                        2'b01: begin
                            if (memory_out_en) begin
                                data[addr_index1][replace_index1][1] <= memory_content;
                                block_fill_state <= 2'b10;
                            end
                        end
                        2'b10: begin
                            if (memory_out_en) begin
                                data[addr_index1][replace_index1][2] <= memory_content;
                                block_fill_state <= 2'b11;
                            end
                        end
                        2'b11: begin
                            if (memory_out_en) begin
                                data[addr_index1][replace_index1][3] <= memory_content;
                                block_fill_state <= 2'b00;
                                nready = (addr_index1 != addr_index2 &&
                                    (!busy[addr_index2][0] || tag[addr_index2][0] != addr_tag2) && 
                                    (!busy[addr_index2][0] || tag[addr_index2][1] != addr_tag2));
                                current_read_state <= nready ? 2'b01 : 2'b10;
                            end
                        end
                    endcase
                end
                2'b01: begin
                    case (block_fill_state)
                        2'b00: begin
                            if (memory_out_en) begin
                                busy[addr_index2][replace_index2] <= 1;
                                tag[addr_index2][replace_index2] <= tag2;
                                lru_tag[addr_index2][replace_index2] <= 1;
                                lru_tag[addr_index2][!replace_index2] <= 0;
                                data[addr_index2][replace_index2][0] <= memory_content;
                                block_fill_state <= 2'b01;
                            end
                        end
                        2'b01: begin
                            if (memory_out_en) begin
                                data[addr_index2][replace_index2][1] <= memory_content;
                                block_fill_state <= 2'b10;
                            end
                        end
                        2'b10: begin
                            if (memory_out_en) begin
                                data[addr_index2][replace_index2][2] <= memory_content;
                                block_fill_state <= 2'b11;
                            end
                        end
                        2'b11: begin
                            if (memory_out_en) begin
                                data[addr_index2][replace_index2][3] <= memory_content;
                                current_read_state <= 2'b10;
                            end
                        end
                    endcase
                end
                2'b10: begin
                    index1 = current_read_addr[8:2];
                    index2 = current_read_addr_offset[8:2];
                    tag1 = current_read_addr[16:9];
                    tag2 = current_read_addr_offset[16:9];
                    instruction_out_en <= 1;
                    if (index1 == index2) begin
                        current_read_data = (busy[index1][0] && tag[index1][0] == tag1) ? {data[index1][0][3], data[index1][0][2], data[index1][0][1], data[index1][0][0]} : 
                            {data[index1][1][3], data[index1][1][2], data[index1][1][1], data[index1][1][0]};
                    end else begin
                        current_read_data[15:0] = (busy[index1][0] && tag[index1][0] == tag1) ? {data[index1][0][3], data[index1][0][2]} : 
                            {data[index1][1][3], data[index1][1][2]};
                        current_read_data[31:16] = (busy[index2][0] && tag[index2][0] == tag2) ? {data[index2][0][1], data[index2][0][0]} : 
                            {data[index2][1][1], data[index2][1][0]};
                    end
                    c_instruction <= current_read_data[1:0] != 2'b11;
                    raw_instruction <= current_read_data;
                    current_read_state <= 2'b11;
                end
            endcase
        end
    end
endmodule