#!/usr/bin/env python3
"""Generate a tiny RV64 binary covering all 32-bit AMO RMW ops.

The repository environment may not have a RISC-V assembler installed, so this
script emits raw instruction words directly. The generated program is loaded at
0x80000000, uses 0x80000700 as a scratch word, and ends with the project's
custom good-trap instruction on success.
"""

from __future__ import annotations

import struct
from pathlib import Path


BASE_PC = 0x80000000
OUT_DIR = Path(__file__).resolve().parent
BIN_PATH = OUT_DIR / "atomic_full_w.bin"
LISTING_PATH = OUT_DIR / "atomic_full_w.S"

ZERO = 0
T0 = 5
T1 = 6
T2 = 7
T3 = 28
T4 = 29
T5 = 30
T6 = 31


def check_signed(value: int, bits: int) -> int:
    low = -(1 << (bits - 1))
    high = (1 << (bits - 1)) - 1
    if not (low <= value <= high):
        raise ValueError(f"{value} does not fit signed {bits}")
    return value


def s32(value: int) -> int:
    value &= 0xFFFF_FFFF
    return value if value < 0x8000_0000 else value - 0x1_0000_0000


def i_type(opcode: int, rd: int, funct3: int, rs1: int, imm: int) -> int:
    check_signed(imm, 12)
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def s_type(opcode: int, funct3: int, rs1: int, rs2: int, imm: int) -> int:
    check_signed(imm, 12)
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode


def b_type(opcode: int, funct3: int, rs1: int, rs2: int, offset: int) -> int:
    if offset % 2:
        raise ValueError("branch offset must be 2-byte aligned")
    check_signed(offset, 13)
    imm = offset & 0x1FFF
    return (
        ((imm >> 12) & 0x1) << 31
        | ((imm >> 5) & 0x3F) << 25
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm >> 1) & 0xF) << 8
        | ((imm >> 11) & 0x1) << 7
        | opcode
    )


def lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def addi(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x13, rd, 0b000, rs1, imm)


def addiw(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x1B, rd, 0b000, rs1, imm)


