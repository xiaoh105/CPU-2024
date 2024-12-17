// A controller that emits writeback signals steadily
module writeback_controller(
    input clk,
    input rst,
    input writeback_en1,
    input [4:0] writeback_vregid1,
    input [31:0] writeback_val1,
    input writeback_en2,
    input [4:0] writeback_vregid2,
    input [31:0] writeback_val2,
    input writeback_en3,
    input [4:0] writeback_vregid3,
    input [31:0] writeback_val3,
    output reg writeback3_en,
    output reg [4:0] writeback3_vregid,
    output reg [31:0] writeback3_val
);
    reg [4:0] head,tail;
    reg [4:0] vregid[31:0];
    reg [31:0] val[31:0];
    always @(posedge clk) begin
        reg [4:0] tail2, tail3;
        if (rst) begin
            head <= 5'b0;
            tail <= 5'b0;
        end else begin
            if (head != tail) begin
                writeback3_en <= 1;
                writeback3_vregid <= vregid[head];
                writeback3_val <= val[head];
                head <= head + 1;
            end else begin
                writeback3_en <= 0;
            end
            tail2 = tail + writeback_en1;
            tail3 = tail2 + writeback_en2;
            if (writeback_en1) begin
                vregid[tail] <= writeback_vregid1;
                val[tail] <= writeback_val1;
            end
            if (writeback_en2) begin
                vregid[tail2] <= writeback_vregid2;
                val[tail2] <= writeback_val2;
            end
            if (writeback_en3) begin
                vregid[tail3] <= writeback_vregid3;
                val[tail3] <= writeback_val3;
            end
            tail <= tail3 + writeback_en3;
        end
    end
endmodule