# {{PROJECT_NAME}}

## Stack
- **Language**: Rust
- **Build**: Cargo

## Development
- `cargo run` — build and run
- `cargo test` — run tests
- `cargo clippy` — lint
- `cargo fmt` — format

## Architecture
- `src/main.rs` — entry point
- `src/lib.rs` — library root
- `src/` — modules organized by domain

## Conventions
- `clippy::pedantic` enabled
- Error handling with `thiserror` / `anyhow`
- No `unsafe` without documented justification
