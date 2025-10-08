// Serial-to-parallel converter using shift register
module serial_to_parallel (
    input logic clk,
    input logic rst_n,
    input logic serial_in,
    input logic load_enable,
    output logic [3:0] parallel_out,
    output logic valid
);

logic [3:0] shifted_data;

// Shift register collects serial data
shift_register shifter (
    .clk(clk),
    .rst_n(rst_n),
    .serial_in(serial_in),
    .parallel_out(shifted_data)
);

// Output register with load enable
d_register #(.WIDTH(4)) output_reg (
    .clk(clk),
    .rst_n(rst_n),
    .d(load_enable ? shifted_data : parallel_out),
    .q(parallel_out)
);

// Valid flag
d_register #(.WIDTH(1)) valid_reg (
    .clk(clk),
    .rst_n(rst_n),
    .d(load_enable),
    .q(valid)
);

endmodule

