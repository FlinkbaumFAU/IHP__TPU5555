// Self-checking testbench for counter.v.
//
// Checks the reset value, one increment per rising edge over more than a full
// wrap, and that asserting rst_n mid-count clears it asynchronously -- i.e.
// without waiting for a clock edge.
//
// make sim_rtl runs it under verilator (--binary --timing).

`timescale 1ns / 1ps

module tb_counter;

    localparam integer COUNTER_WIDTH = 8;
    localparam integer PERIOD        = 10;

    reg                      clk   = 1'b0;
    reg                      rst_n = 1'b0;
    wire [COUNTER_WIDTH-1:0] count;

    reg  [COUNTER_WIDTH-1:0] expected;
    integer                  errors = 0;
    integer                  i;

    counter #(.COUNTER_WIDTH(COUNTER_WIDTH)) uut (
        .clk  (clk),
        .rst_n(rst_n),
        .count(count)
    );

    always #(PERIOD/2) clk = ~clk;

    task check(input [COUNTER_WIDTH-1:0] want, input [8*24-1:0] what);
        if (count !== want) begin
            $display("FAIL %0s @ %0t: count = %0d, expected %0d",
                     what, $time, count, want);
            errors = errors + 1;
        end
    endtask

    initial begin
        // Held in reset across several clock edges.
        #(2*PERIOD + 1);
        check(0, "reset");

        // Release between edges, then one increment per rising edge, for
        // more than a full wrap.
        rst_n    = 1'b1;
        expected = 0;
        for (i = 0; i < (1 << COUNTER_WIDTH) + 16; i = i + 1) begin
            @(posedge clk); #1;
            expected = expected + 1'b1;
            check(expected, "increment");
        end

        // Asynchronous clear: mid-period, no clock edge involved.
        #(PERIOD/4);
        rst_n = 1'b0;
        #1;
        check(0, "async reset");

        if (errors == 0) $display("PASS: counter");
        else             $display("FAIL: counter, %0d error(s)", errors);
        $finish;
    end

endmodule
