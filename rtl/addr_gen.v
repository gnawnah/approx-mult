module addr_gen #(
    parameter WIDTH = 8, parameter DEPTH = 5, parameter ADDR = 3
)(
    input wire clk,
    input wire rst,
    output reg [ADDR-1:0] addr0,
    output reg [ADDR-1:0] addr1 
);

    reg [1:0] counter; // 2 bit counter, only 3 clock cycles

    always @(posedge clk) begin
        if(rst)
            counter <= 0;
        else if(counter < 2'd3) //only count up while below 3
            counter <= counter + 1; // hold at 3, stays at default case (no input)
    end

    always @(*) begin
        case(counter)
            2'b00: begin
                addr0 = 1;
                addr1 = 0;
            end
            2'b01: begin
                addr0 = 3;
                addr1 = 2;
            end
            2'b10: begin
                addr0 = 0;
                addr1 = 4;
            end
            default: begin
                addr0 = 0;
                addr1 = 0;
            end
        endcase

    end
endmodule