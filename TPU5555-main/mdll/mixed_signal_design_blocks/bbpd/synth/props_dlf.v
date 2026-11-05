// Formal properties for the loop-filter accumulator.
//
// Proved with plain `yosys sat -prove-asserts` (see synth/props_dlf.tcl), not
// SymbiYosys: sby is not installed in this environment, and for a design whose
// entire state is one 8-bit register a bounded model check straight out of
// yosys is the same proof with one fewer dependency.
//
// Wrapper rather than asserts inside dlf.v so that the RTL stays a plain
// synthesisable module with nothing for the hardening flow to trip over.

module dlf_props (
    input  wire       clk,
    input  wire       resetb,
    input  wire       comp,
    input  wire       load,
    input  wire [7:0] seed
);

    localparam [7:0] RESET_CODE = 8'h18;

    wire [7:0] code;

    // PREG = 0: load/seed straight in, the single-clock equivalent of the
    // clk_ref re-register (see rtl/dlf.v).
    dlf #(.RESET_CODE(RESET_CODE), .PREG(0)) dut (
        .clk_ref (clk), .clk (clk), .resetb (resetb), .comp (comp),
        .load (load), .seed (seed), .code (code)
    );

    // History. `valid` gates the $past-style properties until one clock edge
    // has been taken after reset release, so the free initial state of the
    // bounded check cannot masquerade as a violation.
    reg [7:0] prev_code;
    reg       prev_load, prev_comp;
    reg [7:0] prev_seed;
    reg       valid;

    always @(posedge clk or negedge resetb) begin
        if (!resetb) begin
            prev_code <= RESET_CODE;
            prev_load <= 1'b0;
            prev_comp <= 1'b0;
            prev_seed <= 8'h00;
            valid     <= 1'b0;
        end else begin
            prev_code <= code;
            prev_load <= load;
            prev_comp <= comp;
            prev_seed <= seed;
            valid     <= 1'b1;
        end
    end

    always @(posedge clk) begin
        if (resetb) begin
            // 1. Synchronous load wins over the accumulate path.
            a_load_priority:
                assert (!prev_load || code == prev_seed);

            // 2. The accumulator moves by at most one LSB per reference cycle.
            //    This is where the loop gain lives; anything else here would
            //    change the loop dynamics silently.
            a_step_at_most_one:
                assert (!valid || prev_load ||
                        code == prev_code ||
                        code == prev_code + 8'd1 ||
                        code == prev_code - 8'd1);

            // 3. SATURATION -- the property that matters most. A wrap at
            //    either rail inverts the loop sign for one step and throws the
            //    DCO to the far end of its range.
            a_no_wrap_high:
                assert (!valid || prev_load || !(prev_code == 8'hFF && code == 8'h00));
            a_no_wrap_low:
                assert (!valid || prev_load || !(prev_code == 8'h00 && code == 8'hFF));

            // 4. Direction follows the comparator, given clk_gen's cap bank is
            //    monotonic code-up => frequency-down.
            //      comp = 1 (div late, ring too slow)  -> code decreases
            //      comp = 0 (div early, ring too fast) -> code increases
            //    ...except at the rail, where it holds.
            a_dir_down:
                assert (!valid || prev_load || !prev_comp ||
                        code == (prev_code == 8'h00 ? 8'h00 : prev_code - 8'd1));
            a_dir_up:
                assert (!valid || prev_load || prev_comp ||
                        code == (prev_code == 8'hFF ? 8'hFF : prev_code + 8'd1));
        end
    end

    // 5. Asynchronous reset forces the start code.
    always @(*) begin
        if (!resetb)
            a_reset_code: assert (code == RESET_CODE);
    end

endmodule
