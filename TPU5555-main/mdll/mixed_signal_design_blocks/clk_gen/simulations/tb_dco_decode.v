// Exhaustive check of the DCO cap-bank decoder.
//
// The input space is 8 code bits x the divider's 4 Gray period counts and the
// decoder is purely combinational, so sweeping every combination is a
// complete proof of the properties below -- there is no state to reach and
// nothing left unexercised.

`timescale 1ns/1ps

module tb_dco_decode;

    localparam integer NBIT  = 6;
    localparam integer NSKIP = 2;

    integer errors = 0;

    // ---------------- bin2therm, standalone ----------------
    reg  [NBIT-1:0]      bin;
    wire [(1<<NBIT)-2:0] therm;

    bin2therm #(.NBIT(NBIT)) dut_t (.bin(bin), .therm(therm));

    // ---------------- dco_decode, full ----------------
    reg  [NBIT+NSKIP-1:0] code;
    reg  [1:0] g;
    wire [7:0] co0, cob0, co1, cob1, co2, cob2, co3, cob3;

    dco_decode #(.NBIT(NBIT), .NSKIP(NSKIP)) dut_d (
        .code(code), .g(g),
        .co0(co0), .cob0(cob0), .co1(co1), .cob1(cob1),
        .co2(co2), .cob2(cob2), .co3(co3), .cob3(cob3)
    );

    // Slot -> thermometer index, mirroring dco_decode's mapping but written
    // out independently so a typo in one does not hide a typo in the other.
    function integer therm_index;
        input integer c, s, p;
        begin
            therm_index = 8*p + 2*c + s;
        end
    endfunction

    integer i, c, s, p, k, n, want, run_sum, prev_sum;
    reg [1:0] gray [0:3];
    integer n_on, n_out, n_outb, n_cell[0:3];
    integer prev_on, imbalance, lo, hi;
    integer seen [0:63];
    reg [63:0] slots;

    task check;
        input cond;
        input [8*80:1] msg;
        begin
            if (!cond) begin
                $display("FAIL: %0s", msg);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // ---- 1. bin2therm: popcount == bin, and set bits are contiguous ----
        for (k = 0; k < (1<<NBIT); k = k + 1) begin
            bin = k[NBIT-1:0];
            #1;
            n_on = 0;
            for (i = 0; i < (1<<NBIT)-1; i = i + 1)
                n_on = n_on + therm[i];
            if (n_on !== k) begin
                $display("FAIL: popcount(therm)=%0d, expected %0d (bin=%0d)", n_on, k, k);
                errors = errors + 1;
            end
            for (i = 0; i < (1<<NBIT)-2; i = i + 1)
                if (therm[i] < therm[i+1]) begin
                    $display("FAIL: therm not contiguous at bit %0d (bin=%0d)", i, k);
                    errors = errors + 1;
                end
        end

        // ---- 2. mapping is a bijection onto 0..63 ----
        for (i = 0; i < 64; i = i + 1) seen[i] = 0;
        for (c = 0; c < 4; c = c + 1)
            for (s = 0; s < 2; s = s + 1)
                for (p = 0; p < 8; p = p + 1)
                    seen[therm_index(c,s,p)] = seen[therm_index(c,s,p)] + 1;
        for (i = 0; i < 64; i = i + 1)
            if (seen[i] !== 1) begin
                $display("FAIL: therm index %0d claimed by %0d slots, expected 1", i, seen[i]);
                errors = errors + 1;
            end

        // ---- 3. dco_decode over every code and every period of a run ----
        // Period n of a run (divider count in Gray: 00 01 11 10) gets unit N
        // = code[7:2] in addition when it is one of the last k = code[1:0]
        // periods; the four periods together enable 4N + k unit-periods, so
        // div moves a quarter step per code LSB.
        gray[0] = 2'b00; gray[1] = 2'b01; gray[2] = 2'b11; gray[3] = 2'b10;
        prev_sum = -1;
        for (k = 0; k < (1<<(NBIT+NSKIP)); k = k + 1) begin
          code = k[NBIT+NSKIP-1:0];
          run_sum = 0;
          for (n = 0; n < 4; n = n + 1) begin
            g = gray[n];
            #1;
            slots = {cob3, co3, cob2, co2, cob1, co1, cob0, co0};

            n_on = 0;
            for (i = 0; i < 64; i = i + 1) n_on = n_on + slots[i];
            run_sum = run_sum + n_on;

            want = (k >> NSKIP) + ((n >= 4 - (k % 4) && (k % 4) != 0) ? 1 : 0);
            if (want > 63) want = 63;
            if (n_on !== want) begin
                $display("FAIL: code %0d period %0d enables %0d units, expected %0d",
                         k, n, n_on, want);
                errors = errors + 1;
            end

            // differential balance: out vs outb never differs by > 1 unit
            n_out  = 0;
            n_outb = 0;
            for (i = 0; i < 8; i = i + 1) begin
                n_out  = n_out  + co0[i]  + co1[i]  + co2[i]  + co3[i];
                n_outb = n_outb + cob0[i] + cob1[i] + cob2[i] + cob3[i];
            end
            imbalance = (n_out > n_outb) ? (n_out - n_outb) : (n_outb - n_out);
            if (imbalance > 1) begin
                $display("FAIL: code %0d out/outb imbalance %0d units (out=%0d outb=%0d)",
                         k, imbalance, n_out, n_outb);
                errors = errors + 1;
            end

            // per-cell load spread: cells fill round-robin, so <= 2 units apart
            for (c = 0; c < 4; c = c + 1) n_cell[c] = 0;
            for (i = 0; i < 8; i = i + 1) begin
                n_cell[0] = n_cell[0] + co0[i] + cob0[i];
                n_cell[1] = n_cell[1] + co1[i] + cob1[i];
                n_cell[2] = n_cell[2] + co2[i] + cob2[i];
                n_cell[3] = n_cell[3] + co3[i] + cob3[i];
            end
            lo = n_cell[0]; hi = n_cell[0];
            for (c = 1; c < 4; c = c + 1) begin
                if (n_cell[c] < lo) lo = n_cell[c];
                if (n_cell[c] > hi) hi = n_cell[c];
            end
            if (hi - lo > 2) begin
                $display("FAIL: code %0d cell loads spread %0d units (%0d %0d %0d %0d)",
                         k, hi-lo, n_cell[0], n_cell[1], n_cell[2], n_cell[3]);
                errors = errors + 1;
            end
          end

          // over a run: 4N + k unit-periods, strictly increasing with the code
          // (flat only where unit 64 would be needed)
          want = (k < 252) ? k : 252;
          if (run_sum !== want) begin
              $display("FAIL: code %0d enables %0d unit-periods per run, expected %0d",
                       k, run_sum, want);
              errors = errors + 1;
          end
          if (run_sum < prev_sum) begin
              $display("FAIL: code %0d: %0d unit-periods, fewer than at code %0d",
                       k, run_sum, k-1);
              errors = errors + 1;
          end
          prev_sum = run_sum;
        end

        // ---- 4. cob3[7] is the only permanently dead slot ----
        code = {(NBIT+NSKIP){1'b1}};   // all units that can be on, are on
        g = 2'b10;
        #1;
        check(cob3[7] === 1'b0, "cob3[7] should be tied low at full scale");
        n_on = 0;
        slots = {cob3, co3, cob2, co2, cob1, co1, cob0, co0};
        for (i = 0; i < 64; i = i + 1) n_on = n_on + slots[i];
        check(n_on === 63, "full scale should enable exactly 63 units");

        if (errors == 0)
            $display("PASS: dco_decode exhaustive check clean (256 codes x 4 periods)");
        else
            $display("FAILED with %0d error(s)", errors);

        $finish;
    end

endmodule
