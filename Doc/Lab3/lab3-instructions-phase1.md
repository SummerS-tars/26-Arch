# 仓库 Lab 完成情况分析

**Date**: April 19, 2026 at 09:41 PM
**Turns**: 1
**Source**: [Gemini Chat](https://gemini.google.com/app/accfb91695017c5a)

---

## Turn 1

### 🤖 Assistant

针对 Lab 3 阶段一（基础无冒险指令扩展），核心目标是将移位与比较逻辑无缝融入现有的五级流水线中。这 10 条指令（`slli/srli/srai`, `sll/srl/sra`, `slti/sltiu`, `slt/sltu`）均属于运算类指令，**不涉及程序计数器（PC）的跳转，也不引发控制冒险**，因此主要工作集中在 **译码（Decode）** 和 **执行（Execute/ALU）** 两个阶段。
以下是具体的实施流程、代码实现思路及 Debug 指南。

---

### 1. 数据通路与分析流程
在动手写代码前，先理清这些指令在流水线中的数据流向：

1. **IF（取指）**：不变，按 `PC + 4` 正常取指令。
2. **ID（译码）**：
  - **识别指令**：根据 `opcode`（I-Type 或 R-Type）、`funct3` 以及 `funct7`（或 I-Type 的高位立即数）识别出具体是哪一条指令。
  - **操作数准备**：比较指令需要读 `rs1` 和 `rs2`（或立即数 `imm`）；移位指令的移位量来自 `rs2` 的低位，或者 I-Type 指令的 `shamt`（立即数的低位）。
  - **生成控制信号**：产生新的 `alu_op`（例如 `ALU_SLT`, `ALU_SRA` 等）传递给下一级。
3. **EX（执行）**：
  - ALU 根据传入的 `alu_op`，对 `srca` 和 `srcb` 执行对应的比较或移位操作，结果输出到 `alu_result`。
4. **MEM（访存）**：不变，直接透传 `alu_result`（不触发内存读写）。
5. **WB（写回）**：不变，将 `alu_result` 写回目标寄存器 `rd`。

---

### 2. 参考实现细节

#### 步骤一：译码阶段扩展 (`core_decode.sv`)
目前的解码器需要能精确区分这 10 条指令。你需要为这些操作定义对应的 ALU 控制码。
**核心关注点：特殊立即数的提取**
在 RV64I 中，普通的 I-Type 立即数是 12 位符号扩展。但**移位指令（如 srai）的 I-Type 编码是特殊的**：

- 它的低 6 位（`imm[5:0]`）表示移位量（`shamt`）。
- 它的第 30 位（`imm[10]`，即原始指令的第 30 位）被用来区分逻辑右移（`srli`，该位为 0）和算术右移（`srai`，该位为 1）。
**实现思路参考：**

```代码段
// 1. 扩充 ALU OP 定义 (建议在 common.sv 或 config.sv 中)
typedef enum logic [4:0] {
    ALU_ADD, ALU_SUB, ...,
    ALU_SLL, ALU_SRL, ALU_SRA, // 移位
    ALU_SLT, ALU_SLTU          // 比较
} alu_op_t;

// 2. 在 decode 的 case 树中增加匹配逻辑
// 对于 I-Type (opcode == 7'b0010011)
case (funct3)
    3'b010: alu_op = ALU_SLT;  // slti
    3'b011: alu_op = ALU_SLTU; // sltiu
    3'b001: alu_op = ALU_SLL;  // slli
    3'b101: begin
        // 这里必须检查指令的第 30 位来区分逻辑/算术右移
        if (instr[30] == 1'b1) alu_op = ALU_SRA; // srai
        else                   alu_op = ALU_SRL; // srli
    end
endcase

```

#### 步骤二：ALU 执行逻辑扩展 (`core_alu.sv`)
这里主要考验对 SystemVerilog 数据类型和运算符的掌握。
**实现思路参考：**

```代码段
// 提取移位量 (RV64I 中，移位量是操作数 B 的低 6 位)
wire [5:0] shamt = srcb[5:0]; 

always_comb begin
    alu_result = 64'b0; // 默认值
    case (alu_op)
        // --- 比较指令 ---
        // SLTU: 无符号比较，直接使用 < 运算符
        ALU_SLTU: alu_result = (srca < srcb) ? 64'b1 : 64'b0;
        
        // SLT: 有符号比较，必须显式转换为 $signed
        ALU_SLT:  alu_result = ($signed(srca) < $signed(srcb)) ? 64'b1 : 64'b0;

        // --- 移位指令 ---
        ALU_SLL:  alu_result = srca << shamt;
        ALU_SRL:  alu_result = srca >> shamt;
        
        // SRA: 算术右移。注意：不仅要使用 >>> 运算符，左操作数还必须被识别为有符号数！
        ALU_SRA:  alu_result = $unsigned($signed(srca) >>> shamt); 
        // ... 其他运算
    endcase
end

```

---

### 3. 验证方法
在这个阶段，由于还未实现分支跳转，不能依赖完整的 C 程序测试（因为 C 语言的 `if-else` 或循环必然会编译出控制流指令）。你需要**手写纯直线的汇编代码**来针对性测试。
**编写验证脚本 (test_phase1.S)**：

```代码段
.global _start
_start:
    # 1. 测试有符号与无符号比较
    li x1, -5          # x1 = 0xFFFFFFFFFFFFFFFB
    li x2, 5           # x2 = 5
    slt x3, x1, x2     # x3 应该为 1 (-5 < 5)
    sltu x4, x1, x2    # x4 应该为 0 (极大的无符号数不小于 5)

    # 2. 测试算术右移与逻辑右移
    li x5, 0xF000000000000000
    srli x6, x5, 4     # x6 = 0x0F00000000000000 (高位补 0)
    srai x7, x5, 4     # x7 = 0xFF00000000000000 (高位补符号位)

    # 用一个死循环结束（这需要 jump，如果没有，就在仿真台设置固定运行周期即可）

```
将此文件编译为 `.bin` 后，加载到你的模拟器中运行固定周期（例如 20 个周期），然后**打印或在波形中观察寄存器堆 x3, x4, x6, x7 的最终值**是否符合预期。

---

### 4. 常见问题与基础 Debug 思路
作为习惯于处理后端架构和系统级问题的开发者，你会发现硬件底层的 Debug 往往更依赖对数据边界和类型系统的敏锐度。以下是这一阶段最容易踩坑的点：

#### 坑点 1：Verilog 的有符号数“陷阱”（最常见）

- **现象**：`slt` (有符号比较) 和 `sra` (算术右移) 算出的结果完全不对，负数被当作极大正数处理，或者算术右移高位补了 0。
- **根因**：SystemVerilog 中，如果你声明的 `srca` 是 `logic [63:0]`，系统默认它是**无符号**的。即使你使用了 `>>>` 算术右移操作符，如果左操作数不是 `signed` 类型，编译器依然会执行逻辑右移操作。
- **Debug 方案**：必须严格使用 `$signed()` 进行强制类型转换。例如 `$signed(srca) >>> shamt`。在看波形时，可以把对应信号的显示格式（Radix）调成 `Decimal (Signed)`，直观查看当前传入的到底是不是负数。

#### 坑点 2：移位截断错误

- **现象**：遇到极大的立即数（虽然不合规但可能出现在测试边界条件中）时，移位结果异常。
- **根因**：RV64 规范要求，对于 64 位寄存器操作，**移位量仅看低 6 位**（取值 0-63）。如果没有截断 `srcb` 的低 6 位，直接 `srca << srcb` 可能会导致未定义行为或综合出庞大且多余的移位器逻辑。
- **Debug 方案**：确保在 ALU 中明确写出 `srcb[5:0]` 作为 shift_amount。

#### 体系结构级的 Debug 手段
如果肉眼看不出波形错误，请立即启用 Diff-Test：

1. 开启你项目里的 Verilator 与 NEMU 的 Diff-Test。
2. 运行你的测试汇编。
3. Diff-Test 会在你第一条算错的 `slt` 或 `srai` 指令 Commit 时**立刻报错**，并告诉你：“在 PC = 0x80000xxx 处，NEMU 算出的 `rd` 是 Y，你的 CPU 算出的 `rd` 是 Z”。
4. 拿到这个出错的 PC 地址，回到 GTKWave 波形图中，查找取指阶段 `pc == 0x80000xxx` 的那一刻。
5. 顺着流水线往后跟 2 个时钟周期，观察该指令在 EX 阶段时的 `alu_op`、`srca`、`srcb` 到底是什么值，通常就能秒定位是译码解错了，还是 ALU 算错了。

---

*Exported from [Voyager](https://github.com/Nagi-ovo/gemini-voyager)*  
*Generated on April 19, 2026 at 09:41 PM*