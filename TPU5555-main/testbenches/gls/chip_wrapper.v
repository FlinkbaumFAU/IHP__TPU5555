// Gate-level wrapper: presents the routed chip netlist TPU5555 (pad ports)
// under the port interface of the RTL core hdc_word40_top, so the SPI
// testbench tb_hdc_word40_gate.v drives the whole chip (pads, SPI front end,
// command loader, accelerator, SRAM macros) unchanged.
`timescale 1ns / 1ps

module hdc_word40_top (
    input  wire clk_i,
    input  wire rstn_i,
    input  wire sclk_i,
    input  wire mosi_i,
    input  wire cs_n_i,
    output wire led_o,
    output wire miso_o
);
    wire pad_clk  = clk_i;
    wire pad_rstn = rstn_i;
    wire pad_sclk = sclk_i;
    wire pad_mosi = mosi_i;
    wire pad_cs_n = cs_n_i;
    wire pad_led, pad_miso;
    wire [4:0] pad_spare = 5'b0;   // unused inputs, tied low as on the board
    // MDLL test structure (v.2.0.0): its inputs tied low, i.e. held in reset,
    // its outputs left open. The MDLL itself is the stub below; this
    // simulation covers the HDC chip, the MDLL is verified at transistor level.
    wire pad_mdll_clk_ref = 1'b0;
    wire pad_mdll_resetb  = 1'b0;
    wire pad_mdll_clk, pad_mdll_clk_raw, pad_mdll_locked;
    wire [7:0] pad_mdll_code;

    TPU5555 chip (
        .pad_clk  (pad_clk),
        .pad_rstn (pad_rstn),
        .pad_sclk (pad_sclk),
        .pad_mosi (pad_mosi),
        .pad_cs_n (pad_cs_n),
        .pad_led  (pad_led),
        .pad_miso (pad_miso),
        .pad_spare(pad_spare),
        .pad_mdll_clk_ref(pad_mdll_clk_ref),
        .pad_mdll_resetb (pad_mdll_resetb),
        .pad_mdll_clk    (pad_mdll_clk),
        .pad_mdll_clk_raw(pad_mdll_clk_raw),
        .pad_mdll_locked (pad_mdll_locked),
        .pad_mdll_code   (pad_mdll_code)
    );

    assign led_o  = pad_led;
    assign miso_o = pad_miso;
endmodule

// The bondpad is a metal-only cell without a simulation model. Its pin is
// declared as an input (no driver) so that Verilator's tristate resolution
// does not see a second, undriven inout on every pad net.
module bondpad_70x70 (input PAD);
endmodule

// The MDLL hard macro (TPU5555-main/mdll/) has no digital model: a ring
// oscillator and a sampler that is metastable by design. Stub with its ports;
// outputs low, as while the MDLL is held in reset.
module mdll (
    input  wire       clk_ref,
    input  wire       resetb,
    output wire       clk_out,
    output wire       locked,
    output wire [7:0] code
);
    assign clk_out = 1'b0;
    assign locked  = 1'b0;
    assign code    = 8'h00;
endmodule
