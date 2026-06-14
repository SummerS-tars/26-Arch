#!/usr/bin/env python3
"""Generate a tiny RAM-disk loader diagnostic.

The emu loads the main program at 0x80000000 and, with --fs-image, loads a
secondary image at 0x87000000. This test reads a magic word from that fixed
address and ends with the project's custom good trap if the load worked.
"""

from __future__ import annotations

import struct
from pathlib import Path


BASE_PC = 0x80000000
RAMDISK_BASE = 0x87000000
MAGIC = 0x12345678
OUT_DIR = Path(__file__).resolve().parent

ZERO = 0
T0 = 5
T1 = 6
T2 = 7
A0 = 10
TRAP_INST = 0x0005006B


def check_signed(value: int, bits: int) -> None:
    if not (-(1 << (bits - 1)) <= value <= (1 << (bits - 1)) - 1):
        raise ValueError(f"{value} does not fit signed {bits}")


def i_type(opcode: int, rd: int, funct3: int, rs1: int, imm: int) -> int:
    check_signed(imm, 12)
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def b_type(opcode: int, funct3: int, rs1: int, rs2: int, offset: int) -> int:
    check_signed(offset, 13)
    imm = offset & 0x1FFF
    return (
        ((imm >> 12) & 1) << 31
        | ((imm >> 5) & 0x3F) << 25
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm >> 1) & 0xF) << 8
        | ((imm >> 11) & 1) << 7
        | opcode
    )


def r_type(opcode: int, rd: int, funct3: int, rs1: int, rs2: int, funct7: int = 0) -> int:
    return (funct7 << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def addi(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x13, rd, 0b000, rs1, imm)


def addiw(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x1B, rd, 0b000, rs1, imm)


def slli(rd: int, rs1: int, shamt: int) -> int:
    return (shamt << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0x13


def add(rd: int, rs1: int, rs2: int) -> int:
    return r_type(0x33, rd, 0b000, rs1, rs2)


def lw(rd: int, rs1: int) -> int:
    return i_type(0x03, rd, 0b010, rs1, 0)


def load_i32(rd: int, value: int) -> list[int]:
    value &= 0xFFFF_FFFF
    signed = value if value < 0x8000_0000 else value - 0x1_0000_0000
    upper = (signed + 0x800) >> 12
    lower = signed - (upper << 12)
    if upper == 0:
        return [addiw(rd, ZERO, lower)]
    return [lui(rd, upper), addiw(rd, rd, lower)]


class Program:
    def __init__(self) -> None:
        self.items: list[tuple[str, tuple | int, str]] = []
        self.labels: dict[str, int] = {}

    @property
    def pc(self) -> int:
        return BASE_PC + len(self.items) * 4

    def label(self, name: str) -> None:
        self.labels[name] = self.pc

    def emit(self, instr: int, comment: str = "") -> None:
        self.items.append(("instr", instr, comment))

    def emit_all(self, instrs: list[int], comment: str = "") -> None:
        for index, instr in enumerate(instrs):
            self.emit(instr, comment if index == len(instrs) - 1 else "")

    def bne(self, rs1: int, rs2: int, label: str, comment: str = "") -> None:
        self.items.append(("bne", (rs1, rs2, label), comment))

    def resolve(self) -> list[tuple[int, str]]:
        out: list[tuple[int, str]] = []
        for index, (kind, payload, comment) in enumerate(self.items):
            pc = BASE_PC + index * 4
            if kind == "instr":
                out.append((payload, comment))  # type: ignore[arg-type]
            else:
                rs1, rs2, label = payload
                out.append((b_type(0x63, 0b001, rs1, rs2, self.labels[label] - pc), comment))
        return out


def build() -> Program:
    program = Program()
    program.emit(addi(T0, ZERO, 1), "base high bit")
    program.emit(slli(T0, T0, 31), "0x80000000")
    program.emit(addi(T1, ZERO, 7), "ramdisk offset unit")
    program.emit(slli(T1, T1, 24), "0x07000000")
    program.emit(add(T0, T0, T1), "ramdisk base 0x87000000")
    program.emit(lw(T1, T0), "read magic")
    program.emit_all(load_i32(T2, MAGIC), "expected magic")
    program.bne(T1, T2, "fail", "check magic")
    program.emit(addi(A0, ZERO, 0), "good trap code")
    program.emit(TRAP_INST, "good trap")
    program.label("fail")
    program.emit(addi(A0, ZERO, 1), "bad trap code")
    program.emit(TRAP_INST, "bad trap")
    return program


def write_outputs(program: Program) -> None:
    resolved = program.resolve()
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "ramdisk_magic_test.bin").write_bytes(
        b"".join(struct.pack("<I", instr) for instr, _ in resolved)
    )
    (OUT_DIR / "ramdisk_magic.img").write_bytes(struct.pack("<I", MAGIC))
    with (OUT_DIR / "ramdisk_magic_test.S").open("w") as asm:
        for index, (instr, comment) in enumerate(resolved):
            pc = BASE_PC + index * 4
            suffix = f" # {comment}" if comment else ""
            asm.write(f"{pc:016x}: {instr:08x}{suffix}\n")


if __name__ == "__main__":
    write_outputs(build())
    print("generated ramdisk_magic_test.bin and ramdisk_magic.img")
