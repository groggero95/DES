#include <sys/types.h>
#include <sys/stat.h>
#include <sys/mman.h>

#include <fcntl.h>
#include <errno.h>
#include <string.h>
#include <stdint.h>
#include <unistd.h>
#include <stdio.h>
#include <stdlib.h>
// The device file
#define DES_DEVICE  "/dev/uio0"
// The size of the address space of our hardware peripheral
#define DES_SIZE     0x1000
// The des base address specified on the device tree
#define DES_BASE     0x40000000
// size for string contaning the variable
#define BASE64_SIZE	16
#define BASE32_SIZE	8

int main(int argc, char **argv) {
	int status = 0; // return status
	int fd;         // file descriptor for device file

	// the interface registers of the hardware peripheral, memory-mapped in
	// virtual address space
	// Use volatile keyword to prvent assumption on its value
	volatile uint32_t *regs;

	uint32_t interrupts; // interrupts counter
	char p_l[BASE32_SIZE+1];
	char p_h[BASE32_SIZE+1];
	char c_l[BASE32_SIZE+1];
	char c_h[BASE32_SIZE+1];
	char k0_l[BASE32_SIZE+1];
	char k0_h[BASE32_SIZE+1];

	char p_all[2+BASE64_SIZE+1];
	char c_all[2+BASE64_SIZE+1];
	char k0_all[2+BASE64_SIZE+1];

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
	printf("* Note that not all (plaintext,cyphertext) tuple may have a solution		*\n");
	printf("* thus carefull considerations need to be made before starting the attack,	*\n");
	printf("* in such a way you will not wait forever. In any case be pre[ared to wait 	*\n");
	printf("* for a while, the zybo can only contain a few DES encriptor.				*\n");
	for (int i = 0; i < 30; ++i, printf("*"));

	printf("\nThe keyword 'q' can be used to exit the program whenever an input is requested\n");


	// Infinite loop for command line interface
	while (1) {

		printf("Please enter the plaintext:\n");
		scanf("%s", p_all);
		if(strncmp(p_all, "q", 1) == 0){
			break;
		}
		printf("Please enter the cyphertext:\n");
		scanf("%s", c_all);
		if(strncmp(c_all, "q", 1) == 0){
			break;
		}
		printf("Please enter the starting key:\n");
		scanf("%s", k0_all);
		if(strncmp(k0_all, "q", 1) == 0){
			break;
		}
		// Enable interrupts
		interrupts = 1;
		// Enable interrupts
		if(strncmp(p_all, "0x", 2) == 0){
			strncpy(p_h, &p_all[2], 8);
			strncpy(p_l, &p_all[10], 8);
			p_h[BASE32_SIZE] = '\0';
			p_l[BASE32_SIZE] = '\0';
		} else {
			strncpy(p_h, &p_all[0], 8);
			strncpy(p_l, &p_all[8], 8);
			p_h[BASE32_SIZE] = '\0';
			p_l[BASE32_SIZE] = '\0';
		}

		if(strncmp(c_all, "0x", 2) == 0){
			strncpy(c_h, &c_all[2], 8);
			strncpy(c_l, &c_all[10], 8);
			c_h[BASE32_SIZE] = '\0';
			c_l[BASE32_SIZE] = '\0';
		} else {
			strncpy(c_h, &c_all[0], 8);
			strncpy(c_l, &c_all[8], 8);
			c_h[BASE32_SIZE] = '\0';
			c_l[BASE32_SIZE] = '\0';
		}

		if(strncmp(k0_all, "0x", 2) == 0){
			strncpy(k0_h, &k0_all[2], 8);
			strncpy(k0_l, &k0_all[10], 8);
			k0_h[BASE32_SIZE] = '\0';
			k0_l[BASE32_SIZE] = '\0';
		} else {
			strncpy(k0_h, &k0_all[0], 8);
			strncpy(k0_l, &k0_all[8], 8);
			k0_h[BASE32_SIZE] = '\0';
			k0_l[BASE32_SIZE] = '\0';
		}





		if (write(fd, &interrupts, sizeof(interrupts)) < 0) {
			fprintf(stderr, "Cannot enable interrupts: %s\n", strerror(errno));
			status = -1;
			break;
		}


		regs[0] = strtoul(p_l, NULL, 16);
		regs[1] = strtoul(p_h, NULL, 16);

		fflush(stdout);
		printf("Plain written %x%x\n", regs[0], regs[1]);
		fflush(stdout);

		// Cyphertext
		regs[2] = strtoul(c_l, NULL, 16);
		regs[3] = strtoul(c_h, NULL, 16);
		fflush(stdout);
		printf("Cypher written %x%x\n", regs[2], regs[3]);
		fflush(stdout);

		// Starting secret key
		regs[4] = strtoul(k0_l, NULL, 16); // right one terminates in 5168
		printf("k0 low written %x\n", regs[4]);
		regs[5] = strtoul(k0_h, NULL, 16); // supposeed to end in 3
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
