# Question-to-Mastery Roadmap

> 本文件记录后续版本计划，避免 smoke test 后遗忘。它不是当前运行产物，而是项目级开发路线。

**当前版本：MVP v0.1**  
**当前架构：3 agent types + 2 skills**

```text
Agents:
- question-planner
- mastery-builder
- learning-evaluator

Skills:
- designing-mastery-paths
- reviewing-mastery-paths
```

---

## 版本管理原则

1. **先验证，再扩展**：每个新组件都必须证明自己是 load-bearing。
2. **保留旧 Harness 核心**：主 Agent 不读输入/产物正文；子 Agent 产物落文件；主 Agent 只读路径和 PASS/FAIL；同任务失败 resume 原 Builder/Evaluator。
3. **优先调 rubric，再加 Agent**：如果质量不够，先改 `reviewing-mastery-paths` 和 `designing-mastery-paths`，不要马上拆更多 Agent。
4. **每个版本必须有 smoke test**：用固定问题或新问题验证输出质量。
5. **开发计划写在 `docs/plans/`，版本路线写在 `docs/roadmap/`，架构决策写在 `docs/adr/`。**

---

## v0.1 — MVP: Question-to-Mastery 基础闭环

### 状态

In progress / smoke testing.

### 目标

把一个学习问题转化为三组学习产物，并通过独立 evaluator 评估修正。

### 范围

- 固定 3 个任务：
  - Task 1: Framing
  - Task 2: Mastery Path
  - Task 3: Application
- 固定 3 agent types。
- 固定 2 skills。
- 每个 task 一个 builder instance + 一个 evaluator instance。
- FAIL 后 resume 同一对 builder/evaluator。

### 验收标准

- 能完整跑完 `ai-agent-memory` smoke test。
- 生成全部 7 个学习产物。
- 生成 3 个 task evaluation report。
- `run-log.md` 记录完整。
- 如果 FAIL，修正循环能正确 resume。

### 观察点

- Evaluator 是否太宽松。
- Builder 是否生成泛泛总结。
- Task 之间是否一致。
- `learning-contract.md` 是否足够约束后续产物。

---

## v0.2 — Rubric Calibration: 评估器调优

### 触发条件

Smoke test 发现以下问题之一：

- Evaluator 明显放过泛泛内容。
- FAIL 反馈不可执行。
- 分数和人工判断不一致。
- Builder 修正后没有明显变好。

### 计划改动

- 强化 `reviewing-mastery-paths`：
  - 增加 FAIL 示例。
  - 增加“泛泛输出”反例。
  - 增加每个 task 的 hard gates。
- 强化报告格式：
  - 每个 FAIL 必须指定文件名。
  - 每个 FAIL 必须指定修改方向。
  - 禁止“建议进一步完善”这类空话。

### 验收标准

- Evaluator 能准确指出至少 3 类可执行问题。
- Builder 根据报告修正后，下一轮报告能明确说明哪些问题已修复。

---

## v0.3 — Contract Calibration: Learning Contract 调优

### 触发条件

如果 Builder 输出偏散、偏百科、偏长文，说明 `learning-contract.md` 不够强。

### 计划改动

- 强化 `question-planner`：
  - 必须写“本轮不学什么”。
  - 必须写“核心概念优先级”。
  - 必须写“输入显式场景约束”。
  - 必须写“每个 task 的验收重点”。
- 强化 `designing-mastery-paths`：
  - 增加 Learning Contract 的优秀/糟糕示例。

### 验收标准

- Builder 能明显围绕 contract 生成，而不是自由发挥。
- Task 2 和 Task 3 能引用 Task 1 的领域地图。

---

## v0.2-observability — Harness 可视化观察层

### 目标

让使用者能实时观察主 Agent、Planner、Builder、Evaluator 之间的通讯、任务状态、PASS/FAIL、resume 修正循环。

### 计划文件

```text
docs/plans/harness-observability-visualization-plan.md
```

### MVP 改动

- 新增 `events.jsonl` 事件流。
- 可选新增 `state.json` 当前状态快照。
- 新增 `tools/harness-visualizer.html` 单文件可视化面板。
- UI 展示 timeline、agent swimlane、task cards、resume loop。

### 原则

Observability 只观察，不参与决策；不读取学习产物正文；不破坏主 Agent 上下文隔离。

---

## v0.4 — Question Coach Mode: 好问题训练模式

### 目标

支持模糊输入，例如：

```text
我想学习 AI Agent。
我想了解某个新领域。
我想变得更会提问。
```

### 可能方案

不一定新增 Agent。优先尝试在 `question-planner` 中内置 question coaching。

### 新产物候选

```text
better-questions.md
question-options.md
```

### 流程

如果输入过宽：

