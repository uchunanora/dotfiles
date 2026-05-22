---
name: skill-creator
description: Guides repo-local skill creation and updates. Use when adding or editing .claude/skills, SKILL.md frontmatter, references, scripts, or skill routing.
---

# Skill Creator

`.claude/skills/` 配下のリポジトリローカルなSkillを作成・更新するときに、このSkillを使用します。

## ワークフロー

1. Skillが必要かどうかを判断する。繰り返し発生するリポジトリ作業で、専門的なワークフロー・ローカルなリファレンス・コマンド列・オンデマンドで発動すべきポリシーが必要な場合にのみ追加する。
2. `.claude/skills/<skill-name>/SKILL.md` を、YAML frontmatterと簡潔なMarkdownの手順とともに作成または更新する。
3. `SKILL.md` は中核となるワークフローとナビゲーションに焦点を絞る。詳細な例・API・長いチェックリストは `references/` ファイルに移し、`SKILL.md` から直接リンクする。
4. `scripts/` 配下のスクリプトは、書き直すより実行したほうがよい決定論的・反復的な操作に対してのみ追加する。
5. エージェントが作業前に発見すべきリポジトリローカルなSkillを追加した場合は、ルートの `CLAUDE.md` のSkill Routing一覧を更新する。
6. 編集後は `pnpm run format` を実行し、その変更に応じた通常のリポジトリ検証レベルを適用する。

## Frontmatter

必須フィールド:

```yaml
---
name: skill-name
description: Skillが何をするか、いつ使うかを記述する。
---
```

Agent Skillsのベストプラクティスおよびskill構造のドキュメントにある、Anthropicのskill作成ガイダンスに従う:

- `description` フィールドは主要な発見メカニズムである。
- 説明は三人称で書く。
- そのSkillが何をするかと、いつ使うかの具体的な文脈・トリガーとなる語句・ファイル種別・コマンド・タスク種別の両方を含める。
- 「ドキュメントを助ける」「ファイルを処理する」のような曖昧な説明は避ける。
- skillの名前と説明は常に読み込まれるため、メタデータは簡潔に保つ。Anthropicのサイズガイダンスでは、frontmatterはおよそ100ワード程度として扱う。

任意のファイルルーティングフィールド:

- Claudeスタイルのファイルマッチングには `paths` を使う。カンマ区切りのglob文字列、またはYAMLリストで指定できる。
- あるskillが複数のエージェントランタイムをまたいで特定のファイル種別に対して発動すべき場合は、互換性のヒントとして `globs` を追加する。
- TypeScriptまたはJavaScriptに適用すべきクロスエージェントのリポジトリローカルなskillには、両方を含める:

```yaml
paths:
  - "**/*.ts"
  - "**/*.tsx"
  - "**/*.js"
  - "**/*.jsx"
globs: "*.ts,*.tsx,*.js,*.jsx"
```

- Codexスタイルの発見をパスメタデータだけに依存しない。skillを発動させるべきファイル種別とアクションについては、`description` 内で明示的に記述し続ける。

このリポジトリでは、1〜2文の短い説明（通常20〜35ワード程度）を推奨する。説明をラベルだけになるほど圧縮しないこと。エージェントが確実にskillを選べるだけのトリガー文脈が依然として必要である。

良い例:

```yaml
description: Guides Rust test workflows. Use when adding or fixing cargo tests, CLI snapshot tests, or fixture-backed parser and loader tests.
```

弱い例:

```yaml
description: Use for tests.
```

## 本文

本文は手順的かつリポジトリ固有の内容に保つ:

- 実行するコマンド。
- 読むべきファイルやリファレンス。
- 見落としやすいローカルな慣習。
- 変更後に期待される検証。
- よくあるミスを防ぐ小さな例。

モデルがすでに知っている一般的な概念の説明は避ける。skillの本文はskillが発動して初めて読み込まれるが、読み込まれた後はタスクの文脈と限られたコンテキストを取り合うことになる。

## References

詳細が条件付きの場合はリファレンスファイルを使う:

```text
.agents/skills/example-skill/
├── SKILL.md
└── references/
    ├── api.md
    └── examples.md
```

リファレンスファイルは `SKILL.md` から直接リンクし、それぞれをいつ読むべきかを明記する。エージェントは中間ファイルをプレビューするだけのことがあるため、入れ子になったリファレンスの連鎖は避ける。
