# TREGO starter

Ky projekt tani ka:

- `Home`
- `About`
- `Login`
- `Forgot Password`
- `Sign Up`
- `Wishlist`
- `Cart`
- `Kafshet shtepiake`
- `Admin Products`

Llogarite ruhen ne databaze, perdoruesi kyqet vetem nese email-i dhe fjalekalimi perputhen me te dhenat e ruajtura, admini mund te shtoje produkte qe dalin automatikisht si karta ne kategori, dhe klienti i kyçur mund t'i ruaje produktet ne `wishlist` ose `cart`.

Regjistrimi i ri kerkon edhe verifikim te email-it me kod 6-shifror. Kodi vlen `30 minuta`; nese kerkohet kod i ri, kodi i meparshem skadon automatikisht. Derisa email-i te verifikohet, `Login` nuk lejohet dhe user-i ridrejtohet te faqja `Verifiko emailin`.

## Teknologjite

- Python 3 API
- SQLite lokalisht
- PostgreSQL ne deploy nese vendos `DATABASE_URL`
- Vue 3 + Vite per frontend-in kryesor te klientit
- CSS ekzistuese e projektit e perdorur nga frontend-i i ri ne Vue

Per `Postgres` ne deploy perdoret `psycopg`.

## Voice assistant zanor

Ne projekt tani eshte integruar nje voice assistant real, i gatshem per prodhim, me `Vapi web widget`.

### Pse u zgjodh ky opsion

Krahasimi i shkurter:

- `Vapi`
  Zgjidhja me e thjeshte per nje assistant real zanor ne web: widget i embeddable, voice-first, `public key + assistant id`, pa backend te ri ne kete projekt.
- `Voiceflow`
  E thjeshte gjithashtu, por zakonisht eshte me e orientuar te builder-i i vet i flukseve/chat-it dhe ka pak me shume pune operative per voice-first rollout.
- `Custom OpenAI Realtime`
  Me fleksibla, por jo zgjidhja me e lehte: do endpoint per token/ephemeral session, menaxhim audio/WebRTC dhe me shume kod custom.

Per kete arsye, u zgjodh `Vapi` si opsioni me i lehte dhe me pak pune custom, por qe prape jep voice assistant real.

### Environment variables

Per ta aktivizuar widget-in zanor, vendos:

- `VITE_VAPI_PUBLIC_KEY`
- `VITE_VAPI_ASSISTANT_ID`
- `VITE_VAPI_ASSISTANT_LABEL` opsionale

Shembull:

```bash
export VITE_VAPI_PUBLIC_KEY="pk_live_or_test_here"
export VITE_VAPI_ASSISTANT_ID="your_assistant_id"
export VITE_VAPI_ASSISTANT_LABEL="Asistenti zanor TREGO"
```

Shenim i rendesishem:

- `VITE_VAPI_PUBLIC_KEY` eshte `public`, pra lejohet te jete ne frontend
- mos vendos `private/server keys` te Vapi ne frontend
- logjika dhe sekretet e verteta mbeten te Vapi dashboard / provider settings

### Si ta konfigurosh ne Vapi

1. Krijo nje assistant ne dashboard te `Vapi`.
2. Zgjidh modelin, voice-in dhe prompt-in e assistant-it.
3. Kopjo `Public Key`.
4. Kopjo `Assistant ID`.
5. Vendosi si env vars ne projekt.

Widget-i shfaqet automatikisht vetem kur keto env vars jane te vendosura.

### Si ta testosh lokalisht

1. Nise backend-in:

```bash
cd /Users/ebsarhoxha/Documents/Playground
python3 app.py
```

2. Nise frontend-in me env vars:

```bash
cd /Users/ebsarhoxha/Documents/Playground
VITE_VAPI_PUBLIC_KEY="pk_test_or_live_here" \
VITE_VAPI_ASSISTANT_ID="your_assistant_id" \
VITE_VAPI_ASSISTANT_LABEL="Asistenti zanor TREGO" \
npm run dev
```

3. Hape app-in ne browser te `localhost`.
4. Lejo lejen e mikrofonit kur browser-i ta kerkon.
5. Ne qoshen e poshtme djathtas do te shfaqet widget-i zanor.

Per `localhost`, shumica e browser-ave lejojne testim me mikrofon. Ne production perdor `HTTPS`.

## Njoftimet me email per bizneset

Kodi i verifikimit dhe resetimi i fjalëkalimit dërgohen tani vetëm përmes Brevo (Messaging API). Për ta aktivizuar vendos këto `environment variables`:

- `BREVO_API_KEY`
- `BREVO_SENDER_EMAIL`
- `BREVO_SENDER_NAME` (opsional, default “TREGO”)

`BREVO_SENDER_EMAIL` duhet të verifikohet në panelin e Brevo-s (Senders → Verified senders). Pas konfirmimit, dërgo kodin e verifikimit direkt nga app-i:

```bash
BREVO_API_KEY="xkeysib-..." \
BREVO_SENDER_EMAIL="no-reply@trego.al" \
BREVO_SENDER_NAME="Trego Support" \
python3 app.py
```

Në Vercel shto të njëjtat env vars në “Project Settings → Environment Variables” (për Preview dhe Production). Nëse Brevo nuk është konfiguruar, kodi i verifikimit printohet në terminal për testim.

## Cfare duhet te instalosh

Ne kete makine tash te duhen:

- `Python 3`
- `Node.js 16+`
- `npm`

Lokalisht backend-i dhe frontend-i nisen ndaras.

## Si ta nisesh

Backend API:

```bash
cd /Users/ebsarhoxha/Documents/Playground
python3 app.py
```

Frontend Vue:

```bash
cd /Users/ebsarhoxha/Documents/Playground
npm run dev
```

