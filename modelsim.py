"""
Python interface to the ModelSim simulator. The simulator is instrumented using FIFO pipes
such that it becomes fully controllable from within Python using TCL commands.
"""

import contextlib
import enum
import os
import os.path
import re
import subprocess
import tempfile
import signal

from collections import namedtuple
from subprocess import Popen, check_output, STDOUT, DEVNULL


__version__ = (0, 0, 1, 'dev')


# the heart of the instrumentation: use blocking FIFO pipes to run TCL commands
SIMULATION_SCRIPT = r'''
set fifo_posi [open "__py_modelsim_posi.fifo" "r"]
set fifo_piso [open "__py_modelsim_piso.fifo" "w"]
fconfigure $fifo_piso -buffering none
puts $fifo_piso "ready"
flush $fifo_piso
gets $fifo_posi command
while {$command != "quit"} {
	if {[catch {
		set result [eval $command]
		puts $fifo_piso [string map {"\n" " "} "S:$result"]
		flush $fifo_piso
	} error ]} {
		puts $fifo_piso [string map {"\n" " "} "E:$error"]
		flush $fifo_piso
	}
	gets $fifo_posi command
}
quit -f
'''


RelativeTime = namedtuple('RelativeTime', ['value', 'unit'])
AbsoluteTime = namedtuple('AbsoluteTime', ['value', 'unit'])


def encode_time(timespec):
	if isinstance(timespec, int):
		return '{{{} ns}}'.format(timespec)
	elif isinstance(timespec, RelativeTime):
		return '{{{} {}}}'.format(timespec.value, timespec.unit)
	elif isinstance(timespec, AbsoluteTime):
		return '{{@{} {}}}'.format(timespec.value, timespec.unit)
	raise Exception('unknown time specification format')

def enc_time(timespec,*args):
	if isinstance(timespec, int):
		if args:
			return '{} {}'.format(timespec,args[0])
		else:
			return '{} ns'.format(timespec)
	elif isinstance(timespec, RelativeTime):
		return '{} {}'.format(timespec.value, timespec.unit)
	elif isinstance(timespec, AbsoluteTime):
		return '@{} {}'.format(timespec.value, timespec.unit)
	raise Exception('unknown time specification format')    

def tcl_escape(value):
	return '{{{}}}'.format(str(value))


class Library:
	"""
	ModelSim Verilog library with context manager support.
	If the directory argument is omitted a temporary directory is created on entering the
	context. Further the library is initialized and all Verilog files are compiled. When
	leaving the context, all temporary resources are freed.
	"""

	def __init__(self, name, *files, directory=None):
		self.name = name
		self.directory = directory
		self.files = list(files)
		self.temporary = None

	def __enter__(self):
		if self.directory is None:
			self.temporary = tempfile.TemporaryDirectory()
			self.directory = self.temporary.name
			self.initialize()
			self.compile()
		return self

	def __exit__(self, exc_type, exc_value, exc_traceback):
		if self.temporary is not None:
			self.temporary.cleanup()
			self.directory = None
			self.temporary = None

	def initialize(self, *arguments):
		"""
		Initialize the library using the `vlib` command.
		"""
		if self.directory is None:
			raise Exception('unable to explicitly initialize temporary library')
		command = ['vlib', self.name] + list(arguments)
		try:
			check_output(command,  cwd=str(self.directory), stderr=STDOUT)
		except subprocess.CalledProcessError as error:
			raise Exception('unable to initialize verilog library', error.output)

	def compile(self, compiler='vcom', *arguments):
		"""
		Compile the Verilog files using the `vlog` command.
		"""
		if self.directory is None:
			raise Exception('unable to explicitly compile temporary library')
		command = [compiler, '-work', self.name] + list(arguments)
		command += (str(self.directory + '/' + filename) for filename in self.files)
		try:
			check_output(command, cwd=str(self.directory), stderr=STDOUT)
		except subprocess.CalledProcessError as error:
			raise Exception('unable to compile verilog files', error.output)

	def simulate(self, toplevel, *arguments, commandline=True, unit='ps', **keywords):
		"""
		Start the simulator with the given toplevel entity using the `vsim` command.
		"""
		if self.directory is None:
			raise Exception('unable to simulate outside of the library context')

		command = ['vsim'] + list(arguments)
		if commandline:
			command.append('-c')
		command.append('{}.{}'.format(self.name, toplevel))
		command.append('-t')
		command.append(unit)
		return Popen(command, cwd=str(self.directory), **keywords)


