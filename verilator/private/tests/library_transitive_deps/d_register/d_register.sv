// Simple register module - basic building block
module d_register #(
    parameter int WIDTH = 8
) (
    input logic clk,
    input logic rst_n,
    input logic [WIDTH-1:0] d,
    output logic [WIDTH-1:0] q
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        q <= '0;
    end else begin
        q <= d;
    end
end

endmodule

