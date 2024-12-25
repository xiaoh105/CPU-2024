// This file includes the reservation station, packed with a divider
module reservation_station_div(
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

    // Instantiate the divider
    wire [31:0] div_result_q;
    wire [31:0] div_result_rem;
    wire div_idle;
    wire div_out_en;
    reg div_in_en;
    reg [31:0] div_input_a;
    reg [31:0] div_input_b;
    reg div_signed;
    div32 div(
        .clk(clk),
        .rst(rst),
        .in_en(div_in_en),
        .a(div_input_a),
        .b(div_input_b),
        .div_signed(div_signed),
        .out_en(div_out_en),
        .idle(div_idle),
        .q(div_result_q),
        .rem(div_result_rem)
    );

    // Attach divider with reservation station:
    // 1. Select an operation that's ready
    // 2. Put op into divider if divider is idle and set the 'live' bit of the selected operation to 0
    // 3. When the output is ready, write it to the writeback
    reg in_ready;
    reg has_ready;
    reg [2:0] ready_id;
    reg [4:0] current_vregid;
    reg [2:0] current_opcode;
    always @(*) begin : div_ready_set
        integer i;
        reg ready[7:0];
        reg ready_width2[3:0];
        reg ready_width4[1:0];

        reg [2:0] ready_id_width2[3:0];
        reg [2:0] ready_id_width4[1:0];
        // Get which slot is ready
        in_ready = in_en && !op1_dependent && !op2_dependent;
        for (i = 0; i < 8; i = i + 1) begin
            ready[i] = live[i] && !a_dependent[i] && !b_dependent[i];
        end
        for (i = 0; i < 4; i = i + 1) begin
            ready_width2[i] = ready[i] || ready[i + 4];
        end
        for (i = 0; i < 2; i = i + 1) begin
            ready_width4[i] = ready_width2[i] || ready_width2[i + 2];
        end
        // Find out ready_id
        for (i = 0; i < 4; i = i + 1) begin
            ready_id_width2[i] = ready[i] ? i : i + 4;
        end
        for (i = 0; i < 2; i = i + 1) begin
            ready_id_width4[i] = ready_width2[i] ? ready_id_width2[i] : ready_id_width2[i + 2];
        end
        ready_id = ready_width4[0] ? ready_id_width4[0] : ready_id_width4[1];
        has_ready = ready_width4[0] || ready_width4[1];
    end
    always @(posedge clk) begin
        if (!rst) begin
            if (div_idle) begin
                if (has_ready) begin
                    div_in_en <= 1;
                    div_input_a <= a_val[ready_id];
                    div_input_b <= b_val[ready_id];
                    div_signed <= !opcode[ready_id][0];
                    current_vregid <= vreg_id[ready_id];
                    current_opcode <= opcode[ready_id];
                end else if (in_ready) begin
                    div_in_en <= 1;
                    div_input_a <= op1;
                    div_input_b <= op2;
                    div_signed <= !op_type[0];
                    current_vregid <= vdest_id;
                    current_opcode <= op_type;
                end else begin
                    div_in_en <= 0;
                end
            end else begin
                div_in_en <= 0;
            end
        end else begin
            div_in_en <= 0;
        end
    end
    always @(posedge clk) begin
        if (rst) begin
            writeback_en <= 0;
        end else begin
            writeback_en <= div_out_en;
            writeback_vregid <= current_vregid;
            writeback_val <= current_opcode[1] ? div_result_rem : div_result_q;
        end
    end
    
    // Update reservation station:
    // 1. Add new instructions if in_en is set
    // 2. Update source register dependency using writeback1/2/3
    // 3. Update full status
    // 4. Clear the unordered list if rst is set
    reg [2:0] empty_id;
    always @(*) begin : div_empty_set
        integer i;
        // Set up empty status
        reg empty_width2[3:0];
        reg empty_width4[1:0];
        reg [2:0] id_width2[3:0];
        reg [2:0] id_width4[1:0];
        for (i = 0; i < 4; i = i + 1) begin
            empty_width2[i] = !live[i] || !live[i + 4];
        end
        for (i = 0; i < 2; i = i + 1) begin
            empty_width4[i] = empty_width2[i] || empty_width2[i + 2];
        end
        // Find out empty_id
        for (i = 0; i < 4; i = i + 1) begin
            id_width2[i] = live[i] ? i + 4 : i;
        end
        for (i = 0; i < 2; i = i + 1) begin
            id_width4[i] = empty_width2[i] ? id_width2[i] : id_width2[i + 2];
        end
        empty_id = empty_width4[0] ? id_width4[0] : id_width4[1];
    end
    always @(posedge clk) begin : div_live_set
        integer i;
        for (i = 0; i < 8; i = i + 1) begin
            live[i] <= rst ? 0 : 
                div_idle && has_ready && i == ready_id ? 0 : 
                in_en && (!in_ready || has_ready) && i == empty_id ? 1 : live[i];
        end
    end
    always @(posedge clk) begin : div_sequential
        integer i;
        if (rst) begin
            full <= 0;
            size <= 0;
        end else begin
            // Update size
            if ((has_ready || in_ready) & div_idle) begin
                size <= size + in_en - 1;
            end else begin
                size <= size + in_en;
            end
            full <= size + in_en == 8;
            // Update dependency
            for (i = 0; i < 8; i = i + 1) begin
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
            for (i = 0; i < 8; i = i + 1) begin
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
                b_dependent[empty_id] <= !op2_dependent ? 0 :
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