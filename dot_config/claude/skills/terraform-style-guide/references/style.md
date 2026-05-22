# Terraform 全体規約 — 詳細リファレンス

`SKILL.md` の全体規約に対応するコード例集。HCL のフォーマット・命名・ファイル構成の具体例を必要とするときに読む。

## ファイル構成の完全例

```hcl
# terraform.tf
terraform {
  required_version = ">= 1.14"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# variables.tf
variable "environment" {
  description = "デプロイ先環境"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "environment は dev、staging、prod のいずれかである必要があります。"
  }
}

# locals.tf
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
  }
}

# main.tf
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true

  tags = merge(local.common_tags, {
    Name = "${var.project_name}-${var.environment}-vpc"
  })
}

# outputs.tf
output "vpc_id" {
  description = "作成された VPC の ID"
  value       = aws_vpc.main.id
}
```

## ブロック内の記述順

引数 → ブロックの順に並べ、メタ引数は先頭、`lifecycle` は最後に置く。

```hcl
resource "aws_instance" "example" {
  # メタ引数
  count = 3

  # 引数
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  # ブロック
  root_block_device {
    volume_size = 20
  }

  # lifecycle は最後
  lifecycle {
    create_before_destroy = true
  }
}
```

## 命名規則の良い例 / 悪い例

- すべての名前は **小文字とアンダースコア** を使用する
- リソースタイプを含まない **説明的な名詞** を使う
- リソース名は単数形を使用し、複数形にしない
- そのスコープ内に 1 つしかなく、具体的な名前が冗長または不要な場合は `main` を既定名として使う

```hcl
# 悪い例
resource "aws_instance" "webAPI-aws-instance" {}
resource "aws_instance" "web_apis" {}
variable "name" {}

# 良い例
resource "aws_instance" "web_api" {}
resource "aws_vpc" "main" {}
variable "application_name" {}
```

## 変数（variables）

すべての変数に `type` と `description` を必ず指定する。

```hcl
variable "instance_type" {
  description = "Web サーバー用の EC2 インスタンスタイプ"
  type        = string
  default     = "t2.micro"

  validation {
    condition     = contains(["t2.micro", "t2.small", "t2.medium"], var.instance_type)
    error_message = "instance_type は t2.micro、t2.small、t2.medium のいずれかである必要があります。"
  }
}

variable "database_password" {
  description = "データベース管理者ユーザーのパスワード"
  type        = string
  sensitive   = true
}
```

## 出力（outputs）

すべての output に `description` を必ず指定する。

```hcl
output "instance_id" {
  description = "EC2 インスタンスの ID"
  value       = aws_instance.web.id
}

output "database_password" {
  description = "データベース管理者パスワード"
  value       = aws_db_instance.main.password
  sensitive   = true
}
```

## セキュリティ

- 機密値は必ず `sensitive = true` を付与する
- 認証情報やシークレットをハードコードしない

---

_出典: [HashiCorp Terraform Style Guide](https://developer.hashicorp.com/terraform/language/style)_