def slli(rd: int, rs1: int, shamt: int) -> int:
    if not (0 <= shamt < 64):
        raise ValueError("RV64 slli shamt must fit 6 bits")
    return (shamt << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0x13


def sw(rs2: int, rs1: int, imm: int = 0) -> int:
    return s_type(0x23, 0b010, rs1, rs2, imm)


def lw(rd: int, rs1: int, imm: int = 0) -> int:
    return i_type(0x03, rd, 0b010, rs1, imm)


def amo_w(funct5: int, rd: int, rs2: int, rs1: int) -> int:
    return (funct5 << 27) | (rs2 << 20) | (rs1 << 15) | (0b010 << 12) | (rd << 7) | 0x2F


def load_i32(rd: int, value: int) -> list[int]:
    signed = s32(value)
    upper = (signed + 0x800) >> 12
    lower = signed - (upper << 12)
    if upper == 0:
        return [addiw(rd, ZERO, lower)]
    return [lui(rd, upper), addiw(rd, rd, lower)]


def word_result(op: str, old: int, rs2: int) -> int:
    old_u = old & 0xFFFF_FFFF
    rs_u = rs2 & 0xFFFF_FFFF
    if op == "swap":
        return rs_u
    if op == "add":
        return (old_u + rs_u) & 0xFFFF_FFFF
    if op == "xor":
        return old_u ^ rs_u
    if op == "and":
        return old_u & rs_u
    if op == "or":
        return old_u | rs_u
    if op == "min":
        return old_u if s32(old_u) < s32(rs_u) else rs_u
    if op == "max":
        return old_u if s32(old_u) > s32(rs_u) else rs_u
    if op == "minu":
        return old_u if old_u < rs_u else rs_u
    if op == "maxu":
        return old_u if old_u > rs_u else rs_u
    raise ValueError(op)


class Program:
    def __init__(self) -> None:
        self.items: list[tuple[str, int | tuple[int, int, str], str]] = []
        self.labels: dict[str, int] = {}

    @property
    def pc(self) -> int:
        return BASE_PC + len(self.items) * 4

    def label(self, name: str) -> None:
        self.labels[name] = self.pc

    def emit(self, instr: int, comment: str) -> None:
        self.items.append(("instr", instr, comment))

    def emit_all(self, instrs: list[int], comment: str) -> None:
        for index, instr in enumerate(instrs):
            self.emit(instr, comment if index == len(instrs) - 1 else "")

    def bne(self, rs1: int, rs2: int, label: str, comment: str) -> None:
        self.items.append(("bne", (rs1, rs2, label), comment))

    def resolve(self) -> list[tuple[int, str]]:
        out: list[tuple[int, str]] = []
        for index, (kind, payload, comment) in enumerate(self.items):
            pc = BASE_PC + index * 4
            if kind == "instr":
                out.append((payload, comment))  # type: ignore[arg-type]
            else:
                rs1, rs2, label = payload  # type: ignore[misc]
                out.append((b_type(0x63, 0b001, rs1, rs2, self.labels[label] - pc), comment))
        return out


def add_amo_check(program: Program, name: str, funct5: int, old: int, rs2: int) -> None:
    expected_new = word_result(name, old, rs2)
    program.emit_all(load_i32(T1, old), f"{name}: init memory = 0x{old & 0xFFFF_FFFF:08x}")
    program.emit(sw(T1, T0), "store initial word")
    program.emit_all(load_i32(T2, rs2), f"rs2 = 0x{rs2 & 0xFFFF_FFFF:08x}")
    program.emit(amo_w(funct5, T3, T2, T0), f"amo{name}.w")
    program.emit_all(load_i32(T4, old), "expect rd old value")
    program.bne(T3, T4, "fail", "check old value")
    program.emit(lw(T5, T0), "load updated word")
    program.emit_all(load_i32(T6, expected_new), f"expect memory = 0x{expected_new:08x}")
    program.bne(T5, T6, "fail", "check updated memory")


def main() -> None:
    program = Program()
    program.emit(addiw(T0, ZERO, 1), "scratch base high bit")
    program.emit(slli(T0, T0, 31), "x5 = 0x80000000")
    program.emit(addi(T0, T0, 0x700), "x5 = 0x80000700")

    tests = [
        ("swap", 0b00001, 0x1234_5678, 0x8765_4321),
        ("add", 0b00000, 0x7FFF_FFFE, 0x0000_0003),
        ("xor", 0b00100, 0x0F0F_00FF, 0x00FF_0FF0),
        ("and", 0b01100, 0xF0F0_FFFF, 0x0FF0_FF00),
        ("or", 0b01000, 0x0F00_00F0, 0xF000_0F00),
        ("min", 0b10000, 0x8000_0005, 0x0000_0007),
        ("max", 0b10100, 0x8000_0005, 0x0000_0007),
        ("minu", 0b11000, 0x8000_0005, 0x0000_0007),
        ("maxu", 0b11100, 0x8000_0005, 0x0000_0007),
    ]

    for name, funct5, old, rs2 in tests:
        add_amo_check(program, name, funct5, old, rs2)

    program.emit(0x0005006B, "good trap")
    program.label("fail")
    program.emit(0x0000006F, "fail: jump to self")

    resolved = program.resolve()
    BIN_PATH.write_bytes(b"".join(struct.pack("<I", instr) for instr, _ in resolved))
    with LISTING_PATH.open("w", encoding="utf-8") as listing:
        listing.write("# Generated by gen_atomic_full_w_test.py\n")
        for index, (instr, comment) in enumerate(resolved):
            listing.write(f"{BASE_PC + index * 4:016x}: {instr:08x}")
            if comment:
                listing.write(f"  # {comment}")
            listing.write("\n")


if __name__ == "__main__":
    main()
