# 仓库 Lab 完成情况分析

**Date**: April 19, 2026 at 09:41 PM
**Turns**: 1
**Source**: [Gemini Chat](https://gemini.google.com/app/accfb91695017c5a)

---

## Turn 1

### 🤖 Assistant

针对 Lab 3 阶段二（无条件跳转 JAL / JALR 的数据通路与副作用），核心目标是**计算出正确的跳转目标地址（Target PC）**，并且**将返回地址（PC + 4）正确写回目标寄存器（Link Register）**。
在这个阶段，我们**暂时先不处理**由于跳转带来的流水线冲刷（Flush）问题（这是阶段四的任务）。为了验证，我们会在测试汇编的跳转指令后手动插入 NOP（空指令），以“肉眼”规避控制冒险。
以下是具体的分析流程、参考实现及 Debug 指南。

---

### 1. 数据通路与分析流程
无条件跳转指令（`jal`, `jalr`）的特殊性在于它们具有“双重身份”：既要修改 PC（控制流），又要写寄存器（数据流）。我们需要理清这两条独立的数据通路：

1. **IF（取指）**：
  - 现有的 `Next_PC` 逻辑是单纯的 `PC + 4`。
  - **改造**：需要引入一个多路选择器（MUX）。当检测到跳转时，`Next_PC` 切换为后续阶段计算出的 `Target_PC`。
2. **ID（译码）**：
  - **识别指令**：识别 J-Type（`jal`，opcode=`1101111`）和 I-Type（`jalr`，opcode=`1100111`，funct3=`000`）。
  - **立即数提取（易错！）**：按照 RV 规范，将指令中的立即数乱序片段拼接并进行符号扩展。
  - **保存 PC+4**：跳转指令需要将 `当前 PC + 4` 写回 `rd`。当前阶段的 PC 需要被流水线寄存器一路传递下去。
3. **EX（执行）**：
  - **计算 Target PC**：
    - 对于 `jal`：`Target_PC = Current_PC + sext(imm)`
    - 对于 `jalr`：`Target_PC = (rs1 + sext(imm)) & ~64'b1`
  - **计算 Link Address**：计算 `Current_PC + 4`（如果你的取指模块已经输出了 `PC+4`，直接透传即可）。
  - *架构设计抉择*：你可以让主 ALU 去算 `PC+4`，用一个额外的加法器算 `Target_PC`；也可以反过来。通常建议用额外的专用加法器计算 `Target_PC`（为后续分支预测提前做准备），主 ALU 不做运算或透传 `PC+4`。
4. **MEM（访存）**：透传 Link Address，不进行内存读写。
5. **WB（写回）**：将传下来的 Link Address（`PC+4`）写回目标寄存器 `rd`（通常是 `x1/ra`）。

---

### 2. 参考实现细节

#### 步骤一：译码阶段与立即数拼接 (`core_decode.sv`)
J-Type 的立即数拼接是整个 RISC-V 编码中最反人类的设计之一，请务必对着官方手册的图仔细核对。
**实现思路参考：**

```代码段
// 1. 扩充控制信号
logic is_jal;
logic is_jalr;

// 2. 解码与立即数提取
always_comb begin
    is_jal  = 1'b0;
    is_jalr = 1'b0;
    imm     = 64'b0;
    
    case (opcode)
        7'b1101111: begin // JAL (J-Type)
            is_jal = 1'b1;
            // 拼接 J-Type 立即数: imm[20|10:1|11|19:12]
            // 注意最低位隐式为0，最高位需符号扩展到 64 位
            imm = {{43{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
        end
        7'b1100111: begin // JALR (I-Type)
            is_jalr = 1'b1;
            // 普通 I-Type 立即数: imm[11:0]
            imm = {{52{instr[31]}}, instr[31:20]};
        end
        // ... 其他指令
    endcase
end

```

#### 步骤二：执行阶段的地址计算 (`core_alu.sv` 或专属的 `core_branch.sv`)
我们需要计算目标地址，并处理 JALR 的强制清零规则。
**实现思路参考：**

```代码段
// 假设这些信号从 ID 级流水线寄存器传入
input logic [63:0] current_pc;
input logic [63:0] rs1_data;
input logic [63:0] imm;
input logic        is_jal;
input logic        is_jalr;

output logic [63:0] target_pc;
output logic        jump_enable; // 告诉 IF 级需要切换 PC 来源

always_comb begin
    target_pc   = 64'b0;
    jump_enable = 1'b0;

    if (is_jal) begin
        target_pc   = current_pc + imm;
        jump_enable = 1'b1;
    end 
    else if (is_jalr) begin
        // JALR 关键点：相加后，最低位强制清零
        target_pc   = (rs1_data + imm) & ~64'b1; 
        jump_enable = 1'b1;
    end
end

```

#### 步骤三：Link Address 的写回通路整合
你需要确保 `PC+4` 被一路传送到 WB 级。一种优雅的做法是在 WB 级的写回多路选择器（Writeback MUX）中增加一个通路：

```代码段
// 在 WB 级，决定写入 rd 的数据来源
always_comb begin
    case (wb_sel)
        WB_SEL_ALU:  rd_data = alu_result;
        WB_SEL_MEM:  rd_data = mem_read_data;
        WB_SEL_PC4:  rd_data = wb_pc + 4; // 处理 JAL/JALR 的副作用
        default:     rd_data = 64'b0;
    endcase
end

```

---

### 3. 验证方法（带 NOP 的防碰撞测试）
因为我们还没实现 Flush，跳转指令后面的 1~2 条指令（视你的 jump_enable 信号从哪一阶段发出而定）会被错误执行。我们**在测试代码中手动插入 NOP 吸收这些气泡**。
**编写验证脚本 (test_phase2.S)**：

```代码段
.global _start
_start:
    li x2, 100         # 给 x2 随便赋个值，作对照

    # 测试 1: JAL 远跳
    jal x1, target_1   # 跳转到 target_1，x1 应该等于当前 PC + 4
    nop                # 吸收 IF 阶段的错误取指
    nop                # 吸收 ID 阶段的错误取指
    li x2, 999         # 如果跳转失败，x2 会被改成 999，测试就失败了

target_1:
    # 此时观察：PC 是否来到了这里？ x1 是否保存了 jal 指令的下一条指令地址？
    
    # 测试 2: JALR 寄存器跳转
    la x3, target_2    # 将 target_2 的地址加载到 x3
    addi x3, x3, 1     # 故意在地址加 1，测试 JALR 的最低位清零功能
    jalr x4, x3, 0     # 跳转到 x3+0，x4 应该保存返回地址，且因为最低位清零，不会报指令不对齐错误
    nop
    nop
    li x2, 888

target_2:
    # 此时观察：PC 是否来到了这里？x4 的值是否正确？
    
    # 死循环结束
end_loop:
    j end_loop

```

---

### 4. 常见坑点与基础 Debug 思路

#### 坑点 1：J-Type 立即数位序拼错（重灾区）

- **现象**：`jal` 跳转到了一个完全随机的、离谱的地址（比如跳到了内存越界区域引发异常）。
- **根因**：RISC-V 的 J-Type 立即数位序是打乱的。如果照抄 I-Type 或者顺序拼接，会导致位权完全错乱。
- **Debug 思路**：在 Vivado 或 GTKWave 中，抓取 `jal` 指令所在 ID 阶段的 `imm` 信号。手动将汇编代码中的偏移量（比如跳转到当前地址 + 0x10）算成二进制，对比波形里的 `imm` 是否真的是 `0x0000_0000_0000_0010`。如果是乱码，一定是拼接逻辑写错了。

#### 坑点 2：JALR 忽略了最低位清零

- **现象**：执行 `jalr` 后，后续取指总是失败，抛出 Instruction Address Misaligned（指令地址未对齐）异常。
- **根因**：RISC-V 要求指令必须是对齐的（通常是 4 字节对齐，如果有 C 扩展则是 2 字节）。`jalr` 规范明确指出 `(rs1 + imm) & ~1`。如果忘记 `& ~1` 且目标地址是奇数，IF 模块发出的取指地址将是非法的。
- **Debug 思路**：检查 EX 级或负责计算 `target_pc` 的模块，确认是否有 `& ~64'b1` 这一步。检查传给 IF 级 SRAM 的地址最低两位是否出现非 `00`（无 C 扩展情况下）的情况。

#### 坑点 3：写回的 PC 值阶段错乱

- **现象**：`x1` (ra) 寄存器保存的返回地址不等于 `jal` 指令的 PC+4，而是等于 `jal` 下面第二条、第三条指令的 PC，甚至等于目标地址。
- **根因**：流水线中 PC 寄存器没有级联传递。如果在 WB 级直接读取全局模块的当前 PC，由于流水线的延迟，当 `jal` 到达 WB 级时，IF 级早就取到了后面的指令。
- **Debug 思路**：检查流水线寄存器。必须在 IF/ID 寄存器中保存 `IF_PC`，在 ID/EX 保存 `ID_PC`，依此类推。WB 级计算 `rd_data = wb_pc + 4` 时，使用的必须是跟着指令**一路漂移下来的 wb_pc**，绝对不能跨阶段飞线读取。

---

*Exported from [Voyager](https://github.com/Nagi-ovo/gemini-voyager)*  
*Generated on April 19, 2026 at 09:41 PM*