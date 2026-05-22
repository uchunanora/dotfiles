---
name: fastapi
description: FastAPIの実装ベストプラクティス集。新規・既存のFastAPIコードで、async/syncルートの選択、Pydanticスキーマ、Depends依存性、JWT認証、SQLAlchemy 2.0非同期DB、テスト、Alembicマイグレーションを書くとき、または差分にアンチパターンが無いかレビューするときに使う。
---

# FastAPI ベストプラクティス

AIエージェント向けのFastAPI実装規約。特定プロジェクトに依存しない汎用パターンとして使う。

## このスキルを使うとき

- FastAPIプロジェクトの雛形、または新しい機能モジュール（`auth`, `posts`, `users` など）を作るとき
- ルートを `async def` / `def`（sync）どちらにするか判断するとき
- Pydanticスキーマ・`BaseSettings`・`Depends` 依存性・JWT認証・SQLAlchemy非同期DBを書くとき
- テスト・Alembicマイグレーション・APIドキュメントを整備するとき
- 差分に下記の **アンチパターン** が混入していないかレビューするとき

## プロジェクト構成

ファイル種別ではなく **ドメイン（機能）** で分割する。境界づけられたコンテキスト1つにつき1パッケージ。

```
fastapi-project/
├── alembic/                # DBマイグレーション（Alembic）
├── src/
│   ├── {domain}/           # 例: auth/, posts/, aws/
│   │   ├── router.py       # APIエンドポイント
│   │   ├── schemas.py      # Pydanticモデル
│   │   ├── models.py       # SQLAlchemy ORMモデル
│   │   ├── service.py      # ビジネスロジック
│   │   ├── dependencies.py # ルート依存性
│   │   ├── config.py       # ドメインスコープの BaseSettings
│   │   ├── constants.py    # 定数・エラーコード
│   │   ├── exceptions.py   # ドメイン固有例外
│   │   └── utils.py        # ヘルパー関数
│   ├── config.py           # グローバル BaseSettings
│   ├── models.py           # 共有 Pydantic / ORM 基底
│   ├── exceptions.py       # グローバル例外
│   ├── database.py         # 非同期エンジン + セッションファクトリ
│   └── main.py             # FastAPI app + lifespan
├── tests/                  # src のドメイン構成をミラーする
│   ├── auth/
│   ├── aws/
│   └── posts/
├── .env
├── .gitignore
├── logging.ini             # ロギング設定
└── alembic.ini             # Alembic設定
```

**ドメインをまたぐimportは、常に明示的なモジュール名を使う。** `from src.auth import *` は禁止。

```python
from src.auth import constants as auth_constants
from src.notifications import service as notification_service
from src.posts.constants import ErrorCode as PostsErrorCode
```

## 非同期ルートの判断

### 判断ルール

| ルートの内容                                | 採用                                                  |
| ------------------------------------------- | ----------------------------------------------------- |
| `await` 可能なノンブロッキングI/O           | `async def`                                           |
| ブロッキングI/O（非同期クライアントが無い） | `def`（sync、スレッドプールで実行）                   |
| 両者の混在                                  | `async def` ＋ ブロッキング部分を `run_in_threadpool` |
| CPUバウンドな処理（>50ms の計算）           | ワーカープロセスへ退避（Celery / RQ / Arq）           |

### Do / Don't

```python
# DON'T — async ルート内のブロッキング呼び出しはイベントループ全体を凍結させる
@router.get("/bad")
async def bad():
    time.sleep(10)            # このワーカー上の全リクエストをブロックする
    return {"ok": True}

# DO — sync ルートなら FastAPI がスレッドプールで実行する
@router.get("/sync-ok")
def sync_ok():
    time.sleep(10)            # ループではなくスレッドプールのワーカー1つをブロック
    return {"ok": True}

# DO — await 可能な sleep を使う async ルート
@router.get("/async-ok")
async def async_ok():
    await asyncio.sleep(10)   # 制御を譲り、ループは他リクエストを処理し続ける
    return {"ok": True}

# DO — sync ライブラリを呼ばざるを得ない async ルート
from fastapi.concurrency import run_in_threadpool

@router.get("/wrap")
async def wrap():
    result = await run_in_threadpool(legacy_sync_client.fetch, "id")
    return result
```

### スレッドプールの注意点

- Starletteのスレッドプールはデフォルト40。飽和させると全 sync ルートが遅くなる。
- スレッドはコルーチンよりコストが高い。「とりあえず」で sync ルートを使わない。

## アンチパターン（差分レビュー用チェックリスト）

差分をレビューするエージェントは、これらの混入を確認する。いずれもエージェントが実際に作り込みがちな失敗パターン。

