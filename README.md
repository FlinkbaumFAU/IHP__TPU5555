# IHP__TPU5555

Hyperdimensional-computing (HDC) classifier chip with an SPI host interface, in IHP SG13CMOS5L.
It is a complete padded design (2.4 mm × 2.0 mm, 35 IO pads, 6 SRAM macros) for the IHP Open-Silicon MPW,
category **Digital / TPU** (ML accelerator). Since v.2.0.0 it also carries an all-digital MDLL (×4 clock multiplier)
as a separate test structure with its own pads.

- `doc/`: datasheet, specification, TRL assessment, `info.json`
- `dependencies/`: none (IO cells, SRAM macros and standard cells come from the IHP Open PDK)
- `release/v.2.0.0/`: final GDS (`TPU5555.gds`, seal ring and fill included) and netlists, with the MDLL
- `release/v.1.0.0/`: the first release, without the MDLL
- `TPU5555-main/`: RTL, constraints, LibreLane flow, implementation views, verification reports, MDLL sources (`mdll/`)
- `measurements/v.2.0.0/`: empty until silicon is available (`v.1.0.0/` likewise)

License: Apache-2.0 (see `LICENSE`; third-party notices in `NOTICE`)
