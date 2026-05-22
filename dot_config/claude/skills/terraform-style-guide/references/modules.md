# Terraform モジュール設計 — 詳細リファレンス

`infra/modules/**` 配下の再利用可能なモジュールを設計するためのコード例集。全体規約（`references/style.md`）を前提に、本ファイルのルールを追加で適用する。

## モジュール構成の基本

モジュールは単一の責務を持ち、外部から見たインターフェース（input / output）を最小限かつ明示的に保つ。

| ファイル       | 用途                                             |
| -------------- | ------------------------------------------------ |
| `main.tf`      | モジュールの中核となるリソースおよび data source |
| `variables.tf` | モジュールが受け取る入力（アルファベット順）     |
| `outputs.tf`   | 呼び出し元に公開する値（アルファベット順）       |
| `locals.tf`    | モジュール内部で計算する値                       |

## 動的リソース生成

### 原則: `count` よりも `for_each` を優先する

リソースが論理的に「集合」として扱われる場合、インデックスではなくキーで識別できる `for_each` を使う。これによりリストの中間要素を削除したときの破壊的な再作成を防げる。

```hcl
# 悪い例 — 複数リソースを count で生成
resource "aws_instance" "web" {
  count = var.instance_count
  tags  = { Name = "web-${count.index}" }
}

# 良い例 — for_each で名前付きインスタンスを生成
variable "instance_names" {
  description = "起動する Web インスタンスの名前集合"
  type        = set(string)
  default     = ["web-1", "web-2", "web-3"]
}

resource "aws_instance" "web" {
  for_each = var.instance_names
  tags     = { Name = each.key }
}
```

### `count` を使うのは条件付き生成のとき

「作るか作らないか」の 0/1 切り替えにのみ `count` を使う。

```hcl
resource "aws_cloudwatch_metric_alarm" "cpu" {
  count = var.enable_monitoring ? 1 : 0

  alarm_name = "high-cpu-usage"
  threshold  = 80
}
```

## モジュール変数の設計

モジュールの変数は外部 API そのもの。後方互換性を意識して設計する。

- すべての変数に `type` と `description` を必ず付ける。
- 必須（default なし）と任意（default あり）を明確に分ける。
- 取りうる値が限定されているものは `validation` ブロックで制約する。
- 機密情報を受け取る変数には必ず `sensitive = true` を付ける。
- 真偽値の変数は `enable_xxx` / `create_xxx` のように動作が読み取れる名前にする。

```hcl
variable "environment" {
  description = "デプロイ先環境"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev、staging、prod のいずれかである必要があります。"
  }
}

variable "enable_monitoring" {
  description = "CloudWatch アラームを作成するかどうか"
  type        = bool
  default     = false
}

variable "database_password" {
  description = "データベース管理者ユーザーのパスワード"
  type        = string
  sensitive   = true
}
```

複雑な入力には `object` 型を使い、構造を明示する。

```hcl
variable "subnets" {
  description = "作成するサブネットの定義"
  type = map(object({
    cidr_block        = string
    availability_zone = string
    public            = bool
  }))
}
```

## モジュール出力の設計

呼び出し元が必要とする値だけを output として公開する。内部実装の詳細は出さない。

- すべての output に `description` を必ず付ける。
- 機密値を返す output には `sensitive = true` を付ける。
- 集合リソース（`for_each`）を返す場合は、呼び出し元が参照しやすいよう `map` で公開する。

```hcl
output "instance_ids" {
  description = "作成された Web インスタンスの ID（キーはインスタンス名）"
  value       = { for k, v in aws_instance.web : k => v.id }
}

output "database_password" {
  description = "データベース管理者パスワード"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

## タグ付け

モジュール内で固有のタグを付ける場合も、呼び出し元から渡された共通タグとマージできるようにする。

```hcl
variable "tags" {
  description = "全リソースに付与する追加タグ"
  type        = map(string)
  default     = {}
}

locals {
  module_tags = merge(var.tags, {
    Module = "vpc"
  })
}
```

## モジュール内で禁止・回避すること

- モジュール内での `provider` ブロックの定義（呼び出し元から受け取る）。
- ハードコードされたリージョン、アカウント ID、認証情報。
- モジュール固有の `terraform.tfvars` をモジュールディレクトリに置くこと。
- 不要なリソースを output に露出させること（内部実装の隠蔽を保つ）。
- 1 モジュールに複数の責務（VPC と RDS と IAM を同一モジュールにまとめるなど）を詰め込むこと。

---

_出典: [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)_
