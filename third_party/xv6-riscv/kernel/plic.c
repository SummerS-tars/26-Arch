#include "types.h"
#include "param.h"
#include "memlayout.h"
#include "riscv.h"
#include "defs.h"

//
// the riscv Platform Level Interrupt Controller (PLIC).
//

void
plicinit(void)
{
  // No PLIC is wired in the 26-Arch difftest platform yet.
}

void
plicinithart(void)
{
  // No-op.
}

// ask the PLIC what interrupt we should serve.
int
plic_claim(void)
{
  return 0;
}

// tell the PLIC we've served this IRQ.
void
plic_complete(int irq)
{
  (void)irq;
}
