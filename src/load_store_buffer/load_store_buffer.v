// A simple load store buffer that supports instruction and data fetch/write
// This module IS NOT packed with icache/dcache
module load_store_buffer(
    input clk,
    input rst,
    input rob_rst,
    input rw_en,
    input write_mode,
    input addr_ready,
    input [17:0] rw_addr,
    input [4:0] addr_dependency,
    input value_ready,
    input [31:0] write_value,
    input [4:0] read_vdest,
    input rw_sign_ext,
    input [1:0] rw_width,
    input commit_en,
    input writeback1_en,
    input [4:0] writeback1_vregid,
    input [31:0] writeback1_val,
    input writeback2_en,
    input [4:0] writeback2_vregid,
    input [31:0] writeback2_val,
    input writeback3_en,
    input [4:0] writeback3_vregid,
    input [31:0] writeback3_val,
    input dcache_idle,
    input dcache_rw_feedback_en,
    input [31:0] dcache_load_val,
    output reg writeback_en,
    output reg [4:0] writeback_vregid,
    output reg [31:0] writeback_val,
    output reg full,
    output reg dcache_rw_en,
    output reg dcache_write_mode,
    output reg [1:0] dcache_width,
    output reg dcache_sign_ext,
    output reg [17:0] dcache_addr,
    output reg [31:0] dcache_value
);
    reg [3:0] head, tail;
    reg commit[15:0];
    reg write_op[15:0];
    reg addr_rdy[15:0];
    // When address isn't ready, address[17:0] holds offset and address[31:27] holds dependency
    reg [31:0] address[15:0];
    reg value_rdy[15:0];
    // For write ops: 
    // 1. If value isn't ready, value[4:0] holds dependency
    // 2. o.w. value[31:0] holds value
    // For load ops: 
    // 1. value[4:0] holds virtual destination register
    // 2. value [31] holds sign_ext flag
    reg [31:0] value[15:0];
    reg [1:0] width[15:0];

    reg rob_rst_block;

    always @(*) begin
        full = tail + 4'd1 + rw_en == head || tail + 4'd2 + rw_en == head;
        if (!rob_rst && !rob_rst_block && dcache_rw_feedback_en) begin
            dcache_addr = address[head+4'd1][17:0];
            dcache_sign_ext = value[head+4'd1][31];
            dcache_width = width[head+4'd1];
            dcache_value = value[head+4'd1];
            if (head + 4'd1 != tail && head != tail) begin
                if (address[head][17:16] == 2'b11 && address[head+4'd1][17:16] == 2'b11) begin
                    dcache_rw_en = 0;
                end else if (write_op[head+4'd1] && addr_rdy[head+4'd1] && value_rdy[head+4'd1] && commit[head+4'd1]) begin
                    dcache_rw_en = 1;
                    dcache_write_mode = 1;
                end else if (!write_op[head+4'd1] && addr_rdy[head+4'd1]) begin
                    dcache_rw_en = 1;
                    dcache_write_mode = 0;
                end else begin
                    dcache_rw_en = 0;
                end
            end else begin
                dcache_rw_en = 0;
            end
        end else if (!rob_rst && head != tail && dcache_idle) begin
            dcache_addr = address[head][17:0];
            dcache_sign_ext = value[head][31];
            dcache_value = value[head];
            dcache_width = width[head];
            if (write_op[head] && addr_rdy[head] && value_rdy[head] && commit[head]) begin
                dcache_rw_en = 1;
                dcache_write_mode = 1;
            end else if (!write_op[head] && addr_rdy[head]) begin
                dcache_rw_en = 1;
                dcache_write_mode = 0;
            end else begin
                dcache_rw_en = 0;
            end
        end else begin
            dcache_rw_en = 0;
        end
    end
    always @(posedge clk) begin : lsb_sequential
        integer i;
        if (rst) begin
            head <= 0;
            tail <= 0;
            rob_rst_block <= 0;
            writeback_en <= 0;
            full <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                commit[i] <= 0;
                write_op[i] <= 0;
                value_rdy[i] <= 1;
            end
        end else if (rob_rst) begin : lsb_reset
            reg [3:0] tmp1, tmp2, tmp3, tmp4, new_tail;
            tmp1 = (write_op[head+4'd8] && commit[head+4'd8]) ? head + 4'd8 : head;
            tmp2 = (write_op[tmp1+4'd4] && commit[tmp1+4'd4]) ? tmp1 + 4'd4 : tmp1;
            tmp3 = (write_op[tmp2+4'd2] && commit[tmp2+4'd2]) ? tmp2 + 4'd2 : tmp2;
            tmp4 = (write_op[tmp3+4'd1] && commit[tmp3+4'd1]) ? tmp3 + 4'd1 : tmp3;
            new_tail = (!write_op[tmp4] || !commit[tmp4]) ? tmp4 : tmp4 + 4'd1;
            for (i = 0; i < 16; i = i + 1) begin
                if (new_tail <= i && i < tail || tail < new_tail && (new_tail <= i || i < tail)) begin
                    write_op[i] <= 0;
                    commit[i] <= 0;
                    value_rdy[i] <= 1;
                end
            end
            tail <= new_tail;
            if ((!dcache_idle || dcache_rw_en) && head == new_tail) begin
                rob_rst_block <= 1;
            end
            if (dcache_rw_feedback_en && write_op[head]) begin
                if (head == tail) begin
                    $fatal(1, "Load Store Buffer overflows when reset");
                end
                head <= head + 1;
                commit[head] <= 0;
                write_op[head] <= 0;
            end
            writeback_en <= 0;
        end else begin
            if (rob_rst_block) begin
                if (dcache_rw_feedback_en) begin
                    rob_rst_block <= 0;
                end
            end else if (dcache_rw_feedback_en) begin
                if (!write_op[head]) begin
                    writeback_en <= 1;
                    writeback_vregid <= value[head][4:0];
                    writeback_val <= dcache_load_val;
                end else begin
                    writeback_en <= 0;
                end
                commit[head] <= 0;
                write_op[head] <= 0;
                if (head == tail) begin
                    $fatal(1, "Trying to pop elements in LSB while it is empty");
                end
                head <= head + 1;
            end else begin
                writeback_en <= 0;
            end
            if (rw_en) begin
                write_op[tail] <= write_mode;
                addr_rdy[tail] <= addr_ready ? 1 :
                    (writeback1_en && writeback1_vregid == addr_dependency) || 
                    (writeback2_en && writeback2_vregid == addr_dependency) || 
                    (writeback3_en && writeback3_vregid == addr_dependency) ? 1 : addr_ready;
                address[tail] <= addr_ready ? rw_addr : 
                    (writeback1_en && writeback1_vregid == addr_dependency) ? writeback1_val + rw_addr : 
                    (writeback2_en && writeback2_vregid == addr_dependency) ? writeback2_val + rw_addr :
                    (writeback3_en && writeback3_vregid == addr_dependency) ? writeback3_val + rw_addr : rw_addr;
                address[tail][31:27] <= addr_dependency;
                width[tail] <= rw_width;
                if (write_mode) begin
                    value_rdy[tail] <= value_ready ? 1 :
                        (writeback1_en && writeback1_vregid == write_value[4:0]) || 
                        (writeback2_en && writeback2_vregid == write_value[4:0]) || 
                        (writeback3_en && writeback3_vregid == write_value[4:0]) ? 1 : value_ready;
                    value[tail] <= value_ready ? write_value : 
                        (writeback1_en && writeback1_vregid == write_value[4:0]) ? writeback1_val : 
                        (writeback2_en && writeback2_vregid == write_value[4:0]) ? writeback2_val : 
                        (writeback3_en && writeback3_vregid == write_value[4:0]) ? writeback3_val : write_value;
                end else begin
                    value_rdy[tail] <= 1;
                    value[tail][4:0] <= read_vdest;
                    value[tail][31] <= rw_sign_ext;
                end
                tail <= tail + 1;
                if (tail + 1 == head) begin
                    $fatal(1, "Trying to append to LSB while it is full");
                end
            end
            for (i = 0; i < 16; i = i + 1) begin
                if (!addr_rdy[i]) begin
                    if (writeback1_en && writeback1_vregid == address[i][31:27]) begin
                        addr_rdy[i] <= 1;
                        address[i] <= {14'b0, address[i][17:0]} + writeback1_val;
                    end else if (writeback2_en && writeback2_vregid == address[i][31:27]) begin
                        addr_rdy[i] <= 1;
                        address[i] <= {14'b0, address[i][17:0]} + writeback2_val;
                    end else if (writeback3_en && writeback3_vregid == address[i][31:27]) begin
                        addr_rdy[i] <= 1;
                        address[i] <= {14'b0, address[i][17:0]} + writeback3_val;
                    end
                end
            end
            for (i = 0; i < 16; i = i + 1) begin
                if (!value_rdy[i]) begin
                    if (writeback1_en && writeback1_vregid == value[i][4:0]) begin
                        value_rdy[i] <= 1;
                        value[i] <= writeback1_val;
                    end else if (writeback2_en && writeback2_vregid == value[i][4:0]) begin
                        value_rdy[i] <= 1;
                        value[i] <= writeback2_val;
                    end else if (writeback3_en && writeback3_vregid == value[i][4:0]) begin
                        value_rdy[i] <= 1;
                        value[i] <= writeback3_val;
                    end
                end
            end
            if (commit_en) begin : lsb_commit
                reg [3:0] tmp1, tmp2, tmp3, tmp4, commit_id;
                tmp1 = (write_op[head+4'd8] && commit[head+4'd8]) ? head + 4'd8 : head;
                tmp2 = (write_op[tmp1+4'd4] && commit[tmp1+4'd4]) ? tmp1 + 4'd4 : tmp1;
                tmp3 = (write_op[tmp2+4'd2] && commit[tmp2+4'd2]) ? tmp2 + 4'd2 : tmp2;
                tmp4 = (write_op[tmp3+4'd1] && commit[tmp3+4'd1]) ? tmp3 + 4'd1 : tmp3;
                commit_id = (write_op[tmp4] && !commit[tmp4]) ? tmp4 : tmp4 + 4'd1;
                commit[commit_id] <= 1;
            end
        end
    end
endmodule