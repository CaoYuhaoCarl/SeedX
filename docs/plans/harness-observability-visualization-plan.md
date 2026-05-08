# Harness Observability & Visualization Plan

> 目标：让使用者能动态观察 Question-to-Mastery Harness 中主 Agent、Planner、Builder、Evaluator 之间的通讯、任务状态、PASS/FAIL、resume 修正循环，从而更直观理解 harness 架构。

---

## 1. 设计目标

当前 Harness 的核心是文件通信和主 Agent 编排，但执行过程对人来说不够直观。Observability 层要解决：

1. 当前运行到哪个 phase？
2. 哪个 agent instance 正在执行？
3. 当前 task 是 PASS 还是 FAIL？
4. Builder 和 Evaluator 是否是同一个实例被 resume？
5. 哪些文件被创建或更新？
6. 修正循环发生了几轮？
7. 主 Agent 是否保持了“不读正文，只读判定”的纪律？

---

## 2. 原则

1. **不改变核心 Harness 流程**：可视化层只观察，不参与决策。
2. **事件日志优先**：所有状态先写入机器可读事件文件，再由 UI 展示。
3. **Markdown 继续保留**：`run-log.md` 仍然是人类可读日志。
4. **JSONL 作为实时数据源**：新增 `events.jsonl`，每行一个事件，方便增量读取。
5. **先静态/半实时，再实时**：MVP 不需要 WebSocket，先用浏览器定时轮询本地 JSONL。
6. **不暴露产物正文**：可视化 UI 展示路径、状态、判定，不展示学习产物全文。

---

## 3. 推荐文件结构

每次运行输出目录增加：

```text
output/{PROJECT_NAME}/
├── run-log.md             # 人类可读日志，继续保留
├── events.jsonl            # 机器可读事件流，新增
├── state.json              # 当前状态快照，新增，可选
└── visualizer.html         # 单文件可视化面板，新增，可选
```

项目根目录可增加：

```text
tools/
└── harness-visualizer.html # 通用可视化模板
```

---

## 4. events.jsonl 事件协议

每行一个 JSON object：

```json
{"ts":"260507 1814","type":"project_started","project":"ai-agent-memory","source":"input/questions/question-source-ai-agent-memory.md","output":"output/ai-agent-memory"}
```

### 4.1 项目事件

```json
{"ts":"260507 1814","type":"project_started","project":"ai-agent-memory","source":"...","output":"..."}
{"ts":"260507 1815","type":"project_finished","project":"ai-agent-memory","duration":"12m","status":"PASS"}
```

### 4.2 Planner 事件

```json
{"ts":"260507 1815","type":"agent_started","role":"question-planner","task":"planning"}
{"ts":"260507 1818","type":"agent_finished","role":"question-planner","task":"planning","outputs":["learning-plan.md","learning-contract.md","learning-design-guide.md"]}
```

### 4.3 Builder 事件

```json
{"ts":"260507 1819","type":"agent_started","role":"mastery-builder","task":"task01","instance_id":"abc123"}
{"ts":"260507 1823","type":"agent_finished","role":"mastery-builder","task":"task01","instance_id":"abc123","outputs":["question-brief.md","domain-map.md"]}
```

### 4.4 Evaluator 事件

```json
{"ts":"260507 1824","type":"agent_started","role":"learning-evaluator","task":"task01","instance_id":"def456"}
{"ts":"260507 1826","type":"evaluation_finished","role":"learning-evaluator","task":"task01","instance_id":"def456","report":"review-reports/task01-evaluation.md","judgment":"FAIL"}
```

### 4.5 Resume 事件

```json
{"ts":"260507 1827","type":"agent_resumed","role":"mastery-builder","task":"task01","instance_id":"abc123","reason":"evaluation_failed","round":1}
{"ts":"260507 1831","type":"agent_resumed","role":"learning-evaluator","task":"task01","instance_id":"def456","reason":"recheck","round":1}
```

### 4.6 Task 状态事件

```json
{"ts":"260507 1832","type":"task_status_changed","task":"task01","from":"🔄","to":"✅","iterations":1}
```

---

## 5. state.json 快照协议

`events.jsonl` 是历史流，`state.json` 是当前状态，便于 UI 快速加载。

示例：

