// A 32-bit divider. Takes 20 cyles to calculate one single division.(No pipelining)
// Algorithm: SRT Division, Radix-4
// Warning: This divider does not deal with signed division overflow and /0 cases. Check for corner cases before using!
module lookup_table(
    input [2:0] b,
    input signed [5:0] p,
    output reg [2:0] q
);
    always @(*) begin
        case (b)
            3'b000: begin
                if (-12 <= p && p <= -7) begin
                    q = 3'b110;
                end else if (p <= -3) begin
                    q = 3'b101;
                end else if (p <= 1) begin
                    q = 3'b000;
                end else if (p <= 5) begin
                    q = 3'b001;
                end else if (p <= 11) begin
                    q = 3'b010;
                end
            end
            3'b001: begin
                if (-14 <= p && p <= -8) begin
                    q = 3'b110;
                end else if (p <= -3) begin
                    q = 3'b101;
                end else if (p <= 2) begin
                    q = 3'b000;
                end else if (p <= 6) begin
                    q = 3'b001;
                end else if (p <= 13) begin
                    q = 3'b010;
                end
            end
            3'b010: begin
                if (-15 <= p && p <= -9) begin
                    q = 3'b110;
                end else if (p <= -3) begin
                    q = 3'b101;
                end else if (p <= 2) begin
                    q = 3'b000;
                end else if (p <= 7) begin
                    q = 3'b001;
                end else if (p <= 14) begin
                    q = 3'b010;
                end
            end
            3'b011: begin
                if (-16 <= p && p <= -9) begin
                    q = 3'b110;
                end else if (p <= -3) begin
                    q = 3'b101;
                end else if (p <= 2) begin
                    q = 3'b000;
                end else if (p <= 8) begin
                    q = 3'b001;
                end else if (p <= 15) begin
                    q = 3'b010;
                end
            end
            3'b100: begin
                if (-18 <= p && p <= -10) begin
                    q = 3'b110;
                end else if (p <= -4) begin
                    q = 3'b101;
                end else if (p <= 3) begin
                    q = 3'b000;
                end else if (p <= 9) begin
                    q = 3'b001;
                end else if (p <= 17) begin
                    q = 3'b010;
                end
            end
            3'b101: begin
                if (-19 <= p && p <= -11) begin
                    q = 3'b110;
                end else if (p <= -4) begin
                    q = 3'b101;
                end else if (p <= 3) begin
                    q = 3'b000;
                end else if (p <= 9) begin
                    q = 3'b001;
                end else if (p <= 18) begin
                    q = 3'b010;
                end
            end
            3'b110: begin
                if (-20 <= p && p <= -11) begin
                    q = 3'b110;
                end else if (p <= -4) begin
                    q = 3'b101;
                end else if (p <= 3) begin
                    q = 3'b000;
                end else if (p <= 10) begin
                    q = 3'b001;
                end else if (p <= 19) begin
                    q = 3'b010;
                end
            end
            3'b111: begin
                if (-22 <= p && p <= -12) begin
                    q = 3'b110;
                end else if (p <= -4) begin
                    q = 3'b101;
                end else if (p <= 4) begin
                    q = 3'b000;
                end else if (p <= 11) begin
                    q = 3'b001;
                end else if (p <= 21) begin
                    q = 3'b010;
                end
            end
        endcase
    end
endmodule

