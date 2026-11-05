// Vernier ring counter: counts rising edges of one TDC ring.
//
// src/tdc.sch instantiates it twice, once per ring, through counter.sym. It is
// clocked straight off the ring output, so the count is the number of ring
// periods since rst_n was released.
//
// Asynchronous active-low reset, free-running wrap at 2^COUNTER_WIDTH.

module counter #(
    parameter COUNTER_WIDTH = 8
) (
    input  wire                     clk,
    input  wire                     rst_n,
    output reg  [COUNTER_WIDTH-1:0] count
);

    always @(posedge clk or negedge rst_n)
        if (!rst_n)
            count <= {COUNTER_WIDTH{1'b0}};
        else
            count <= count + 1'b1;

endmodule
