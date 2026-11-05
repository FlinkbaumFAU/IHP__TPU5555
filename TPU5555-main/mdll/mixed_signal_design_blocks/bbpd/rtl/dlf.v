// Digital loop filter for the MDLL's sequential-tracking mode.
//
// A first-order bang-bang accumulator: the phase comparator in src/pd.sch
// reports only the SIGN of the phase error, so the filter integrates that sign
// into the DCO's 8-bit control code.
//
//     comp = 1  ->  div edge LATE   ->  4*T_DCO > T_REF  ->  ring too slow
//     comp = 0  ->  div edge EARLY  ->  4*T_DCO < T_REF  ->  ring too fast
//
// clk_gen's cap bank is monotonic in the direction code-up => frequency-down
// (63 identical unit caps under a thermometer code), so "too slow" means
// decrement and "too fast" means increment. That monotonicity is what makes a
// sign-only loop converge at all: the step direction is never wrong, so the
// code walks straight to lock and then dithers about it.
//
// Two properties this module must hold, both checked in simulations/:
//
//   1. It SATURATES. A wrap at 0x00 or 0xFF would invert the loop sign for one
//      step and kick the DCO to the opposite end of its range.
//   2. It moves by at most one LSB per reference cycle. The loop gain lives
//      here and nowhere else.
//
// load/seed is lock_ctrl's preset (coarse acquisition, restart).
//
// Timing: an update early in the next run
// ----------------------------------------
// The decision on run k (div vs. clk_ref) exists only at the clk_ref edge that
// starts run k+1. The code is updated D_DLF ~1 ns after that edge (clk, from
// pd.sch's delay chain), so the decision already acts on run k+1 instead of
// k+2 -- the bang-bang limit cycle then spans one LSB instead of three
// (lock_ctrl/simul/sweep_variants.py). Two consequences shape this module:
//
//   * comp is unresolved routinely. At lock div sits at the pd's threshold by
//     design, and x1/x2 get only a few tau (~56 ps at tt, ~100 ps at ss,
//     simulations/char_meta.py) before this update. So the state is held in
//     GRAY code: code+1 and code-1 then differ in at most two bits, and comp
//     reaches only those (dlf_and: comp AND "this bit differs", a NAND-based
//     cell that holds a solid 0 when the other input is 0, whatever level comp
//     is at). However the flops resolve, the result is within +-2 LSB of the
//     current code -- an ordinary dither step. In binary the carry chain made
//     it anything up to +-127 (0x7F/0x80).
//   * lock_ctrl's load/seed arrive ~0.8 ns after clk_ref (1.3 ns at ss), too
//     late for this clock. They are re-registered on clk_ref (load_q, seed_q)
//     and loaded at the next update -- one reference period after lock_ctrl
//     set them, exactly as when this module ran on clk_ref itself.
//     They reset to "load RESET_CODE", lock_ctrl's own reset values (load
//     high, seed START), so no update between reset and lock_ctrl's preset
//     follows comp.
//     PREG = 0 bypasses that stage, for the single-clock formal models, where
//     it is the cycle-equivalent (yosys' sat steps every flop each cycle).
//
// code is the binary value (lock_ctrl and clk_gen's decoder use binary).

