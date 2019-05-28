#!/usr/bin/python3
import modelsim as msim
import os
import sys
import des
import random

def minimum(a,b):
	if a > b:
		return b
	else:
		return a

def rm_parity(num):
    n = bin(num)[2:].zfill(64)
    c = [j for i,j in enumerate(n) if (i+1) % 8 != 0]
    return int(''.join(c),2)

if len(sys.argv) != 2:
	print("Error, wrong arguments, format: ./program_name N_test")
	sys.exit(-1)

N = int(sys.argv[1],10)

# Get class to performa a correct encription and setup some empty list needed for the test
d = des.des()
pt = []
key = []
ct_list = []
lr_correct_list = []
cd_correct_list = []
k_correct_list = []

# Define the path for the working folder
path= os.getcwd()
# Set compiler flags
arg = '-2008'
compiler = 'vcom'
# Set component to simulate
toplevel = 'des'

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

# Get importante signals to check
lr_n = msim.Object(toplevel + '/lr_n',sim)
cd_n = msim.Object(toplevel + '/cd_n',sim)
k_n = msim.Object(toplevel + '/k_n',sim)
c = msim.Object(toplevel + '/c',sim)
k_c = msim.Object(toplevel + '/k_c',sim)

# Setup the clock
sim.setclock(clock_period=2)

# Setup reset and enable signals and advance simulation time in order reset all the clocked elements
sim.force('rst',[0,1],[0,2])
sim.force('en',[0,1],[0,2])
sim.run(1)

for i in range(N):
	pt.insert(0,random.getrandbits(64))
	key.insert(0,random.getrandbits(64))
	sim.force('p',[pt[0]],[0])
	sim.force('k',[key[0]],[0])
	sim.run(2)
	ct, lr_correct, cd_correct, k_correct = d.encrypt(key[0],pt[0])
	ct_list.insert(0,ct)
	lr_correct_list.insert(0,lr_correct)
	cd_correct_list.insert(0,cd_correct)
	k_correct_list.insert(0,k_correct)
	for j in range(minimum(16,i+1)):
		if int(k_correct_list[j][j],16) != k_n[j]:
			print("Error in pipeline for k generation at step {} got {} instead of {}".format(j,hex(k_n[j]),k_correct[j][j]))
			sim.quit()
			sys.exit(-1)

		if j == 0:
			if int(lr_correct_list[0][0],16) != lr_n[0]:
				print("Error after initial permutation got {} instead of {} for plaintext={} and key={}".format(hex(lr_n[0]),lr_correct_list[0][0],hex(pt[j]),hex(key[j])))
				sim.quit()
				sys.exit(-1)
			if int(cd_correct_list[0][0],16) != cd_n[0]:
				print("Error after first key permutation got {} instead of {} for plaintext={} and key={}".format(hex(cd_n[0]),cd_correct_list[0][0],hex(pt[j]),hex(key[j])))
				sim.quit()
				sys.exit(-1)

		if int(lr_correct_list[j][j+1],16) != lr_n[j+1]:
			print("Error at step {} intermediate value lr_n={} instead of {} for plaintext={} and key={}".format(j,hex(lr_n[j+1]),lr_correct_list[j][j+1],hex(pt[j]),hex(key[j])))
			sim.quit()
			sys.exit(-1)

		if int(cd_correct_list[j][j+1],16) != cd_n[j+1]:
			print("Error at step {} intermediate value cd_n={} instead of {} for plaintext={} and key={}".format(j,hex(cd_n[j+1]),cd_correct_list[j][j+1],hex(pt[j]),hex(key[j])))
			sim.quit()
			sys.exit(-1)

	if i >= 16:
		if int(ct_list[-1],16) != c.value or rm_parity(key[-1]) != k_c.value:
			print("Error after final permuatation cyphertext={} instead of {} for plaintext={} and key={}".format(hex(c.value),ct_list[-1],hex(pt[-1]),hex(key[-1])))
			sim.quit()
			sys.exit(-1)

		pt.pop()
		key.pop()
		ct_list.pop()
		lr_correct_list.pop()
		cd_correct_list.pop()
		k_correct_list.pop()

sim.quit()
print("Tested sucessfully {} (key,palintext) pairs".format(N))