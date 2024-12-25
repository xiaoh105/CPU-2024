// A memory contoller that selects between icache and dcache
module memory_controller(
    input clk,
    input rst,
    input hci_rdy,
    input dcache_rw_en,
    input dcache_write_mode,
    input [17:0] dcache_addr,
    input [7:0] dcache_data,
    input icache_rw_en,
    input [17:0] icache_addr,
    input [7:0] mem_din,
    output reg dcache_out_en,
    output reg [7:0] dcache_out_data,
    output reg icache_out_en,
    output reg [7:0] icache_out_data,
    output reg mem_write_mode,
    output reg [17:0] mem_addr,
    output reg [7:0] mem_dout
);
    always @(*) begin
        mem_write_mode = !hci_rdy ? 0 : dcache_rw_en ? dcache_write_mode : 0;
        mem_addr = !hci_rdy ? 0 : dcache_rw_en ? dcache_addr : 
            icache_rw_en ? icache_addr : 0;
        mem_dout = dcache_rw_en ? dcache_data :
            icache_rw_en ? icache_addr : 0;
    end
    always @(*) begin
        dcache_out_data = mem_din;
        icache_out_data = mem_din;
    end
    always @(posedge clk) begin
        if (rst) begin
            dcache_out_en <= 0;
            icache_out_en <= 0;
        end else if (hci_rdy) begin
            dcache_out_en <= dcache_rw_en;
            icache_out_en <= dcache_rw_en ? 0 : icache_rw_en;
        end
    end
endmodule