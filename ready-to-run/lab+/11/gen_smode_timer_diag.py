#!/usr/bin/env python3
"""Generate a tiny S-mode timer delegation diagnostic.

The expected architectural behavior for full xv6-style S-mode timer support is
that an enabled delegated timer interrupt traps to stvec with scause=STIP
(0x8000...0005). The current RTL may still route the machine timer interrupt to
M-mode; this test records that as a diagnostic failure.
"""

from __future__ import annotations

import struct
from pathlib import Path


BASE_PC = 0x80000000
OUT_DIR = Path(__file__).resolve().parent

ZERO = 0
T0 = 5
T1 = 6
A0 = 10

CSR_SSTATUS = 0x100
CSR_STVEC = 0x105
CSR_MSTATUS = 0x300
CSR_MIE = 0x304
CSR_MTVEC = 0x305
CSR_MIDELEG = 0x303
CSR_MEPC = 0x341
CSR_MCAUSE = 0x342
CSR_SCAUSE = 0x142

CLINT_MTIMECMP = 0x3800_4000
TRAP_INST = 0x0005006B


def check_signed(value: int, bits: int) -> None:
    if not (-(1 << (bits - 1)) <= value <= (1 << (bits - 1)) - 1):
        raise ValueError(f"{value} does not fit signed {bits}")


def i_type(opcode: int, rd: int, funct3: int, rs1: int, imm: int) -> int:
    check_signed(imm, 12)
    return ((imm & 0xFFF) << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def s_type(opcode: int, funct3: int, rs1: int, rs2: int, imm: int) -> int:
    check_signed(imm, 12)
    imm &= 0xFFF
    return ((imm >> 5) << 25) | (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | ((imm & 0x1F) << 7) | opcode


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


def j_type(opcode: int, rd: int, offset: int) -> int:
    check_signed(offset, 21)
    imm = offset & 0x1F_FFFF
    return (
        ((imm >> 20) & 1) << 31
        | ((imm >> 1) & 0x3FF) << 21
        | ((imm >> 11) & 1) << 20
        | ((imm >> 12) & 0xFF) << 12
        | (rd << 7)
        | opcode
    )


def lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def addi(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x13, rd, 0b000, rs1, imm)


def slli(rd: int, rs1: int, shamt: int) -> int:
    return (shamt << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0x13


def sd(rs2: int, rs1: int, imm: int = 0) -> int:
    return s_type(0x23, 0b011, rs1, rs2, imm)


def csrw(csr: int, rs1: int) -> int:
    return (csr << 20) | (rs1 << 15) | (0b001 << 12) | 0x73


def csrr(rd: int, csr: int) -> int:
    return (csr << 20) | (0b010 << 12) | (rd << 7) | 0x73


def load_i32(rd: int, value: int) -> list[int]:
    value &= 0xFFFF_FFFF
    signed = value if value < 0x8000_0000 else value - 0x1_0000_0000
    upper = (signed + 0x800) >> 12
    lower = signed - (upper << 12)
    if upper == 0:
        return [addi(rd, ZERO, lower)]
    return [lui(rd, upper), addi(rd, rd, lower)]


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

    def jal(self, rd: int, label: str, comment: str = "") -> None:
        self.items.append(("jal", (rd, label), comment))

    def load_label(self, rd: int, label: str, comment: str = "") -> None:
        self.items.append(("label_base", (rd, label), ""))
        self.items.append(("label_shift", (rd, label), ""))
        self.items.append(("label_off", (rd, label), comment))

    def resolve(self) -> list[tuple[int, str]]:
        out: list[tuple[int, str]] = []
        for index, (kind, payload, comment) in enumerate(self.items):
            pc = BASE_PC + index * 4
            if kind == "instr":
                out.append((payload, comment))  # type: ignore[arg-type]
            elif kind == "bne":
                rs1, rs2, label = payload
                out.append((b_type(0x63, 0b001, rs1, rs2, self.labels[label] - pc), comment))
            elif kind == "jal":
                rd, label = payload
                out.append((j_type(0x6F, rd, self.labels[label] - pc), comment))
            else:
                rd, label = payload
                offset = self.labels[label] - BASE_PC
                check_signed(offset, 12)
                if kind == "label_base":
                    out.append((addi(rd, ZERO, 1), comment))
                elif kind == "label_shift":
                    out.append((slli(rd, rd, 31), comment))
                else:
                    out.append((addi(rd, rd, offset), comment))
        return out


def build() -> Program:
    program = Program()
    program.jal(ZERO, "m_entry", "jump to setup")

    program.label("m_trap")
    program.emit(csrr(T0, CSR_MCAUSE), "read mcause for debug visibility")
    program.emit(addi(A0, ZERO, 1), "diagnostic failure: interrupt trapped to M-mode")
    program.emit(TRAP_INST, "bad trap")

    program.label("s_trap")
    program.emit(csrr(T0, CSR_SCAUSE), "read scause for debug visibility")
    program.emit(addi(A0, ZERO, 0), "diagnostic success")
    program.emit(TRAP_INST, "good trap")

    program.label("m_entry")
    program.load_label(T0, "m_trap", "mtvec = m_trap")
    program.emit(csrw(CSR_MTVEC, T0), "write mtvec")
    program.load_label(T0, "s_trap", "stvec = s_trap")
    program.emit(csrw(CSR_STVEC, T0), "write stvec")
    program.emit(addi(T0, ZERO, 1 << 5), "delegate STIP")
    program.emit(csrw(CSR_MIDELEG, T0), "write mideleg")
    program.emit(addi(T0, ZERO, 1 << 7), "enable MTIE source for current platform")
    program.emit(csrw(CSR_MIE, T0), "write mie")
    program.emit_all(load_i32(T1, CLINT_MTIMECMP), "mtimecmp address")
    program.emit(sd(ZERO, T1), "mtimecmp = 0")
    program.emit_all(load_i32(T0, 0x802), "MPP=S and SIE=1")
    program.emit(csrw(CSR_MSTATUS, T0), "write mstatus")
    program.load_label(T0, "s_wait", "mepc = s_wait")
    program.emit(csrw(CSR_MEPC, T0), "write mepc")
    program.emit(0x30200073, "mret to S-mode")

    program.label("s_wait")
    program.jal(ZERO, "s_wait", "wait for delegated timer interrupt")
    return program


def write_image(program: Program) -> None:
    resolved = program.resolve()
    image = bytearray(b"".join(struct.pack("<I", instr) for instr, _ in resolved))
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "smode_timer_diag.bin").write_bytes(image)
    with (OUT_DIR / "smode_timer_diag.S").open("w") as asm:
        for index, (instr, comment) in enumerate(resolved):
            pc = BASE_PC + index * 4
            suffix = f" # {comment}" if comment else ""
            asm.write(f"{pc:016x}: {instr:08x}{suffix}\n")


if __name__ == "__main__":
    write_image(build())
    print("generated smode_timer_diag.bin")
