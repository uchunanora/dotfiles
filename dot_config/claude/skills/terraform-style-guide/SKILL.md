---
name: terraform-style-guide
description: HashiCorp公式スタイルガイドに準拠したTerraform/HCL規約。infra/ や *.tf でリソース・variable・output・モジュールを書く、ファイル構成や命名を決める、for_each/count を選ぶ、機密値を扱う、または差分をレビューするときに使う。
---

# Terraform 規約

HashiCorp 公式スタイルガイドに準拠した Terraform / HCL を書くための規約。全体規約とモジュール設計の両方を扱う。

## このスキルを使うとき

- 新しい Terraform 構成（`terraform.tf` / `main.tf` / `variables.tf` など）や `infra/modules/**` の再利用モジュールを書くとき
- リソース・`variable`・`output`・`locals` の命名やファイル配置を決めるとき
- 複数リソースを動的生成する際に `for_each` と `count` のどちらを使うか判断するとき
- 機密値・タグ・`validation` の付け方を確認するとき
- 差分が下記の規約・チェックリストに反していないかレビューするとき

## コード生成の構築順序

1. プロバイダ設定とバージョン制約から開始する
2. 依存される側の `data` source を先に定義する
3. 依存関係の順にリソースを構築する
4. 主要なリソース属性は `output` として公開する
5. 設定可能な値はすべて `variable` に切り出す

## ファイル構成

| ファイル       | 用途                                           | ルート | モジュール |
| -------------- | ---------------------------------------------- | :----: | :--------: |
| `terraform.tf` | Terraform 本体およびプロバイダのバージョン要件 |   ✓    |     —      |
| `providers.tf` | プロバイダ設定                                 |   ✓    |     —      |
| `main.tf`      | 主要なリソースおよび data source               |   ✓    |     ✓      |
| `variables.tf` | 入力変数の宣言（アルファベット順）             |   ✓    |     ✓      |
| `outputs.tf`   | 出力値の宣言（アルファベット順）               |   ✓    |     ✓      |
| `locals.tf`    | ローカル値の宣言                               |   ✓    |     ✓      |

モジュールは `provider` ブロックを内部で定義しない（呼び出し元から受け取る）。

## 命名規則

- すべての名前は **小文字とアンダースコア**。
- リソースタイプを含まない **説明的な名詞**、**単数形**。
- スコープ内に 1 つしかなく具体名が冗長なら `main` を既定名にする。

```hcl
# 悪い例
resource "aws_instance" "webAPI-aws-instance" {}
resource "aws_instance" "web_apis" {}

# 良い例
resource "aws_instance" "web_api" {}
resource "aws_vpc" "main" {}
```

## ブロック内の記述順

メタ引数（`count` / `for_each` など）→ 引数 → ネストブロックの順に並べ、`lifecycle` は最後に置く。詳細な例は `references/style.md`。

## variable / output の必須ルール

- すべての `variable` に `type` と `description` を付ける。
- すべての `output` に `description` を付ける。
- 取りうる値が限定されるなら `variable` に `validation` ブロックを付ける。
- 機密値は `variable` / `output` の双方で `sensitive = true`。
- 認証情報・シークレットをハードコードしない。
- 真偽値の変数は `enable_xxx` / `create_xxx` のように動作が読める名前にする。

## 動的リソース生成: for_each を優先

- リソースが論理的な「集合」なら **`for_each`**（キーで識別。中間要素削除時の破壊的な再作成を防ぐ）。
- **`count`** は「作るか作らないか」の 0/1 条件付き生成のときだけ使う。

```hcl
# 集合 → for_each
resource "aws_instance" "web" {
  for_each = var.instance_names   # set(string)
  tags     = { Name = each.key }
}

# 条件付き生成 → count
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0
}
```

`for_each` の集合を返す `output` は、呼び出し元が参照しやすいよう `map` で公開する。

## モジュールで禁止・回避すること

- 内部での `provider` ブロック定義。
- リージョン・アカウント ID・認証情報のハードコード。
- モジュールディレクトリへの `terraform.tfvars` 配置。
- 内部実装の詳細を `output` に露出させること。
- 1 モジュールに複数責務（VPC + RDS + IAM など）を詰め込むこと。

## レビュー チェックリスト

- [ ] `terraform fmt` / `terraform validate` を通過
- [ ] ファイルが標準構成（上表）に従っている
- [ ] リソース名がアンダースコア区切りの説明的な名詞（単数形）
- [ ] すべての `variable` に `type` と `description`
- [ ] すべての `output` に `description`
- [ ] 取りうる値が限定される `variable` に `validation`
- [ ] 機密値の `variable` / `output` に `sensitive = true`
- [ ] 認証情報・シークレットがハードコードされていない
- [ ] 集合リソースは `for_each`（条件付き生成のみ `count`）
- [ ] モジュールが単一責務で、`provider` を内部定義していない
- [ ] 共通タグを外部から注入できる構造（`var.tags` を `merge`）
- [ ] リージョン・アカウント ID 等の環境固有値がハードコードされていない

## 詳細リファレンス

具体的なコード例が必要になったら該当ファイルを読む。

- **全体規約のコード例が必要なとき** → `references/style.md`
  ファイル構成の完全例（`terraform.tf` / `variables.tf` / `locals.tf` / `main.tf` / `outputs.tf`）、ブロック記述順の完全例、命名の良い例/悪い例、`variable` / `output` の `validation` ・ `sensitive` 例、セキュリティ。
- **モジュール設計のコード例が必要なとき** → `references/modules.md`
  `for_each` / `count` の良い例・悪い例、`object` 型による複雑な入力、`map` 出力、共通タグの `merge`、禁止事項の詳細。全体規約（`references/style.md`）を前提に追加適用する。

---

_出典: [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)_
