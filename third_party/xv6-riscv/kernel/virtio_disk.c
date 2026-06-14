//
// RAM-disk backed block driver for the 26-Arch difftest platform.
//
// The host emu loads xv6-fs.img into physical memory at RAMDISK via
// --fs-image. xv6's buffer cache still calls the stock virtio_disk_* names, so
// this file keeps the existing interface while replacing the QEMU virtio MMIO
// protocol with direct memory copies.
//

#include "types.h"
#include "riscv.h"
#include "defs.h"
#include "param.h"
#include "memlayout.h"
#include "spinlock.h"
#include "sleeplock.h"
#include "fs.h"
#include "buf.h"

static struct spinlock ramdisk_lock;

void
virtio_disk_init(void)
{
  initlock(&ramdisk_lock, "ramdisk");
}

void
virtio_disk_rw(struct buf *b, int write)
{
  uint64 offset = (uint64)b->blockno * BSIZE;

  if (offset + BSIZE > RAMDISK_SIZE)
    panic("ramdisk block out of range");

  acquire(&ramdisk_lock);
  if (write)
    memmove((void *)(RAMDISK + offset), b->data, BSIZE);
  else
    memmove(b->data, (void *)(RAMDISK + offset), BSIZE);
  release(&ramdisk_lock);
}

void
virtio_disk_intr(void)
{
  // RAM-disk operations complete synchronously.
}
