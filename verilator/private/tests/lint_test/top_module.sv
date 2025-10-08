// Top module with dependencies for testing transitive linting

module top_module (
    input  logic       clk,
    input  logic       rst_n,
    input  logic       enable,
    input  logic       mux_sel,
    input  logic [7:0] mux_b_in,
    output logic [7:0] result
);

logic [7:0] counter_out;

// Instantiate counter
counter counter_inst (
    .clk(clk),
    .rst_n(rst_n),
    .enable(enable),
    .count(counter_out)
);

// Instantiate mux
mux #(.WIDTH(8)) mux_inst (
    .a(counter_out),
    .b(mux_b_in),
    .sel(mux_sel),
    .out(result)
);

endmodule
