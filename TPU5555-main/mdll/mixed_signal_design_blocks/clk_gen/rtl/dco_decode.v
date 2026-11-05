// DCO cap-bank decoder: 8-bit loop-filter code -> 63 unit-capacitor enables,
// permuted into the eight per-delay-cell buses that dco.sch wires up.
//
// The ring has 4 differential delay cells (x3..x6 in dco.sch), each loading
// both `out` and `outb`, giving 8 capacitively loaded nodes and 16 unit-cap
// slots per cell -- 64 slots for 63 thermometer bits.
//
// Slot assignment, for cell c (0..3), side s (0 = co/out, 1 = cob/outb),
// slot p (0..7):
//
//     co_c[p]  <- therm[8*p + 2*c    ]
//     cob_c[p] <- therm[8*p + 2*c + 1]
//
// (c,p,s) maps bijectively onto 0..63, so index 63 has no thermometer bit
// behind it and cob3[7] ties low. Cells 0..2 carry 16 units, cell 3 carries 15.
//
// Consequences of consecutive thermometer bits being an out/outb pair:
//   - out/outb imbalance never exceeds one unit cap at any code
//   - the four cells fill round-robin, so their loads differ by <= 2 units
//
// Dither. The loop filter accumulates 8 bits; the cap bank has 63 units, i.e.
// resolves code[7:2] = N. code[1:0] = k adds unit N (the next one) for the
// LAST k of the 4 DCO periods of each run, so div -- the sum of the four --
// moves in quarter steps: 4*T(N) + k*(T(N+1) - T(N)). Within one run, not as
// an average over runs: every run is re-injected, so only the sum inside a run
// counts (lock_ctrl/simul/sweep_variants.py; dithering the first k periods
// instead loses the gain once the code updates mid-run).
//
// g[1:0] is clk_gen's divider count of the current run's periods, in Gray
// (00, 01, 11, 10 = period 0..3; the divider is a Johnson counter), so one bit
// changes per DCO edge and
//     frac_on = (period >= 4 - k):  k=1: g1 & ~g0,  k=2: g1,  k=3: g1 | g0
// is one gate per k with a single changing input: no glitch on a cap enable
// while the ring runs. In period 0 frac_on is 0 for every k, and that is when
// the loop filter updates the code, so a change of k cannot glitch it either.
// frac_on and each unit's enable (therm[i] | frac_on & therm[i-1]) are built
// from kept modules (synth/synth_decode.tcl) so abc keeps that structure.
// N = 63 has no unit 64: codes 0xFC..0xFF are all full scale.

module dco_decode #(
    parameter integer NBIT  = 6,   // DCO resolution
    parameter integer NSKIP = 2    // code LSBs discarded
) (
    input  wire [NBIT+NSKIP-1:0] code,
    input  wire [1:0]            g,     // divider's Gray period count
    output wire [7:0]            co0,
    output wire [7:0]            cob0,
    output wire [7:0]            co1,
    output wire [7:0]            cob1,
    output wire [7:0]            co2,
    output wire [7:0]            cob2,
    output wire [7:0]            co3,
    output wire [7:0]            cob3
);

    localparam integer NTHERM = (1 << NBIT) - 1;   // 63
    localparam integer NSLOT  = (1 << NBIT);       // 64

    wire [NTHERM-1:0] therm;

    bin2therm #(.NBIT(NBIT)) u_therm (
        .bin   (code[NBIT+NSKIP-1:NSKIP]),
        .therm (therm)
    );

    // frac_on: this period is one of the last k of the run.
    wire [1:0] k = code[NSKIP-1:0];
    wire n3, n1, frac_on;
    dco_andn u_n3 (.a (g[1]), .b (g[0]), .y (n3));     // period 3
    dco_or   u_n1 (.a (g[1]), .b (g[0]), .y (n1));     // periods 1..3
    dco_mux4 u_fr (.s (k), .d0 (1'b0), .d1 (n3), .d2 (g[1]), .d3 (n1), .y (frac_on));

    // Unit i is on below N, and unit N while frac_on.
    wire [NTHERM-1:0] en;
    genvar u;
    generate
        for (u = 0; u < NTHERM; u = u + 1) begin : g_en
            if (u == 0) begin : first
                dco_or u_e (.a (therm[0]), .b (frac_on), .y (en[0]));
            end else begin : rest
                dco_ao u_e (.a (therm[u]), .b (frac_on), .c (therm[u - 1]), .y (en[u]));
            end
        end
    endgenerate

    // Slot 63 has no thermometer bit behind it -- tie it low.
    wire [NSLOT-1:0] therm_ext = {1'b0, en};

    // tc[16*c + 8*s + p] is cell c, side s, slot p.
    wire [NSLOT-1:0] tc;

    genvar c, s, p;
    generate
        for (c = 0; c < 4; c = c + 1) begin : g_cell
            for (s = 0; s < 2; s = s + 1) begin : g_side
                for (p = 0; p < 8; p = p + 1) begin : g_slot
                    assign tc[16*c + 8*s + p] = therm_ext[8*p + 2*c + s];
                end
            end
        end
    endgenerate

    assign co0  = tc[ 7: 0];
    assign cob0 = tc[15: 8];
    assign co1  = tc[23:16];
    assign cob1 = tc[31:24];
    assign co2  = tc[39:32];
    assign cob2 = tc[47:40];
    assign co3  = tc[55:48];
    assign cob3 = tc[63:56];

endmodule

// The gates frac_on and the enables are made of; kept through mapping.
module dco_andn (input wire a, input wire b, output wire y);
    assign y = a & ~b;
endmodule

module dco_or (input wire a, input wire b, output wire y);
    assign y = a | b;
endmodule

module dco_ao (input wire a, input wire b, input wire c, output wire y);
    assign y = a | (b & c);
endmodule

module dco_mux4 (input wire [1:0] s, input wire d0, input wire d1,
                 input wire d2, input wire d3, output wire y);
    assign y = s[1] ? (s[0] ? d3 : d2) : (s[0] ? d1 : d0);
endmodule