module normalization(
    input [31:0] a,
    input [31:0] b,
    output reg [31:0] a_norm,
    output reg [31:0] b_norm,
    output reg [31:0] p,
    output reg [4:0] shift_cnt
);
    always @(*) begin
        reg [31:0] p_temp[3:0], a_temp[3:0], b_temp[3:0];
        if (!(|b[31:16])) begin
            p_temp[0] = {16'b0, a[31:16]};
            a_temp[0] = a << 16;
            b_temp[0] = b << 16;
            shift_cnt[4] = 1;
        end else begin
            p_temp[0] =32'b0;
            a_temp[0] = a;
            b_temp[0] = b;
            shift_cnt[4] = 0;
        end
        if (!(|b_temp[0][31:24])) begin
            p_temp[1] = {p_temp[0][23:0], a_temp[0][31:24]};
            a_temp[1] = a_temp[0] << 8;
            b_temp[1] = b_temp[0] << 8;
            shift_cnt[3] = 1;
        end else begin
            p_temp[1] = p_temp[0];
            a_temp[1] = a_temp[0];
            b_temp[1] = b_temp[0];
            shift_cnt[3] = 0;
        end
        if (!(|b_temp[1][31:28])) begin
            p_temp[2] = {p_temp[1][27:0], a_temp[1][31:28]};
            a_temp[2] = a_temp[1] << 4;
            b_temp[2] = b_temp[1] << 4;
            shift_cnt[2] = 1;
        end else begin
            p_temp[2] = p_temp[1];
            a_temp[2] = a_temp[1];
            b_temp[2] = b_temp[1];
            shift_cnt[2] = 0;
        end
        if (!(|b_temp[2][31:30])) begin
            p_temp[3] = {p_temp[2][29:0], a_temp[2][31:30]};
            a_temp[3] = a_temp[2] << 2;
            b_temp[3] = b_temp[2] << 2;
            shift_cnt[1] = 1;
        end else begin
            p_temp[3] = p_temp[2];
            a_temp[3] = a_temp[2];
            b_temp[3] = b_temp[2];
            shift_cnt[1] = 0;
        end
        if (!b_temp[3][31]) begin
            p = {p_temp[3][30:0], a_temp[3][31]};
            a_norm = a_temp[3] << 1;
            b_norm = b_temp[3] << 1;
            shift_cnt[0] = 1;
        end else begin
            p = p_temp[3];
            a_norm = a_temp[3];
            b_norm = b_temp[3];
            shift_cnt[0] = 0;
        end
    end
endmodule

module div32(
    input clk,
    input rst,
    input in_en,
    input [31:0] a,
    input [31:0] b,
    input div_signed,
    output reg idle,
    output reg out_en,
    output reg [31:0] q,
    output reg [31:0] rem
);
    reg [4:0] state;
    reg [31:0] dividend;
    reg [32:0] divisor, p;
    reg [4:0] shift_cnt;
    reg sgn, dividend_sgn;
    reg [31:0] q_add, q_sub, q_temp;

    reg [31:0] a_raw, b_raw;
    wire [31:0] a_norm, b_norm, p_init;
    wire [4:0] shift_cnt_temp;
    normalization norm(.a(a_raw), .b(b_raw), .a_norm(a_norm), .b_norm(b_norm), .p(p_init), .shift_cnt(shift_cnt_temp));
    reg [2:0] b_msb3;
    reg [5:0] p_msb6;
    wire [2:0] qi;
    lookup_table lookup_table(.b(b_msb3), .p(p_msb6), .q(qi));
    always @(posedge clk) begin
        reg [31:0] a_abs, b_abs;
        reg [32:0] new_p;
        reg [31:0] new_q;
        if (rst) begin
            state <= 5'b11111;
            out_en <= 0;
            idle <= 1;
        end else begin
            if (state == 5'b11111) begin
                out_en <= 0;
                if (in_en) begin
                    sgn <= div_signed ? a[31] ^ b[31] : 0;
                    dividend_sgn <= div_signed ? a[31] : 0;
                    a_abs = (div_signed && a[31]) ? -a : a;
                    b_abs = (div_signed && b[31]) ? -b : b;
                    a_raw <= a_abs;
                    b_raw <= b_abs;
                    q_add <= 32'b0;
                    q_sub <= 32'b0;
                    idle <= 0;
                    state <= 5'b11110;
                end
            end else if (state == 5'b11110) begin
                dividend <= a_norm;
                divisor <= {1'b0, b_norm};
                p <= {1'b0, p_init};
                shift_cnt <= shift_cnt_temp;
                p_msb6 <= {1'b0, p_init[31:27]};
                b_msb3 <= b_norm[30:28];
                state <= 5'b00000;
            end else if (!state[4]) begin
                if (qi[2]) begin
                    q_sub <= {q_sub[29:0], qi[1:0]};
                    q_add <= q_add << 2;
                end else begin
                    q_add <= {q_add[29:0], qi[1:0]};
                    q_sub <= q_sub << 2;
                end
                case (qi)
                    3'b000: begin
                        new_p = {p[30:0], dividend[31:30]};
                    end
                    3'b001: begin
                        new_p = {p[30:0], dividend[31:30]} - divisor;
                    end
                    3'b010: begin
                        new_p = {p[30:0], dividend[31:30]} - (divisor << 1);
                    end
                    3'b101: begin
                        new_p = {p[30:0], dividend[31:30]} + divisor;
                    end
                    3'b110: begin
                        new_p = {p[30:0], dividend[31:30]} + (divisor << 1);
                    end
                endcase
                p <= new_p;
                p_msb6 <= new_p[32:27];
                dividend <= dividend << 2;
                state <= state + 1;
            end else if (state == 5'b10000) begin
                new_q = q_add - q_sub;
                if (p[32]) begin
                    q_temp <= new_q - 1;
                    p <= p + divisor;
                end else begin
                    q_temp <= new_q;
                end
                state <= 5'b10001;
            end else if (state == 5'b10001) begin
                out_en <= 1;
                idle <= 1;
                q <= sgn ? -q_temp : q_temp;
                rem <= dividend_sgn ? -(p >> shift_cnt) : (p >> shift_cnt);
                state <= 5'b11111;
            end
        end
    end
endmodule