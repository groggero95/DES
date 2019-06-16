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
	printf("Entered in main\n");
	int status = 0; // return status
	int fd;         // file descriptor for device file
	// the interface registers of the hardware peripheral, memory-mapped in
	// virtual address space
	volatile uint32_t *regs;

	uint32_t p_l = 0xd55297ad, p_h = 0xbec7fa95;
	// int p_l = 0xd55297ad, p_h = 0xbec7fa95;
	// int p_l = 0xd55297ad, p_h = 0xbec7fa95;

	printf("Variable def\n");

	// Open device
	fd = open(DES_DEVICE, O_RDWR);
	if (fd == -1) {
		fprintf(stderr, "Cannot open device file %s: %s\n", DES_DEVICE, strerror(errno));
		return -1;
	}

	printf("Open device\n");

	// Map device file in memory, read-only, shared with other processes mapping
	// the same memory region
	regs = mmap((void*)DES_BASE, DES_SIZE, PROT_READ | PROT_WRITE, MAP_SHARED, fd, 0);
	if (regs == MAP_FAILED) {
		fprintf(stderr, "Mapping error: %s\n", strerror(errno));
		close(fd);
		return -1;
	}

	printf("Map memory\n");

	// Infinite loop waiting for interrupts
	while (1) {
		uint32_t interrupts; // interrupts counter

		printf("In while\n");

		// Enable interrupts
		interrupts = 1;
		printf("Past interrupt\n");
		// Enable interrupts
		if (write(fd, &interrupts, sizeof(interrupts)) < 0) {
			fprintf(stderr, "Cannot enable interrupts: %s\n", strerror(errno));
			status = -1;
			break;
		}
		printf("Past interrupt check\n");


		// Here we will write on our registers
		// Plaintext
		printf("Write reg\n");

		//  memcpy((void*)regs, (const void *) &p_l, 64);
		// printf("Print per giulio\n");
		//  memcpy((void*) regs+1, (const void *) &p_h,4);

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
		regs[4] = 0x9f2d5068; // right one terminates in 168
		regs[5] = 0x009473f4;
		fflush(stdout);
		printf("K strat writtent\n");
		fflush(stdout);


		// Wait for interrupt
		if (read(fd, &interrupts, sizeof(interrupts)) < 0) {
			fprintf(stderr, "Cannot read device file: %s\n", strerror(errno));
			status = -1;
			break;
		}

		printf("Received %u interrupts\n", interrupts);

		// Read and display content of interface registers
		printf("Register 0: 0x%08x\n", regs[9]);
		printf("Register 1: 0x%08x\n", regs[10]);
	}

	// Unmap
	munmap((void*)regs, DES_SIZE);
	// Close device file
	close(fd);

	return status;
}

