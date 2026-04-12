# Supabase Database Setup

This project reads `DATABASE_URL` and automatically uses Postgres when that
variable is present.

Environment loading priority in local development:

1. shell / platform environment variables
2. `.env.local`
3. `.env`

## Local development

Put your Supabase connection string in `.env.local`:

```env
DATABASE_URL="postgres://postgres.PROJECT_REF:YOUR_PASSWORD@aws-0-REGION.pooler.supabase.com:5432/postgres?sslmode=require"
```

Use one of these, depending on your workflow:

- Supavisor session mode: best for persistent local app sessions and IPv4-safe connections
- Direct connection: best for database tools if your network supports IPv6

## Vercel / serverless deployment

For Vercel, set `DATABASE_URL` to the Supabase Supavisor transaction-mode
connection string from the Supabase dashboard `Connect` panel. This is the
recommended mode for serverless workloads.

Example shape:

```env
DATABASE_URL="postgres://postgres.PROJECT_REF:YOUR_PASSWORD@aws-0-REGION.pooler.supabase.com:6543/postgres?sslmode=require"
```

## Why this works well here

- The backend opens short-lived Postgres connections per request
- Prepared statements are already disabled in `psycopg`
- That makes Supabase transaction mode a good fit for Vercel functions

## Migration checklist

1. Create a Supabase project
2. Copy the correct connection string from `Connect`
3. Put it in local `.env.local` as `DATABASE_URL`
4. Set the same `DATABASE_URL` in Vercel project environment variables
5. Redeploy
6. Verify:
   - `/api/products`
   - `/api/businesses/public`
   - `/api/recommendations/home`
   - login flow
