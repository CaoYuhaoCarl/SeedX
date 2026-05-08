<div align="center">

<img src="docs/assets/question-to-mastery-banner.png" alt="Question-to-Mastery banner" width="100%">

# Question-to-Mastery

<img src="https://img.shields.io/badge/version-v0.1_MVP-blue.svg" alt="Version v0.1 MVP">
<img src="https://img.shields.io/badge/Status-Active-success.svg" alt="Status Active">
<img src="https://img.shields.io/badge/Architecture-Multi--agent-8a2be2" alt="Architecture Multi-agent">
<a href="https://x.com/CaoYuhaoCarl"><img src="https://img.shields.io/badge/follow-%40CaoYuhaoCarl-000000?logo=x&logoColor=white" alt="Follow on X"></a>

<a href="README.md">🇺🇸 English</a> · 🇨🇳 **简体中文** · <a href="README.ja.md">🇯🇵 日本語</a>

</div>

一个多智能体学习路径生成系统：输入一个学习问题，输出一套经过独立评估、可直接执行的学习掌握路径。

```text
学习问题
  ↓
question-planner  生成 Learning Contract 和设计指引
  ↓
mastery-builder   逐任务生成学习产物
  ↓
learning-evaluator  独立评估 PASS/FAIL
  ↓
FAIL 时 resume 同一 Builder 修正、同一 Evaluator 复评（最多 2 轮）
```

系统默认不绑定任何特定用户、行业、职业或应用场景。个性化只来自输入文件中显式写出的背景、目标和约束。

---

## 快速开始

### Slash 触发（推荐）

在 Claude Code 直接发：

```text
+ask <你的学习问题正文>
```

`UserPromptSubmit` hook 会自动：
- 把问题正文落盘到 `input/questions/question-<时间戳>.md`
- 注入路径与启动指令；主 Agent 直接进入编排流程
- 后台打开 Harness Visualizer，并等待本次运行的 `events.jsonl` + `state.json`

项目名和输出目录从文件名自动推导，无需手填。

### 严格隔离模式（敏感问题适用）

问题包含 PII、商业机密，或希望最大化"主 Agent 完全看不到正文"的纯度时：

| 触发 | 行为 | UX |
|---|---|---|
| `+ask`（先把正文复制到剪贴板，不带 body） | 通过 `pbpaste` 落盘并启动 | 1 步 |
| `+ask-strict <正文>` | 落盘并 block 原消息，等用户发 `+start` 启动 | 2 步 |
| `+start [path]` | 启动指定文件或最近落盘的问题文件 | — |

剪贴板与 strict 模式隔离强度相同（正文从不进入主 Agent context），区别仅在 UX。详见 [CLAUDE.md §1.2](CLAUDE.md)。

### 手动指定（高级）

如果想自定义项目名或输出目录，仍可使用旧式提示：

```text
学习问题路径：{WORKSPACE_DIR}/input/questions/{question-file}.md
项目名：{project-name}
输出目录：{WORKSPACE_DIR}/output/{project-name}

请严格按当前工作区的 CLAUDE.md 执行：
- 当前工作区：{WORKSPACE_DIR}
- 学习问题路径只作为输入，不得把输出目录设置为输入文件所在文件夹
- 所有生成物写入输出目录
- 默认保持通用学习者视角；只有输入文件显式提供的背景、目标、场景和约束才能进入 learning-contract 与产物
- 初始化后创建 run-log.md、events.jsonl、state.json，然后启动 question-planner subagent
```

示例输入文件见 `input/questions/`。

---

## 运行产出

一次完整运行在 `output/{project-name}/` 下生成：

```text
output/{project-name}/
├── learning-plan.md           # 执行计划
├── learning-contract.md       # 学习合同（Builder/Evaluator 的共同锚点）
├── learning-design-guide.md   # 设计指引
├── question-brief.md          # 问题摘要
├── domain-map.md              # 领域地图
├── learning-path.md           # 学习路径
├── exercises.md               # 练习
├── checkpoints.md             # 检查点
├── application-plan.md        # 应用计划
├── transfer-plan.md           # 迁移计划
├── project-lessons.md         # 跨任务经验记录
├── run-log.md                 # 人类可读运行日志
├── events.jsonl               # 事件流（供可视化面板消费）
├── state.json                 # 当前状态快照
└── review-reports/
    ├── task01-evaluation.md
    ├── task02-evaluation.md
    └── task03-evaluation.md
```

