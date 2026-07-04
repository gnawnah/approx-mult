module addr_gen #(
    parameter WIDTH = 8, parameter DEPTH = 4, parameter ADDR = 2
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
        else
            counter <= counter + 1;
    end

    always @(*) begin
        case(counter)
            2'b00: begin
                addr0 = 0;
                addr1 = 0;
            end
            2'b01: begin
                addr0 = 2;
                addr1 = 1;
            end
            2'b10: begin
                addr0 = 0;
                addr1 =3
            end
            default: begin
                addr0 = 0;
                addr1 = 0
            end
        endcase

    end
endmodule