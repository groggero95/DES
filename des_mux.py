#!/usr/bin/python3
import modelsim as msim
import os
import sys
import des
import random

def padhex(m,nb=32):
	"""Trasform number m into hexadecimal form, spproximating to the next 32 bit chunk.
	for example padhex(10,15) --> '0x0000000a' while padhex(10,36) --> '0x000000000000000a'"""
	return '0x' + hex(m)[2:].zfill(int(nb//4))

def set_des(n):
	os.system('sed -ri ' + r"'s/(\w+ NDES : \w+ :=) [0-9]+/\1 {}/g'".format(n) + " 0_des_pkg.vhd")

def rm_parity(num):
    n = bin(num)[2:].zfill(64)
    c = [j for i,j in enumerate(n) if (i+1) % 8 != 0]
    return int(''.join(c),2)

# Check if the correct argument is passesd
if len(sys.argv) != 3:
	print("Error, wrong arguments, format: ./program_name N_test N_des")
	sys.exit(-1)

N = int(sys.argv[1],10)
n_des = int(sys.argv[2],10)

set_des(n_des)

# Initialize des encriptor
d = des.des()

# Define the path for the working folder
path= os.getcwd()
# Set compiler flags
arg = '-2008'
compiler = 'vcom'
# Set component to simulate
toplevel = 'des_mux'

# Get the file to compile
files = [f for f in os.listdir('.') if os.path.isfile(f) and f[-3:] == 'vhd']
files.sort()
files = files[:-3]

# Cretae the library and compile all the files
lib = msim.Library('work',*files, directory=path)
lib.initialize()
lib.compile(compiler,arg)

# Create a simulator object
sim = msim.Simulator(lib,toplevel)
sim.start()

# Setup the clock period constant
clk_period = 1

# Get importante signals to check
p = msim.Object(toplevel + '/p',sim)
k_start = msim.Object(toplevel + '/k_start',sim)
c_target = msim.Object(toplevel + '/c_target',sim)
k_high = msim.Object(toplevel + '/k_high',sim)
k_found = msim.Object(toplevel + '/k_found',sim)
# n_des = sim.examine(toplevel + '/DES_N')
k_result = msim.Object(toplevel + '/k_result',sim)
k_right = msim.Object(toplevel + '/k_right',sim)



# Setup the clock
sim.setclock(clock_period=clk_period)

# Setup reset and enable signals and advance simulation time in order to reset all the clocked elements
sim.force('rst',[0,1],[0,1])
sim.force('en',[0,1],[0,1])
p.force([0],[0])
k_start.force([0],[0])
c_target.force([0],[0])
sim.run(1)

for i in range(N):
	key = random.getrandbits(64)
	pt = random.getrandbits(64)
	p.force([pt],[0])
	c_target.force([int(d.encrypt(key,pt)[0],16)],[0])
	diff =  random.randint(0,100)
	k_start.force([rm_parity(key) - diff],[0])
	n_clock = 16 + diff//n_des + 2
	print("Started at key {} random distance from correct key is {}".format(padhex(k_start.value,56),diff))
	for i in range(n_clock):
		sim.run(clk_period)
		k_start.force([k_start.value + n_des],[0])
		if k_high.value != (k_start.value - (16*n_des + 1)) and i >= 16:
			print(i, n_des, sim.time)
			print("Error the expected high key is {} but got {} instead".format(padhex(k_start.value,56),padhex(k_high.value,56)))
			sim.quit()
			sys.exit()


	if not k_found.value:
		print("Error key not found after the expected {} clock cycles".format(n_clock))
		sim.quit()
		sys.exit()

	if k_right.value != rm_parity(key):
		print("Found key {} instead of {}".format(padhex(k_right.value,56),padhex(rm_parity(key),56)))
		sim.quit()
		sys.exit()
	else:
		print("Found key {} in expected {} clock cycles".format(padhex(k_right.value,56),n_clock))




sim.quit()