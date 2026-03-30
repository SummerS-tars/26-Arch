# Lab2 完成度与 Lab3 准备度评估

## 当前范围一句话结论

当前实现已经基于五级流水线骨架实际通过 `Lab2` 基线测试，但还不具备 `Lab3` 所需的控制流与更强指令支持；如果后续继续做 `Lab3`，应把重点从 `MEM` 路径转到 `PC/跳转/分支/冲刷` 主线上。

## 评估依据

本结论同时基于三类信息：

- 仓库结构与标准命令：`Makefile`、`ready-to-run/`
- 当前 RTL 代码检查：`vsrc/src/core.sv`、`vsrc/src/core_decode.sv`
- 实际测试执行：
  - `make test-lab2`
  - `make test-lab1-extra`
  - `make test-lab3`
  - `make test-lab3-extra`

## 当前实现状态

### 代码层面的实际状态

当前 CPU 仍然是一个以 `vsrc/src/core.sv` 为核心的五级流水线实现，已有的能力可以概括为：

- 基本的 `IF/ID/EX/MEM/WB` 流水寄存器与推进框架
- 寄存器堆、ALU、基础 hazard 检测、基础 forwarding
- `Lab2` 所需的 load/store 数据通路
- `dbus` 请求生成、load 宽度截取、符号/零扩展
- Difftest 提交与寄存器状态导出

与之前的 `Lab1 base` 状态相比，当前实现已经明显前进到：

- `Lab2` 基线路径可用
- `MEM` 阶段不再是占位逻辑
- `load/store/lui` 已被接入真实执行路径

### 实测验证状态

#### `make test-lab2`

```text
Command: make test-lab2
Result: PASS
Key line: Core 0: HIT GOOD TRAP at pc = 0x8001fffc
Relevant detail: instrCnt = 32,767, cycleCnt = 80,278
Next step: 可以把 Lab2 视为“当前仓库下已验证通过”的状态
```

#### `make test-lab1-extra`

```text
Command: make test-lab1-extra
Result: FAIL
Key line: s11 different at pc = 0x0080000020, right= 0xffffffffffffffff, wrong = 0x0000000000000000
Relevant detail: 失败点位于 `divu` 所在区域，`ready-to-run/lab1/lab1-extra-test.S` 在该位置开始大量使用 `mul/div/rem`
Next step: 这不是 Lab2 主路径问题，而是 M-extension 尚未实现
```

#### `make test-lab3`

```text
Command: make test-lab3
Result: FAIL
Key line: sp different at pc = 0x0080000000, right= 0x000000008000a000, wrong = 0x0000000000000000
Relevant detail: 在第一条 `auipc sp, ...` 就失配，instrCnt = 0
Next step: 优先补控制流/PC 相对类指令，而不是继续深挖 MEM 路径
```

#### `make test-lab3-extra`

```text
Command: make test-lab3-extra
Result: FAIL
Key line: sp different at pc = 0x0080000000, right= 0x0000000080009000, wrong = 0x0000000000000000
Relevant detail: 同样在第一条 `auipc` 即失败，说明当前尚未进入 Lab3 主体程序
Next step: 先让 Lab3 base 进入主程序，再考虑 extra 的更强指令边界
```

## 对 Lab2 完成度的判断

### 结论

如果按“课程基线是否通过标准测试”来判断，`Lab2` 当前可视为 **已完成并通过基线验证**。

如果按“是否已经把后续会影响 Lab3 的问题全部解决”来判断，`Lab2` 当前是 **核心目标已完成，但不是后续 Labs 无需再动的终态**。

### 原因

当前 `Lab2` 已完成的核心内容包括：

- load/store 译码接通
- `lui` 接通
- `MEM` 阶段 `dbus` 请求生成
- store 数据移位与 byte strobe
- load 数据截取与符号/零扩展
- 共享 `ibus/dbus` 下的基本冻结
- 为 store 数据使用已前递的 `rs2`
- Difftest 提交时序修正

但当前实现仍然有两个“Lab2 完成后可接受、但对后续演进不够强”的边界：

- 控制流仍然基本停留在 `next_pc = pc + 4`
- `lab1-extra` 代表的 M-extension 仍然完全不支持

因此，更准确的说法是：

- `Lab2`：当前目标已经达成
- 面向 `Lab3`：当前架构只具备“数据通路侧基础”，尚不具备“控制流侧基础”

## 当前架构对后续 Lab3 的支持程度

###+ 已有的支持

当前架构对 `Lab3` 不是完全无基础，以下内容是可以直接复用的：

- 五级流水线框架本身可以继续用
- `MEM/WB` 与 load/store 主通路已经建立，后续程序型 workload 不需要从头重写访存
- 基本 forwarding / load-use hazard 框架已经存在
- Difftest 提交链路已经能配合更真实的多周期访存
- `SimTop`、`dbus/ibus`、仲裁器和标准测试流都已经连通

这些意味着：

- 做 `Lab3` 时不需要重做整体架构
- 主要是“补控制语义和流水线控制”，不是“推翻 Lab2 重写”

###+ 当前不支持的关键部分