module dlf #(
    // Code after reset: lock_ctrl's START (lock_ctrl/rtl/lock_ctrl.v), the
    // code acquisition starts from. The two are separate macros, so it is
    // repeated here; simulations/check_mdll.py fails if they differ. With
    // load/seed preset to load it as well, the code is START from reset
    // through lock_ctrl's first preset: the ring's first run after reset
    // (mdll.sch's start controller) is at START, not at a code that dlf's
    // first, unloaded update stepped and lock_ctrl's preset then overwrote
    // part-way through that run.
    parameter [7:0] RESET_CODE = 8'h18,
    parameter       PREG       = 1
) (
    input  wire       clk_ref,  // clk_ref: re-registers load/seed
    input  wire       clk,      // clk_ref delayed ~1 ns (pd.sch clk_dlf): the update
    input  wire       resetb,   // async, active low
    input  wire       comp,     // pd's decision, possibly unresolved
    input  wire       load,     // synchronous preset, takes priority over comp
    input  wire [7:0] seed,
    output wire [7:0] code
);

    function automatic [7:0] bin2gray(input [7:0] b);
        bin2gray = b ^ (b >> 1);
    endfunction

    function automatic [7:0] gray2bin(input [7:0] g);
        integer i;
        begin
            gray2bin[7] = g[7];
            for (i = 6; i >= 0; i = i - 1)
                gray2bin[i] = gray2bin[i + 1] ^ g[i];
        end
    endfunction

    // lock_ctrl's preset, re-registered on clk_ref
    reg       load_r;
    reg [7:0] seed_r;
    always @(posedge clk_ref or negedge resetb)
        if (!resetb) {load_r, seed_r} <= {1'b1, RESET_CODE};
        else         {load_r, seed_r} <= {load, seed};
    wire       load_q = PREG ? load_r : load;
    wire [7:0] seed_q = PREG ? seed_r : seed;

    genvar i;
    reg  [7:0] g;               // the code, Gray

    // code = gray2bin(g): bit i is the XOR of g[7:i]. As a prefix tree of kept
    // XORs, three levels deep -- left to abc it became an 8-deep ripple
    // (clk -> code[0] 1.64 ns at tt), and code is what switches the caps.
    wire [7:0] p1, p2;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_g2b
            if (i < 7) begin : l1
                dlf_xor u (.a (g[i]), .b (g[i + 1]), .y (p1[i]));
            end else begin : l1
                assign p1[i] = g[i];
            end
            if (i < 6) begin : l2
                dlf_xor u (.a (p1[i]), .b (p1[i + 2]), .y (p2[i]));
            end else begin : l2
                assign p2[i] = p1[i];
            end
            if (i < 4) begin : l3
                dlf_xor u (.a (p2[i]), .b (p2[i + 4]), .y (code[i]));
            end else begin : l3
                assign code[i] = p2[i];
            end
        end
    endgenerate

    // Both neighbours from the state alone (early); load_q picks the preset.
    // From a conversion of their own: on the tree above, the next-state logic
    // loaded its nodes with 10..12 inputs each (clk -> code 1.53 ns at tt).
    wire [7:0] cb = gray2bin(g);
    wire [7:0] gu = (cb == 8'hFF) ? g : bin2gray(cb + 8'd1);
    wire [7:0] gd = (cb == 8'h00) ? g : bin2gray(cb - 8'd1);
    wire [7:0] ul, diff, nxt;

    wire [7:0] gseed = bin2gray(seed_q);

    dlf_ld u_ld (.load (load_q), .seed (gseed), .gu (gu), .gd (gd),
                 .ul (ul), .diff (diff));

    // nxt = ul ^ (diff & comp), per bit, as kept gates (synth/synth_dlf.tcl):
    // comp meets each bit only through an AND whose other input is static.
    wire [7:0] cd;
    generate
        for (i = 0; i < 8; i = i + 1) begin : g_bit
            dlf_and u_and (.a (comp), .b (diff[i]), .y (cd[i]));
            dlf_xor u_xor (.a (ul[i]), .b (cd[i]), .y (nxt[i]));
        end
    endgenerate

    always @(posedge clk or negedge resetb) begin
        if (!resetb) g <= bin2gray(RESET_CODE);
        else         g <= nxt;
    end

endmodule

// ul: the next state for comp = 0 (up, or the preset); diff: the bits in
// which comp = 1 (down) differs -- at most two, none while loading.
module dlf_ld (
    input  wire       load,
    input  wire [7:0] seed,     // Gray
    input  wire [7:0] gu,
    input  wire [7:0] gd,
    output wire [7:0] ul,
    output wire [7:0] diff
);
    assign ul   = load ? seed : gu;
    assign diff = load ? 8'd0 : gu ^ gd;
endmodule

module dlf_and (input wire a, input wire b, output wire y);
    assign y = a & b;
endmodule

module dlf_xor (input wire a, input wire b, output wire y);
    assign y = a ^ b;
endmodule
