#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "defs.h"

void main();
void timerinit();

// entry.S needs one stack per CPU.
__attribute__((aligned(16))) char stack0[4096 * NCPU];

// entry.S jumps here in machine mode on stack0.
void
start()
{
  // keep each CPU's hartid in its tp register, for cpuid().
  int id = r_mhartid();
  w_tp(id);

  // Bring-up workaround: run the kernel entry directly in machine mode first.
  // The stock mret-to-S path still needs a dedicated CSR/mret debug pass.
  main();
  for (;;)
    ;
}

// ask each hart to generate timer interrupts.
void
timerinit()
{
  // No-op on the 26-Arch difftest platform for now.
}