class Object:
	"""
	Represents a Verilog object within the simulation. Verilog objects support slicing for
	arrays and member access for structs using native Python syntax.
	"""

	def __init__(self, path, simulator):
		i = path.rfind('/')
		self.path = path[:i]
		self.name = path[i+1:]
		self.full_name = path
		self.way, self.limits, self.type = simulator.describe(self.path,self.name)
		self.kind = simulator.show(self.path,self.name)
		self.simulator = simulator

	def __repr__(self):
		return '<Object "{}/{}">'.format(self.path,self.name)

	def __truediv__(self, segment):
		return Object('{}/{}'.format(self.path, segment), self.simulator)

	def __getitem__(self, item):
		if isinstance(item, int):
			return self.simulator.examine(self.path + '/' + self.name + '({})'.format(item))
		elif isinstance(item, slice):
			if item.start == None:
				item.start = self.limits[0]
			if item.stop == None:
				item.stop == self.limits[1]
			if item.step != None:
				time = AbsoluteTime(item.step,'ps')
			return self.simulator.examine(self.path + '/' + self.name + '({}:{})'.format(item.start,item.stop))				
		else:
			raise Exception('unsupported key access on ' + self.kind + ' object')

	def __setitem__(self, item, value):
		if isinstance(item, int):
			self.simulator.change(self.path + '({})'.format(item), value)
		elif isinstance(item, slice):
			if not isinstance(item.start, int) or not isinstance(item.stop, int):
				raise Exception('unsupported slice types on verilog object')
			if item.step is not None:
				raise Exception('slice steps are not supported on verilog objects')
			for offset, number in enumerate(value):
				self[item.start + offset] = number
		else:
			raise Exception('unsupported key access on verilog object')

	def __getattr__(self, name):
		return Object(self.path + '.' + name, self.simulator)

	@property
	def value(self):
		"""
		The value of the object as returned by the `examine` TCL command.
		"""
		return self.simulator.examine(self.full_name)

	def force(self, *arguments, **keywords):
		"""
		Force the value of a Verilog net by the `force` TCL command.
		"""
		return self.simulator.force(self.full_name, *arguments, **keywords)

	def change(self, *arguments, **keywords):
		"""
		Change the value of a parameter, variable or register by the `change` TCL command.
		"""
		return self.simulator.change(self.full_name, *arguments, **keywords)

	def nets(self):
		"""
		Find Verilog nets starting from the objects's path using the `find` command.
		"""
		return self.simulator.nets(self.full_name)

	def signals(self):
		"""
		Find Verilog signals starting from the objects's path using the `find` command.
		"""
		return self.simulator.signals(self.path)

	def instances(self):
		"""
		Find Verilog instances starting from the objects's path using the `find` command.
		"""
		return self.simulator.instances(self.full_name)


class TCLError(Exception):
	"""
	Error during the execution of a TCL command.
	"""

	def __init__(self, command, message):
		super().__init__(message)
		self.command = command


def append_nested(matrix, depth, value, *args):
	'''
	This function allow to append a value to a nested list created at runtime 
	and whose dimension is only known during the execution of the program
	depth : equal to the dimention of the matrix -1
	args  : we need as many index as the depth value
	Example : append_nested(matrix,2,0,2,1) is equivalent to matrix[2][1].append(0)
	This function assumes sim.setclock()that matrix has as many level as needed
	'''
	if depth == 0:
		matrix.append(value) 
		return
	else:
		return append_nested(matrix[args[0]],depth-1,value,*args[1:])


def neg_range(limit):
	while limit < 0:
		yield limit
		limit += 1


# regular expression for the `examine` command result parser
EXAMINE_REGEX = re.compile(r'(?P<begin>{)|(?P<end>})|(?P<value>[0-9A-Fa-fXUXHWL-]+)')


def parse_examine_result(string, base=16):
	"""
	Parse the result of an examine command into either a value or a list of values. Values
	typically are integers, however they might be string if the value is undefined.
	"""
	if not string.find('...') < 0:
		raise Exception('examine command returned incomplete result')
	stack = []
	depth = -1
	past_depth = 0
	max_depth = 0
	indexes = []
	for match in EXAMINE_REGEX.finditer(string):
		if match.lastgroup == 'value':
			string = str(match.group('value'))
			value = string if any(x in string for x in 'XUXHWL-') else int(string, base)
			if stack:
				append_nested(stack,depth,value,*indexes)
			else:
				return value
		elif match.lastgroup == 'begin':

			if (max_depth-depth) > 1:
				for i in neg_range(1- max_depth + depth):
					if i == 1- max_depth + depth:
						indexes[i] += 1
					else:
						indexes[i] = -1
				append_nested(stack,depth+1,[],*indexes)

			depth += 1

			if max_depth < depth:
				max_depth = depth
				indexes.append(0)
				append_nested(stack,depth-1,[],*indexes)

		elif match.lastgroup == 'end':
			depth -= 1
			if depth == -1:
				return stack[0]

	raise Exception('unable to parse result of examine command')


