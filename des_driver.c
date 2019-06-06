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

int main(int argc, char **argv) {
  int status = 0; // return status
  int fd;         // file descriptor for device file
  // the interface registers of the hardware peripheral, memory-mapped in
  // virtual address space
  volatile uint32_t *regs;

  // Open device
  fd = open(DES_DEVICE, O_RDWR);
  if(fd == -1) {
    fprintf(stderr, "Cannot open device file %s: %s\n", DES_DEVICE, strerror(errno));
    return -1;
  }

  // Map device file in memory, read-only, shared with other processes mapping
  // the same memory region
  regs = mmap(NULL, DES_SIZE, PROT_READ, MAP_SHARED, fd, 0);
  if(regs == MAP_FAILED) {
    fprintf(stderr, "Mapping error: %s\n", strerror(errno));
    close(fd);
    return -1;
  }

  // Infinite loop waiting for interrupts
  while(1) {
    uint32_t interrupts; // interrupts counter


	// Enable interrupts
    interrupts = 1;
	// Enable interrupts
    if(write(fd, &interrupts, sizeof(interrupts)) < 0) {
      fprintf(stderr, "Cannot enable interrupts: %s\n", strerror(errno));
      status = -1;
      break;
    }

	// Here we will write on our registers
	// Plaintext
	regs[0] = 0xd55297ad;
	regs[1] = 0xbec7fa95;
	// Cyphertext
	regs[2] = 0xd1b6fc54;
	regs[3] = 0x0f4b5674;
	// Starting secret key
	regs[4] = 0x9f2d5068; // right one terminates in 168
	regs[5] = 0x009473f4;


   // Wait for interrupt
    if(read(fd, &interrupts, sizeof(interrupts)) < 0) {
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

