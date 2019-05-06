import modelsim as msim
import os

path='/home/ansel/Desktop/Eurecom/DigitalSystems/des'
arg = '-2008'
compiler = 'vcom'
toplevel = 'des_tb'
files = [f for f in os.listdir('.') if os.path.isfile(f) and f[-3:] == 'vhd']
files.sort()
lib = msim.Library('work',*files, directory=path)
lib.initialize()
lib.compile(compiler,arg)
sim = msim.Simulator(lib,toplevel)
sim.start()
sim.setclock()
sim.show('/des_tb/')

sim.force('p',[0x0123456789ABCDEF],[0])
sim.force('k',[0x133457799BBCDFF1],[0])
sim.force('rst',[0,1],[0,1])
sim.force('en',[0,1],[0,1])

insig = sim.find('signals','-in','/*').split()
outsig = sim.find('signals','-out','/*').split()
sim.force(insig[0],0,mode=msim.ForceModes.DEPOSIT,repeat=100)

sim.examine('clk')
sim.examine('p')
sim.examine('k_n')



# force -deposit des/clk 1 {0 ns}, 0 {1 ns} -repeat {2 ns}


# Used to record the values of signals and variables in the design
# if we do not log we cannot access data easily
# log -r /*

# grep {type signal_name}
# show path_to_signal

sim.posi.write('describe p\n'.encode())
code, data = sim.piso.readline().decode().partition(':')[::2]
code, data = sim.piso.readline().decode().partition(':')[::2]

data = sim.piso.readline().decode().partition(':')[::2]
