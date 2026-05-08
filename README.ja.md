<div align="center">

<img src="docs/assets/question-to-mastery-banner.png" alt="Question-to-Mastery banner" width="100%">

# Question-to-Mastery

<img src="https://img.shields.io/badge/version-v0.1_MVP-blue.svg" alt="Version v0.1 MVP">
<img src="https://img.shields.io/badge/Status-Active-success.svg" alt="Status Active">
<img src="https://img.shields.io/badge/Architecture-Multi--agent-8a2be2" alt="Architecture Multi-agent">
<a href="https://x.com/CaoYuhaoCarl"><img src="https://img.shields.io/badge/follow-%40CaoYuhaoCarl-000000?logo=x&logoColor=white" alt="Follow on X"></a>

<a href="README.md">🇺🇸 English</a> · <a href="README.zh-CN.md">🇨🇳 简体中文</a> · 🇯🇵 **日本語**

</div>

Question-to-Mastery は、学習質問を入力すると、独立評価済みでそのまま実行できる「習得までの学習パス」を生成するマルチエージェントシステムです。

```text
学習質問
  ↓
question-planner  Learning Contract と設計ガイドを作成
  ↓
mastery-builder   タスクごとに学習成果物を生成
  ↓
learning-evaluator  PASS/FAIL を独立評価
  ↓
FAIL の場合、同じ Builder を resume して修正し、
同じ Evaluator で再評価する（最大 2 回）
```

このシステムは、デフォルトでは特定のユーザー、業界、職種、利用シーンに結びつきません。個別化は、入力ファイルに明示された背景、目標、制約からのみ行われます。

---

## クイックスタート

次の 3 つの変数を置き換えて、Claude Code に送ってください。

```text
学習質問パス: {WORKSPACE_DIR}/input/questions/{question-file}.md
プロジェクト名: {project-name}
出力ディレクトリ: {WORKSPACE_DIR}/output/{project-name}

現在のワークスペースの CLAUDE.md に厳密に従ってください:
- 現在のワークスペース: {WORKSPACE_DIR}
- 学習質問パスは入力専用です。出力ディレクトリを入力ファイルのあるフォルダに設定しないでください
- すべての生成物を出力ディレクトリに書き込んでください
- デフォルトでは汎用的な学習者視点を維持してください。入力ファイルに明示された背景、目標、シーン、制約だけを learning-contract と成果物に反映できます
- 初期化後、run-log.md、events.jsonl、state.json を作成し、question-planner subagent を起動してください
```

入力例は `input/questions/` にあります。

---

## 実行出力

完全な 1 回の実行では、`output/{project-name}/` に次のファイルが生成されます。

```text
output/{project-name}/
├── learning-plan.md           # 実行計画
├── learning-contract.md       # Builder/Evaluator 共通の学習契約
├── learning-design-guide.md   # 設計ガイド
├── question-brief.md          # 質問概要
├── domain-map.md              # ドメインマップ
├── learning-path.md           # 学習パス
├── exercises.md               # 演習
├── checkpoints.md             # チェックポイント
├── application-plan.md        # 応用計画
├── transfer-plan.md           # 転移計画
├── project-lessons.md         # タスク横断の学び
├── run-log.md                 # 人間が読める実行ログ
├── events.jsonl               # 可視化パネル用イベントストリーム
├── state.json                 # 現在状態のスナップショット
└── review-reports/
    ├── task01-evaluation.md
    ├── task02-evaluation.md
    └── task03-evaluation.md
```

---

## 固定タスク単位

| Task | 名前 | Builder の出力 | 評価レポート |
|---|---|---|---|
| task01 | Framing | `question-brief.md`, `domain-map.md` | `review-reports/task01-evaluation.md` |
| task02 | Mastery Path | `learning-path.md`, `exercises.md`, `checkpoints.md` | `review-reports/task02-evaluation.md` |
| task03 | Application & Transfer | `application-plan.md`, `transfer-plan.md` | `review-reports/task03-evaluation.md` |

タスクは `task01 → task02 → task03` の固定順で実行されます。各タスクは Build の後に Evaluate されます。PASS なら次のタスクへ進み、FAIL なら最大 2 回の修正ループに入ります。

---

## ディレクトリ構成

```text
.
├── CLAUDE.md                        # メイン Agent のオーケストレーションプロトコル
├── README.md                        # 英語 README、デフォルト
├── README.zh-CN.md                  # 簡体字中国語 README
├── README.ja.md                     # 日本語 README
├── input/questions/                 # 学習質問の入力ファイル
├── output/{project-name}/           # 実行出力、プロジェクトごとに分離
├── docs/
│   ├── assets/                      # README とドキュメント用アセット
│   ├── plans/                       # 実装計画
│   ├── roadmap/                     # バージョンロードマップ
│   ├── adr/                         # Architecture Decision Records
│   └── specs/                       # イベントプロトコルとログ形式の仕様
├── tools/
│   ├── harness-visualizer.html      # 単一ファイルの可視化パネル
│   └── open-visualizer.sh           # パネル起動スクリプト
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

## Observability 可視化

v0.2 では軽量な観測レイヤーが追加されました。学習成果物の本文は読まず、実行状態だけを表示します。

```bash
# 指定プロジェクトの events.jsonl + state.json を読み込み、2 秒ごとに更新するパネルを開く
./tools/open-visualizer.sh {project-name}

# プロジェクト名を省略すると、output/ 以下の最新プロジェクトを自動選択
./tools/open-visualizer.sh
```

イベントプロトコルは [docs/specs/harness-observability-events.md](docs/specs/harness-observability-events.md)、ログ形式は [docs/specs/run-log-format.md](docs/specs/run-log-format.md) を参照してください。

---

## 評価基準

`learning-evaluator` は、1 から 5 で採点する 6 次元の rubric を使います。

| 次元 | 説明 |
|---|---|
| Question Quality | 質問が正しく理解され、焦点化されているか |
| Coverage | ドメインの網羅性が十分か |
| Clarity | 表現が明確で理解しやすいか |
| Actionability | 出力をそのまま実行できるか |
| User Context Fit | 個別化が入力ファイルに厳密に基づいているか |
| Transferability | 知識を新しいシーンへ転移できるか |

すべての次元で 4/5 以上が PASS 条件です。追加のハードゲートとして、入力ファイルにない個人、業界、職種の背景を成果物が導入した場合は FAIL になります。

---

## チューニングガイド

**成果物が汎用的すぎる場合:**
1. まず `reviewing-mastery-paths` skill を調整し、Evaluator をより厳密にします。
2. 次に `designing-mastery-paths` skill を調整し、Builder の生成目標をより明確にします。
3. 新しい Agent の追加や Reviewer の分割は最後に検討します。

**成果物が特定のユーザーや業界を誤って仮定している場合:**
1. 入力ファイルがその背景を本当に提供しているか確認します。
2. `learning-contract.md` の「学習者背景と応用シーン」を確認します。
3. 最後に `reviewing-mastery-paths` の `User Context Fit` ハードゲートを調整します。

各コンポーネントは、複雑性を増やす前に、それ自体が load-bearing であることを示す必要があります。

---

## 設計判断

詳しくは [docs/adr/0001-question-to-mastery-architecture.md](docs/adr/0001-question-to-mastery-architecture.md) を参照してください。
