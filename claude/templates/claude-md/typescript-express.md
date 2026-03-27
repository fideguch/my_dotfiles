# {{PROJECT_NAME}}

## Stack
- **Runtime**: Node.js + Express
- **Language**: TypeScript
- **Database**: {{DATABASE}}

## Development
- `npm run dev` — start dev server with hot reload
- `npm run build` — compile TypeScript
- `npm run test` — run tests

## Architecture
- `src/routes/` — Express route handlers
- `src/middleware/` — custom middleware
- `src/services/` — business logic
- `src/models/` — data models / repository layer

## Conventions
- All routes return consistent `{ success, data, error }` envelope
- Input validation with Zod at route boundaries
- Error handling via centralized error middleware
