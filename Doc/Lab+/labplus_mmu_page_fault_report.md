# Lab+ MMU Page Fault 报告

## 任务目标

本任务将原先 MMU 对 invalid PTE 的“虚拟地址直通回退”改为真正产生 page fault，并把 MMU fault 反馈到 core 的异常提交路径。

本轮实现范围：

- Sv39 页表遍历中的 invalid PTE page fault。
- instruction/load/store page fault cause。
- PTE R/W/X/A/D 权限检查。
- 基本 U-mode 权限检查。
- superpage PPN 对齐检查。
- page fault 后不发起最终访存。

暂不实现完整 S-mode trap/delegation/`sret`，也暂不实现 MXR/SUM 的完整语义。

## 实现内容

### Cause 常量

`trap_pkg` 新增：

- `CAUSE_INST_PAGE_FAULT = 12`
- `CAUSE_LOAD_PAGE_FAULT = 13`
- `CAUSE_STORE_PAGE_FAULT = 15`

### 总线 fault 回传

为了让 `MMU.sv` 能区分 fault 类型并把 fault 反馈给 core，本任务扩展了公共总线结构：

- `mem_access_t`
  - `MEM_ACCESS_FETCH`
  - `MEM_ACCESS_LOAD`
  - `MEM_ACCESS_STORE`
- `dbus_req_t` / `cbus_req_t` 增加 `access`。
- `ibus_resp_t` / `dbus_resp_t` / `cbus_resp_t` 增加 `page_fault`。

`IBusToCBus` 将取指请求标记为 `MEM_ACCESS_FETCH`。`DBusToCBus` 透传 data-side 请求类型。`core.sv` 在 MEM 阶段为普通 load/store 和 AMO/LR/SC 设置访问类型，其中 AMO RMW 与 SC 按 store/AMO fault 处理，LR 按 load fault 处理。

### MMU 检查

`MMU.sv` 新增 page fault 判断：

- 虚拟地址不满足 Sv39 canonical 格式。
- PTE `V=0`。
- PTE `W=1 && R=0`。
- 页表 walk 到 level 0 仍不是 leaf PTE。
- leaf PTE 权限不满足当前访问：
  - fetch 需要 X。
  - load 需要 R。
  - store 需要 W。
  - 任意访问需要 A。
  - store 需要 D。
  - U-mode 访问需要 U。
- 1GB / 2MB superpage 的低级 PPN 未对齐。

一旦发现 page fault，MMU 进入 fault response 状态，向上游返回 `ready=1`、`last=1`、`page_fault=1`，不再发起最终物理访存。

### Core 接入

取指侧：

- IF/ID 捕获 `iresp.page_fault`。
- ID/EX 将其转换为 `CAUSE_INST_PAGE_FAULT`。
- `mtval` 使用 faulting PC，也就是虚拟取指地址。

数据侧：

- MEM 阶段捕获 `dresp.page_fault`。
- MEM/WB 将其转换为 load 或 store page fault。
- `mtval` 使用 `ex_mem_q.alu_result`，也就是 faulting data virtual address。

异常提交仍复用现有 WB trap 控制逻辑。

## 验证结果

### 构建

`make sim` 通过。

### 主线回归

- Lab4：通过，`HIT GOOD TRAP at pc = 0x8001fff8`。
- Lab5：输出 `Return from init! Test passed`。
- Lab6：输出 `Privileged test finished.` / `Exit with code = 0`。
- Lab+3：通过，`HIT GOOD TRAP at pc = 0x800000dc`。
- Lab+4：前置特权/PMP 子测仍输出 `Single test passed.`。

### Page Fault 诊断自测

新增生成器：

- `ready-to-run/lab+/4/gen_page_fault_test.py`

生成文件：

- `page_fault_load.bin/.S`
- `page_fault_store.bin/.S`
- `page_fault_inst.bin/.S`

当前诊断结果：

- `page_fault_load.bin` 在 Difftest 下可见 DUT 在 `ld` 处产生 page fault 状态：
  - faulting PC：`0x80000084`
  - `mcause = 13`
  - `mepc = 0x80000084`
  - `mtval = 0x40000000`
- 由于参考模型对这个临时裸机环境的行为不同，Difftest 会按架构状态差异中止；这里将其作为诊断证据，而不是 Difftest 通过项。
- no-diff good-trap 收尾当前仍不稳定，后续若需要更漂亮的自测产物，可以继续打磨自测 trap harness。

## 当前边界

已完成 page fault 核心硬件路径，但仍保留以下边界：

- 未实现 MXR/SUM 完整语义。
- 未实现 S-mode trap delegation，因此 page fault 仍进入现有 M-mode trap 路径。
- 自测生成器已能构造 fault 场景，但 no-diff good-trap 收尾仍需完善。

下一步若继续推进特权架构，建议进入任务 10：S-mode trap / delegation / `sret`。
