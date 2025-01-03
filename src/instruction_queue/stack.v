// A call stack for predicting jalr operations. 
// Function call with depth >16 may be inaccurate.
module call_stack(
    input clk,
    input rst,
    input hci_rdy,
    input in_en,
    input push_mode,
    input [16:0] push_addr,
    output reg [16:0] top
);
    reg [3:0] ptr;
    reg [16:0] addr_stack[15:0];
    always @(*) begin
        top = (in_en && !push_mode) ? addr_stack[ptr-1] : addr_stack[ptr];
    end
    always @(posedge clk) begin : stack_sequential
        integer i;
        if (rst) begin
            ptr <= 0;
            for (i = 0; i < 16; i = i + 1) begin
                addr_stack[i] <= 0;
            end
        end else if (hci_rdy) begin
            if (in_en) begin
                if (push_mode) begin
                    ptr <= ptr + 1;
                    addr_stack[ptr+1] <= push_addr;
                end else begin
                    ptr <= ptr - 1;
                end
            end
        end
    end
endmodule