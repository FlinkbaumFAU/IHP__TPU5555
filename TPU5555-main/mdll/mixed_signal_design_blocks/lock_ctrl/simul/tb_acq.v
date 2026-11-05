// Behavioural acquisition testbench: the real lock_ctrl and dlf RTL against
// event-level models of clk_gen, pd and the TDC.
//
// The transistor-level closed loop (root test_mdll.sch) takes hours per run.
// This takes milliseconds, so it is where the loop LOGIC is checked -- the
// handshake, convergence, the choice of K, and above all that acquisition never
// overshoots onto the side the TDC cannot measure -- across the model
// parameters that are only known approximately. The transistor-level run then
// only has to confirm that the models were right.
//
// Models (all times in ps):
//   clk_gen  gated ring with clk_gen's M_out guard, after clk_gen's open-loop
//            gate_check (build/gate_check_divgate_a.txt, 2026-10-07). A
//            clk_ref rising edge injects only if the injection window inj
//            (clk_gen's sel) is high at it; inj then falls T_SELF later. The
//            run's DCO periods start D_INJ after the edge; div is the 4th edge.
//            The selector looks at clk_ref T_SELA after the middle of the 4th
//            period (sel, ~1.1 ns before div):
//              - clk_ref low:  sel rises, the ring gates; the next rising edge
//                injects even if the 4th edge (div) comes after it -- a
//                slightly slow ring is still re-aligned every period
//                (code 80 at tt: div +0.64 ns, gated).
//              - clk_ref high, not yet fallen since the injection (too fast,
//                code 0..16): not armed; div still comes at the 4th edge and
//                the ring gates in the next low half.
//              - clk_ref high after a fall (late by more than ~T_DCO/2): sel
//                only glitches, lock_ctrl never sees it; the ring free-runs
//                and its next 4 periods start at this div.
//            T_DCO is the measured table in dco_period.vh, scaled by
//            DCO_PCT/100 to emulate a PVT corner. T_SELF is from
//            simulations/char_acq.py.
//            (Until 2026-10-28 this model raised sel T_SELR = 560 ps AFTER div,
//            which predates the divn1-armed selector: every run that landed
//            within 560 ps of the edge -- the lock point -- went into a
//            falling-edge injection mode the hardware no longer has.)
//   pd       comp_raw = clk_ref sampled on div; comp = comp_raw retimed on the
//            falling edge of clk_ref (bbpd/src/pd.sch x1, x2; +D_DLF moves x2).
//   tdc      x8 toggles on each Sel rise (cleared by Start low); a run starts
//            T_ARM after x8 rises. Slow ring starts on the next div, fast on
//            the next clk_ref. If the fast ring starts less than T_BUF after the
//            slow one (or before it): hit. Otherwise the Vernier counts
//            f = ceil((dt mod T_S) / LSB), s = f + floor(dt / T_S), captured
//            when the fast ring catches up. busy falls T_CLR after capture.
//
//            A run armed on a SKIPPED edge would see div shortly after arming
//            and the fast ring a period later -- a bogus "too fast" reading.
//            lock_ctrl prevents that by arming only when inj is high.
//
// Plusargs: +D_INJ= +T_BUF= +T_S= +T_F= +DCO_PCT= +T_ARM= +T_CLR= +TDC_PCT=
//           +T_SELA= +VERBOSE[=2]
//
// Design variants, all off by default (= the hardware as built):
//   +DITHER     clk_gen dithers code[1:0] = k: the first k of the 4 DCO periods
//               of a run use code[7:2]+1, the rest code[7:2]. +DITHER=2: the
//               LAST k periods -- then every LSB step changes a period that is
//               still ahead when a mid-run (+D_DLF) update lands.
//   +D_DLF=     > 0: dlf is clocked D_DLF ps after clk_ref rising instead of on
//               it, so a decision reaches the code inside the next run; pd's x2
//               then retimes D_X2 ps after clk_ref rising (+D_X2=, default
//               1000) instead of on its falling edge. A period in progress when
//               the code changes finishes its remaining fraction at the new
//               code's speed.
//   +D_CODE=    the code reaches the cap bank D_CODE ps after dlf's clock
//               (dlf's Gray -> binary, routing, clk_gen's decoder; default 0).
//   +MISS_PS=   > 0: a free-running (late) run whose div would land more than
//               MISS_PS after the last rising clk_ref gives no div (gate_check:
//               88..120 lose div in some periods). x1 then keeps its last
//               decision.
//   (Out of lock lock_ctrl restarts acquisition by itself -- missed
//   injections, the code at a rail; see its header. Restarts are counted as
//   falls of locked.)
//   +LATE_FLAG  bbpd's late flag (pd.sch x4/x5): sel rising while clk_ref is
//               high sets late, sel rising while it is low clears it, and x2
//               retimes comp_raw OR late.
//   +FAULT_CYC= +FAULT_PCT=   FAULT_CYC cycles after the first handover the DCO
//               slows by FAULT_PCT/100 (a supply/temperature step). The run
//               then has to relock: locked, off the rails, for SETTLE cycles.
//
// Besides the code band, a locked run reports the lock error div - clk_ref
// (nearest rising edge) over its last NWIN divs: "err a..b ps".
// TDC_PCT scales the interval the counts are computed from (not the hit
// decision): > 100 makes the TDC over-report, forcing coarse overshoot onto
// the slow side, which is how recovery from the slow side is exercised.
//
// PASS judges ACQUISITION, lock_ctrl's job: handover within MAX_CYC reference
// cycles and, unless TDC_PCT > 100, no coarse load past the lock point and a
// handover code within one DCO step of it. The bang-bang loop's dither band
// after handover is reported ("final a..b"), with a NOTE when it strays more
// than two steps: that band is set by clk_gen's selector dead band and the pd,
// not by lock_ctrl (see the clk_gen model above).

