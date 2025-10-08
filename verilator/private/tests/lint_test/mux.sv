// Simple mux module for lint testing

module mux #(
    parameter WIDTH = 8
) (
    input  logic [WIDTH-1:0] a,
    input  logic [WIDTH-1:0] b,
    input  logic             sel,
    output logic [WIDTH-1:0] out
);

always_comb begin
    if (sel) begin
        out = b;
    end else begin
        out = a;
    end
end

endmodule