@contextlib.contextmanager
def timeout(time):
	# Register a function to raise a TimeoutError on the signal.
	signal.signal(signal.SIGALRM, raise_timeout)
	# Schedule the signal to be sent after ``time``.
	signal.alarm(time)

	try:
		yield
	except TimeoutError:
		pass
	finally:
		# Unregister the signal so it won't be triggered
		# if the timeout is not reached.
		signal.signal(signal.SIGALRM, signal.SIG_IGN)


def raise_timeout(signum, frame):
	raise TimeoutError

# regular expression for the `find instances` command result parser
INSTANCES_REGEX = re.compile(r'{(?P<path>[^ ]+) \((?P<type>[^)]+)\)}')

def parse_find_instances_result(string, simulator):
	"""
	Parse the result of an `find instances`.
	"""
	result = {}
	for match in INSTANCES_REGEX.finditer(string):
		if match.group('type') not in result:
			result[match.group('type')] = []
		result[match.group('type')].append(Object(match.group('path'), simulator))
	return result

SHOW_REGEX = re.compile(r'(?P<begin>{)|(?P<type>[0-9A-Za-z]+\s)|(?P<name>[0-9A-Za-z_]+)|(?P<end>})')
# TODO expand the list of signal in case of use of verilog
types = ('Signal','Port', 'Generic','Variable','VHDLConstant')


def parse_show_result(string,name=None):
	save = False
	kind = ''
	result = []
	if name:
		for match in SHOW_REGEX.finditer(string.strip()):
			if match.lastgroup == 'type':
					kind = str(match.group('type'))[:-1]
			if match.lastgroup == 'name':
				if name == str(match.group('name')):
					return kind
	else:
		for match in SHOW_REGEX.finditer(string.strip()):
			if match.lastgroup == 'type':
				if str(match.group('type'))[:-1] in types:
					save = True
					kind = str(match.group('type'))[:-1]
			if match.lastgroup == 'name' and save:
				result.append((kind,str(match.group('name'))))
				save = False

	return result

DESCRIBE_REGEX = re.compile(r'Array\((?P<left>[0-9]+) (?P<dir>\w+) (?P<right>[0-9]+)\)|VHDL \w+ type (?P<type>\w+)')

def parse_describe_result(string):
	directions = []
	limits = []
	_type = ''
	for match in DESCRIBE_REGEX.finditer(string):
		if match.lastgroup == 'right':
			directions.append(match.group('dir'))
			limits.append((match.group('left'),match.group('right')))
		elif match.lastgroup == 'type':
			_type = match.group('type')
	return directions, limits, _type

	
class ForceModes(enum.Enum):
	"""
	Modes for the `force` command as described in the ModelSim documentation.
	"""
	FREEZE = '-freeze'
	DRIVE = '-drive'
	DEPOSIT = '-deposit'


Radixes = {'hex'      : 16,
		   'octal'    :  8,
		   'binary'   :  2,
		   'decimal'  : 10,
		   'unsigned' : 10,
		   'ascii'    :  '',
		   'time'     :  '',
		   'symbolic' :  ''}


