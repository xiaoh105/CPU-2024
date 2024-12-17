// This file includes the reservation station, packed with the standard ALU
module reservation_station_alu(
    input clk,
    input rst,
    input in_en,
    input [4:0] op_type,
    input [4:0] vdest_id,
    input op1_dependent,
    input [31:0] op1,
    input op2_dependent,
    input [31:0] op2,
    input writeback2_en,
    input [4:0] writeback2_vregid,
    input [31:0] writeback2_val,
    input writeback3_en,
    input [4:0] writeback3_vregid,
    input [31:0] writeback3_val,
    output reg writeback1_en,
    output reg [4:0] writeback1_vregid,
    output reg [31:0] writeback1_val,
    output reg full
);
    // Define unordered list in reservation station
    reg live[15:0];
    reg [4:0] opcode[15:0];
    reg [4:0] vreg_id[15:0];
    reg a_dependent[15:0];
    reg [31:0] a_val[15:0];
    reg b_dependent[15:0];
    reg [31:0] b_val[15:0];
    reg [3:0] size;

    // Instantiate ALU
    wire [31:0] alu_result;
    reg [31:0] alu_input_a;
    reg [31:0] alu_input_b;
    reg [4:0] alu_input_opcode;
    arithmetic_logic_unit alu(
        .a(alu_input_a),
        .b(alu_input_b),
        .op(alu_input_opcode),
        .result(alu_result)
    );

    // Attach ALU with reservation station:
    // 1. Select an operation that's ready and put it into ALU
    // 2. Set the 'live' bit of the selected operation to 0
    // 3. Use the output of ALU as writeback1
    reg in_ready;
    reg has_ready;
    reg [3:0] ready_id;
    always @(*) begin
        reg ready[15:0];
        reg ready_width2[7:0];
        reg ready_width4[3:0];
        reg ready_width8[1:0];

        reg [3:0] ready_id_width2[7:0];
        reg [3:0] ready_id_width4[3:0];
        reg [3:0] ready_id_width8[1:0];
        // Get which slot is ready
        in_ready = in_en && !op1_dependent && !op2_dependent;
        for (int i = 0; i < 16; ++i) begin
            ready[i] = live[i] && !a_dependent[i] && !b_dependent[i];
        end
        for (int i = 0; i < 8; ++i) begin
            ready_width2[i] = ready[i] || ready[i + 4'd8];
        end
        for (int i = 0; i < 4; ++i) begin
            ready_width4[i] = ready_width2[i] || ready_width2[i + 4'd4];
        end
        for (int i = 0; i < 2; ++i) begin
            ready_width8[i] = ready_width4[i] || ready_width4[i + 4'd2];
        end
        // Find out ready_id
        for (int i = 0; i < 8; ++i) begin
            ready_id_width2[i] = ready[i] ? i : i + 4'd8;
        end
        for (int i = 0; i < 4; ++i) begin
            ready_id_width4[i] = ready_width2[i] ? ready_id_width2[i] : ready_id_width2[i + 4'd4];
        end
        for (int i = 0; i < 2; ++i) begin
            ready_id_width8[i] = ready_width4[i] ? ready_id_width4[i] : ready_id_width4[i + 4'd2];
        end
        ready_id = ready_width8[0] ? ready_id_width8[0] : ready_id_width8[1];
        has_ready = ready_width8[0] || ready_width8[1];
        // Set ALU inputs
        if (has_ready) begin
            alu_input_a = a_val[ready_id];
            alu_input_b = b_val[ready_id];
            alu_input_opcode = opcode[ready_id];
        end else if (in_ready) begin
            alu_input_a = op1;
            alu_input_b = op2;
            alu_input_opcode = op_type;
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            writeback1_en <= 0;
        end else begin
            writeback1_en <= has_ready || in_ready;
            writeback1_vregid <= has_ready ? vreg_id[ready_id] : vdest_id;
            writeback1_val <= alu_result;
            if (has_ready) begin
                live[ready_id] <= 0;
            end
        end
    end
    
    // Update reservation station:
    // 1. Add new instructions if in_en is set
    // 2. Update source register dependency using writeback1/2/3
    // 3. Update full status
    // 4. Clear the unordered list if rst is set
    reg [3:0] empty_id;
    always @(*) begin
        // Set up empty status
        reg empty_width2[7:0];
        reg empty_width4[3:0];
        reg empty_width8[1:0];
        reg [3:0] id_width2[7:0];
        reg [3:0] id_width4[3:0];
        reg [3:0] id_width8[1:0];
        for (int i = 0; i < 8; ++i) begin
            empty_width2[i] = !live[i] || !live[i + 4'd8];
        end
        for (int i = 0; i < 4; ++i) begin
            empty_width4[i] = empty_width2[i] || empty_width2[i + 4'd4];
        end
        for (int i = 0; i < 2; ++i) begin
            empty_width8[i] = empty_width4[i] || empty_width4[i + 4'd2];
        end
        // Find out empty_id
        for (int i = 0; i < 8; ++i) begin
            id_width2[i] = live[i] ? i + 4'd8 : i;
        end
        for (int i = 0; i < 4; ++i) begin
            id_width4[i] = empty_width2[i] ? id_width2[i] : id_width2[i + 4'd4];
        end
        for (int i = 0; i < 2; ++i) begin
            id_width8[i] = empty_width4[i] ? id_width4[i] : id_width4[i + 4'd2];
        end
        empty_id = empty_width8[0] ? id_width8[0] : id_width8[1];
    end
    always @(posedge clk) begin
        if (rst) begin
            full <= 0;
            size <= 0;
            for (int i = 0; i < 16; ++i) begin
                live[i] <= 0;
            end
        end else begin
            // Update size
            if (has_ready || in_ready) begin
                size <= size + in_en - 1;
            end else begin
                size <= size + in_en;
            end
            full <= size + in_en == 16;
            // Update dependency
            for (int i = 0; i < 16; ++i) begin
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
            for (int i = 0; i < 16; ++i) begin
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
                a_dependent[empty_id] <= 
                    (writeback1_en && writeback1_vregid == op1[4:0]) || 
                    (writeback2_en && writeback2_vregid == op1[4:0]) || 
                    (writeback3_en && writeback3_vregid == op1[4:0]) ? 0 : op1_dependent;
                a_val[empty_id] <= !op1_dependent ? op1 : 
                    (writeback1_en && writeback1_vregid == op1[4:0]) ? writeback1_val : 
                    (writeback2_en && writeback2_vregid == op1[4:0]) ? writeback2_val : 
                    (writeback3_en && writeback3_vregid == op1[4:0]) ? writeback3_val : op1;
                b_dependent[empty_id] <= 
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