// This file includes the reservation station, packed with a multiplier
module reservation_station_mul(
    input clk,
    input rst,
    input in_en,
    input [2:0] op_type,
    input [4:0] vdest_id,
    input op1_dependent,
    input [31:0] op1,
    input op2_dependent,
    input [31:0] op2,
    input writeback1_en,
    input [4:0] writeback1_vregid,
    input [31:0] writeback1_val,
    input writeback2_en,
    input [4:0] writeback2_vregid,
    input [31:0] writeback2_val,
    input writeback3_en,
    input [4:0] writeback3_vregid,
    input [31:0] writeback3_val,
    output reg writeback_en,
    output reg [4:0] writeback_vregid,
    output reg [31:0] writeback_val,
    output reg full
);
    // Define unordered list in reservation station
    reg live[7:0];
    reg [2:0] opcode[7:0];
    reg [4:0] vreg_id[7:0];
    reg a_dependent[7:0];
    reg [31:0] a_val[7:0];
    reg b_dependent[7:0];
    reg [31:0] b_val[7:0];
    reg [3:0] size;

    // Instantiate the multiplier
    wire [31:0] mul_result_hi;
    wire [31:0] mul_result_lo;
    wire mul_idle;
    wire mul_out_en;
    reg mul_in_en;
    reg [31:0] mul_input_a;
    reg [31:0] mul_input_b;
    reg a_signed;
    reg b_signed;
    mul32 mul(
        .clk(clk),
        .rst(rst),
        .in_en(mul_in_en),
        .a(mul_input_a),
        .b(mul_input_b),
        .a_signed(a_signed),
        .b_signed(b_signed),
        .out_en(mul_out_en),
        .idle(mul_idle),
        .sum_hi(mul_result_hi),
        .sum_lo(mul_result_lo)
    );

    // Attach multiplier with reservation station:
    // 1. Select an operation that's ready
    // 2. Put op into multiplier if multiplier is idle and set the 'live' bit of the selected operation to 0
    // 3. When the output is ready, write it to the writeback
    reg in_ready;
    reg has_ready;
    reg [2:0] ready_id;
    reg [4:0] current_vregid;
    reg [2:0] current_opcode;
    always @(*) begin
        reg ready[7:0];
        reg ready_width2[3:0];
        reg ready_width4[1:0];

        reg [2:0] ready_id_width2[3:0];
        reg [2:0] ready_id_width4[1:0];
        // Get which slot is ready
        in_ready = in_en && !op1_dependent && !op2_dependent;
        for (int i = 0; i < 8; ++i) begin
            ready[i] = live[i] && !a_dependent[i] && !b_dependent[i];
        end
        for (int i = 0; i < 4; ++i) begin
            ready_width2[i] = ready[i] || ready[i + 4];
        end
        for (int i = 0; i < 2; ++i) begin
            ready_width4[i] = ready_width2[i] || ready_width2[i + 2];
        end
        // Find out ready_id
        for (int i = 0; i < 4; ++i) begin
            ready_id_width2[i] = ready[i] ? i : i + 4;
        end
        for (int i = 0; i < 2; ++i) begin
            ready_id_width4[i] = ready_width2[i] ? ready_id_width2[i] : ready_id_width2[i + 2];
        end
        ready_id = ready_width4[0] ? ready_id_width4[0] : ready_id_width4[1];
        has_ready = ready_width4[0] || ready_width4[1];
    end
    always @(posedge clk) begin
        if (!rst) begin
            if (mul_idle) begin
                if (has_ready) begin
                    mul_in_en <= 1;
                    mul_input_a <= a_val[ready_id];
                    mul_input_b <= b_val[ready_id];
                    if (opcode[ready_id][1]) begin
                        b_signed <= 0;
                        a_signed <= !opcode[ready_id][0];
                    end else begin
                        a_signed <= 1;
                        b_signed <= 1;
                    end
                    live[ready_id] <= 0;
                    current_vregid <= vreg_id[ready_id];
                    current_opcode <= opcode[ready_id][1];
                end else if (in_ready) begin
                    mul_in_en <= 1;
                    mul_input_a <= op1;
                    mul_input_b <= op2;
                    if (op_type[1]) begin
                        b_signed <= 0;
                        a_signed <= !op_type[0];
                    end else begin
                        a_signed <= 1;
                        b_signed <= 1;
                    end
                    current_vregid <= vdest_id;
                    current_opcode <= op_type;
                end else begin
                    mul_in_en <= 0;
                end
            end else begin
                mul_in_en <= 0;
            end
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            writeback_en <= 0;
        end else begin
            writeback_en <= mul_out_en;
            writeback_vregid <= current_vregid;
            writeback_val <= current_opcode == 3'b000 ? mul_result_lo : mul_result_hi;
        end
    end
    
    // Update reservation station:
    // 1. Add new instructions if in_en is set
    // 2. Update source register dependency using writeback1/2/3
    // 3. Update full status
    // 4. Clear the unordered list if rst is set
    reg [2:0] empty_id;
    always @(*) begin
        // Set up empty status
        reg empty_width2[3:0];
        reg empty_width4[1:0];
        reg [2:0] id_width2[3:0];
        reg [2:0] id_width4[1:0];
        for (int i = 0; i < 4; ++i) begin
            empty_width2[i] = !live[i] || !live[i + 4];
        end
        for (int i = 0; i < 2; ++i) begin
            empty_width4[i] = empty_width2[i] || empty_width2[i + 2];
        end
        // Find out empty_id
        for (int i = 0; i < 4; ++i) begin
            id_width2[i] = live[i] ? i + 4 : i;
        end
        for (int i = 0; i < 2; ++i) begin
            id_width4[i] = empty_width2[i] ? id_width2[i] : id_width2[i + 2];
        end
        empty_id = empty_width4[0] ? id_width4[0] : id_width4[1];
    end
    always @(posedge clk) begin
        if (rst) begin
            full <= 0;
            size <= 0;
            for (int i = 0; i < 8; ++i) begin
                live[i] <= 0;
            end
        end else begin
            // Update size
            if ((has_ready || in_ready) && mul_idle) begin
                size <= size + in_en - 1;
            end else begin
                size <= size + in_en;
            end
            full <= size + in_en == 8;
            // Update dependency
            for (int i = 0; i < 8; ++i) begin
                if (live[i] && a_dependent[i]) begin
                    if (writeback1_en && a_val[i][4:0] == writeback1_vregid) begin
                        a_dependent[i] <= 0;
                        a_val[i] <= writeback1_val;
                    end else if (writeback2_en && a_val[i][4:0] == writeback2_vregid) begin
                        a_dependent[i] <= 0;
                        a_val[i] <= writeback2_val;
                    end else if (writeback3_en && a_val[i][4:0] == writeback3_vregid) begin
                        a_dependent[i] <= 0;
                        a_val[i] <= writeback3_val;
                    end
                end
            end
            for (int i = 0; i < 8; ++i) begin
                if (live[i] && b_dependent[i]) begin
                    if (writeback1_en && b_val[i][4:0] == writeback1_vregid) begin
                        b_dependent[i] <= 0;
                        b_val[i] <= writeback1_val;
                    end else if (writeback2_en && b_val[i][4:0] == writeback2_vregid) begin
                        b_dependent[i] <= 0;
                        b_val[i] <= writeback2_val;
                    end else if (writeback3_en && b_val[i][4:0] == writeback3_vregid) begin
                        b_dependent[i] <= 0;
                        b_val[i] <= writeback3_val;
                    end
                end
            end
            // Push new instructions
            if (in_en && (!in_ready || has_ready)) begin
                live[empty_id] <= 1;
                opcode[empty_id] <= op_type;
                vreg_id[empty_id] <= vdest_id;
                a_dependent[empty_id] <= !op1_dependent ? 0 :
                    (writeback1_en && writeback1_vregid == op1[4:0]) || 
                    (writeback2_en && writeback2_vregid == op1[4:0]) || 
                    (writeback3_en && writeback3_vregid == op1[4:0]) ? 0 : op1_dependent;
                a_val[empty_id] <= !op1_dependent ? op1 : 
                    (writeback1_en && writeback1_vregid == op1[4:0]) ? writeback1_val : 
                    (writeback2_en && writeback2_vregid == op1[4:0]) ? writeback2_val : 
                    (writeback3_en && writeback3_vregid == op1[4:0]) ? writeback3_val : op1;
                b_dependent[empty_id] <= !op1_dependent ? 0 :
                    (writeback1_en && writeback1_vregid == op2[4:0]) || 
                    (writeback2_en && writeback2_vregid == op2[4:0]) || 
                    (writeback3_en && writeback3_vregid == op2[4:0]) ? 0 : op2_dependent;
                b_val[empty_id] <= !op2_dependent ? op2 : 
                    (writeback1_en && writeback1_vregid == op2[4:0]) ? writeback1_val : 
                    (writeback2_en && writeback2_vregid == op2[4:0]) ? writeback2_val : 
                    (writeback3_en && writeback3_vregid == op2[4:0]) ? writeback3_val : op2;
            end
        end
    end
endmodule