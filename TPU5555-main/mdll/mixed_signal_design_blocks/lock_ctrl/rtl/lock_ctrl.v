// Coarse-acquisition controller for the MDLL: TDC -> DCO code, then hand over.
//
// clk_gen is a gated ring: it runs N=4 DCO periods from each injection, raises
// div, and then waits for the next clk_ref edge. The wait is the frequency
// error the loop has to null,
//
//     e = T_REF - 4*T_DCO          (> 0: ring too fast)
//
// and the Vernier TDC measures it directly: slow ring started by div, fast
// ring by the next clk_ref. The fine loop (bbpd's pd + dlf) only ever sees the
// SIGN of e and walks the code one LSB per reference cycle. This module
// shortens that walk: while the ring is far from lock it turns TDC readings
// into code jumps, then gets out of the way.
//
// The TDC can only measure one side. A ring that is too slow reaches div
// after clk_ref, the fast ring starts first, and the TDC reports `hit` -- the
// same answer as "close enough". So acquisition must approach from the fast
// side and never overshoot:
//
//   * Reset forces a fast start code (START), so the first reading is always
//     on the measurable side. Not 0x00: with clk_gen's inv_2 / cap_8 ring
//     (2026-10-30) the lowest codes are so fast that clk_gen's divider
//     release (x12) misses the injection's own edge (8-bit codes <= 16 at ss,
//     <= 8 at tt/ff), so div comes after 5 DCO periods -- at ss near 6-bit 4
//     a fast ring could then read as `hit`. START is fast at every corner
//     (4*T_DCO ~8.5 ns at ss with the extracted wiring) and above that region.
//   * The code-per-picosecond gain K is set BELOW the smallest real one (see
//     K_NUM/K_SHIFT), so each jump under-corrects and the next reading is
//     still on the fast side.
//   * It hands over on `hit`, or as soon as a correction would be smaller
//     than one DCO step -- the coarse loop has then reached its resolution,
//     and a zero-size jump would otherwise stall it.
//
// Arming only on injecting edges. A slow ring overshoots the next clk_ref, so
// that edge does NOT inject: the ring idles until the one after. A run armed
// on such a skipped edge would start the slow ring on a div shortly after it
// and the fast ring a whole period later -- a large, bogus "too fast" reading
// that jumps the code the wrong way. So the TDC is armed only in a cycle where
// clk_gen's injection window `inj` (its `sel`: armed after the 3rd DCO edge,
// it rises about half a DCO period before div and stays high until just after
// the injection; clk_gen/simulations/gate_check.py) was high at the clock
// edge, i.e. on an edge that injects. `inj` is sampled asynchronously; it can
// only be ambiguous when sel rises right at the edge, i.e. div about half a
// DCO period late -- and then the worst outcome is a run that never starts,
// which the WAIT timeout turns into a handover.
// A slow ring may also never produce an injecting edge at all: clk_gen only
// gates (waits for clk_ref) when sel rises while clk_ref is LOW; if it rises
// in the high half -- div more than about half a DCO period late -- sel
// merely glitches and the ring free-runs. So ARM times out too, and "no
// injecting edge for TMO cycles" hands over; if the ring keeps missing
// injections there, FINE restarts acquisition (see Re-acquisition below).
// (Found in the transistor-level closed loop, 2026-09-28: stuck in ARM.)
// (The window this guards is narrow in practice: the TDC's own ~0.67 ns arming
// latency already turns an overshoot of up to about two DCO steps into a
// correct `hit`, and beyond T_REF/2 the bang-bang pd misreads the sign anyway.
// It is cheap and formally proven, so it stays -- see simul/tb_acq.v.)
//
// TDC handshake. The TDC arms a run on every second rising edge of its Sel
// input, starting with the first after Start rises (x8 toggles, x9 fires on
// x8's rising Q). Each measurement therefore raises Start, sends ONE Sel pulse,
// waits for busy to rise and fall (two-flop synchroniser), reads the counts --
// stable, because no further Sel pulse is sent -- and drops Start again, which
// clears the counts and puts x8 back in its reset phase for the next one.
//
// Three states, and every edge of a measurement does something:
//
//   edge  state  action
//   A     WAIT   busy_s fell: read the counts; jump (seed <= target) or hand
//                over; Start low
//   A+1   ARM    Start high; dlf loads the jump -- the ring's run from this
//                edge is the one that sees the code change mid-flight
//   A+2   ARM    Sel (on an injecting edge): measures the run from A+2, the
//                first one entirely on the new code
//
// So the cycle with Start low is also the cycle dlf needs to take the jump;
// a separate settle state would only delay Sel. After reset, load and seed
// already force START, so the first measurement starts the same way at A+1.
//
// The loop filter is frozen for the whole coarse phase: load stays high and
// seed holds the last value loaded (START from reset, then each jump target), so
// dlf keeps reloading the same code. Otherwise dlf's bang-bang path would keep
// stepping the code while a measurement is in flight. (seed must NOT follow
// code: seed is registered, so seed <= code would reload the code from two
// edges back and make it alternate between the old and the new value.)
//
// Re-acquisition. FINE is left again -- back to ARM, exactly as after reset:
// locked low, the code forced to START, a fresh measurement -- when the lock is
// evidently gone. Two signs, both checked against tb_acq's fault injection
// (simul/sweep_variants.py --faults):
//
//   * Missed injections. In lock sel rises ~1 ns before the 4th DCO edge,
//     in the low half of clk_ref, so EVERY rising edge injects. A ring late
//     by more than ~T_DCO/2 only glitches sel in the high half and free-runs.
//     A slowed ring usually does not run to a rail: it finds a false lock
//     (e.g. 4*T_DCO ~ 1.5*T_REF, div alternating between the rising and the
//     falling edge, the pd split evenly between early and late) in which
//     every other edge still injects. So the misses are counted until CLR
//     consecutive edges inject, not required back to back: MISS of them
//     restart.
//   * The code at a rail (0x00 or 0xFF) for RAIL cycles. A ring out of range
//     -- too slow even at 0x00, or too fast even at 0xFF -- injects on every
//     edge, and the pd then drives dlf into its limit and holds it there.
//
// inj is asynchronous to clk_ref. In FINE it goes through one flop (inj_q)
// before it reaches the counters, so a sample taken while sel moves cannot
// resolve differently in different counter bits. In lock sel moves ~1 ns
// before and ~0.3 ns after the edge, so that only happens out of lock.

