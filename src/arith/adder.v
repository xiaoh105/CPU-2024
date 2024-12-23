// This file holds various adder for special use in other arithmetic modules
module full_adder(
    input a,
    input b,
    input c,
    output reg sum,
    output reg carry
);
    always @(*) begin
        sum = a ^ b ^ c;
        carry = (a & b) | (b & c) | (c & a);
    end
endmodule

module carry_save_adder
#(
    parameter WIDTH = 32
)
(
    input [WIDTH-1:0] a,
    input [WIDTH-1:0] b,
    input [WIDTH-1:0] c,
    output [WIDTH:0] sum,
    output [WIDTH:0] carry
);
    genvar i;
    assign carry[0] = 0;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : generate_adder
            full_adder adder(a[i], b[i], c[i], sum[i], carry[i + 1]);
        end
    endgenerate
endmodule