# テスト・マイグレーション・APIドキュメント

`SKILL.md` から参照。テスト基盤・Alembicマイグレーション・APIドキュメントの具体コード。

## テスト

### 最初から非同期クライアントを使う

```python
import pytest
from httpx import AsyncClient, ASGITransport

from src.main import app


@pytest.fixture
async def client():
    transport = ASGITransport(app=app)
    async with AsyncClient(transport=transport, base_url="http://test") as ac:
        yield ac


@pytest.mark.asyncio
async def test_create_post(client: AsyncClient):
    resp = await client.post("/posts", json={"title": "hi"})
    assert resp.status_code == 201
```

> `async_asgi_testclient` は使わない（メンテ停止）。上記の httpx + `ASGITransport` がサポートされた手段。

### テストでは依存性をオーバーライドする

内部実装を monkeypatch しない。FastAPI 組み込みの `dependency_overrides` を使う。

```python
from src.auth.dependencies import parse_jwt_data
from src.main import app


def fake_user():
    return {"user_id": "00000000-0000-0000-0000-000000000001"}


@pytest.fixture(autouse=True)
def _override_auth():
    app.dependency_overrides[parse_jwt_data] = fake_user
    yield
    app.dependency_overrides.clear()
```

## マイグレーション（Alembic）

- マイグレーションは静的かつリバーシブルにする。
- 非同期テンプレートを使う: `alembic init -t async migrations`
- ファイル名は内容が分かるものに:
  ```ini
  # alembic.ini
  file_template = %%(year)d-%%(month).2d-%%(day).2d_%%(slug)s
  ```
  → `2026-04-14_add_post_content_idx.py`

## APIドキュメント

### 選んだ環境以外ではドキュメントを隠す

```python
from fastapi import FastAPI
from src.config import settings

SHOW_DOCS_IN = {"local", "staging"}
app_kwargs = {"title": "My API"}
if settings.ENVIRONMENT not in SHOW_DOCS_IN:
    app_kwargs["openapi_url"] = None    # /docs と /redoc を無効化
app = FastAPI(**app_kwargs)
```

### エンドポイントを完全に文書化する

```python
from fastapi import APIRouter, status

router = APIRouter()


@router.post(
    "/items",
    response_model=ItemResponse,
    status_code=status.HTTP_201_CREATED,
    summary="Create an item",
    description="Creates an item owned by the authenticated user.",
    tags=["items"],
    responses={
        status.HTTP_400_BAD_REQUEST: {"model": ErrorResponse, "description": "Validation error"},
        status.HTTP_409_CONFLICT:    {"model": ErrorResponse, "description": "Slug already exists"},
    },
)
async def create_item(payload: ItemCreate) -> ItemResponse: ...
```