`timescale 1ps / 1ps

module tb_acq #(
    // lock_ctrl's STEP (handover threshold, code LSBs): 0 = the RTL's own;
    // build variants with verilator -GTB_STEP=n.
    parameter integer TB_STEP = 0
);

    localparam integer T_REF   = 10000;
    localparam integer MAX_CYC = 400;
    localparam integer SETTLE  = 120;    // cycles observed after handover

    integer D_INJ   = 330;
    integer T_BUF   = 60;
    integer T_S     = 1064;
    integer T_F     = 1047;
    integer DCO_PCT = 100;
    integer T_ARM   = 670;
    integer T_CLR   = 500;
    integer TDC_PCT = 100;
    integer VERBOSE = 0;
    integer DITHER  = 0;
    integer D_DLF   = 0;
    integer D_X2    = 1000;
    integer D_CODE  = 0;
    integer MISS_PS = 0;
    integer T_SELA  = 215;               // middle of the 4th period -> sel
    integer LATE_FLAG = 0;
    integer FAULT_CYC = 0;
    integer FAULT_PCT = 100;
    real    dco_scale = 1.0;             // DCO_PCT/100, times FAULT_PCT/100 after the fault

    integer t_dco [0:63];

    // ---------------------------------------------------------------- clocks
    reg clk_ref = 1'b0;
    reg resetb  = 1'b0;
    always #(T_REF / 2) clk_ref = ~clk_ref;

    // Delayed copies of clk_ref for the +D_DLF variant: dlf's clock and pd x2's.
    reg clk_dlf_d = 1'b0, clk_x2_d = 1'b0;
    always @(clk_ref) begin
        clk_dlf_d <= #(D_DLF) clk_ref;
        clk_x2_d  <= #(D_X2)  clk_ref;
    end
    wire clk_dlf = (D_DLF > 0) ? clk_dlf_d : clk_ref;
    wire clk_x2  = (D_DLF > 0) ? clk_x2_d  : ~clk_ref;

    // ------------------------------------------------------------------- DUT
    wire [7:0] code, seed, tdc_s_w, tdc_f_w;
    wire       load, start, sel, locked;
    reg        comp_raw = 1'b0, comp = 1'b0;

    dlf u_dlf (
        .clk_ref (clk_ref), .clk (clk_dlf), .resetb (resetb), .comp (comp),
        .load (load), .seed (seed), .code (code)
    );

    reg        busy = 1'b0, hit = 1'b0;
    reg  [7:0] tdc_s = 8'd0, tdc_f = 8'd0;

    generate
        if (TB_STEP > 0) begin : g_step
            lock_ctrl #(.STEP(TB_STEP)) u_ctrl (
                .clk (clk_ref), .resetb (resetb),
                .inj (inj),
                .busy (busy), .hit (hit), .tdc_s (tdc_s), .tdc_f (tdc_f),
                .start (start), .sel (sel),
                .code (code), .load (load), .seed (seed), .locked (locked)
            );
        end else begin : g_rtl
            lock_ctrl u_ctrl (
                .clk (clk_ref), .resetb (resetb),
                .inj (inj),
                .busy (busy), .hit (hit), .tdc_s (tdc_s), .tdc_f (tdc_f),
                .start (start), .sel (sel),
                .code (code), .load (load), .seed (seed), .locked (locked)
            );
        end
    endgenerate

    // --------------------------------------------------------- clk_gen model
    // Period n (0..3) of a run at code c. +DITHER: the first code[1:0]
    // periods get one unit more; +DITHER=2: the last code[1:0] (none past the
    // last unit, 63).
    function real tper(input [7:0] c, input integer n);
        integer c6;
        c6 = c[7:2];
        if (c6 < 63 && ((DITHER == 1 && n < c[1:0]) || (DITHER == 2 && n >= 4 - c[1:0])))
            c6 = c6 + 1;
        tper = t_dco[c6] * dco_scale;
    endfunction

    // The code as the cap bank sees it: D_CODE after dlf's output.
    reg [7:0] code_dco = 8'h80;
    always @(code) code_dco <= #(D_CODE) code;

    // Next time after t at which the cap bank's code may change.
    function integer next_upd(input integer t);
        integer base;
        base = T_REF / 2 + D_DLF + D_CODE;
        if (t < base) next_upd = base;
        else          next_upd = base + ((t - base) / T_REF + 1) * T_REF;
    endfunction

    localparam integer T_SELF = 320;     // injecting edge -> sel fall

    // Fraction f of DCO period n from now. If dlf's clock edge falls inside
    // it, the rest runs at the new code's speed.
    task automatic advance(input integer n, input real f);
        integer tu;
        real    tp, tend, left;
        tp   = tper(code_dco, n);
        tend = $realtime + f * tp;
        tu   = next_upd($time);
        while (tu < tend) begin
            #(tu + 1 - $time);           // just after dlf's flops have switched
            left = (tend - $realtime) / tp;
            tp   = tper(code_dco, n);
            tend = $realtime + left * tp;
            tu   = next_upd($time);
        end
        #(tend - $realtime);
    endtask

    reg div  = 1'b0;
    reg inj  = 1'b1;                     // ring idle at reset: first edge injects
    reg fell = 1'b0;                     // clk_ref fell since the injection (x7)
    reg late = 1'b0;                     // bbpd x4: clk_ref at sel's last rise
    integer t_ref = 0;                   // last rising clk_ref
    always @(posedge clk_ref) t_ref = $time;
    always @(negedge clk_ref) fell = 1'b1;

    task automatic pulse_div(input reg late);
        if (late && MISS_PS > 0 && $time - t_ref > MISS_PS && $time - t_ref < T_REF / 2) begin
            if (VERBOSE > 1) $display("  %8t  div missing (%0d ps late)", $time, $time - t_ref);
        end else begin
            div = 1'b1;
            div <= #(1000) 1'b0;
        end
    endtask

    // The rest of the 4th period after the selector has looked (T_SELA past
    // its middle), then div. Forked when the ring gates: a slightly slow ring
    // is re-injected before its div, so the next run must not wait for it.
    task automatic finish_run(input reg late);
        advance(3, 0.5 - T_SELA / tper(code_dco, 3));
        pulse_div(late);
    endtask

    reg free;
    always begin
        @(posedge clk_ref);
        if (resetb && inj) begin
            fell = 1'b0;
            inj <= #(T_SELF) 1'b0;
            #(D_INJ);
            free = 1'b1;
            while (free) begin
                advance(0, 1.0);
                advance(1, 1.0);
                advance(2, 1.0);
                advance(3, 0.5);
                #(T_SELA);
                if (!clk_ref) begin
                    // gates: div at the 4th edge, then wait for the next edge
                    late = 1'b0;
                    inj  = 1'b1;
                    free = 1'b0;
                    fork finish_run(1'b0); join_none
                end else if (!fell) begin
                    // too fast to arm: div at the 4th edge, gate in the low half
                    finish_run(1'b0);
                    @(negedge clk_ref);
                    late = 1'b0;                 // sel rises in the low half
                    inj  = 1'b1;
                    free = 1'b0;
                end else begin
                    // late: sel glitches, the ring free-runs from this div
                    late = 1'b1;
                    finish_run(1'b1);
                end
            end
        end
    end

    // -------------------------------------------------------------- pd model
    always @(posedge div or negedge resetb)
        if (!resetb) comp_raw <= 1'b0; else comp_raw <= clk_ref;
    always @(posedge clk_x2 or negedge resetb)
        if (!resetb) comp <= 1'b0; else comp <= comp_raw | (LATE_FLAG != 0 && late);

    // ------------------------------------------------------------- TDC model
    reg x8q = 1'b0;
    always @(posedge sel or negedge start)
        if (!start) x8q <= 1'b0; else x8q <= ~x8q;

    always @(negedge start) begin
        tdc_s = 8'd0; tdc_f = 8'd0; hit = 1'b0;
    end

    integer ts0, tf0, dt, fr, sr, t_cap, nrun = 0;
    always begin
        @(posedge x8q);
        #(T_ARM);
        if (start) begin
            busy = 1'b1;
            fork
                begin @(posedge div);     ts0 = $time; end
                begin @(posedge clk_ref); tf0 = $time; end
            join
            dt = tf0 - ts0;
            nrun = nrun + 1;
            if (dt < T_BUF) begin
                t_cap = (ts0 > tf0 ? ts0 : tf0) + T_BUF;
                #(t_cap - $time);
                tdc_s = 8'd0; tdc_f = 8'd0; hit = 1'b1;
            end else begin
                dt = dt * TDC_PCT / 100;
                fr = ((dt % T_S) + (T_S - T_F) - 1) / (T_S - T_F);
                sr = fr + dt / T_S;
                t_cap = tf0 + fr * T_F;
                #(t_cap - $time);
                tdc_s = sr > 255 ? 8'd255 : sr[7:0];
                tdc_f = fr > 255 ? 8'd255 : fr[7:0];
                hit   = 1'b0;
            end
            if (VERBOSE)
                $display("  %8t  TDC run %0d: dt=%0d ps -> hit=%0d s=%0d f=%0d",
                         $time, nrun, dt, hit, tdc_s, tdc_f);
            #(T_CLR);
            busy = 1'b0;
        end
    end

    // ------------------------------------------------------------ checking
    // Ideal lock code: the largest 6-bit code whose ring is still (just) fast,
    // i.e. D_INJ + 4*T_DCO <= T_REF. The loop should dither around the step
    // between it and the next code.
    integer c_fast, i, cyc = 0, t_lock = -1, n_load = 0, c_ho = -1;
    integer overshoot = 0, errors = 0;

    // Relock bookkeeping. `run` counts consecutive divs within +-E_OK of a
    // rising clk_ref while locked and off the rails; SETTLE of them is a
    // lock. A reference period without a div clears it.
    localparam integer E_OK = 500;
    integer n_restart = 0, run = 0, t_fault = -1, t_div = 0, t_settle = -1;
    reg     was_locked = 1'b0;
    always @(posedge clk_ref) if (resetb) begin
        if (was_locked && !locked) begin
            n_restart = n_restart + 1;
            if (VERBOSE)
                $display("  %8t  restart %0d at code %0d", $time, n_restart, code);
        end
        was_locked = locked;
        if ($time - t_div > 2 * T_REF || code == 8'h00 || code == 8'hFF) run = 0;
    end

    // The last NWIN locked cycles' code and the last NWIN divs' lock error.
    localparam integer NWIN = 60;
    integer w_code [0:NWIN-1];
    integer w_err  [0:NWIN-1];
    integer nw = 0, nd = 0, e_div;
    always @(posedge div) if (!locked) run = 0; else begin
        e_div = $time - ((($time - T_REF / 2 + T_REF / 2) / T_REF) * T_REF + T_REF / 2);
        t_div = $time;
        run   = (e_div < E_OK && e_div > -E_OK && code != 8'h00 && code != 8'hFF) ? run + 1 : 0;
        if (run == 16 && t_settle < 0) t_settle = cyc - 16;
        w_err[nd % NWIN] = e_div;
        nd = nd + 1;
        if (VERBOSE > 1)
            $display("  %8t  div: err %0d ps, code %0d", $time, e_div, code);
    end
    always @(posedge clk_ref) if (resetb && locked) begin
        w_code[nw % NWIN] = code;
        nw = nw + 1;
    end

    always @(posedge clk_ref) if (resetb) begin
        cyc = cyc + 1;
        if (load && !locked && cyc > 2 && t_lock < 0) begin
            if (seed != code) begin
                n_load = n_load + 1;
                if (VERBOSE)
                    $display("  %8t  jump %0d: code %3d -> %3d (6-bit %0d -> %0d)",
                             $time, n_load, code, seed, code[7:2], seed[7:2]);
            end
            if (seed[7:2] > c_fast + 1) overshoot = overshoot + 1;
        end
        if (locked && t_lock < 0) begin
            t_lock = cyc;
            c_ho   = code[7:2];
            if (VERBOSE)
                $display("  %8t  locked after %0d cycles at code %0d (6-bit %0d)",
                         $time, cyc, code, code[7:2]);
        end
    end

    integer cmin, cmax, c8min, c8max, emin, emax, k;
    initial begin
        if (!$value$plusargs("D_INJ=%d",   D_INJ))   D_INJ   = 330;
        if (!$value$plusargs("T_BUF=%d",   T_BUF))   T_BUF   = 60;
        if (!$value$plusargs("T_S=%d",     T_S))     T_S     = 1064;
        if (!$value$plusargs("T_F=%d",     T_F))     T_F     = 1047;
        if (!$value$plusargs("DCO_PCT=%d", DCO_PCT)) DCO_PCT = 100;
        if (!$value$plusargs("T_ARM=%d",   T_ARM))   T_ARM   = 670;
        if (!$value$plusargs("T_CLR=%d",   T_CLR))   T_CLR   = 500;
        if (!$value$plusargs("TDC_PCT=%d", TDC_PCT)) TDC_PCT = 100;
        if (!$value$plusargs("D_DLF=%d",   D_DLF))   D_DLF   = 0;
        if (!$value$plusargs("D_X2=%d",    D_X2))    D_X2    = 1000;
        if (!$value$plusargs("D_CODE=%d",  D_CODE))  D_CODE  = 0;
        if (!$value$plusargs("MISS_PS=%d", MISS_PS)) MISS_PS = 0;
        if (!$value$plusargs("T_SELA=%d",  T_SELA))  T_SELA  = 215;
        LATE_FLAG = $test$plusargs("LATE_FLAG");
        if (!$value$plusargs("FAULT_CYC=%d", FAULT_CYC)) FAULT_CYC = 0;
        if (!$value$plusargs("FAULT_PCT=%d", FAULT_PCT)) FAULT_PCT = 100;
        if (!$value$plusargs("DITHER=%d", DITHER)) DITHER = $test$plusargs("DITHER");
        if (!$value$plusargs("VERBOSE=%d", VERBOSE)) VERBOSE = $test$plusargs("VERBOSE");
        if (D_DLF > 0 && D_X2 >= D_DLF) $fatal(1, "D_X2 must be below D_DLF");
        dco_scale = DCO_PCT / 100.0;
`include "dco_period.vh"
        c_fast = -1;
        for (i = 0; i < 64; i = i + 1)
            if (D_INJ + 4 * t_dco[i] * DCO_PCT / 100 <= T_REF) c_fast = i;

        #(1000) resetb = 1'b1;
        wait (t_lock > 0 || cyc >= MAX_CYC);
        if (t_lock > 0 && FAULT_CYC > 0) begin
            repeat (FAULT_CYC) @(posedge clk_ref);
            dco_scale = dco_scale * FAULT_PCT / 100.0;
            t_fault   = cyc;
            run       = 0;
            if (VERBOSE)
                $display("  %8t  fault: DCO x%0d%% at code %0d", $time, FAULT_PCT, code);
            wait (run >= SETTLE || cyc >= t_fault + MAX_CYC * 3);
        end else if (t_lock > 0)
            repeat (SETTLE) @(posedge clk_ref);

        if (t_lock < 0) begin
            $display("FAIL: no handover within %0d cycles (code %0d)", MAX_CYC, code);
            errors = errors + 1;
        end
        if (overshoot && TDC_PCT <= 100) begin
            $display("FAIL: %0d coarse load(s) past the lock point (6-bit > %0d)",
                     overshoot, c_fast + 1);
            errors = errors + 1;
        end
        if (t_lock > 0 && TDC_PCT <= 100 && (c_ho < c_fast - 1 || c_ho > c_fast + 1)) begin
            $display("FAIL: handover at 6-bit %0d, lock point %0d/%0d", c_ho, c_fast, c_fast + 1);
            errors = errors + 1;
        end
        if (t_fault >= 0 && run < SETTLE) begin
            $display("FAIL: no relock within %0d cycles of the fault (code %0d, locked %0d, %0d restarts)",
                     cyc - t_fault, code, locked, n_restart);
            errors = errors + 1;
        end

        // The last NWIN locked cycles (code) and divs (error).
        cmin = 255; cmax = 0; c8min = 255; c8max = 0; emin = 1 << 30; emax = -(1 << 30);
        for (k = 0; k < (nw < NWIN ? nw : NWIN); k = k + 1) begin
            if (w_code[k] >> 2 < cmin) cmin = w_code[k] >> 2;
            if (w_code[k] >> 2 > cmax) cmax = w_code[k] >> 2;
            if (w_code[k] < c8min) c8min = w_code[k];
            if (w_code[k] > c8max) c8max = w_code[k];
        end
        for (k = 0; k < (nd < NWIN ? nd : NWIN); k = k + 1) begin
            if (w_err[k] < emin) emin = w_err[k];
            if (w_err[k] > emax) emax = w_err[k];
        end
        if (t_lock > 0 && t_fault < 0 && (cmin < c_fast - 1 || cmax > c_fast + 2))
            $display("NOTE: bang-bang dither %0d..%0d strays from lock point %0d/%0d",
                     cmin, cmax, c_fast, c_fast + 1);
        $display("%s: D_INJ=%0d T_BUF=%0d T_S=%0d T_F=%0d DCO=%0d%% TDC=%0d%% | lock point %0d/%0d, %0d jumps, %0d TDC runs, handover at cycle %0d code %0d, final %0d..%0d",
                 errors ? "FAIL" : "PASS", D_INJ, T_BUF, T_S, T_F, DCO_PCT, TDC_PCT,
                 c_fast, c_fast + 1, n_load, nrun, t_lock, c_ho, cmin, cmax);
        $display("STAT: code8 %0d..%0d err %0d..%0d ps pp %0d, %0d restarts, settled at %0d%s",
                 c8min, c8max, emin, emax, emax - emin, n_restart, t_settle,
                 t_fault >= 0 ? $sformatf(" | fault at %0d, relocked %0d cycles later",
                                          t_fault, cyc - SETTLE - t_fault) : "");
        $finish;
    end

endmodule
