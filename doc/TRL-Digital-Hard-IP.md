# Digital Hard IP Quality Assessment using TRL scale

---

## TRL 1-3 Not evaluated

## TRL3 - Experimental proof of concept

- [x] Is the IP functionality clearly described?
- [x] Have the potential applications of the IP been identified and described?
- [x] Are the IP requirements and specifications described (I/O description, Target technology, does it include a standard interface...)?
- [x] Has the RTL design been completed (Doesn't need to be synthesized)?
- [x] Has a complete behavioral simulation been performed?
  RTL of the full core through the SPI interface, all 4347 training and 1088 test samples: 1039/1088 correct (`TPU5555-main/testbenches/gls/`).
- [x] Is a RTL model provided (doesn't need to be synthesizable)?
- [x] Are the behavioral testbenches provided?
  `TPU5555-main/testbenches/gls/` (`./build.sh rtl`), plus `TPU5555-main/testbenches/` (memory equivalence).

## TRL4 - Component prototype

- [x] Has the design been synthesized?
- [x] Has a complete post-synthesis simulation been performed?
  Done on the routed netlist, which contains the synthesized logic (see TRL5).
- [x] Is a post-synthesis model provided with all required files?
- [x] Are the post-synthesis testbenches provided?
  `TPU5555-main/testbenches/gls/` (`./build.sh gate`).
- [x] Are the preliminary Power, Performance and Area (PPA) results provided?

## TRL5 - Subsystem designed and tested

- [x] Is the Place and Route stage performed successfully?
- [ ] Are all the required files to instantiate the IP provided (LEF, netlist, .gds, liberty file .lib…)?
  Netlist, GDS, LIB and SDF are provided. No LEF, because TPU5555 is a complete padded chip, not a block to instantiate.
- [x] Are all the library dependencies stated?
- [x] Are the post-place&Route simulations performed and the testbenches provided?
  Zero-delay simulation of the routed netlist with the PDK cell and SRAM models, full data set, three random power-up states: SPI trace and all 1088 predictions identical to RTL (`TPU5555-main/testbenches/gls/`, README.md).
- [x] Are there clear instructions to use and integrate the hard IP?

## TRL6 - Functional (Alpha) prototype

- [ ] Is the silicon fabricated and demonstrated on a development board or other platform?
- [ ] Are the functional tests reported?
- [ ] Have the key performance metrics been measured in silicon (Power, timing…)?
- [ ] Is the IP characterized under voltage, temperature and process conditions?

## TRL7 - Field demonstration prototype

- [ ] Is the silicon fabricated and demonstrated on a development board or other platform?
- [ ] Are the functional tests reported?
- [ ] Have the key performance metrics been measured in silicon (Power, timing…)?
- [ ] Is the IP characterized under voltage, temperature and process conditions?

## TRL8 - Beta prototype (commercial ready system)

- [ ] Has the IP been deployed in an end-use product?
- [ ] Has the IP been tested in a pilot production run or customer field trial?
- [ ] Has the IP passed the industry standard compliance certification testing?

## TRL9 - Commercial application

- [ ] Has this IP been in product production? Is the hard IP integrated in any commercial IC?
- [ ] Are the IP authors providing support for bug fixing or enhancement requests?
- [ ] Does the IP documentation include any training materials?
