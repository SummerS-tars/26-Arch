#!/usr/bin/env python3
"""Generate tiny RV64 Sv39 page-fault self-tests.

Each generated binary enters S-mode with one 1GB identity mapping for the test
code, then triggers exactly one unmapped access. The M-mode trap handler checks
mcause/mtval and ends with the project's custom good-trap instruction.
"""

from __future__ import annotations

import struct
from pathlib import Path


BASE_PC = 0x80000000
ROOT_PT = 0x80001000
BAD_VA = 0x40000000
OUT_DIR = Path(__file__).resolve().parent

ZERO = 0
T0 = 5
T1 = 6
A0 = 10
A1 = 11
A2 = 12

CSR_MSTATUS = 0x300
CSR_MTVEC = 0x305
CSR_MEPC = 0x341
CSR_MCAUSE = 0x342
CSR_MTVAL = 0x343
CSR_SATP = 0x180

CAUSE_INST_PAGE_FAULT = 12
CAUSE_LOAD_PAGE_FAULT = 13
CAUSE_STORE_PAGE_FAULT = 15
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
        ((imm >> 12) & 0x1) << 31
        | ((imm >> 5) & 0x3F) << 25
        | (rs2 << 20)
        | (rs1 << 15)
        | (funct3 << 12)
        | ((imm >> 1) & 0xF) << 8
        | ((imm >> 11) & 0x1) << 7
        | opcode
    )


def j_type(opcode: int, rd: int, offset: int) -> int:
    check_signed(offset, 21)
    imm = offset & 0x1F_FFFF
    return (
        ((imm >> 20) & 0x1) << 31
        | ((imm >> 1) & 0x3FF) << 21
        | ((imm >> 11) & 0x1) << 20
        | ((imm >> 12) & 0xFF) << 12
        | (rd << 7)
        | opcode
    )


def r_type(opcode: int, rd: int, funct3: int, rs1: int, rs2: int) -> int:
    return (rs2 << 20) | (rs1 << 15) | (funct3 << 12) | (rd << 7) | opcode


def lui(rd: int, imm20: int) -> int:
    return ((imm20 & 0xFFFFF) << 12) | (rd << 7) | 0x37


def addi(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x13, rd, 0b000, rs1, imm)


def addiw(rd: int, rs1: int, imm: int) -> int:
    return i_type(0x1B, rd, 0b000, rs1, imm)


def slli(rd: int, rs1: int, shamt: int) -> int:
    return (shamt << 20) | (rs1 << 15) | (0b001 << 12) | (rd << 7) | 0x13


def or_(rd: int, rs1: int, rs2: int) -> int:
    return r_type(0x33, rd, 0b110, rs1, rs2)


def ld(rd: int, rs1: int) -> int:
    return i_type(0x03, rd, 0b011, rs1, 0)


def sd(rs2: int, rs1: int) -> int:
    return s_type(0x23, 0b011, rs1, rs2, 0)


def jalr(rd: int, rs1: int) -> int:
    return i_type(0x67, rd, 0b000, rs1, 0)


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


def build(kind: str, cause: int, trigger_instr: int) -> Program:
    program = Program()
    program.label("start")
    program.jal(ZERO, "m_entry", "jump to setup")

    program.label("trap_handler")
    program.emit(csrr(T0, CSR_MCAUSE), "trap: read mcause")
    program.bne(T0, A1, "fail", "check expected cause")
    program.emit(csrr(T0, CSR_MTVAL), "trap: read mtval")
    program.bne(T0, A2, "fail", "check expected mtval")
    program.emit(addi(A0, ZERO, 0), "good trap code")
    program.emit(TRAP_INST, "good trap")

    program.label("fail")
    program.emit(addi(A0, ZERO, 1), "bad trap code")
    program.emit(TRAP_INST, "bad trap")

    program.label("m_entry")
    program.load_label(T0, "trap_handler", "mtvec = trap_handler")
    program.emit(csrw(CSR_MTVEC, T0), "write mtvec")
    program.emit(addi(T0, ZERO, 1), "satp mode high bit")
    program.emit(slli(T0, T0, 63), "satp MODE=Sv39")
    program.emit_all(load_i32(T1, ROOT_PT >> 12), "root page table PPN")
    program.emit(or_(T0, T0, T1), "satp value")
    program.emit(csrw(CSR_SATP, T0), "enable Sv39")
    program.emit(0x12000073, "sfence.vma")
    program.load_label(T0, "s_fault", "mepc = S-mode fault stage")
    program.emit(csrw(CSR_MEPC, T0), "write mepc")
    program.emit_all(load_i32(T0, 0x800), "mstatus.MPP = S")
    program.emit(csrw(CSR_MSTATUS, T0), "write mstatus")
    program.emit(0x30200073, "enter S-mode")

    program.label("s_fault")
    program.emit(addi(A1, ZERO, cause), f"expect {kind} page fault")
    program.emit_all(load_i32(A2, BAD_VA), "expected mtval")
    program.emit_all(load_i32(T1, BAD_VA), "bad VA")
    program.emit(trigger_instr, f"trigger {kind} page fault")
    program.emit(addi(A0, ZERO, 2), "fault did not happen")
    program.emit(TRAP_INST, "bad trap")
    return program


def write_image(name: str, program: Program) -> None:
    resolved = program.resolve()
    image = bytearray(b"".join(struct.pack("<I", instr) for instr, _ in resolved))

    root_offset = ROOT_PT - BASE_PC
    if len(image) > root_offset:
        raise RuntimeError("program overlaps root page table")
    image.extend(b"\x00" * (root_offset - len(image) + 4096))

    root_index = (BASE_PC >> 30) & 0x1FF
    pte_flags = 0x001 | 0x002 | 0x004 | 0x008 | 0x040 | 0x080
    pte = ((BASE_PC >> 12) << 10) | pte_flags
    struct.pack_into("<Q", image, root_offset + root_index * 8, pte)

    (OUT_DIR / f"page_fault_{name}.bin").write_bytes(image)
    with (OUT_DIR / f"page_fault_{name}.S").open("w", encoding="utf-8") as listing:
        listing.write("# Generated by gen_page_fault_test.py\n")
        for index, (instr, comment) in enumerate(resolved):
            listing.write(f"{BASE_PC + index * 4:016x}: {instr:08x}")
            if comment:
                listing.write(f"  # {comment}")
            listing.write("\n")
        listing.write(f"\n# root[{root_index}] = 0x{pte:016x} at 0x{ROOT_PT + root_index * 8:016x}\n")


def main() -> None:
    tests = {
        "load": (CAUSE_LOAD_PAGE_FAULT, ld(T0, T1)),
        "store": (CAUSE_STORE_PAGE_FAULT, sd(T0, T1)),
        "inst": (CAUSE_INST_PAGE_FAULT, jalr(ZERO, T1)),
    }
    for name, (cause, instr) in tests.items():
        write_image(name, build(name, cause, instr))


if __name__ == "__main__":
    main()