module lock_ctrl #(
    // T_slow / (T_slow - T_fast): slow-ring periods per TDC LSB. The two rings
    // are the same cells, so this ratio is PVT-invariant by construction
    // (tdc/simulations/char_osci.py checks that). Measured ~60 in the
    // clk_gen -> TDC open-loop run (simulations/char_acq.py).
    parameter integer R       = 60,
    // Jump = err * K_NUM / 2^K_SHIFT, in 8-bit code LSBs. One 8-bit LSB moves
    // e by a quarter DCO step (dither): 49..68 ps at tt between START and the
    // lock point (clk_gen's inv_2 / cap_8 characterisation, 2026-10-30), and
    // one TDC LSB is ~17.8 ps, so the exact gain is 0.26..0.36 LSB per TDC
    // LSB. At the other corners both scale alike (the TDC rings are delay
    // cells too). 3/16 is below the whole range: every jump under-corrects.
    parameter integer K_NUM   = 3,
    parameter integer K_SHIFT = 4,
    // Handover once a jump would be smaller than this, in code LSBs. clk_gen
    // dithers code[1:0] (rtl/dco_decode.v), so every LSB moves div by a
    // quarter DCO step and the TDC sees fractional codes: at STEP = 4 (one
    // whole step, from before the dither) the under-correcting K handed over
    // two steps short at the slow corner (tb_acq). STEP = 2 meets the
    // one-step handover in all of sim_acq; settling takes at most 4 cycles
    // longer (41 vs 37 worst case), STEP = 1 up to 12.
    parameter integer STEP    = 2,
    // ARM/WAIT timeout in reference cycles. A real run ends within R fast-ring
    // periods of clk_ref (the Vernier only catches up the remainder below one
    // slow period): ~7 cycles at tt, ~12 at ss, where the rings are slower
    // (busy high ~12 cycles in the ss / 1.08 V / 125 C mixed run). A fast ring
    // injects on every edge.
    parameter integer TMO     = 31,
    // Out of lock (FINE): MISS edges without injection restart acquisition,
    // forgotten after CLR consecutive injecting edges; so do RAIL cycles with
    // the code at 0x00/0xFF. Widths: MISS <= 4, CLR <= 16, RAIL <= 8.
    parameter integer MISS    = 2,
    parameter integer CLR     = 16,
    parameter integer RAIL    = 8,
    // The code acquisition starts from, after reset and after a restart:
    // 6-bit 6. See the header (why not 0x00).
    parameter integer START   = 8'h18
) (
    input  wire       clk,       // clk_ref
    input  wire       resetb,    // async, active low
    input  wire       inj,       // clk_gen sel: this clk_ref edge injects
    // TDC
    input  wire       busy,      // high while a run is in progress (async)
    input  wire       hit,       // captured: clk_ref too close to/before div
    input  wire [7:0] tdc_s,     // captured slow-ring count
    input  wire [7:0] tdc_f,     // captured fast-ring count
    output reg        start,     // TDC enable; low clears it
    output reg        sel,       // TDC arming strobe
    // loop filter
    input  wire [7:0] code,      // dlf output
    output reg        load,
    output reg  [7:0] seed,
    output wire       locked
);

    localparam [1:0] S_ARM  = 2'd0,  // Start high; one Sel on an injecting edge
                     S_WAIT = 2'd1,  // busy seen high, then low: jump or hand over
                     S_FINE = 2'd2;  // bang-bang owns the code

    reg [1:0] state;
    reg [4:0] tmo;
    reg       inj_q;                 // inj at the last edge, for FINE only
    reg [1:0] miss;                  // edges without injection
    reg [3:0] irun;                  // consecutive injecting edges
    reg [2:0] rail;                  // consecutive cycles at 0x00/0xFF

    // busy is asynchronous to clk_ref: two-flop synchroniser.
    reg busy_m, busy_s, seen_busy;
    always @(posedge clk or negedge resetb)
        if (!resetb) {busy_m, busy_s} <= 2'b00;
        else         {busy_m, busy_s} <= {busy, busy_m};

    // Interval in TDC LSBs: t = s*T_s - f*T_f = (s-f)*T_s + f*(T_s-T_f).
    // s < f cannot happen for a real run; treat it as no measurable error.
    // Widths: 255*255 + 255 < 2^16, and K_NUM < 16.
    localparam [7:0]  R8    = R[7:0];
    localparam [3:0]  KN    = K_NUM[3:0];
    localparam [19:0] STEPW = STEP[19:0];
    localparam [4:0]  TMOW  = TMO[4:0];
    localparam [7:0]  STARTW = START[7:0];
    localparam [1:0]  MISSW = MISS[1:0] - 2'd1;
    localparam [3:0]  CLRW  = CLR[3:0]  - 4'd1;
    localparam [2:0]  RAILW = RAIL[2:0] - 3'd1;

    wire at_rail = (code == 8'h00) || (code == 8'hFF);

    wire        s_ge_f = tdc_s >= tdc_f;
    wire [7:0]  ds     = tdc_s - tdc_f;
    wire [15:0] err    = s_ge_f ? {8'd0, ds} * {8'd0, R8} + {8'd0, tdc_f} : 16'd0;
    wire [19:0] prod   = {4'd0, err} * {16'd0, KN};
    wire [19:0] jump   = prod >> K_SHIFT;
    wire [8:0]  sum    = {1'b0, code} + {1'b0, jump[7:0]};
    wire [7:0]  target = (|jump[19:8] || sum[8]) ? 8'hFF : sum[7:0];
    wire        at_res = jump < STEPW;  // below one DCO step

    assign locked = (state == S_FINE);

    always @(posedge clk or negedge resetb) begin
        if (!resetb) begin
            state     <= S_ARM;
            start     <= 1'b0;
            sel       <= 1'b0;
            load      <= 1'b1;           // with seed: force the start code
            seed      <= STARTW;
            seen_busy <= 1'b0;
            tmo       <= 5'd0;
            inj_q     <= 1'b0;
            miss      <= 2'd0;
            irun      <= 4'd0;
            rail      <= 3'd0;
        end else begin
            sel   <= 1'b0;
            load  <= 1'b1;
            inj_q <= inj;
            miss  <= 2'd0;
            irun  <= 4'd0;
            rail  <= 3'd0;
            case (state)
                S_ARM: begin
                    // Start goes high first; Sel follows no earlier than the
                    // next cycle, so x8 is out of reset when it arrives.
                    start     <= 1'b1;
                    seen_busy <= 1'b0;
                    tmo       <= tmo + 5'd1;
                    if (start && inj) begin
                        sel   <= 1'b1;
                        tmo   <= 5'd0;
                        state <= S_WAIT;
                    end else if (tmo == TMOW) begin  // no injecting edge
                        start <= 1'b0;
                        load  <= 1'b0;
                        state <= S_FINE;
                    end
                end
                S_WAIT: begin
                    tmo <= tmo + 5'd1;
                    if (busy_s) seen_busy <= 1'b1;
                    if (seen_busy && !busy_s) begin  // counts are stable
                        start <= 1'b0;               // clears counts and x8
                        tmo   <= 5'd0;
                        if (hit || at_res) begin
                            load  <= 1'b0;
                            state <= S_FINE;
                        end else begin
                            seed  <= target;
                            state <= S_ARM;
                        end
                    end else if (tmo == TMOW) begin  // run never happened
                        start <= 1'b0;
                        load  <= 1'b0;
                        state <= S_FINE;
                    end
                end
                S_FINE: begin
                    load  <= 1'b0;
                    start <= 1'b0;
                    if (inj_q) begin
                        irun <= (irun == CLRW) ? irun : irun + 4'd1;
                        miss <= (irun == CLRW) ? 2'd0 : miss;
                    end else
                        miss <= miss + 2'd1;
                    rail <= at_rail ? rail + 3'd1 : 3'd0;
                    if ((!inj_q && miss == MISSW) || (at_rail && rail == RAILW)) begin
                        // out of lock: start over, as after reset
                        state <= S_ARM;
                        load  <= 1'b1;
                        seed  <= STARTW;
                        tmo   <= 5'd0;
                        miss  <= 2'd0;
                        irun  <= 4'd0;
                        rail  <= 3'd0;
                    end
                end
                default: state <= S_ARM;
            endcase
        end
    end

endmodule
