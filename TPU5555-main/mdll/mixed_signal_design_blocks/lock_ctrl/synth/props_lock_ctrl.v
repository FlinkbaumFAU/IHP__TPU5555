// Formal properties for lock_ctrl, proved by BMC with plain `yosys sat`
// (synth/props_lock_ctrl.tcl), as bbpd/synth/props_dlf.v.
//
// The real dlf closes the code loop (bbpd/rtl/dlf.v); everything else -- the
// TDC counts, hit, busy, clk_gen's injection window inj, and the comparator's
// comp -- is left free, so the properties hold for ANY behaviour of the TDC,
// clk_gen and the phase detector, including a TDC that reports nonsense.
//
// Wrapper rather than asserts inside lock_ctrl.v so that the RTL stays a
// plain synthesisable module.

module lock_ctrl_props (
    input  wire       clk,
    input  wire       resetb,
    input  wire       busy,
    input  wire       hit,
    input  wire [7:0] tdc_s,
    input  wire [7:0] tdc_f,
    input  wire       comp,
    input  wire       inj
);

    // lock_ctrl's start code, passed to the DUT so the properties check the
    // value it is built with.
    localparam [7:0] START = 8'h18;

    wire       start, sel, load, locked;
    wire [7:0] seed, code;

    // PREG = 0: the single-clock equivalent of dlf's clk_ref re-register.
    dlf #(.PREG(0)) u_dlf (
        .clk_ref (clk), .clk (clk), .resetb (resetb), .comp (comp),
        .load (load), .seed (seed), .code (code)
    );

    lock_ctrl #(.START(START)) dut (
        .clk (clk), .resetb (resetb), .inj (inj),
        .busy (busy), .hit (hit), .tdc_s (tdc_s), .tdc_f (tdc_f),
        .start (start), .sel (sel),
        .code (code), .load (load), .seed (seed), .locked (locked)
    );

    // Edges taken since reset release or a restart, saturating at 3.
    reg [1:0] n;
    reg [7:0] prev_code;
    reg       prev_locked, prev2_locked, prev_start, prev_inj, prev2_inj, prev3_inj, sel_seen;
    reg [5:0] armwait;      // consecutive cycles with Start high and no Sel yet
    reg [3:0] rail_run;     // consecutive edges with the code at 0x00/0xFF, saturating
    reg [3:0] lock_age;     // consecutive edges locked, saturating
    wire      at_rail = (code == 8'h00) || (code == 8'hFF);
    wire      fell    = prev_locked && !locked;

    always @(posedge clk or negedge resetb) begin
        if (!resetb) begin
            n           <= 2'd0;
            prev_code   <= 8'h00;
            prev_locked <= 1'b0;
            prev2_locked <= 1'b0;
            prev_start  <= 1'b0;
            prev_inj    <= 1'b0;
            prev2_inj   <= 1'b0;
            prev3_inj   <= 1'b0;
            rail_run    <= 4'd0;
            lock_age    <= 4'd0;
            sel_seen    <= 1'b0;
            armwait     <= 6'd0;
        end else begin
            armwait     <= (start && !sel && !sel_seen) ? armwait + 6'd1 : 6'd0;
            prev_start  <= start;
            prev_inj    <= inj;
            prev2_inj   <= prev_inj;
            prev3_inj   <= prev2_inj;
            // sel pulses seen since Start last rose (Start low clears x8)
            sel_seen    <= start && (sel_seen || sel);
            if (fell)            n <= 2'd0;      // a restart forces START again
            else if (n != 2'd3)  n <= n + 2'd1;
            prev_code   <= code;
            prev_locked <= locked;
            prev2_locked <= prev_locked;
            rail_run    <= !at_rail ? 4'd0 : (rail_run == 4'd15 ? rail_run : rail_run + 4'd1);
            lock_age    <= !locked  ? 4'd0 : (lock_age == 4'd15 ? lock_age : lock_age + 4'd1);
        end
    end

    always @(posedge clk) begin
        if (resetb) begin
            // 1. Once locked, the controller is completely out of the loop:
            //    no loads into dlf, TDC disabled, no arming strobes.
            a_fine_hands_off:
                assert (!locked || (!load && !start && !sel));

            // 2. Re-acquisition only on evidence: locked falls only after an
            //    edge that did not inject (lock_ctrl acts on it one edge
            //    later, through inj_q) or with the code at a rail for RAIL = 8
            //    edges. In a lock every edge injects and the code stays off
            //    the rails, so the lock is never dropped.
            a_restart_justified:
                assert (!fell || !prev2_inj || rail_run >= 4'd8);

            //    A restart starts over exactly as reset does: the start code
            //    (fast at every corner) is forced, so acquisition again
            //    approaches from the measurable side.
            a_restart_forces_fast:
                assert (!fell || (load && seed == START));

            //    And the evidence is acted on: two consecutive edges without
            //    injection while locked restart (the window that forgets
            //    single misses needs 16 injecting edges in between) ...
            a_restart_on_misses:
                assert (!(prev2_locked && !prev2_inj && !prev3_inj) || !locked);

            //    ... and so does a code stuck at a rail.
            a_restart_on_rail:
                assert (!(locked && lock_age >= 4'd10 && rail_run >= 4'd10));

            // 3. Once the force to START (after reset or a restart) has landed,
            //    the code never moves DOWN (towards faster) while lock_ctrl
            //    owns it -- whatever
            //    comp says, since dlf is frozen, and whatever the TDC reports.
            //    Acquisition approaches from the fast side; a decrease would
            //    push the ring away from lock, and a wrap past 0xFF would show
            //    up as exactly such a decrease. (The edge on which a restart
            //    drops locked still belongs to dlf: its last bang-bang step
            //    may go down -- `fell`.)
            a_code_never_down:
                assert (n < 2'd3 || locked || fell || code >= prev_code);

            // 4. The TDC is enabled a cycle before it is armed, so its toggle
            //    flop (x8) is out of reset when Sel arrives -- and armed only
            //    on an edge that injects.
            a_sel_needs_start:
                assert (!sel || (start && prev_start));
            a_sel_on_injection:
                assert (!sel || prev_inj);

            // 6. Liveness, bounded: lock_ctrl never sits more than ~TMO cycles
            //    with Start high and no Sel -- whatever inj does. A ring late
            //    by more than about half a DCO period only glitches sel in the
            //    high half, never at a rising edge, and the controller must
            //    not wait for it forever.
            a_arm_bounded:
                assert (armwait < 6'd40);

            // 5. Exactly one Sel pulse per Start-high interval: a second one
            //    would toggle x8 back and re-arm, and a later capture could
            //    then change the counts while they are being read.
            a_one_sel_per_start:
                assert (!sel || !sel_seen);
        end
    end

endmodule