class Simulator:
	"""
	Python interface to an instrumented ModelSim instance.
	"""
	def __init__(self, library, toplevel, libraries=None, unit='ps', log='cmd.log'):
		self.library = library
		self.toplevel = toplevel
		self.libraries = libraries or []
		self.directory = None
		self.running = False
		self.process = None
		self.posi = None
		self.piso = None
		self.time = None
		self.unit = unit
		self.__log = open(log,'w+')
		self.__log_name = log
		self.__last_pos = 0
		# cache for examine results: speedup multiple accesses
		self.examine_cache = {}

	def __getitem__(self, path):
		return Object(path, self)

	def __truediv__(self, segment):
		return Object('/{}/{}'.format(self.toplevel, segment), self)

	def __getshow__(self):
		self.__log.seek(self.__last_pos,0)
		result = list(self.__log)
		return ' '.join(result[2:-1])

	def start(self, *arguments, stdout=DEVNULL, stderr=DEVNULL):
		"""
		Start an instrumented ModelSim instance simulating the toplevel entity.
		"""
		if self.running:
			raise Exception('unable to start simulator: already running')

		self.running = True
		self.time = 0

		self.directory = self.library.directory

		posi_name = os.path.join(str(self.directory), '__py_modelsim_posi.fifo')
		piso_name = os.path.join(str(self.directory), '__py_modelsim_piso.fifo')
		script_name = os.path.join(str(self.directory), '__py_modelsim_script.do')

		os.mkfifo(posi_name)
		os.mkfifo(piso_name)

		with open(script_name, 'wb') as script:
			script.write(SIMULATION_SCRIPT.encode())

		arguments = ['-do', '__py_modelsim_script.do'] + list(arguments)
		for library in self.libraries:
			arguments.append('-Lf')
			arguments.append(library)

		self.process = self.library.simulate(self.toplevel, *arguments, unit=self.unit,
											 stdout=self.__log, stderr=stderr)

		with timeout(2):
			try:
				self.posi = open(str(posi_name), 'wb', 0)
			except TimeoutError as e:
				raise Exception("Unable to open modelsim with vsim command")

		with timeout(2):
			try:
				self.piso = open(str(piso_name), 'rb')
			except TimeoutError as e:
				raise Exception("Unable to open modelsim with vsim command")

		self.examine_cache = {}

		if self.piso.readline().decode().strip() != 'ready':
			self.process.kill()
			self.cleanup()
			raise Exception('unable to start simulator: internal communication error')

	def object(self, path):
		"""
		Return an object for the given path.
		"""
		return Object(path, self)

	def execute(self, command, show=0):
		"""
		Execute the given TCL command by sending it to the simulator. Returns the result
		or raises a `TCLError` if the command failed.
		"""
		if not self.running or self.process.returncode is not None:
			raise Exception('unable to execute command: simulator not running')
		self.__last_pos = self.__log.seek(0,1)
		self.posi.write((command + '\n').encode())
		code, data = self.piso.readline().decode().partition(':')[::2]
		if code == 'S':
			if show:
				data = self.__getshow__()
			return data.strip()
		else:
			raise TCLError(command, data)

	def examine(self, path, radix='hex', time=None, *arguments, cache=True):
		"""
		Issue an examine command for the given path. Since we do not log any signals per
		default, time-travel is not supported.
		"""
		if cache and (path, time) in self.examine_cache:
			return self.examine_cache[(path,time)]
		else:
			command = ['examine']
			# Insert the radix
			command.append('-' + radix)
			
			# Insert the instant at which we are checking the value
			if time:
				command.append('-time {}'.format(encode_time(time)))
			
			# Add othre arguments, eamine can do much more, look into the modelsim manual:
			# https://www.microsemi.com/document-portal/doc_view/136364-modelsim-me-10-4c-command-reference-manual-for-libero-soc-v11-7
			for arg in arguments:
				command.append(arg)

			# add the signal we want to look at
			command.append(tcl_escape(path))
			if radix in Radixes:
				result = parse_examine_result(self.execute(' '.join(command)),Radixes[radix])
			else:
				result = parse_examine_result(self.execute(' '.join(command)))

			if cache:
				if time:
					self.examine_cache[(path,time)] = result
				else:
					time = RelativeTime(self.time,self.unit)
					self.examine_cache[(path,time)] = result
			return result

	def change(self, path, value):
		"""
		Change the value of Verilog parameters, registers, memories, and variables. This
		allows us for instance to change memory content and thereby simulate MMIO.
		"""
		if isinstance(value, int):
			value = bin(value)[2:]
		elif isinstance(value, list):
			value = tcl_escape(' '.join(bin(item)[2:] for item in value))
		return self.execute('change {} {}'.format(tcl_escape(path), value))

	def force(self, path, values = [], times = [], mode=None, cancel=None, repeat=None):
		"""
		Force a Verilog net to a specified value. This allows us to control for instance
		the clock signal or stimulate external interrupts.
		"""
		if len(times) != len(values) or len(times) == 0:
			raise Exception('Unbalanced value-time sequence')

		command = ['force']
		# Set operation  mode of command force
		if mode is not None:
			command.append(mode.value)

		# append path to the signal
		command.append(path)

		for value,time in zip(values,times):
			if time == times[-1]:
				command.append('2#{} {}'.format(bin(value)[2:], enc_time(time,'ns')))
			else:
				command.append('2#{} {},'.format(bin(value)[2:], enc_time(time,'ns')))


		# add repeat time 
		if repeat is not None:
			command.append('-repeat {}'.format(enc_time(repeat)))

		# cancel if necessary
		if cancel is not None:
			command.append('-cancel {}'.format(enc_time(cancel)))

		return self.execute(' '.join(command))

	def noforce(self, *paths):
		"""
		Removes the effect of any active force commands on the given objects.
		"""
		self.examine('noforce {}'.format(' '.join(map(tcl_escape, paths))))

	def setclock(self, path='clk', clock_period=1):
		"""
		Easyly drive a clock signal with the specified clock period
		"""
		tStart = RelativeTime(0,'ns')
		tEnd = RelativeTime(round(clock_period/2,1),'ns')
		period = RelativeTime(round(clock_period/2,1)*2,'ns')
		values = [0, 1]
		self.force(path, values, [tStart, tEnd], mode=ForceModes.DEPOSIT, repeat=period)

	def run(self, time):
		"""
		Run the simulation for `time` nanoseconds.
		"""
		self.examine_cache = {}
		self.time += time
		self.execute('run {} ns'.format(time))

	def cleanup(self):
		"""
		Remove FIFO pipes and the TCL script.
		"""
		os.unlink(os.path.join(self.directory, '__py_modelsim_posi.fifo'))
		os.unlink(os.path.join(self.directory, '__py_modelsim_piso.fifo'))
		os.unlink(os.path.join(self.directory, '__py_modelsim_script.do'))
		self.__log.close()
		os.unlink(os.path.join(self.directory, self.__log_name))
		os.unlink(os.path.join(self.directory, 'transcript'))

	def quit(self):
		"""
		Quit the simulation and wait until it has terminated, cleanup afterwards.
		"""
		try:
			self.posi.write('quit\n'.encode())
			self.process.wait()
		finally:
			self.cleanup()

	def find(self, kind, *arguments):
		"""
		Find simulation objects using the `find` TCL command.
		"""
		result = self.execute('find {} {}'.format(kind, ' '.join(arguments))).split()
		if len(result) == 1:
			return result[0]
		else:
			return result 


	def show(self,path,name=None):
		"""
		Find the type associated to a name, signal, generic, variable
		"""
		return parse_show_result(self.execute('show {}'.format(path),show=1),name)

	def describe(self, path,name=None):
		if isinstance(path,str) and name:
			return parse_describe_result(self.execute('describe {}/{}'.format(path,name)))
		else:
			return re.sub(' +',' ', self.execute('describe {}'.format(path))) 


	def nets(self, path=None):
		"""
		Find Verilog nets using the `find` TCL command.
		"""
		path = (path or '') + '/*'
		nets = self.find('nets', '-internal', tcl_escape(path), '-recursive')
		return list(map(self.object, nets))

	def signals(self, path=None):
		"""
		Find Verilog signals using the `find` TCL command.
		"""
		path = (path or '') + '/*'
		signals = self.find('signals', '-internal', tcl_escape(path), '-recursive')
		return list(map(self.object, signals))

	def instances(self, path=None):
		"""
		Find Verilog instances using the `find` TCL command.
		"""
		path = (path or '') + '/*'
		instances = self.find('instances', '-recursive', tcl_escape(path))
		return parse_find_instances_result(' '.join(instances), self)


@contextlib.contextmanager
def simulate(toplevel, *files, libraries=None):
	"""
	Context manager for easy usage of the simulator.
	"""
	library = Library('simulation')
	library.files.extend(files)
	with library:
		simulator = Simulator(library, toplevel, libraries)
		simulator.start()
		yield simulator
		simulator.quit()


def interactive(toplevel, *files, namespace=None, libraries=None, **keywords):
	"""
	Launch an interactive interpreter to control the simulator.
	"""
	from ptpython.repl import embed

	with simulate(toplevel, *files, libraries=libraries) as simulator:
		namespace = namespace or {}
		namespace.update({
			'simulator': simulator,
			'run': simulator.run,
			'execute': simulator.execute,
			'examine': simulator.examine,
			'change': simulator.change,
			'force': simulator.force,
			'noforce': simulator.noforce,
			'nets': simulator.nets,
			'signals': simulator.signals,
			'instances': simulator.instances
		})

		embed(namespace, namespace, **keywords)

# Used to record the values of signals and variables in the design
# if we do not log we cannot access data easily
# log -r /*

# grep {type signal_name}
# show path_to_signal
# EXPLORE the serchlog command
# EXPLORE log command to record the value of signals
# log -r /* --- log all signals in the design, needed to look at their past values