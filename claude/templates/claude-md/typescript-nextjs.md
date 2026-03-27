# {{PROJECT_NAME}}

## Stack
- **Framework**: Next.js (App Router)
- **Language**: TypeScript
- **Styling**: {{STYLING}} (e.g., Tailwind CSS, CSS Modules)
- **Database**: {{DATABASE}} (e.g., Supabase, Prisma + PostgreSQL)

## Development
- `npm run dev` — start dev server
- `npm run build` — production build
- `npm run lint` — run ESLint
- `npm run test` — run tests

## Architecture
- `app/` — App Router pages and layouts
- `components/` — reusable UI components
- `lib/` — utilities, API clients, constants
- `types/` — shared TypeScript types

## Conventions
- Server Components by default; add `'use client'` only when needed
- API routes in `app/api/` use Route Handlers
- Environment variables: `.env.local` (gitignored), `.env.example` (committed)
