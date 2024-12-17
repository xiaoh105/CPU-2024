// A simple tournament predictor. Local history and index are both 10 bits.
module predictor(
    input clk,
    input rst,
    input branch_record_en,
    input [16:0] branch_address,
    input branch_take,
    input [16:0] q_address,
    output reg q_take
);
    reg [9:0] global_state;
    reg [1:0] global_predictor[1023:0];
    reg [1:0] local_predictor[1023:0];
    // >= 2 for selecting local predictors
    reg [1:0] selector[1023:0];

    // Responding to queries
    always @(*) begin
        reg [9:0] index;
        index = q_address[9:0];
        q_take = selector[index][1] ? local_predictor[index][1] : global_predictor[global_state][1];
    end

    // Updating branch information using provided information
    always @(posedge clk) begin
        if (rst) begin
            global_state <= 0;
            for (int i = 0; i < 1024; ++i) begin
                global_predictor[i] <= 2'b00;
                local_predictor[i] <= 2'b00;
                selector[i] <= 2'b01;
            end
        end else begin
            if (branch_record_en) begin
                reg [9:0] index;
                index = branch_address[9:0];
                if (global_predictor[global_state][1] == branch_take && local_predictor[index][1] != branch_take) begin
                    selector[index] <= (selector[index] == 0) ? 0 : selector[index] - 1;
                end
                if (global_predictor[global_state][1] != branch_take && local_predictor[index][1] == branch_take) begin
                    selector[index] <= (selector[index] == 2'b11) ? 2'b11 : selector[index] + 1;
                end
                if (branch_take) begin
                    global_predictor[global_state] <= (global_predictor[global_state] == 2'b11) ? 2'b11 : global_predictor[global_state] + 1;
                    local_predictor[index] <= (local_predictor[index] == 2'b11) ? 2'b11 : local_predictor[index] + 1;
                end else begin
                    global_predictor[global_state] <= (global_predictor[global_state] == 0) ? 0 : global_predictor[global_state] - 1;
                    local_predictor[index] <= (local_predictor[index] == 0) ? 0 : local_predictor[index] - 1;
                end
                global_state <= {global_state[8:0], branch_take};
            end
        end
    end
endmodule