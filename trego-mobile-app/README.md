# Trego Mobile App

Vue + Ionic + Capacitor mobile app that reuses the existing TREGO backend and database.

## What this project does

- uses the same backend endpoints under `/api/...`
- uses the same product, wishlist, cart, orders, messages, and business data sources
- keeps the structure familiar, but with a mobile-first app design

## Setup

1. Copy `.env.example` to `.env`
2. Set `VITE_API_BASE_URL` to your backend origin
3. Install dependencies
4. Run the app

## Commands

- `npm install`
- `npm run dev`
- `npm run build`
- `npm run cap:sync`
- `npm run cap:open:ios`
- `npm run cap:open:android`

## Important note

Because the app talks to the same backend from a native mobile shell, backend CORS and cookie/session settings may need to allow the mobile app origin if login/session cookies are used.
