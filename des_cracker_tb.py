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

def dump_signals(path):
	l = list(map(sim.object,sim.find('signals',path + '/*')))
	l.sort(key=lambda x: x.name)
	for s in l:
		if isinstance(s.value,str):
			print(s.name,s.value)
		elif isinstance(s.value,int):
			print(s.name,hex(s.value))
		elif isinstance(s.value,list):
			print(s.name,list(map(hex,s.value)))

def set_des(n):
	os.system('sed -ri ' + r"'s/(\w+ NDES : \w+ :=) [0-9]+/\1 {}/g'".format(n) + " 0_des_pkg.vhd")

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
	wait = random.randint(2,8)
	# Set the delay for the acknowledge of the operation
	done_sig.force([0,1],[0,wait])
	# Set the data signal
	data_sig.force([data],[0])
	# Scgedule the valid signal high for two clock cycle
	valid_sig.force([1,0],[0,2])

def write_axi(wavalid, wdvalid, waddr, address, wdata, data, wstrb, waack, wdack, wresp, wdone, status):
	# Setup the write address part of transaction from CPU perspective
	setup_axi_request(wavalid,waddr,address,wdone)
	# Setup the write data part of transaction from CPU perspective
	setup_axi_request(wdvalid,wdata,data,wdone)
	# Not used but assign value to strobe communication (In the protocol is used to decide how many bytes are transferred in a sequence)
	wstrb.force([random.getrandbits(4)],[0])
	# dump_signals('des_cracker')
	# Advance simulation time
	sim.run(clk_period)
	# dump_signals('des_cracker')
	# Check for acknowledge from the cracker, it sould be immediate
	if (waack.value & wdack.value) != 1:
		print("Error, no acknowledge received from the controller")
	while (wdone.value != 1):
		# dump_signals('des_cracker')
		sim.run(clk_period)
		# Check if the two acknowledge have been correctly deasserted, they should last one clock cycle
		if (waack.value == 1 or wdack.value == 1):
			print("Error write address ack with value {} and data ack with value {} are expected to be asserted only 1 ck".format(waack.value,wdack.value))
		if wresp.value == 0:
			print("Error, des_cracker did not wait the aknowledge from the CPU, expected 1 for s0_axi_bready but got {}".format(wresp.value))
	# End write transaction
	# dump_signals('des_cracker')
	sim.run(clk_period)
	if wdone.value & wresp.value == 1:
		sim.run(clk_period)

	wdone.force([0],[0])
	# dump_signals('des_cracker')
	if wresp.value != 0:
		print("Error, des_cracker did not deasserted acknowledge to CPU, expected 0 for s0_axi_bready but got {}".format(wresp.value))
	# Return the status code of the transaction
	print("Successfully written data {} at address {}".format(hex(data),hex(address)))
	return status.value


def read_axi(ravalid, raddr, address, raack, rvalid, wdone, status,rdata):
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
	wdone.force([0],[0])
	print("Successfully read data {} at address {}".format(hex(rdata.value),hex(address)))
	# Return the status code of the transaction
	return status.value

# Check if the correct argument is passesd
if len(sys.argv) != 3:
	print("Error, wrong arguments, format: ./program_name N_test N_des")
	sys.exit(-1)


N = int(sys.argv[1],10)
n_des = int(sys.argv[2],10)

set_des(n_des)

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
files = files[:-2]

# Cretae the library and compile all the files
lib = msim.Library('work',*files, directory=path)
lib.initialize()
lib.compile(compiler,arg)

# Create a simulator object
sim = msim.Simulator(lib,toplevel)
sim.start()

# Get important signals to check
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

set_zero(list(map(sim.object,sim.find('signals','-in',toplevel + '/*'))))

# Setup the clock
sim.setclock(path='aclk', clock_period=clk_period)

# Setup reset and enable signals and advance simulation time in order reset all the clocked elements
sim.force('aresetn',[0,1],[0,5])
sim.run(5.5)

for i in range(N):

	key = random.getrandbits(64)
	pt = random.getrandbits(64)
	ct = int(d.encrypt(key,pt)[0],16)
	diff =  random.randint(0,200)
	k_start = rm_parity(key) - diff

	print("Looking for the key {} with plaintext {} and cyphertext {}.\nThe starting key is {}, the random difference was {}".format(hex(rm_parity(key)),hex(pt),hex(ct),hex(k_start),diff))
	# n_clock = 16 + diff//n_des + 1.7

	# write plaintext
	write_axi(awvalid,wvalid,awaddr,P_L,wdata,get_low_h(pt,64),wstrb,awready,wready,bvalid,bready,bresp)
	write_axi(awvalid,wvalid,awaddr,P_H,wdata,get_high_h(pt,64),wstrb,awready,wready,bvalid,bready,bresp)
	# write cyphertext
	write_axi(awvalid,wvalid,awaddr,C_L,wdata,get_low_h(ct,64),wstrb,awready,wready,bvalid,bready,bresp)
	write_axi(awvalid,wvalid,awaddr,C_H,wdata,get_high_h(ct,64),wstrb,awready,wready,bvalid,bready,bresp)
	# write start key
	write_axi(awvalid,wvalid,awaddr,K0_L,wdata,get_low_h(k_start,64),wstrb,awready,wready,bvalid,bready,bresp)
	write_axi(awvalid,wvalid,awaddr,K0_H,wdata,get_high_h(k_start,64),wstrb,awready,wready,bvalid,bready,bresp)

	while irq.value == 0:
		sim.run(clk_period)

	# print(dump_signals(toplevel))

	read_axi(arvalid,araddr,K1_L,arready,rvalid,rready,rresp,rdata)
	k_found = rdata.value 
	read_axi(arvalid,araddr,K1_H,arready,rvalid,rready,rresp,rdata)
	k_found |= rdata.value << 32

	if (k_found != rm_parity(key)):
		print("Error, expecting key {} but got instead {}".format(hex(k_start+diff),hex(k_found)))
	else:
		print("The attack succeded! Started from key {} and found the key {}".format(hex(k_start),hex(k_found)))



sim.quit()
print("Found sucessfully {} keys".format(N))