当前代码对 `Lab3` 的主要阻塞点非常明确，而且都集中在控制流：

1. `core.sv` 当前仍然是固定顺序取指：

   - `next_pc = pc + 4`
   - 没有 branch/jump 重定向路径

2. `core_decode.sv` 虽然会生成一部分 `branch/jal/jalr/auipc` 的立即数，但没有把它们接成真正的执行控制：

   - 没有 `AUIPC` 的写回语义
   - 没有 `JAL/JALR` 的写回与跳转语义
   - 没有 `BEQ/BNE/BLTU/...` 的比较与转移判定语义

3. 当前流水线没有成体系的控制流 flush 机制：

   - 跳转/分支命中后如何清掉错误路径上的 IF/ID、ID/EX，还没有建立
   - 这部分是从 `Lab2` 进入 `Lab3` 的核心工作

4. `lab1-extra` 明确暴露出 M-extension 缺失：

   - 这意味着如果 `Lab3` 额外测试或编译结果中包含 `mul/div/rem`，当前实现也无法通过

### 支持程度结论

可用一个更直白的分级来描述：

- 对 `Lab2`：高支持，已经实测通过
- 对 `Lab3 base`：低支持，当前在入口第一条 `auipc` 就失败
- 对 `Lab3 extra`：更低支持，除控制流外还可能叠加 M-extension 缺口

## 从现在继续推进的推荐路径

### 路径一：先把当前 Lab2 状态固化

建议先做两件小事：

- 更新 `status.md`，把 `Lab2` 的通过结果写进去
- 在实验报告里记录本次 `MEM` 路径与 stall/commit 修正的关键点

这是为了避免后续进入 `Lab3` 后，项目摘要仍停留在“Lab2 fail”的旧结论。

### 路径二：建立 Lab3 最小可启动路径

这里的目标不是一下子打通所有 `Lab3`，而是先让程序能跨过 `_start`。

优先级建议如下：

1. 支持 `AUIPC`

   - 这是当前 `Lab3` 的第一个真实阻塞点
   - 从测试结果看，`sp` 在第一条指令就失配，优先级最高

2. 支持 `JAL` / `JALR`

   - `lab3-test.S` 很早就出现 `jal main`
   - 还需要配套 link register 写回

3. 支持基础 branch

   - 至少先覆盖 `beq`、`bne`、`bltu`
   - `lab3-test.S` 的启动代码和函数循环中都在使用

4. 建立控制流 flush / redirect

   - 这是让 branch/jump 正常工作的关键
   - 没有 flush，就算 decode/比较写出来，也会因错误路径提交而失败

### 路径三：在 Lab3 base 跑通后再看 extra 边界

等 `make test-lab3` 能进入主程序并通过更多代码后，再决定下一步是：

- 优先补更完整的 branch/jump 角落情况
- 还是直接进入 M-extension

如果只是课程主线需要先过 `Lab3 base`，那么 M-extension 不应先于控制流主线实现。

## 建议的 Lab3 任务拆解

如果后续要继续实现，我建议按下面的顺序做：

1. `AUIPC` 写回

   - 目标：修复 `make test-lab3` 在 `pc=0x80000000` 的首条失配

2. `JAL/JALR` 跳转与返回地址写回

   - 目标：程序可以从 `_start` 跳入 `main` 并返回

3. branch 比较与 `next_pc` 重定向

   - 目标：支持 `beq/bne/bltu` 等循环与条件判断

4. 控制流 flush

   - 目标：跳转或分支成功时，清理错误路径上的指令

5. 回归 `make test-lab3`

   - 先看新的首个失败点属于：
     - 控制流
     - load/store
     - hazard/forwarding
     - M-extension

6. 若 `lab3-extra` 仍卡在 `mul/div/rem`

   - 再单独规划 M-extension，而不要把它和基础控制流改动混在一起

## 对当前架构的整体判断

当前架构的优点是：

- 已经从“只有 Lab1 base”进化到“可支撑 Lab2”
- 数据通路方向的组织方式基本合理
- 继续往上扩展时，主要是增加控制流能力而不是推倒重来

当前架构的主要短板是：

- 控制信号类型还偏少，控制流语义尚未被系统化表达
- `core.sv` 里已经逐渐把更多策略堆在主模块中，继续做 `Lab3` 时要小心主文件失控

因此，当前最合适的判断是：

- **不需要重构架构再做 Lab3**
- **但需要在现有骨架上补一轮“控制流能力建设”**
- **如果 `core.sv` 在做 jump/branch/flush 时继续变重，应考虑把控制流相关逻辑提成局部 helper 或小模块**

## 最终建议

对你现在的项目状态，我的建议是：

- `Lab2` 可以按“已完成并通过基线测试”处理
- 先把当前通过状态记录进项目文档或状态摘要
- 进入 `Lab3` 时，把工作主轴从 `MEM` 改为 `PC + control-flow + flush`
- 不要在一开始就把 `Lab3` 和 M-extension 混成一个任务

一句话说，当前项目已经迈过了 `Lab2` 的主门槛，但要进入 `Lab3`，需要补的是“会跑程序的控制流 CPU”，而不再只是“能做 load/store 的 CPU”。
