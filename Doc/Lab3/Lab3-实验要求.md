# Lab 3 - 跳转和条件跳转

> 课程：计算机组成与体系结构（H）
> 截止：2026-04-21 23:59 ⚠️
> Wiki：https://github.com/26-Arch/26-Arch/wiki/Lab-3
> 仓库：https://github.com/26-Arch/26-Arch

---

## 实验要求

要求 CPU 支持跳转和条件跳转。CPU 需要支持以下指令并通过测试：

### 分支指令（Branch）
| 指令 | 功能 |
|------|------|
| `beq` | 相等跳转 |
| `bne` | 不等跳转 |
| `blt` | 小于跳转（有符号） |
| `bge` | 大于等于跳转（有符号） |
| `bltu` | 小于跳转（无符号） |
| `bgeu` | 大于等于跳转（无符号） |

### 移位与比较 — 立即数版本
| 指令 | 功能 |
|------|------|
| `slti` | 立即数比较设置（有符号） |
| `sltiu` | 立即数比较设置（无符号） |
| `slli` | 立即数逻辑左移 |
| `srli` | 立即数逻辑右移 |
| `srai` | 立即数算术右移 |

### 移位与比较 — 寄存器版本
| 指令 | 功能 |
|------|------|
| `sll` | 逻辑左移 |
| `slt` | 小于比较设置（有符号） |
| `sltu` | 小于比较设置（无符号） |
| `srl` | 逻辑右移 |
| `sra` | 算术右移 |

### 宽版本（32 位操作，结果符号扩展到 64 位）
| 指令 | 功能 |
|------|------|
| `slliw` | 32 位逻辑左移 |
| `srliw` | 32 位逻辑右移 |
| `sraiw` | 32 位算术右移 |
| `sllw` | 32 位逻辑左移 |
| `srlw` | 32 位逻辑右移 |
| `sraw` | 32 位算术右移 |

### PC 相关
| 指令 | 功能 |
|------|------|
| `auipc` | PC + 立即数 → 寄存器 |
| `jalr` | 寄存器间接跳转并链接 |
| `jal` | 直接跳转并链接 |

---

## 上板测试

本次 Lab **要求上板测试**（因此时间多一周）。

报告应包含 **Vivado 上板的输出**。

---

## Difftest 修改（重要）

测试 Lab3 之前，需要对 `DifftestInstrCommit`（在 `core.sv`）进行修改：

```verilog
.skip ((mem & memaddr[31] == 0)),
```

**原因：** 外部设备（开发板开关、IO、时钟）映射到 `0x0000_0000~0x7FFF_FFFF` 内存空间。Difftest 无法读取外设状态，因此跳过对外设内存读写指令的判断。

⚠️ **必须保证 skip 正确（不能一直为 1），否则 Difftest 完全失效！**

---

## 测试

```bash
make test-lab3          # 标准测试，看到 HIT GOOD TRAP 即通过
make test-lab3-extra    # 含乘除法指令的测试（可选）
```

输出中 `it/s` 代表 CPU 性能（假设 clock 为 25MHz）。

### 生成波形图

```bash
make test-lab3 VOPT="--dump-wave"                              # 前 10^6 周期
make test-lab3 VOPT="--dump-wave -b 10000000 -e 10100000"      # 指定区间
```

生成的 `.fst` 文件在 `build/` 目录下，使用 `gtkwave` 打开。

---

## Lab 3 的核心挑战：控制冒险

实现跳转/分支指令后，五级流水线会面临 **控制冒险（Control Hazard）**：

- **分支预测错误：** 取指阶段已经取了跳转目标之后的两条指令，但实际应跳转到其他地址
- **解决方案选择：**
  - ** stall / flush：** 简单但性能差——检测到跳转后暂停流水线
  - **延迟槽（Delay Slot）：** 不推荐
  - **分支预测：** 更复杂但性能更好——预测跳转方向，错误时 flush

---

## 历史 Labs 累积指令

为方便排查，以下是 Lab 1-3 的全部指令集：

### Lab 1 — 算术与逻辑运算
`addi`, `xori`, `ori`, `andi`, `add`, `sub`, `and`, `or`, `xor`, `addiw`, `addw`, `subw`
选做：`mul`, `div`, `divu`, `rem`, `remu`, `mulw`, `divw`, `divuw`, `remw`, `remuw`

### Lab 2 — 内存读写 + LUI
`ld`, `sd`, `lb`, `lh`, `lw`, `lbu`, `lhu`, `lwu`, `sb`, `sh`, `sw`, `lui`

### Lab 3 — 跳转、条件跳转、移位、比较
见上方表格。完成后理论上已支持 **RV64I（+M）完整非特权指令集**。

---

## 扩展（可选，不加分）

自 Lab 3 完成后，CPU 已是完整的 RV64I(+M) 处理器，可以用 `riscv64-unknown-elf-g++` 编译 C++ 程序在上面运行。

- 测试模板仓库：https://github.com/26-Arch/testgen
- 可用函数（`fudan_arch.h`）：`putchar`, `puts`, `put_i<T>`, `memcpy`, `uptime_us`
- 不能使用标准库

---

## 提交要求

1. 主目录下新建 `docs/` 文件夹
2. 将报告（PDF）放入并命名为 `report.pdf`
3. 运行 `make handin`
4. 提交生成的 **zip 文件**（仅 zip）

- 提交平台：Elearning
- 截止：4 月 21 日 23:59
- 满分 100 分，迟交扣分，代码无法运行可能扣大部分
- 报告要求清晰易读，不按格式/字数评分

---

## 参考资料

- [实验讲解（Difftest / 总线 / Verilator / 调试）](https://github.com/26-Arch/26-Arch/wiki/%E5%AE%9E%E9%AA%8C%E8%AE%B2%E8%A7%A3)
- [Lab 1 Wiki](https://github.com/26-Arch/26-Arch/wiki/Lab-1)
- [Lab 2 Wiki](https://github.com/26-Arch/26-Arch/wiki/Lab-2)
- [自测试生成器](https://github.com/26-Arch/testgen)
- [Verilator Warnings 说明](https://verilator.org/guide/latest/warnings.html)
