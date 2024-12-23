// A decompression module to convert 16-bit instructions into 32-bit instructions
// Do nothing for 32-bit instructions
// Consisting only combinatorial modules, no latency
module decompress(
    input [31:0] instr,
    output reg [31:0] instr_out
);
    always @(*) begin : decompression
        reg [11:0] imm;
        reg [2:0] funct3;
        reg [6:0] funct7;
        if (instr[1:0] == 2'b11) begin
            instr_out = instr;
        end else if (instr[1:0] == 2'b00) begin
            if (instr[15:13] == 3'b000) begin
                // C.ADDI4SPN to ADDI
                imm = {2'b0, instr[10:7], instr[12:11], instr[5], instr[6], 2'b00};
                instr_out = {imm, 5'd2, 3'b000, 2'b01, instr[4:2], 7'b0010011};
            end else if (instr[15:13] == 3'b010) begin
                // C.LW to LW
                imm = {5'b0, instr[5], instr[12:10], instr[6], 2'b00};
                instr_out = {imm, 2'b01, instr[9:7], 3'b010, 2'b01, instr[4:2], 7'b0000011};
            end else if (instr[15:13] == 3'b110) begin
                imm = {5'b0, instr[5], instr[12:10], instr[6], 2'b00};
                instr_out = {imm[11:5], 2'b01, instr[4:2], 2'b01, instr[9:7], 3'b010, imm[4:0], 7'b0100011};
            end
        end else if (instr[1:0] == 2'b01) begin
            if (instr[14:13] == 2'b01) begin
                // C.J/C.JAL to JAL
                imm = {instr[12], instr[8], instr[10:9], instr[6], instr[7], instr[2], instr[11], instr[5:3], 1'b0};
                instr_out = {imm[11], imm[10:1], imm[11], {8{imm[11]}}, (instr[15] ? 5'b0 : 5'b1), 7'b1101111};
            end else if (instr[15:13] == 3'b010) begin
                // C.LI to ADDI
                imm = {{6{instr[12]}}, instr[12], instr[6:2]};
                instr_out = {imm, 5'b0, 3'b000, instr[11:7], 7'b0010011};
            end else if (instr[15:13] == 3'b011) begin
                if (instr[11:7] == 2) begin
                    // C.ADDI16SP to ADDI
                    imm = {{3{instr[4]}}, instr[4:3], instr[5], instr[2], instr[6], 4'b0};
                    instr_out = {imm, 5'd2, 3'b000, 5'd2, 7'b0010011};
                end else begin
                    // C.LUI to LUI
                    instr_out = {{14{instr[12]}}, instr[12], instr[6:2], instr[11:7], 7'b0110111};
                end
            end else if (instr[15:14] == 2'b11) begin
                // C.BEQZ to BEQ
                imm = {{3{instr[12]}}, instr[12], instr[6:5], instr[2], instr[11:10], instr[4:3], 1'b0};
                instr_out = {imm[11], imm[10:5], 5'b0, 2'b01, instr[9:7], 2'b00, instr[13], imm[4:1], imm[11], 7'b1100011};
            end else if (!instr[15]) begin
                // C.NOP/C.ADDI to ADDI
                imm = {{6{instr[12]}}, instr[12], instr[6:2]};
                instr_out = {imm, instr[11:7], 3'b000, instr[11:7], 7'b0010011};
            end else begin
                if (!instr[11]) begin
                    // C.SRLI/C.SRAI to SRIL/SRAI
                    imm = {6'b0, instr[12], instr[6:2]};
                    instr_out = {1'b0, instr[10], 5'b0, imm[4:0], 2'b01, instr[9:7], 3'b101, 2'b01, instr[9:7], 7'b0010011};
                end else if (!instr[10]) begin
                    // C.ANDI to ANDI
                    imm = {{6{instr[12]}}, instr[12], instr[6:2]};
                    instr_out = {imm, 2'b01, instr[9:7], 3'b111, 2'b01, instr[9:7], 7'b0010011};
                end else begin
                    // C.SUB/C.XOR/C.OR/C.AND to SUB/XOR/OR/AND
                    case (instr[6:5])
                        2'b00: begin 
                            funct3 = 3'b000;
                            funct7 = 7'b0100000;
                        end
                        2'b01: begin
                            funct3 = 3'b100;
                            funct7 = 7'b0;
                        end
                        2'b10: begin
                            funct3 = 3'b110;
                            funct7 = 7'b0;
                        end
                        2'b11: begin
                            funct3 = 3'b111;
                            funct7 = 7'b0;
                        end
                    endcase
                    instr_out = {funct7, 2'b01, instr[4:2], 2'b01, instr[9:7], funct3, 2'b01, instr[9:7], 7'b0110011};
                end
            end
        end else if (instr[1:0] == 2'b10) begin
            if (instr[15:13] == 3'b000) begin
                // C.SLLI to SLLI
                imm = {6'b0, instr[12], instr[6:2]};
                instr_out = {7'b0, imm[4:0], instr[11:7], 3'b001, instr[11:7], 7'b0010011};
            end else if (instr[15:13] == 3'b010) begin
                // C.LWSP to LW
                imm = {4'b0, instr[3:2], instr[12], instr[6:4], 2'b0};
                instr_out = {imm, 5'd2, 3'b010, instr[11:7], 7'b0000011};
            end else if (instr[15:13] == 3'b100) begin
                if (instr[6:2] == 0) begin
                    // C.JR/C.JALR to JALR
                    instr_out = {12'b0, instr[11:7], 3'b000, (instr[12] ? 5'b1 : 5'b0), 7'b1100111};
                end else begin
                    // C.MV/C.ADD to ADD
                    instr_out = {7'b0, instr[6:2], (instr[12] ? instr[11:7] : 5'b0), 3'b000, instr[11:7], 7'b0110011};
                end
            end else begin
                // C.SWSP to SW
                imm = {4'b0, instr[8:7], instr[12:9], 2'b0};
                instr_out = {imm[11:5], instr[6:2], 5'd2, 3'b010, imm[4:0], 7'b0100011};
            end
        end
    end
endmodule