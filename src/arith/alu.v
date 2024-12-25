/*
    The normal alu of cpu.(Does not contain multiplication and division)
    op[2:0] is the funct3 of the operation, while op[3] is the 2-th msb of funct7.
    If op[4] is set, then the ALU is turned into compare mode. op[2:0] is funct3 while op[3] MUST be 0.
    DOES NOT handle overflow!
*/
module arithmetic_logic_unit(
    input [31:0] a,
    input [31:0] b,
    input [4:0] op,
    output reg [31:0] result
);
    always @(*) begin
        if (op[4]) begin
            case (op[2:0])
                3'b000: begin
                    result = a == b;
                end
                3'b001: begin
                    result = a != b;
                end
                3'b100: begin
                    result = $signed(a) < $signed(b);
                end
                3'b101: begin
                    result = $signed(a) >= $signed(b);
                end
                3'b110: begin
                    result = a < b;
                end
                3'b111: begin
                    result = a >= b;
                end
                default: begin
                    result = 0;
                end
            endcase
        end else begin
            case (op[2:0])
                3'b000: begin
                    if (op[3]) begin
                        result = a - b;
                    end else begin
                        result = a + b;
                    end
                end
                3'b001: begin
                    result = a << b[4:0];
                end
                3'b010: begin
                    result = ($signed(a) < $signed(b)) ? 1 : 0;
                end
                3'b011: begin
                    result = a < b ? 1 : 0;
                end
                3'b100: begin
                    result = a ^ b;
                end
                3'b101: begin
                    if (op[3]) begin
                        result = $signed(a) >> b[4:0];
                    end else begin
                        result = a >> b[4:0];
                    end
                end
                3'b110: begin
                    result = a | b;
                end
                3'b111: begin
                    result = a & b;
                end
            endcase
        end
    end
endmodule