```json
{
  "project":"ai-agent-memory",
  "source":"input/questions/question-source-ai-agent-memory.md",
  "output":"output/ai-agent-memory",
  "phase":"task_loop",
  "current_task":"task02",
  "tasks":{
    "task01":{"title":"Framing","status":"✅","builder_id":"abc123","evaluator_id":"def456","iterations":1,"judgment":"PASS"},
    "task02":{"title":"Mastery Path","status":"🔄","builder_id":"ghi789","evaluator_id":null,"iterations":0,"judgment":null},
    "task03":{"title":"Application","status":"⏳","builder_id":null,"evaluator_id":null,"iterations":0,"judgment":null}
  }
}
```

---

## 6. 可视化 UI 设计

### 6.1 Timeline View

展示完整事件流：

```text
18:14 Project Started
18:15 Planner Started
18:18 Planner Finished
18:19 Task01 Builder Started
18:23 Task01 Builder Finished
18:24 Task01 Evaluator Started
18:26 Task01 FAIL
18:27 Task01 Builder Resumed
18:31 Task01 Evaluator Resumed
18:32 Task01 PASS
```

### 6.2 Agent Swimlane View

按角色分泳道：

```text
Main Agent       ─ init ── plan request ── task01 ── task02 ── task03 ─ finish
Planner                └──── planning ────┘
Builder                         └─ build ─ fix ─┘  └─ build ─┘
Evaluator                              └ eval ─ re-eval ┘  └ eval ┘
```

### 6.3 Task Cards

每个 task 一张卡：

```text
Task 1: Framing
Status: ✅ PASS
Builder ID: abc123
Evaluator ID: def456
Iterations: 1
Outputs: question-brief.md, domain-map.md
Report: task01-evaluation.md
```

### 6.4 Architecture Flow Diagram

展示固定 Harness 流程：

```text
Source Path → Planner → Contract/Plan → Builder → Deliverables → Evaluator → PASS/FAIL → Resume Loop
```

### 6.5 Discipline Indicators

用于观察是否遵守 Harness 核心纪律：

```text
Main read source body: NO ✅
Main read builder deliverables: NO ✅
Main read full evaluation report: NO ✅
Same-task builder resumed: YES ✅
Same-task evaluator resumed: YES ✅
```

---

## 7. MVP 实现方案

### v0.2-observability MVP

最小实现：

1. 在 `CLAUDE.md` 日志规范中新增：每写 `run-log.md` 时，也追加一行 `events.jsonl`。
2. 创建 `tools/harness-visualizer.html`。
3. visualizer 用浏览器 `fetch()` 定时读取 `events.jsonl`。
4. UI 展示：
   - 项目状态
   - 任务卡片
   - 时间线
   - Agent ID / resume 状态

### 不做

MVP 不做：

- WebSocket。
- 数据库。
- 后端服务。
- 读取产物正文。
- 改变 agent 决策流程。

---

## 8. 更高级版本

### v0.3 实时 Dashboard

增加一个本地小服务：

```text
python tools/serve-visualizer.py output/ai-agent-memory
```

功能：

- 自动刷新。
- 文件变更监听。
- 状态快照 API。

### v0.4 Replay Mode

支持回放一次运行：

```text
0.5x / 1x / 2x speed
```

帮助使用者理解并演示 Harness。

### v0.5 Multi-run Comparison

比较不同 smoke test：

```text
ai-agent-memory
scenario-based-learning
mcp-learning-path
```

看哪个问题触发更多 FAIL、哪个 rubric 更有效。

---

## 9. 为什么这值得做

可视化层能帮助使用者：

1. 直观看到 Agent 间通讯不是“聊天”，而是路径、文件、判定和 resume。
2. 理解 Harness 和普通 prompt 的区别。
3. 发现流程瓶颈：Planner 弱、Builder 泛、Evaluator 松。
4. 给别人演示 Harness 架构。
5. 未来把它变成讲解材料、训练素材或产品 demo。

---

## 10. 推荐优先级

等 v0.1 smoke test 完成后，如果要继续开发，建议顺序：

```text
1. v0.2 Rubric Calibration
2. v0.2-observability events.jsonl + visualizer.html
3. v0.3 Contract Calibration
```

如果目标是“更深刻理解 Harness 架构 / 展示给别人看”，可以把 observability 提前到 v0.2。
