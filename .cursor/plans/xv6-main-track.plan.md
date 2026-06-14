---
name: xv6-main-track
overview: 基于仓库现有内容启动任务 11：先确认完整 xv6 主 Track 的真实阻塞点，并以 RAM disk 作为后续文件系统方向，而不是引入上游 xv6 或实现重型 virtio。产出应包括可复现实验、缺口定位、报告材料，并尽量形成一个小的 ramdisk 方向验证。
todos:
  - id: baseline-xv6-attempt
    content: 重跑任务 11 基线和现有 Lab5/Lab5-extra/Lab6/Lab+3 护栏
    status: completed
  - id: inspect-existing-kernel
    content: 确认现有 Lab5 裁剪内核是否包含完整 xv6 文件系统路径
    status: completed
  - id: map-device-gaps
    content: 定位 RAMHelper2 设备映射与完整 xv6 块设备缺口
    status: completed
  - id: draft-ramdisk-direction
    content: 整理 RAM disk 优先方案的接口草案和限制
    status: completed
  - id: write-xv6-report
    content: 产出任务 11 报告并更新 TODO/status
    status: completed
isProject: false
---

# 任务 11 xv6 主 Track 启动计划

## 范围

本轮按你选择的 `repo_existing_only + ramdisk_first` 推进：只使用当前仓库已有镜像、仿真框架和代码，不引入上游 xv6 源码或外部 `fs.img`。目标是把任务 11 从“完整 xv6 很大”收敛成一个可验证的尝试闭环：确认现有 Lab5 裁剪内核能到哪里、完整 xv6 为什么会卡、RAM disk 方案在本仓库里应接在哪一层。

关键依据：

- [Makefile](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/Makefile) 目前没有完整 xv6 target，最接近的是 `test-lab5` 和 `test-lab5-extra`。
- [ready-to-run/lab5/kernel.asm](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/ready-to-run/lab5/kernel.asm) 是裁剪版内核入口，已能输出 `Return from init! Test passed`，但没有完整磁盘/文件系统路径。
- [difftest/src/test/vsrc/common/ram.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/difftest/src/test/vsrc/common/ram.sv) 现有 MMIO 只有 RAM、UART、CLINT、测试寄存器，没有接入 xv6 可用块设备。
- [difftest/src/test/csrc/common/sdcard.cpp](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/difftest/src/test/csrc/common/sdcard.cpp) 有 SDCard C++ 桩，但没有 RTL/DPI 接线，暂不作为第一方案。

## 实施路径

1. 重新建立任务 11 基线
   - 跑 `make sim`、`make test-lab5`、`make test-lab5-extra`、`make test-lab6`、`make test-labplus-3` 作为护栏。
   - 用现有日志确认：Lab5 裁剪内核可以启动到 init 测试点；Lab5-extra 能覆盖 S-mode delegation/sret；Lab6 中断异常不回归。

2. 做现有 xv6/设备缺口定位
   - 检查 [ready-to-run/lab5/kernel.asm](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/ready-to-run/lab5/kernel.asm) 中是否存在 `virtio`、`disk`、`fsinit`、`bread`、`init` 等完整 xv6 文件系统路径。
   - 检查 [difftest/src/test/vsrc/common/ram.sv](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/difftest/src/test/vsrc/common/ram.sv) 的低地址 MMIO 行为，记录完整 xv6 需要磁盘时会卡在何处。
   - 记录结论：当前仓库缺完整 xv6 镜像与块设备 MMIO，所以本轮不能直接以 shell 作为验收目标。

3. 设计 RAM disk 优先方案但不引入上游 xv6
   - 以“后续如果有完整 xv6 或自定义内核，应该接入 RAM disk”的角度梳理最小接口。
   - 优先考虑在仿真层加载一段内存中的只读文件系统/块数据，而不是实现 virtio-mmio。
   - 先形成接口草案：RAM disk 基址、大小、加载方式、内核侧访问假设、与现有 `RAMHelper2` 的关系。
   - 本轮若没有可消费 RAM disk 的内核代码，不强行写无用 RTL，只把可落地改动限制在诊断脚本/文档/Makefile 辅助入口。

4. 增加最小诊断资产
   - 如果实现后进入 Agent 模式，优先添加一个小型诊断脚本或文档化命令，用来复现“现有环境没有完整块设备”的证据。
   - 可选地添加 `Doc/Lab+/labplus_xv6_main_track_report.md`，记录：现有基线、缺口、RAM disk 方案、下一步需要的外部软件条件。
   - 如果需要 Makefile 辅助入口，只添加不破坏原 target 的 `test-labplus-xv6-attempt` 或文档命令，默认仍使用现有镜像。

5. 验证与收尾
   - 回归护栏：`make sim`、Lab5、Lab5-extra、Lab6、Lab+3。
   - 任务 11 报告中明确区分：实际已验证内容、当前仓库缺失内容、RAM disk 后续方案。
   - 更新 [Doc/Lab+/TODO.md](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/Doc/Lab+/TODO.md) 和 [.agents/skills/26-arch-project-assistant/status.md](/home/thesumst/Data2/development/ComputerOrganization/26-Arch/.agents/skills/26-arch-project-assistant/status.md)。

## 预期产出

- 一个任务 11 报告：`Doc/Lab+/labplus_xv6_main_track_report.md`。
- 一组可复现命令和关键日志，用来说明当前仓库距离完整 xv6 shell 的真实缺口。
- RAM disk 优先方案的接口草案，作为后续真正引入完整 xv6 或定制内核时的实施依据。
- 不破坏任务 0-10 已通过的回归。

## 风险控制

- 不承诺本轮进入完整 xv6 shell，因为仓库没有完整 xv6 镜像/源码和 `fs.img`。
- 暂不实现 virtio-mmio，避免把任务扩大到设备协议移植。
- 暂不动上板路径，先限定在 difftest/Verilator 仿真环境。