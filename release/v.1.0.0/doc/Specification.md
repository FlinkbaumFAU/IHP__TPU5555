# TPU5555 – Specification

## Function

TPU5555 implements a hyperdimensional-computing (HDC) classifier with on-chip training:

- **Encoding.** Each of the N=32 features is quantized to one of M=40 levels:
  `level = round(feature·(M−1)/32768)`. Its level hypervector (continuous memory, CM) is
  XOR-bound with the position hypervector (item memory, IM). The 32 bound vectors are
  bundled bit-wise by majority (`count ≥ N/2`). The computation runs chunk-serially,
  40 bits at a time, for D=1000 bits.
- **Training.** Each bit of the encoded vector adds ±1 to an 11-bit signed counter for
  the current class. A finalize writes sign(counter) into associative-memory (AM) row
  `label` and clears the counters.
- **Inference.** The chip computes the Hamming distance (XOR + popcount) to every AM row
  and returns the argmin as the class (3 bit).

## Block diagram

```
pads ─ spi_slave ─ hdc_spi_loader ─ hdc_cmd_loader ─ Accelerator
                                                      ├─ IdentityMemory    (IM, 32×1000 b)  SRAM 1024x32 + 1024x8
                                                      ├─ ContinousMemory   (CM, 40×1000 b)  SRAM 1024x32 + 1024x8
                                                      ├─ AssociativeMemory (AM,  8×1000 b)  SRAM 256x48
                                                      ├─ ClassCounterRAM   (1000×11 b)      SRAM 1024x16
                                                      └─ majority buffer   (25×40 b flops)
```

## Hierarchy and naming

| View | Top name |
| --- | --- |
| RTL (VHDL) | `hdc_chip_top` (`TPU5555-main/rtl/asic/hdc_chip_top.vhdl`), core instance `i_core` = `hdc_word40_top` |
| GDS, netlists (CDL, Verilog), DEF, LIB, SDF, SPEF | `TPU5555` |

The RTL top name was kept so the LibreLane flow under `TPU5555-main/Flow/` runs unchanged.
The layout and netlists were renamed to `TPU5555` after the flow run. `make_release.py` renames the top cell and corrects the sealring area label. KLayout `LayoutDiff` shows those are the only changes, and all physical checks were re-run on the result (see `release/v.1.0.0/doc/Signoff.md`).

## Clocks and timing

| Clock | Period | Notes |
| --- | --- | --- |
| `clk` | 20 ns | System clock |
| `sclk`, `cs_n` | 100 ns | SPI front end; asynchronous to `clk`, with toggle synchronizers |

Worst slacks after routing: setup +2.30 ns (slow, 1.08 V / 125 °C), hold +0.18 ns
(fast, 1.32 V / −40 °C). There are 0 slew and 0 cap violations. The 216 max-fanout
entries are all CTS clock buffers, each driving 10–16 flip-flops against a limit of 8.
They are waived in `release/v.1.0.0/doc/Signoff.md`.

## Physical implementation

- Die 2400 × 2000 µm, core [365, 365, 2035, 1635] µm, sg13cmos5l IO ring with 22 pads.
- Two macro rows (IM/CM south, counters/AM north) around a ~280 µm logic channel.
- The PDN is a core ring plus a stripe grid (IHP LibreLane template), with SRAM macro grids on Metal4↔TopMetal1.
- 207 ECO antenna diodes sit on SRAM inputs.
- The seal ring was added by the LibreLane `KLayout.SealRing` step and fill by `KLayout.Filler`.

## Signoff

The physical checks were re-run on the final release files (`TPU5555.gds` / `TPU5555.cdl`) with KLayout 0.30.7 and the IHP-Open-PDK `3f66c91` decks. The full report is in `release/v.1.0.0/doc/Signoff.md`, covering scope, waivers, hashes and provenance.

| Check | Result |
| --- | --- |
| KLayout DRC (PDK deck, `no_recommended`) | 0 markers |
| KLayout DRC with `precheck_drc=true` | 0 markers |
| KLayout antenna (PR #990 deck) | 0 markers |
| KLayout density | 0 markers |
| KLayout LVS (PDK deck; IO cells and SRAM macros compared as black boxes, see Signoff.md) | netlists match |
| OpenROAD DRT (flow run) | 0 violations |
| Setup / hold (all corners, flow run) | met; the 216 max-fanout entries are CTS clock buffers (waiver in Signoff.md) |
| Power grid (flow run) | 0 violations |

Logs and result databases are in `TPU5555-main/verification/*/release/` (final files) and `*/full-test-v7/` (original flow run).
