# {{PROJECT_NAME}}

## Stack
- **Framework**: FastAPI
- **Language**: Python 3.12+
- **Database**: {{DATABASE}}

## Development
- `uv run uvicorn app.main:app --reload` — start dev server
- `uv run pytest` — run tests
- `uv run ruff check .` — lint

## Architecture
- `app/` — application package
- `app/routers/` — API route modules
- `app/models/` — Pydantic models and DB schemas
- `app/services/` — business logic
- `tests/` — test suite

## Conventions
- Type hints on all public functions
- Pydantic models for request/response validation
- Dependency injection via FastAPI's `Depends()`