1. Planner 生成 3-5 个更好的问题候选。
2. 默认选择最贴近输入中明确目标的一个继续。
3. 在 `learning-contract.md` 记录选择理由。

### 是否新增 Agent

只有当 planner 内置模式表现不好时，才新增：

```text
question-coach
```

---

## v0.5 — Source-Augmented Learning: 支持资料输入

### 目标

不仅支持“一个问题”，也支持：

- 一篇文章
- 一段视频稿
- 一章书摘
- 一份论文笔记

### 新输入结构候选

```text
input/questions/
input/sources/
input/transcripts/
```

### 新能力

Planner 需要判断：

```text
这是 question-first 还是 source-first？
```

### 新产物候选

```text
source-brief.md
source-claims.md
source-to-question-map.md
```

### 风险

Source 输入容易让 Builder 变成总结器。必须坚持 question-to-mastery，不是 source summary。

---

## v0.6 — Knowledge Base Integration: 第二大脑连接

### 目标

把学习产物沉淀进长期知识系统，例如 Obsidian。

### 候选产物

```text
atomic-notes/
concept-index.md
connections.md
tags.md
review-schedule.md
```

### 需要先验证

- 现有学习产物是否稳定。
- 使用者是否希望用 Obsidian 或本地 Markdown vault。
- 是否需要自动写入 vault，还是先手动复制。

---

## v0.7 — Memory & Review Loop: 复习计划

### 目标

让学习路径不仅生成一次，还能进入复习和长期掌握。

### 产物候选

```text
review-plan.md
spaced-repetition-cards.md
mastery-log.md
```

### 评估点

- flashcards 是否真的可复习。
- checkpoints 是否能在 1 天 / 1 周 / 1 月后复测。

---

## v0.8 — Output Productization: 输出产品化模式

### 目标

把学习结果进一步转化为可复用的项目、内容、研究、工作、讲解或训练素材。

### 新产物候选

```text
explainer-script.md
learner-handout.md
ai-tutor-script.md
practice-design.md
scenario-based-activity.md
```

### 适用场景

- 场景化讲解。
- AI 辅助练习或工作流。
- 团队培训。
- 利益相关者沟通。

---

## v0.9 — Agent Runtime Portability: Claude Code / Codex 通用入口

### 目标

让 Question-to-Mastery Harness 不只绑定 Claude Code，也能被 Codex 等遵循仓库 agent 指令的运行时直接使用。

### 计划改动

- 将当前 `CLAUDE.md` 编排协议迁移或同步到通用入口 `AGENTS.md`。
- 保留 `CLAUDE.md` 作为 Claude Code 兼容入口，避免破坏现有 `+ask` / hook 体验。
- 梳理 `.claude/settings.json` 与 `.claude/hooks/intake-question.sh` 中的 Claude Code 专属能力，标记哪些可以抽成通用脚本，哪些只能作为 Claude Code 增强体验。
- README 中把“Claude Code 启动”改为“Agent Runtime 启动”，并单独说明 Claude Code 的 hook 快捷路径。

### 验收标准

- Codex 在读取 `AGENTS.md` 后能按同一套编排协议启动 Planner / Builder / Evaluator。
- Claude Code 仍可通过 `+ask` / `+start` 使用现有自动落盘与 visualizer 自动打开流程。
- 文档中清楚区分“核心 harness 协议”和“Claude Code 专属 hook UX”。

---

## v1.0 — Stable Question-to-Mastery Harness

### 目标

形成稳定可复用的个人学习成长 Harness。

### v1.0 标准

- 至少 5 个不同主题 smoke tests 通过。
- Evaluator rubric 稳定，不经常误判。
- Builder 输出不泛泛。
- Learning Contract 能稳定约束结果。
- 日志、产物、评估报告结构稳定。
- README 足够让未来使用者或新 Agent 直接启动。

---

## Backlog

### 可能新增 Agent

只有在证明 load-bearing 后再添加：

```text
question-coach       # 专门训练和改写问题
source-reader        # 专门处理长文章/论文/视频稿
knowledge-curator    # 专门整理进知识库
transfer-transformer # 专门做迁移转化
```

### 可能新增 Skills

```text
question-coaching
source-to-mastery
atomic-note-writing
transfer-planning
spaced-repetition-design
```

### 可能新增评估维度

```text
Novelty
Retention Design
Source Fidelity
Knowledge Graph Fit
Productization Potential
```

---

## 下一次继续开发时先看这里

1. 先读 `output/ai-agent-memory/run-log.md` 看 smoke test 结果。
2. 再读三个 evaluation report 的 FAIL/PASS 判定。
3. 如果 evaluator 太松，做 v0.2。
4. 如果 builder 太散，做 v0.3。
5. 如果输入问题太宽处理不好，做 v0.4。

不要跳到 v0.6/v0.8，除非 v0.1-v0.3 已经稳定。