| アンチパターン                                                            | なぜ駄目か                                         | 修正                                                                                                      |
| ------------------------------------------------------------------------- | -------------------------------------------------- | --------------------------------------------------------------------------------------------------------- |
| `async def` 内の `requests.get(...)`                                      | イベントループをブロック。`requests` は同期。      | `httpx.AsyncClient`、または `await run_in_threadpool(requests.get, ...)`。                                |
| `async def` 内の `time.sleep` / `open()` / 同期DBドライバ                 | 同上、ループをブロック。                           | 非同期版を使う（`asyncio.sleep`, `aiofiles`, 非同期ドライバ）。                                           |
| `from jose import jwt`                                                    | `python-jose` はメンテ停止。                       | `import jwt`（PyJWT）。                                                                                   |
| `from async_asgi_testclient import TestClient`                            | メンテ停止。                                       | `httpx.AsyncClient` ＋ `ASGITransport`。                                                                  |
| `model_config = ConfigDict(json_encoders={...})`                          | Pydantic v2 で非推奨。                             | `@field_serializer` または `Annotated[T, PlainSerializer(...)]`。                                         |
| `Field(ge=18, default=None)`                                              | 制約とデフォルトが矛盾。                           | 必須か任意のどちらかに決める。                                                                            |
| `def get_user(id: int = Depends(...))`（デフォルト引数形式）              | レガシー。デフォルト値まわりの落とし穴。           | `user: Annotated[User, Depends(...)]`。                                                                   |
| ルート本体を `except Exception` で包む                                    | バグを隠し、500を黙って200に変える。               | 具体的な例外クラスを捕捉し、意味あるステータスで `HTTPException` を送出。                                 |
| ページ対象になるような処理を `BackgroundTasks` で実行                     | リトライ無し、ワーカー終了で消失。                 | Celery / Arq / RQ を使う。                                                                                |
| `async def` 内で同期ORMセッションを呼ぶ                                   | ループをブロックし、プールをデッドロックさせうる。 | `AsyncSession` を使う。                                                                                   |
| Pydanticモデルを return し、かつ同じクラスを `response_model=` に指定     | モデルが2回構築される（検証＋シリアライズ）。      | `dict`/ORM行を返して `response_model` に検証させるか、`response_model` を外して戻り値の型に任せる。       |
| 深いパスでのドメイン横断import（`from src.auth.service.user import ...`） | 密結合でリファクタが困難。                         | `from src.auth import service as auth_service`。                                                          |
| アプリ全体で1つの `BaseSettings` を使い回す                               | 見通しが悪く、全ドメインが全変数を読む。           | ドメインごとに `BaseSettings` を1つ。                                                                     |
| 結合テストでDBをモックする                                                | モックと本番の乖離がいずれ本番で火を噴く。         | 実DB（testcontainers、使い捨てスキーマ）を使い、認証/外部サービスは `dependency_overrides` で差し替える。 |

## クイックリファレンス

| シナリオ                                  | 解決策                                           |
| ----------------------------------------- | ------------------------------------------------ |
| ノンブロッキングI/O                       | `await` を使う `async def` ルート                |
| ブロッキングI/O（非同期クライアント無し） | `def` ルート（sync、スレッドプールで実行）       |
| async ルート内で同期ライブラリ            | `await run_in_threadpool(fn, *args)`             |
| CPU集約的な処理                           | Celery / Arq / RQ のワーカープロセス             |
| DBに対するリクエスト検証                  | ロード＋検証＋返却を行う依存性                   |
| 検証ロジックを複数ルートで再利用          | 依存性をチェーンする                             |
| 依存性をモダンな書式で注入                | `Annotated[T, Depends(...)]`                     |
| リクエスト単位の依存性キャッシュ          | デフォルト挙動 — 同じ `Depends(x)` は1回だけ実行 |
| ドメインごとの設定                        | ドメインごとに `BaseSettings` サブクラスを1つ    |
| datetime のカスタムシリアライズ           | `@field_serializer`                              |
| 短い fire-and-forget タスク               | `BackgroundTasks`                                |
| 信頼性/スケジュール/重いタスク            | Celery / Arq / RQ                                |
| JWTデコード                               | `PyJWT`（`import jwt`）                          |
| 非同期DB                                  | SQLAlchemy 2.0 async（`AsyncSession`）           |
| HTTPテストクライアント                    | `httpx.AsyncClient` ＋ `ASGITransport`           |
| テストで依存性を差し替え                  | `app.dependency_overrides[dep] = fake`           |
| Lint ＋ Format                            | `ruff check --fix` ＋ `ruff format`              |

## Lint / Format

```shell
ruff check --fix src
ruff format src
```

pre-commit フックに追加するか CI で実行する。Ruff は black + isort + autoflake + flake8 の大半を置き換える。

## 詳細リファレンス

具体的なコード例が必要になったら、該当ファイルを読む。

- **実装パターンを書くとき** → `references/patterns.md`
  Pydantic（バリデータ / カスタム基底モデル / ドメイン別 `BaseSettings`）、Depends依存性（`Annotated` / 検証内包 / チェーン）、JWT認証（PyJWT）、SQLAlchemy 2.0 非同期DB（エンジン / 命名規約 / インデックス命名 / SQLファースト）、バックグラウンド処理（`BackgroundTasks` vs Celery）。
- **テスト・運用を整備するとき** → `references/testing-migrations-docs.md`
  非同期テストクライアント（httpx + `ASGITransport`）、テストでの `dependency_overrides`、Alembicマイグレーション、APIドキュメント（環境ごとの `/docs` 制御 / エンドポイントの完全文書化）。
