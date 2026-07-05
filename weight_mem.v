// ROM (read-only weight memory)

module weight_mem #(
    parameter WIDTH = 8,
    parameter DEPTH = 5,
    parameter ADDR = 3 // number of bits to address DEPTH words
)(
    input wire clk,
    input wire [ADDR-1:0] addr0, // port A address
    input wire [ADDR-1:0] addr1, // port B address
    output reg [WIDTH-1:0] data_out0, // port A data
    output reg [WIDTH-1:0] data_out1  // port B data
);

    reg [WIDTH-1:0] mem [0:DEPTH-1]; // a 1d array that has DEPTH terms, each term is WIDTH bits

    initial begin
        // mem[0] = 0, weights in mem[1..4]
        mem[0] = 8'd0;
        mem[1] = 8'd5;
        mem[2] = 8'd6;
        mem[3] = 8'd7;
        mem[4] = 8'd8;
    end

    always @(posedge clk) begin
        // two simultaneous reads
        data_out0 <= mem[addr0]; // reading mem[addr] only happens on clock tick
        data_out1 <= mem[addr1];
    end
endmodule