Pastaj hape ne browser frontend-in:

```text
http://127.0.0.1:5173
```

Backend API mbetet te:

```text
http://127.0.0.1:8000
```

Shenim:

- frontend-i i ri `Vue + Vite` ne kete konfigurim punon me `Node 16+`
- nese po perdor `nvm`, ne root te projektit mund te besh:

```bash
nvm use
```

- krejt frontend-i kryesor tani kalon nga `Vue`, perfshire:
  - `Home`
  - `Search`
  - `Product detail`
  - `Business profile`
  - `Login`
  - `Sign Up`
  - `Verify email`
  - `Forgot password`
  - `Change password`
  - `Wishlist`
  - `Cart`
  - `Llogaria`
  - `Te dhenat personale`
  - `Adresat`
  - `Porosite`
  - `Porosite e biznesit`
  - `Checkout address`
  - `Payment options`
  - `Admin products`
  - `Biznesi juaj`
  - `Bizneset e regjistruara`

## GitHub dhe Vercel

Per GitHub:

- `.env` nuk duhet te futet ne repo
- perdore [`.env.example`](/Users/ebsarhoxha/Documents/Playground/.env.example) si model
- databaza lokale te `data/` eshte lene jashte repo-s

Per Vercel:

- projekti tani ka [vercel.json](/Users/ebsarhoxha/Documents/Playground/vercel.json) dhe wrapper-in [api/index.py](/Users/ebsarhoxha/Documents/Playground/api/index.py)
- `Vercel` nderton frontend-in me `npm run build` dhe e sherben nga `dist`
- route-t e aplikacionit tani shkojne te `Vue SPA`, perfshire edhe `admin`, `business`, `account` dhe `checkout`
- nese nuk vendos `DATABASE_URL`, ne Vercel databaza SQLite dhe upload-et kalojne ne `/tmp`, pra jane te perkohshme dhe mund te humbin pas restart-it ose cold start-it
- nese vendos `DATABASE_URL`, aplikacioni kalon automatikisht ne `PostgreSQL` dhe i krijon tabelat nga [schema_postgres.sql](/Users/ebsarhoxha/Documents/Playground/schema_postgres.sql)
- per te mos mbetur pa admin ne deploy, mund te vendosesh:
  - `TREGO_BOOTSTRAP_ADMIN_NAME`
  - `TREGO_BOOTSTRAP_ADMIN_EMAIL`
  - `TREGO_BOOTSTRAP_ADMIN_PASSWORD`
- nese nuk ekziston asnje admin, ky admin krijohet automatikisht nga keto env vars
- per deploy me databaze reale, shto edhe:
  - `DATABASE_URL`

Pra tani ke dy menyra:

- `preview/demo`: pa `DATABASE_URL`, me SQLite te perkohshme
- `deploy serioz`: me `DATABASE_URL` te PostgreSQL

## Si funksionon tani

1. `Home` eshte faqja kryesore.
2. `Sign Up` ruan `full name`, `email`, `password hash`, `role`, dhe krijon kod verifikimi per email-in.
3. Pasi perfundon regjistrimi, perdoruesi ridrejtohet te `Verifiko emailin`.
4. `Verifiko emailin` aktivizon llogarine me kod 6-shifror.
5. `Login` kontrollon email-in dhe fjalekalimin me databazen dhe lejohet vetem pasi email-i te jete verifikuar.
6. `Forgot Password` lejon perditesimin e fjalekalimit nese email-i ekziston ne databaze.
7. Nese te dhenat jane te sakta, krijohet nje sesion.
8. `Admin` ridrejtohet te `/admin-products`, ndersa `client` kthehet te `Home`.
9. Nga `Admin Products`, admini mund te shtoje artikuj te rinj.
10. Faqja `Kafshet shtepiake` i lexon produktet nga databaza dhe krijon kartat automatikisht.
11. Nga kartat e produkteve, perdoruesi i kyçur mund te shtoje artikuj ne `wishlist` ose `cart`.
12. Nese llogaria nuk ekziston, te dhenat nuk jane te sakta, ose email-i s'eshte verifikuar, del mesazhi perkates.

## Rolet

- `admin`
- `client`

Shenim:

- nese databaza nuk ka asnje admin, perdoruesi i pare behet `admin`
- ne databazat ekzistuese, perdoruesi me i vjeter caktohet `admin` gjate migrimit

## Skedaret kryesore

- `app.py`
- `api/index.py`
- `schema.sql`
- `schema_postgres.sql`
- `index.html`
- `vite.config.mjs`
- `public/`
- `src/App.vue`
- `src/router/index.js`
- `src/views/`
- `src/components/`
- `static/style.css`
- `static/*.html` per faqet legacy

## Databaza

Databaza krijohet te:

```text
data/accounts.db
```

Tabela `users` ruan:

- `id`
- `full_name`
- `email`
- `password_hash`
- `role`
- `created_at`

Tabela `products` ruan:

- `id`
- `title`
- `description`
- `price`
- `image_path`
- `category`
- `created_by_user_id`
- `created_at`

Tabela `wishlist_items` ruan:

- `user_id`
- `product_id`
- `created_at`

Tabela `cart_items` ruan:

- `user_id`
- `product_id`
- `quantity`
- `created_at`
- `updated_at`

## Si ta kontrollosh databazen

```bash
sqlite3 data/accounts.db "SELECT id, full_name, email, role, created_at FROM users;"
sqlite3 data/accounts.db "SELECT id, title, category, price, created_at FROM products;"
```

## Hapi tjeter

Mbi kete baze mund te shtojme:

- editim dhe fshirje artikujsh nga admini
- porosi online
- menu dinamike
- menaxhim me te avancuar te sesioneve
