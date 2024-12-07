// This file implements a simple dcache
/*
    A 1KB, 2-way set-associative data cache. Use LRU and write-back policy.
    All memory operations MUST BE ALIGNED, or its correctness may not be guaranteed.
    Note: Memory controller must give dcache priority, or error may occur when tring to input data.
 */
module dcache(
    input clk,
    input rst,
    input rw_en,
    input write_mode,
    input [1:0] width,
    input sign_ext,
    input [17:0] rw_addr,
    input [31:0] write_data,
    input io_buffer_full,
    input memory_out_en,
    input [7:0] memory_content,
    output reg rw_feedback_en,
    output reg [31:0] load_data,
    output reg memory_get_en,
    output reg memory_write_mode,
    output reg [17:0] memory_addr,
    output reg [7:0] memory_data,
    output reg idle
);
    reg busy[127:0][1:0];
    reg [7:0] tag[127:0][1:0];
    reg lru_tag[127:0][1:0];
    reg [7:0] data[127:0][1:0][3:0];
    reg dirty[127:0][1:0];
    
    reg [1:0] state;
    reg [1:0] rw_state;
    reg [16:0] mem_addr;
    reg [6:0] mem_index;
    reg [7:0] mem_tag;
    reg [1:0] mem_width;
    reg [31:0] mem_data;
    reg mem_write;
    reg io_wait;
    reg io_display;
    reg replace_id;
    reg sext;
    always @(*) begin
        case (state)
            2'b11: begin
                if (io_display) begin
                    memory_get_en = 0;
                    load_data = {{24{sext ? memory_content[7] : 1'b0}}, memory_content};
                end else if ((rw_en && rw_addr[17:16] == 2'b11 && write_mode || io_wait && mem_write) && !io_buffer_full) begin
                    memory_get_en = 1;
                    memory_write_mode = 0;
                    memory_addr = rw_addr;
                    memory_data = mem_data;
                end else begin
                    memory_get_en = 0;
                end
            end
            2'b00: begin
                if (rw_state == 2'b11 && memory_out_en) begin
                    memory_get_en = 0;
                end else begin
                    memory_get_en = 1;
                    memory_write_mode = 1;
                    memory_addr = {mem_addr[16:2], rw_state + memory_out_en};
                    memory_data = data[mem_index][replace_id][rw_state+memory_out_en];
                end
            end
            2'b01: begin
                if (rw_state == 2'b11 && memory_out_en) begin
                    memory_get_en = 0;
                end else begin
                    memory_get_en = 1;
                    memory_write_mode = 0;
                    memory_addr = {mem_addr[16:2], rw_state + memory_out_en};
                end
            end
            2'b10: begin
                memory_get_en = 0;
            end
        endcase
    end
    always @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= 2'b11;
            rw_state <= 2'b00;
            rw_feedback_en <= 0;
            idle <= 1;
            io_wait <= 0;
            for (int i = 0; i < 128; ++i) begin
                for (int j = 0; j < 2; ++j) begin
                    busy[i][j] <= 0;
                    tag[i][j] <= 0;
                    dirty[i][j] <= 0;
                end
            end
        end else begin
            reg replace;
            reg [6:0] index;
            reg [7:0] data_tag;
            reg [1:0] offset;
            reg [31:0] result;
            case (state)
                // Idle, waiting for instructions
                2'b11: begin
                    sext <= sign_ext;
                    if (io_wait) begin
                        if (!io_buffer_full) begin
                            idle <= 1;
                            state <= 2'b11;
                            rw_feedback_en <= 1;
                            if (!write_mode) begin
                                io_display <= 1;
                            end
                            io_wait <= 0;
                        end
                    end else if (rw_en) begin
                        offset = rw_addr[1:0];
                        index = rw_addr[8:2];
                        data_tag = rw_addr[16:9];
                        mem_addr <= rw_addr;
                        mem_index <= index;
                        mem_tag <= data_tag;
                        mem_write <= write_mode;
                        mem_data <= write_data;
                        mem_width <= width;
                        if (rw_addr[17:16] == 2'b11) begin
                            if (!io_buffer_full) begin
                                idle <= 1;
                                state <= 2'b11;
                                rw_feedback_en <= 1;
                                if (!write_mode) begin
                                    io_display <= 1;
                                end else begin
                                    io_display <= 0;
                                end
                            end else begin
                                io_wait <= 1;
                                io_display <= 0;
                                rw_feedback_en <= 0;
                                idle <= 0;
                            end
                        end else if (busy[index][0] && tag[index][0] == data_tag || busy[index][1] && tag[index][1] == data_tag) begin
                            io_display <= 0;
                            replace = busy[index][1] && tag[index][1] == data_tag;
                            rw_feedback_en <= 1;
                            if (write_mode) begin
                                case (width)
                                    2'b00: begin
                                        data[index][replace][offset] <= write_data[7:0];
                                    end
                                    2'b01: begin
                                        {data[index][replace][offset+1], data[index][replace][offset]} <= write_data[15:0];
                                    end
                                    2'b10: begin
                                        {data[index][replace][3], data[index][replace][2], data[index][replace][1], data[index][replace][0]} <= write_data;
                                    end
                                endcase
                                dirty[index][replace] <= 1;
                                lru_tag[index][replace] <= 1;
                                lru_tag[index][replace^1] <= 0;
                            end else begin
                                case (width)
                                    2'b00: begin
                                        result = {{24{sign_ext ? data[index][replace][offset][7] : 1'b0}}, data[index][replace][offset]};
                                    end
                                    2'b01: begin
                                        result = {
                                            {16{sign_ext ? data[index][replace][offset+1][7] : 1'b0}}, 
                                            data[index][replace][offset+1], 
                                            data[index][replace][offset]
                                        };
                                    end
                                    2'b10: begin
                                        result = {data[index][replace][3], data[index][replace][2], data[index][replace][1], data[index][replace][0]};
                                    end
                                endcase
                                load_data <= result;
                                lru_tag[index][replace] <= 1;
                                lru_tag[index][replace^1] <= 0;
                            end
                            state <= 2'b11;
                            idle <= 1;
                        end else begin
                            rw_feedback_en <= 0;
                            idle <= 0;
                            io_display <= 0;
                            rw_state <= 0;
                            replace = !busy[index][1] || busy[index][0] && !lru_tag[index][1];
                            replace_id <= replace;
                            if (!busy[index][replace] || !dirty[index][replace]) begin
                                if (write_mode && width == 2'b10) begin
                                    state <= 2'b10;
                                end else begin
                                    state <= 2'b01;
                                end
                            end else begin
                                state <= 2'b00;
                            end
                        end
                    end else begin
                        rw_feedback_en <= 0;
                    end
                end
                2'b00: begin
                    if (rw_state != 2'b11) begin
                        if (memory_out_en) begin
                            rw_state <= rw_state + 1;
                        end
                    end else begin
                        if (memory_out_en) begin
                            rw_state <= 0;
                            if (mem_write && mem_width == 2'b10) begin
                                state <= 2'b10;
                            end else begin
                                state <= 2'b01;
                            end
                        end
                    end
                end
                2'b01: begin
                    if (rw_state != 2'b11) begin
                        if (memory_out_en) begin
                            data[mem_index][replace_id][rw_state] <= memory_content;
                            rw_state <= rw_state + 1;
                        end
                    end else begin
                        if (memory_out_en) begin
                            data[mem_index][replace_id][rw_state] <= memory_content;
                            state <= 2'b10;
                        end
                    end
                end
                2'b10: begin
                    busy[mem_index][replace_id] <= 1;
                    tag[mem_index][replace_id] <= mem_tag;
                    lru_tag[mem_index][replace_id] <= 1;
                    lru_tag[mem_index][replace_id^1] <= 0;
                    offset = mem_addr[1:0];
                    rw_feedback_en <= 1;
                    if (mem_write) begin
                        dirty[mem_index][replace_id] <= 1;
                        case (mem_width)
                            2'b00: begin
                                data[mem_index][replace_id][offset] <= mem_data[7:0];
                            end
                            2'b01: begin
                                {data[mem_index][replace_id][offset+1], data[mem_index][replace_id][offset]} <= mem_data[15:0];
                            end
                            2'b10: begin
                                {data[mem_index][replace_id][3], data[mem_index][replace_id][2], 
                                    data[mem_index][replace_id][1], data[mem_index][replace_id][0]} <= mem_data;
                            end
                        endcase
                    end else begin
                        case (mem_width)
                            2'b00: begin
                                load_data <= {{24{sext ? data[mem_index][replace_id][offset][7] : 1'b0}}, data[mem_index][replace_id][offset]};
                            end
                            2'b01: begin
                                load_data <= {{16{sext ? data[mem_index][replace_id][offset+1][7] : 1'b0}}, 
                                    data[mem_index][replace_id][offset+1],
                                    data[mem_index][replace_id][offset]
                                };
                            end
                            2'b10: begin
                                load_data <= {data[mem_index][replace_id][3], data[mem_index][replace_id][2], 
                                    data[mem_index][replace_id][1], data[mem_index][replace_id][0]};
                            end
                        endcase
                    end
                    idle <= 1;
                    state <= 2'b11;
                end
            endcase
        end
    end
endmodule