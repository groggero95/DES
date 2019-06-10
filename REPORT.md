## Team members:

* Alberto   Anselmo,  [Alberto.Anselmo@eurecom.fr](mailto:Alberto.Anselmo@eurecom.fr)
* Giulio    Roggero,  [Giulio.Roggero@eurecom.fr](mailto:Giulio.Roggero@eurecom.fr)

The following report regards a DES bruteforce cracker that has been designed during the __Digital Systems, Hardware - Software Integration__ (AY 2018-19).

# DES Cracker
The goal of this project is to design using `VHDL` a cracker to disclose the key used in the DES enciphering. Knowing the plaintext and the ciphertext, and given a key as a starting point, the HW we have designed will try several possible keys, finally founding the right one, which will be saved in a particular register.
All the design in interfaced using the `AXI Lite 4` protocol to the `ARM` core that is present on the board, so that the registers used to communicate between our design and the external world can be accessed using a simple serial connection which allows to give instructions to the CPU.

## Working Flow
For this project, we have decided to work in such a way:
* design of new unit/layer
* test of the above unit
This has given the opportunity to concentrate the simulation and the testing only on the examined layer, as this phase was already done for the ones standing at lower levels, as we can assume, with a certain degree of safety, that they behave as desired.
Some simulations have been done launching __ModelSim__ commands using a **Python** script, while others designing a "regular" testbench.
At the end, using the [synthesis script](./des_cracker.syn.tcl), a synthesis has been run. On the top of this circuit, which uses the programmable part of the FPGA, a simple driver written in `C` has been developed, to conclude the project.

## Description
In this section we will go through all the files that belong to the project, giving a brief explanation:
* Design source files:
 * [`0_des_pkg.vhd`](./0_des_pkg.vhd): a package which contains constant declarations, functions and types that will be used in the design, as well as components to instantiate
 * [`1_ff.vhd`](./1_ff.vhd): a simple FF with arbitrary size, with synchronous and asynchronous reset in two different architecture, ready to be used in the upper layers
 * [`2_p_box.vhd`](./2_p_box.vhd): an entity that permutes the input accordingly to a constant table previously defined
 * [`3_s_box.vhd`](./3_s_box.vhd): this entity perform the substitution, as defined in the DES standard
 * [`4_k_gen.vhd`](./4_k_gen.vhd): generates the new key for the round, as specified by the standard
 * [`5_f.vhd`](./5_f.vhd):
 * [`6_des.vhd`](./6_des.vhd): this entity wraps the different stages of the DES enciphering, providing also a division into several stages of a pipeline
 * [`8_des_mux.vhd`](./8_des_mux.vhd): this entity provides an interface to instantiate and handle multiple DES cracker entity in parallel, by distributing the keys to test and finally checking if a correct key has been found to send to the upper layer
 * [`des_cracker.vhd`](./des_cracker.vhd): this is the top level entity, which wraps around and includes the control unit, as well as the `AXI` protocol to communicate with the memory
 * [`rnd_pkg.vhd`](./rnd_pkg.vhd): a package containing some functions and procedures to create random numbers
* Simulation files:
 * [`7_des_tb.vhd`](./7_des_tb.vhd): stimulus for a simple DES simulation, to check the outputs at different stages and prepare a more complex testbench
 * [`9_des_mux_tb.vhd`](./9_des_mux_tb.vhd): simple simulation to check the reference behavior of multiple DES at once
 * [`des_cracker_tb.vhd`](./des_cracker_tb.vhd): a regular simulation for the wrapper, to check the correctness of the `AXI` protocol and its implementation for the wrapper
 * [`des_cracker_tb.py`](./des_cracker_tb.py): complete simulation of the wrapper, which takes as argument the number of tests to perform and the number of DES cracker to instantiate
 * [`des_mux.py`](./des_mux.py): a Python simulation to perform a series of test on several DES at the same time
 * [`des.py`](./des.py): a software implementation of the DES, to correctly encipher and check the results
 * [`modelsim.py`](./modelsim.py): declaration of classes and methods used to interface __ModelSim__ with Python, using a series of FIFO to communicate
 * [`sim.py`](./sim.py): a simulation of all the rounds of the DES, single entity
* Other files:
 * [`des_cracker.syn.tcl`](./des_cracker.syn.tcl): synthesis script, with some modifications to explore more aggressively the timing optimizations
 * [`des_driver.c`](./des_driver.c): simple driver to write and read from the mapped registers used in the HW implementation of the cracker
 * [`des_cracker.timing.rpt`](./des_cracker.timing.rpt): synthesis timing report
 * [`des_cracker.utilization.rpt`](./des_cracker.utilization.rpt): synthesis area report

## Design:
We started from the specifications of the `DES standard` to design the units that were in charge of enciphering.

