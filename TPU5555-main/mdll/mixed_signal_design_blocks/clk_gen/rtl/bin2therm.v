// Binary to thermometer decoder.
//
// therm[i] is high iff bin > i, so exactly `bin` bits are set and the set bits
// are always the contiguous low run. Raising the code can therefore only ever
// turn capacitors ON, never off -- which is what makes the DCO tuning curve
// monotonic by construction rather than by capacitor ratio.

module bin2therm #(
    parameter integer NBIT = 6
) (
    input  wire [NBIT-1:0]      bin,
    output wire [(1<<NBIT)-2:0] therm
);

    genvar i;
    generate
        for (i = 0; i < (1<<NBIT)-1; i = i + 1) begin : g_therm
            assign therm[i] = (bin > i[NBIT-1:0]);
        end
    endgenerate

endmodule
