#!/usr/bin/python3
import modelsim as msim
import os
import sys
import des
import random

clk_period = 1

P_L = 0x000
P_H = 0x004
C_L = 0x008
C_H = 0x00C
K0_L = 0x010
K0_H = 0x014
K_L = 0x018
K_H = 0x01C
K1_L = 0x020
K1_H = 0x024


def get_low_h(val,nb):
	return val & ((1 << nb//2) - 1)

def get_high_h(val,nb):
	return val >> (nb//2)

def rm_parity(num):
    n = bin(num)[2:].zfill(64)
    c = [j for i,j in enumerate(n) if (i+1) % 8 != 0]
    return int(''.join(c),2)

def set_zero(signals):
	for s in signals:
		s.force([0],[0])

def setup_axi_request(valid_sig, data_sig, data, done_sig):
	# Define a random time for the acknowledge of the whole operation
	wait = random.randint(1,8)
	# Set the delay for the acknowledge of the operation
	done_sig.force([0,1,0],[0,wait,wait+1])

	# Set the data signal
	data_sig.force([data],[0])
	# Scgedule the valid signal high for one clock cycle
	wdvalid.force([1,0],[0,1])

def write_axi(wavalid, wdvalid, waddr, address, wdata, data, wstrb, waack, wdack, wresp, wdone, status):

	# Setup the write address part of transaction from CPU perspective
	setup_axi_request(wavalid,waddr,address,wdone)
	# Setup the write data part of transaction from CPU perspective
	setup_axi_request(wdvalid,wdata,data,wdone)

	# Not used but assign value to strobe communication (In the protocol is used to decide how many bytes are transferred in a sequence)
	wstrb.force([random.getrandbits(4)],[0])
	# Advance simulation time
	sim.run(clk_period)

	# Check for acknowledge from the cracker, it sould be immediate
	if (waack.value & wdack.value & wresp.value) != 1:
		print("Error, no acknowledge received from the controller")

	while (wdone.value != 1):
		sim.run(clk_period)
		# Check if the two acknowledge have been correctly deasserted, they should last one clock cycle
		if (waack.value == 1 or wdack.value == 1):
			print("Error write address ack with value {} and data ack with value {} are expected to be asserted only 1 ck".format(waack.value,wdack.value))
		if wresp.value == 0:
			print("Error, des_cracker did not wait the aknowledge from the CPU, expected 1 for s0_axi_bvalid but got {}".format(wresp.value))

	# End write transaction
	sim.run(clk_period)
	# Return the status code of the transaction
	return status.value


def read_axi(ravalid, raddr, address, raack, rvalid, wdone, status):

	# Setup the read address part of transaction from CPU perspective
	setup_axi_request(ravalid,raddr,address,wdone)

	# Advance simulation time
	sim.run(clk_period)

	# Check for acknowledge from the cracker, it sould be immediate
	if (raack.value & rvalid.value) != 1:
		print("Error, no acknowledge received from the controller")

	while (wdone.value != 1):
		sim.run(clk_period)
		# Check if the two acknowledge have been correctly deasserted, they should last one clock cycle
		if (raack.value == 1):
			print("Error read address ack with value {} expected to be asserted only 1 ck".format(raack.value))
		if rvalid.value == 0:
			print("Error, des_cracker did not wait the aknowledge from the CPU, expected 1 for s0_axi_rvalid but got {}".format(wresp.value))

	# End read transaction
	sim.run(clk_period)
	# Return the status code of the transaction
	return status.value

if len(sys.argv) != 2:
	print("Error, wrong arguments, format: ./program_name N_test")
	sys.exit(-1)

N = int(sys.argv[1],10)

# Get class to performa a correct encription and setup some empty list needed for the test
d = des.des()


# Define the path for the working folder
path= os.getcwd()
# Set compiler flags
arg = '-2008'
compiler = 'vcom'
# Set component to simulate
toplevel = 'des_cracker'

# Get the file to compile
files = [f for f in os.listdir('.') if os.path.isfile(f) and f[-3:] == 'vhd']
files.sort()

# Cretae the library and compile all the files
lib = msim.Library('work',*files, directory=path)
lib.initialize()
lib.compile(compiler,arg)

# Create a simulator object
sim = msim.Simulator(lib,toplevel)
sim.start()

# Get importante signals to check
# Read signals
araddr	= msim.Object(toplevel + '/s0_axi_araddr',sim)
arvalid = msim.Object(toplevel + '/s0_axi_arvalid',sim)
arready = msim.Object(toplevel + '/s0_axi_arready',sim)
rdata	= msim.Object(toplevel + '/s0_axi_rdata',sim)
rresp	= msim.Object(toplevel + '/s0_axi_rresp',sim)
rvalid	= msim.Object(toplevel + '/s0_axi_rvalid',sim)
rready	= msim.Object(toplevel + '/s0_axi_rready',sim)

# Write signals
awaddr	= msim.Object(toplevel + '/s0_axi_awaddr',sim)
awvalid	= msim.Object(toplevel + '/s0_axi_awvalid',sim)
awready	= msim.Object(toplevel + '/s0_axi_awready',sim)
wdata	= msim.Object(toplevel + '/s0_axi_wdata',sim)
wstrb	= msim.Object(toplevel + '/s0_axi_wstrb',sim)
wvalid	= msim.Object(toplevel + '/s0_axi_wvalid',sim)
wready	= msim.Object(toplevel + '/s0_axi_wready',sim)
bresp	= msim.Object(toplevel + '/s0_axi_bresp',sim)
bvalid	= msim.Object(toplevel + '/s0_axi_bvalid',sim)
bready	= msim.Object(toplevel + '/s0_axi_bready',sim)

# The rest
irq		= msim.Object(toplevel + '/irq',sim)
led		= msim.Object(toplevel + '/led',sim)

set_zero(sim.find('signals','-in',toplevel))

# Setup the clock
sim.setclock(path='aclk', clock_period=clk_period)

# Setup reset and enable signals and advance simulation time in order reset all the clocked elements
sim.force('aresetn',[0,1],[0,5])
sim.run(5.5)

for i in range(N):

	key = random.getrandbits(64)
	pt = random.getrandbits(64)
	ct = int(d.encrypt(key,pt)[0],16)
	diff =  random.randint(0,150)
	k_start = rm_parity(key) - diff

	n_clock = 16 + diff//n_des + 1.7

	# write plaintext
	write_axi(awvalid,wvalid,awaddr,P_L,wdata,get_low_h(pt,64),wstrb,awready,wready,bvalid,bready,bresp)
	write_axi(awvalid,wvalid,awaddr,P_H,wdata,get_high_hs(pt,64),wstrb,awready,wready,bvalid,bready,bresp)
	# write cyphertext
	write_axi(awvalid,wvalid,awaddr,C_L,wdata,get_high_hs(ct,64),wstrb,awready,wready,bvalid,bready,bresp)
	write_axi(awvalid,wvalid,awaddr,C_H,wdata,get_high_hs(ct,64),wstrb,awready,wready,bvalid,bready,bresp)
	# write start key
	write_axi(awvalid,wvalid,awaddr,K0_L,wdata,get_high_hs(k_start,64),wstrb,awready,wready,bvalid,bready,bresp)
	write_axi(awvalid,wvalid,awaddr,K0_H,wdata,get_high_hs(k_start,64),wstrb,awready,wready,bvalid,bready,bresp)

	start_time = sim.time
	while irq.value == 0:
		sim.run(clk_period)

	stop_time = sim.time

	read(arvalid,araddr,K1_L,arready,rvalid,rready,rresp)
	k_found = rdata.value
	read(arvalid,araddr,K1_H,arready,rvalid,rready,rresp)
	k_found |= rdata.value << 32

	if (k_found != rm_parity(key)):
		print("Error, expecting key {} but got instead {}".format(hex(k_start+diff),hex(k_found)))


sim.quit()
print("Found sucessfully {} keys".format(N))