### Pipelining
At the beginning, we decided to pipeline every stage of the pipe, including the first permutation and the last one. This has been done to sensibly improve the performances.
As a matter of fact, we do not really care about the __latency__ of our bruteforce attack. Waiting for a couple of tenths of clock cycles is not at all a problem, as we do not have any real time schedule to respect. On the other hand, working on a pipeline allows us to get a better critical path, thus leading to a smaller clock period and higher clock frequency, which leads to an overall better performances with respect to time.
### Drawbacks
On the other hand, we are probably increasing the power, as more register are involved to pipeline a more important switching activity will be obtained. This will of course cause more switching power, which is the most relevant contribution.
For the very same reason, an increase of the area will be observed as well, as we will need more intermediate registers to save the results of the different stages and pipeline them.
### Considerations
At the end of the day, we can however consider that the above mentioned defects are not so crucial in the context of our implementation, so we will go on the pipeline idea, keeping in mind what we have mentioned in case we need to improve in some "directions" of our design space.
## Additional stage
After many trials, we have observed that the critical path consisted in the comparison of all the obtained ciphers with the correct one. Therefore, we have split the comparison into two subparts, each one of 32 bits. Then, the results of this stage is output for the next one, therefore we check that both the high and low parts are equal in the following clock cycle and eventually we write the correct key and raise the signal to communicate that the result has been found. The algorithm is the following:
```
@CC=i
for i in range(DES_N-1):
    comp_high(i)    = True if (cipher_high(i)   == cipher_target)
    comp_low(i)     = True if (cipher_low(i)    == cipher_target)

@CC=i+1
for i in range(DES_N-1):
    if (comp_high(i) == 1) and (comp_low(i)==1):
        key_found = 1
        key_right = key(i)
    else:
        key_found = 0
```
This of course requires some more registers, but it has allowed us to sensibly increase the clock frequency by improving on the critical path.

## Testing


## Synthesis
We have run a synthesis script which instantiates 10 different design crackers at once. This implies that at the same time we are testing 10 different keys, therefore improving a lot with respect to a single one.
In order to get better timing performance, which is the design variable we have been focused on, we run the following `TCL` commands:
```
opt_design -directive Explore
place_design -directive ExtraTimingOpt
phys_opt_design -directive Explore
route_design -directive Explore
```
With respect to the scripts used before during lectures, those options allows the synthesizer to run some more trials to better optimize the obtained result. Since the algorithms used are of course not of the "exact" type, but "heuristic" ones, it is more likely that better results are obtained, giving more possibilities to the software in charge of the physical floorplanning.

As mentioned in the [description](#description), the two generated reports are included. We can focus on some parts we consider to be relevant:
* as in can be seen in the [timing report](./des_cracker.timing.rpt), a clock having a frequency of `187.512 MHz` will still meet the timing constraint. Additionally, the critical path for the setup regards some control units signal, so we decided to stop with the improvements also on the signals which might violate the hold time, since it is very unlikely that there is sufficient margin to increase more the frequency.

```
Clock       Waveform(ns)         Period(ns)      Frequency(MHz)
-----       ------------         ----------      --------------
clk_fpga_0  {0.000 2.667}        5.333           187.512         

From Clock:  clk_fpga_0
  To Clock:  clk_fpga_0

Setup :            0  Failing Endpoints,  Worst Slack        0.048ns,  Total Violation        0.000ns
Hold  :            0  Failing Endpoints,  Worst Slack        0.020ns,  Total Violation        0.000ns
PW    :            0  Failing Endpoints,  Worst Slack        1.686ns,  Total Violation        0.000ns
---------------------------------------------------------------------------------------------------


Max Delay Paths
--------------------------------------------------------------------------------------
Slack (MET) :             0.048ns  (required time - arrival time)
  Source:                 ps7_axi_periph/s00_couplers/auto_pc/inst/gen_axilite.gen_b2s_conv.axilite_b2s/SI_REG/aw.aw_pipe/m_payload_i_reg[39]/C
                            (rising edge-triggered cell FDRE clocked by clk_fpga_0  {rise@0.000ns fall@2.667ns period=5.333ns})
  Destination:            des_cracker/U0/FSM_onehot_c_state_a_reg[1]_replica_51/D
                            (rising edge-triggered cell FDRE clocked by clk_fpga_0  {rise@0.000ns fall@2.667ns period=5.333ns})

```

* the total slice that are used are reported in the [utilization report](./des_cracker.utilization.rpt). As one may see, there is probably some more space to instantiate an additional cracker, leading to 11 in total, but this will probably bring to a too high occupation of the floorplan. This might cause problems especially to clock distribution, so we decided to keep the number of `DES` instances to 10, in order to have some margin for the synthesizer to work. In addition, it is possible to see how no latches are (wrongly) present in our design. On the other hand, even if our design uses some muxltiplexers, their sizes are not enough to justify the usage of the onboard muxes. Therefore, their functions are mapped to the regular LUTs.

```
+----------------------------+-------+-------+-----------+-------+
|          Site Type         |  Used | Fixed | Available | Util% |
+----------------------------+-------+-------+-----------+-------+
| Slice LUTs                 | 15618 |     0 |     17600 | 88.74 |
|   LUT as Logic             | 15566 |     0 |     17600 | 88.44 |
|   LUT as Memory            |    52 |     0 |      6000 |  0.87 |
|     LUT as Distributed RAM |     0 |     0 |           |       |
|     LUT as Shift Register  |    52 |     0 |           |       |
| Slice Registers            | 20871 |     0 |     35200 | 59.29 |
|   Register as Flip Flop    | 20871 |     0 |     35200 | 59.29 |
|   Register as Latch        |     0 |     0 |     35200 |  0.00 |
| F7 Muxes                   |     0 |     0 |      8800 |  0.00 |
| F8 Muxes                   |     0 |     0 |      4400 |  0.00 |
+----------------------------+-------+-------+-----------+-------+
```

## Goal:
We have that the worst case execution time is:
Therefore, we have to find the optimal ratio

$`T_{clk}/N_{cracker}`$
