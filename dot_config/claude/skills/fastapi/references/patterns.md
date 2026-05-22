# 実装パターン

`SKILL.md` から参照。Pydantic / 依存性 / JWT認証 / 非同期DB / バックグラウンド処理の具体コード。

## Pydantic

### 組み込みバリデータを使う

```python
from enum import StrEnum
from pydantic import AnyUrl, BaseModel, EmailStr, Field


class MusicBand(StrEnum):
    AEROSMITH = "AEROSMITH"
    QUEEN = "QUEEN"
    ACDC = "AC/DC"


class UserCreate(BaseModel):
    first_name: str = Field(min_length=1, max_length=128)
    username: str = Field(min_length=1, max_length=128, pattern=r"^[A-Za-z0-9_-]+$")
    email: EmailStr
    age: int = Field(ge=18)                     # 必須、18以上
    favorite_band: MusicBand | None = None
    website: AnyUrl | None = None
```

> `Field(ge=18, default=None)` と書かない。制約とデフォルトが矛盾する。
> 必須（`Field(ge=18)`）か任意（`int | None = Field(default=None, ge=18)`）かを決める。

### カスタム基底モデル — モダンなシリアライズ

`json_encoders` は Pydantic v2 で非推奨。フィールドごとのルールは `@field_serializer` を使うか、
カスタム型を `PlainSerializer` で注釈する。

```python
from datetime import datetime
from zoneinfo import ZoneInfo
from pydantic import BaseModel, ConfigDict, field_serializer


class CustomModel(BaseModel):
    model_config = ConfigDict(populate_by_name=True)

    @field_serializer("*", when_used="json", check_fields=False)
    def _serialize_datetimes(self, value):
        if isinstance(value, datetime):
            if value.tzinfo is None:
                value = value.replace(tzinfo=ZoneInfo("UTC"))
            return value.strftime("%Y-%m-%dT%H:%M:%S%z")
        return value
```

### BaseSettings をドメインで分割する

`pydantic-settings` は Pydantic v2 以降、独立パッケージ。

```python
# src/auth/config.py
from datetime import timedelta
from pydantic_settings import BaseSettings, SettingsConfigDict


class AuthConfig(BaseSettings):
    model_config = SettingsConfigDict(env_prefix="AUTH_", env_file=".env", extra="ignore")

    JWT_ALG: str
    JWT_SECRET: str
    JWT_EXP_MINUTES: int = 5
    REFRESH_TOKEN_KEY: str
    REFRESH_TOKEN_EXP: timedelta = timedelta(days=30)
    SECURE_COOKIES: bool = True


auth_settings = AuthConfig()
```

## 依存性（Dependencies）

### デフォルト引数の `Depends(...)` ではなく `Annotated` を使う

`Annotated[T, Depends(...)]` は FastAPI 0.95 以降の慣用形で、デフォルト値まわりの落とし穴を避けられる。

```python
# DO — モダンな Annotated 形式
from typing import Annotated
from fastapi import Depends

PostDep = Annotated[dict, Depends(valid_post_id)]

@router.get("/posts/{post_id}")
async def get_post(post: PostDep):
    return post

# 避ける — デフォルト引数形式（動くがレガシー）
@router.get("/posts/{post_id}")
async def get_post(post: dict = Depends(valid_post_id)):
    return post
```

### 依存性の中で検証する（注入するだけにしない）

```python
async def valid_post_id(post_id: UUID4) -> dict:
    post = await service.get_by_id(post_id)
    if not post:
        raise PostNotFound()
    return post
```

### 再利用のために依存性をチェーンする

```python
async def valid_owned_post(
    post: Annotated[dict, Depends(valid_post_id)],
    token_data: Annotated[dict, Depends(parse_jwt_data)],
) -> dict:
    if post["creator_id"] != token_data["user_id"]:
        raise UserNotOwner()
    return post
```

### ルール

- 依存性は **リクエスト単位でキャッシュ** される。同じ `Depends(x)` を1リクエスト内で5回呼んでも `x` は1回だけ実行される。
- 依存性は `async def` を優先する。同期の依存性はスレッドプールで動くため、CPU処理のみの小さなチェックではオーバーヘッドの無駄。
- 依存性を共有したいときは **同じパス変数名** を使う（例: `/profiles/{profile_id}` と `/creators/{profile_id}` の両方で `profile_id`）。

## 認証 — JWT

`python-jose`（メンテ停止）ではなく **`PyJWT`** を使う。

```python
import jwt  # PyJWT
from jwt.exceptions import InvalidTokenError

def decode_token(token: str) -> dict:
    try:
        return jwt.decode(token, settings.JWT_SECRET, algorithms=[settings.JWT_ALG])
    except InvalidTokenError as exc:
        raise InvalidCredentials() from exc
```

## データベース — SQLAlchemy 2.0 async

SQLAlchemy 2.0 の非同期APIを優先する。`encode/databases` はメンテナンスモードのため、新規プロジェクトでは選ばない。

```python
# src/database.py
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker, create_async_engine

engine = create_async_engine(str(settings.DATABASE_URL), pool_pre_ping=True)
SessionFactory = async_sessionmaker(engine, expire_on_commit=False)


async def get_db() -> AsyncSession:
    async with SessionFactory() as session:
        yield session
```

### 命名規約

- `lower_case_snake`
- テーブル名は単数: `post`, `user`, `post_like`
- プレフィックスでグループ化: `payment_account`, `payment_bill`
- `datetime` には `_at` サフィックス、`date` には `_date` サフィックス
- FKカラム名は出現箇所すべてで同じにする（一部で `user_id`、別の所で `profile_id` のように揺らさない。常に `profile_id`）

### インデックス命名規約

```python
from sqlalchemy import MetaData

POSTGRES_INDEXES_NAMING_CONVENTION = {
    "ix": "%(column_0_label)s_idx",
    "uq": "%(table_name)s_%(column_0_name)s_key",
    "ck": "%(table_name)s_%(constraint_name)s_check",
    "fk": "%(table_name)s_%(column_0_name)s_fkey",
    "pk": "%(table_name)s_pkey",
}
metadata = MetaData(naming_convention=POSTGRES_INDEXES_NAMING_CONVENTION)
```

### SQLファースト、Pydanticセカンド

- 結合・集約・JSON整形はSQLで行う。これらは CPython より Postgres の方が速い。
- 結果をPydanticに詰めるのはレスポンス検証のためだけにし、変換のために使わない。

## バックグラウンド処理 — BackgroundTasks vs Celery

| BackgroundTasks を使う場合…              | Celery / Arq / RQ を使う場合…              |
|------------------------------------------|--------------------------------------------|
| タスクが1秒未満                          | 秒〜分かかるタスク                         |
| 失敗を黙って捨ててよい                   | リトライ・デッドレター・可視性が必要        |
| プロセス内で完結（メール送信、行のログ） | CPU負荷が高い、または別プールが必要         |
| スケジューリング不要                     | cron・ETA・レート制限が必要                |

```python
from fastapi import BackgroundTasks

@router.post("/signup")
async def signup(data: SignupIn, bg: BackgroundTasks):
    user = await service.create_user(data)
    bg.add_task(send_welcome_email, user.email)   # fire-and-forget、プロセス内
    return user
```

> BackgroundTasks は **レスポンス送信後、同じワーカープロセス内で** 実行される。ワーカーが死ぬと
> タスクは失われる。リトライは無い。ページ（呼び出し）対象になるような処理には使わない。
