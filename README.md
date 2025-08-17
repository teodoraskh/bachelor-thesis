# Introduction

This repository contains the implementation of the following algorithms: Barrett Reduction, Montgomery Reduction and Shift-Add Reduction.

Each of these algorithms has been implemented in System Verilog using different approaches:

- Fully-Combinatorial

- FSM-Driven

- Pipelined

As a proof-of-concept, the Kyber and Dilithium coefficient moduli have been employed in order to both generate the inputs and also for testing.

In the `algorithms` folder, the python test generation can be found. This script produces two "polynomial" vectors drawn from a Gaussian distribution, with degrees between 2^8 and 2^10, multiplies them and eventually reduces the product using one of the algorithms. The resulting array serves as `expected output` for the algorithms implemented in System Verilog. Additionally, the uniformly random generated vectors are used as input for the algorithms.
To generate expected results, please run the command:

```
	python main.py <algorithm_name> <modulus_scheme_name>
```

The folder `algorithms_sv` contains the implementation for each reduction approach, along with a test file and a testbench. By default, the Dilithium modulus is used. To employ e.g. the Kyber modulus, one has to modify `algorithms_sv/params_pkg.sv`and use the specific modulus. To use any other modulus, one needs to first generate new test results via the python script.

# Testing

Each algorithm comes with a testbench, a test file and a `build_and_run.sh` bash script.
For simulating, IcarusVerilog v12.0 is required, as well as a wave analyzer, such as GTKWave (v3.3.121).

To run the simulation, one needs to simply run:
```
./build_and_run.sh
```
in the source folder of the algorithm.

# Synthesis & Implementation

For deriving actual results (area, time etc.), all algorithms have been synthesized and implemented within AMD's Design Suite, Vivado (2024).

The board we are targeting is `Artix-7 AC701 Evaluation Platform`. The FPGA receives a 200 MHz differential clock from the board. This input is processed through a Clocking Wizard (DSP IP), which produces a single-ended 100 MHz internal clock for use in the design. Since the Clocking Wizard is a DSP IP, this needs to be added from the IP Catalog and configured accordingly. Some of the changes required to support this component during simulation have been already made, however one needs to define `SIMULATION = 1` within the `Settings` menu in Vivado.

For Fully-Combinatorial algorithms, the clock frequency needs to be reduced to 25MHz to avoid data path delays.
Additionally, since we manage anything clock-related using the Clocking Wizard, every algorithm uses the same `clock.xdc` constraint file.

# Results

The results for both synthesis and implementation can be found within `algorithms_sv/vivado_results`. This folder contains both the post-synthesis and the post-implementation routing results, as well as the timing results for all algorithms.