---

## 固定任务单元

| Task | 名称 | Builder 产出 | 评估报告 |
|---|---|---|---|
| task01 | Framing | `question-brief.md`, `domain-map.md` | `review-reports/task01-evaluation.md` |
| task02 | Mastery Path | `learning-path.md`, `exercises.md`, `checkpoints.md` | `review-reports/task02-evaluation.md` |
| task03 | Application & Transfer | `application-plan.md`, `transfer-plan.md` | `review-reports/task03-evaluation.md` |

按 `task01 → task02 → task03` 固定顺序执行。每任务先 Build 后 Evaluate；PASS 进入下一任务，FAIL 进入修复循环（最多 2 轮）。

---

## 目录结构

```text
.
├── CLAUDE.md                        # 主 Agent 编排协议
├── README.md                        # 英文 README，默认入口
├── README.zh-CN.md                  # 简体中文 README
├── README.ja.md                     # 日文 README
├── input/questions/                 # 学习问题输入文件
├── output/{project-name}/           # 运行产出（按项目隔离）
├── docs/
│   ├── assets/                      # README 和文档资产
│   ├── plans/                       # 实施计划
│   ├── roadmap/                     # 版本路线
│   ├── adr/                         # 架构决策记录 (ADR)
│   └── specs/                       # 事件协议与日志格式规范
├── tools/
│   ├── harness-visualizer.html      # 单文件可视化面板
│   └── open-visualizer.sh           # 一键启动面板脚本
└── .claude/
    ├── agents/
    │   ├── question-planner.md
    │   ├── mastery-builder.md
    │   └── learning-evaluator.md
    └── skills/
        ├── designing-mastery-paths/
        └── reviewing-mastery-paths/
```

---

## Observability 可视化

v0.2 增加的轻量观察层：不读取学习产物正文，只暴露运行状态。通过 `+ask` / `+start` 启动时，intake hook 会自动后台打开可视化面板；面板会等待并轮询本次运行的 `events.jsonl` + `state.json`。

```bash
# 自动打开面板，加载指定项目的 events.jsonl + state.json，每 2 秒刷新
./tools/open-visualizer.sh {project-name}

# 不指定项目名时，自动选择 output/ 下最新项目
./tools/open-visualizer.sh
```

事件协议见 [docs/specs/harness-observability-events.md](docs/specs/harness-observability-events.md)，日志格式见 [docs/specs/run-log-format.md](docs/specs/run-log-format.md)。

---

## 评估标准

`learning-evaluator` 使用 6 维 rubric（每维 1-5 分）：

| 维度 | 说明 |
|---|---|
| Question Quality | 问题是否被正确理解和聚焦 |
| Coverage | 领域覆盖是否充分 |
| Clarity | 表达是否清晰可理解 |
| Actionability | 产出是否可直接执行 |
| User Context Fit | 个性化是否严格来自输入文件 |
| Transferability | 知识是否可迁移到新场景 |

所有维度 ≥ 4/5 才能 PASS。额外硬门槛：产物引入输入文件中未提供的个人/行业/职业背景 → FAIL。

---

## 调优指南

**产物太泛：**
1. 先调 `reviewing-mastery-paths` skill，让 Evaluator 更挑剔。
2. 再调 `designing-mastery-paths` skill，让 Builder 生成目标更明确。
3. 最后才考虑增加新 Agent 或拆分 Reviewer。

**产物错误绑定了特定用户/行业：**
1. 先检查输入文件是否确实提供了该背景。
2. 再检查 `learning-contract.md` 的"学习者背景与应用场景"。
3. 最后调 `reviewing-mastery-paths` 的 `User Context Fit` 硬门槛。

每个组件必须证明自己是 load-bearing，否则不增加复杂度。

---

## 设计决策

详见 [docs/adr/0001-question-to-mastery-architecture.md](docs/adr/0001-question-to-mastery-architecture.md)。
