// Simple counter module for lint testing

module counter (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        enable,
    output logic [7:0]  count
);

always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        count <= 8'h00;
    end else if (enable) begin
        count <= count + 8'h01;
    end
end

endmodule
