#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>

// The device file
#define DES_DEVICE  "/dev/uio0"
// The size of the address space of our hardware peripheral
#define DES_SIZE     0x1000
// The des base address specified on the device tree
#define DES_BASE     0x40000000

int main(int argc, char **argv) {
	int status = 0; // return status
	int fd;         // file descriptor for device file

	// the interface registers of the hardware peripheral, memory-mapped in
	// virtual address space
	// Use volatile keyword to prvent assumption on its value
	volatile uint32_t *regs;

	uint32_t interrupts; // interrupts counter


	uint32_t p_l, p_h;
	uint32_t c_l , c_h;
	uint32_t k0_l, k0_h;
	char exit = '1';


	// Open device
	fd = open(DES_DEVICE, O_RDWR);
	if (fd == -1) {
		fprintf(stderr, "Cannot open device file %s: %s\n", DES_DEVICE, strerror(errno));
		return -1;
	}

	// Map device file in memory, read-write, shared with other processes mapping in the same memory region
	regs = mmap((void*)DES_BASE, DES_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (regs == MAP_FAILED) {
		fprintf(stderr, "Mapping error: %s\n", strerror(errno));
		return -1;
	}

	for (int i = 0; i < 10; ++i, printf("*"));
	printf("DES_CRACKER");
	for (int i = 0; i < 10; ++i, printf("*"));
	printf("\n");
	printf("* This program allows you to interface with a custom pheripheral			*\n");
	printf("* built in VHDL and embedded in the FPGA portion of this developer			*\n");
	printf("* board. This ip performs a brute force attack on the DES chypher			*\n");
	printf("* and some information are necessary to initiate the attack:				*\n");
	printf("* 	-- Plaintext:															*\n");
	printf("* 	-- Cyphertext:															*\n");
	printf("* 	-- Starting key:														*\n");
	printf("* Note that not all (plaintext,cyphertext) touple may have a solution		*\n");
	printf("* thus carefull considerations need to be made before starting the attack,	*\n");
	printf("* in such a way you will not wait forever. In any case be pre[ared to wait 	*\n");
	printf("* for a while, the zybo can only contain a few DES encriptor.				*\n");
	for (int i = 0; i < 30; ++i, printf("*"));

	printf("\nThe keyword 'q' can be used to exit the program whenever an input is requested\n");


	// Infinite loop for command line interface
	while (exit) {

		printf("Please enter the plaintext:\n");
	
		printf("Please enter the cyphertext:\n");
	
		printf("Please enter the starting key:\n");

		// Enable interrupts
		interrupts = 1;
		// Enable interrupts
		if (write(fd, &interrupts, sizeof(interrupts)) < 0) {
			fprintf(stderr, "Cannot enable interrupts: %s\n", strerror(errno));
			status = -1;
			break;
		}


		regs[0] = 0xd55297ad;
		regs[1] = 0xbec7fa95;

		fflush(stdout);
		printf("Plain written %x%x\n", regs[0], regs[1]);
		fflush(stdout);

		// Cyphertext
		regs[2] = 0xd1b6fc54;
		regs[3] = 0x0f4b5674;
		fflush(stdout);
		printf("Cypher written %x%x\n", regs[2], regs[3]);
		fflush(stdout);

		// Starting secret key
		regs[4] = 0x9f2d4068; // right one terminates in 5168
		printf("k0 low written %x\n", regs[4]);
		regs[5] = 0x009473f3; // supposeed to end in 3
		printf("k0 low written %x\n", regs[5]);

		// Wait for interrupt
		if (read(fd, &interrupts, sizeof(interrupts)) < 0) {
			fprintf(stderr, "Cannot read device file: %s\n", strerror(errno));
			status = -1;
			break;
		}

		printf("Received %u interrupts\n", interrupts);

		// Read and display content of interface registers
		printf("Register 0: 0x%08x\n", regs[8]);
		printf("Register 1: 0x%08x\n", regs[9]);
	}

	// Unmap
	munmap((void*)regs, DES_SIZE);
	// Close device file
	close(fd);

	return status;
}

