// 4-bit shift register built from individual registers
// Shifts LSB first, so first bit in ends up at MSB position
module shift_register (
    input logic clk,
    input logic rst_n,
    input logic serial_in,
    output logic [3:0] parallel_out
);

logic [3:0] shift_chain;

// Chain of 4 registers - shifts right to left (serial_in goes to MSB)
d_register #(.WIDTH(1)) reg3 (
    .clk(clk),
    .rst_n(rst_n),
    .d(serial_in),
    .q(shift_chain[3])
);

d_register #(.WIDTH(1)) reg2 (
    .clk(clk),
    .rst_n(rst_n),
    .d(shift_chain[3]),
    .q(shift_chain[2])
);

d_register #(.WIDTH(1)) reg1 (
    .clk(clk),
    .rst_n(rst_n),
    .d(shift_chain[2]),
    .q(shift_chain[1])
);

d_register #(.WIDTH(1)) reg0 (
    .clk(clk),
    .rst_n(rst_n),
    .d(shift_chain[1]),
    .q(shift_chain[0])
);

assign parallel_out = shift_chain;

endmodule

