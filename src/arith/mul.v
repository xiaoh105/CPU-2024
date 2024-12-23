// A 32-bit multiplier. Takes 4 cycles to calculate a single multiplication.(no pipelining)
// Warning: Do not deal with overflow with signed * unsigned. Check for overflow before using!!!
module mul32(
    input clk,
    input rst,
    input in_en,
    input [31:0] a,
    input [31:0] b,
    input a_signed,
    input b_signed,
    output reg idle,
    output reg out_en,
    output reg [31:0] sum_hi,
    output reg [31:0] sum_lo
);
    reg [1:0] state;
    reg [63:0] op1, op2;
    reg sgn;

    reg [63:0] carry_save_input0, carry_save_input1;
    reg [63:0] carry_save_input[9:0];
    wire [63:0] carry_save_sum[9:0];
    wire [63:0] carry_save_carry[9:0];

    genvar i;
    generate
        carry_save_adder#(.WIDTH(64)) csa0(
            .a(carry_save_input0), 
            .b(carry_save_input1), 
            .c(carry_save_input[0]), 
            .sum(carry_save_sum[0]), 
            .carry(carry_save_carry[0])
        );
        for (i = 1; i < 10; i = i + 1) begin : carry_save_adder_generate
            carry_save_adder#(.WIDTH(64)) csa(
                .a(carry_save_sum[i-1]), 
                .b(carry_save_carry[i-1]), 
                .c(carry_save_input[i]), 
                .sum(carry_save_sum[i]), 
                .carry(carry_save_carry[i])
            );
        end
    endgenerate
    always @(posedge clk) begin : mul_sequential
        integer i;
        reg [63:0] abs_a, abs_b;
        if (rst) begin
            state <= 3'b111;
            idle <= 1;
            out_en <= 0;
        end else begin
            case (state)
                2'b11: begin
                    out_en <= 0;
                    if (in_en) begin
                        abs_a = {{32{1'b0}}, (a_signed && a[31]) ? -a : a};
                        abs_b = {{32{1'b0}}, (b_signed && b[31]) ? -b : b};
                        op1 <= abs_a;
                        op2 <= abs_b;
                        sgn <= (a_signed && a[31]) ^ (b_signed && b[31]);
                        idle <= 0;
                        carry_save_input0 <= abs_b[0] ? abs_a : 64'b0;
                        carry_save_input1 <= abs_b[1] ? abs_a << 1 : 64'b0;
                        for (i = 0; i < 10; i = i + 1) begin
                            carry_save_input[i] <= abs_b[i + 2] ? abs_a << (i + 2) : 64'b0;
                        end
                        state <= 2'b00;
                    end
                end
                2'b00: begin
                    carry_save_input0 <= carry_save_sum[9];
                    carry_save_input1 <= carry_save_carry[9];
                    for (i = 0; i < 10; i = i + 1) begin
                        carry_save_input[i] <= op2[i + 12] ? op1 << (i + 12) : 64'b0;
                    end
                    state <= 2'b01;
                end
                2'b01: begin
                    carry_save_input0 <= carry_save_sum[9];
                    carry_save_input1 <= carry_save_carry[9];
                    for (i = 0; i < 10; i = i + 1) begin
                        carry_save_input[i] <= op2[i + 22] ? op1 << (i + 22) : 64'b0;
                    end
                    state <= 2'b10;
                end
                2'b10: begin
                    out_en <= 1;
                    if (sgn) begin
                        {sum_hi, sum_lo} <= -(carry_save_sum[9] + carry_save_carry[9]);
                    end else begin
                        {sum_hi, sum_lo} <= carry_save_sum[9] + carry_save_carry[9];
                    end
                    idle <= 1;
                    state <= 2'b11;
                end
            endcase
        end
    end
endmodule