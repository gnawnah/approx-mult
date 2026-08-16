module mac_array #(
    parameter WIDTH = 8,
    parameter TRUNC_BITS = 2,
    parameter CORRECTION = 0,
    parameter N = 256
) (
    input wire clk,
    input wire rst,
    input wire [WIDTH-1:0] a,
    input wire [WIDTH-1:0] b,
    input wire valid,
    output wire [N*4*WIDTH-1:0] acc_flat
);

    genvar i;
    generate
        for (i=0; i<N; i=i+1) begin: g_mac
            localparam [WIDTH-1:0] XOR_A = i;
            localparam [WIDTH-1:0] XOR_B = ~i;

            mac #(
                .WIDTH(WIDTH),
                .TRUNC_BITS(TRUNC_BITS),
                .CORRECTION(CORRECTION)
            ) u_mac (.clk(clk),
                    .rst(rst),
                    .a(a^XOR_A), 
                    .b(b^XOR_B),
                    .valid(valid),
                    .acc(acc_flat[(i+1)*4*WIDTH-1:i*4*WIDTH])
                );
        end
    endgenerate


endmodule
