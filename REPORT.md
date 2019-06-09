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
In this section we will go through all the source files that belong to the project, giving a brief explanation:
* 

## Goal:
We have that the worst case execution time is:
Therefore, we have to find the optimal ratio

$`T_{clk}/N_{cracker}`$
