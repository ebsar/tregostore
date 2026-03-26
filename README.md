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

Llogarite ruhen ne databazen SQLite, perdoruesi kyqet vetem nese email-i dhe fjalekalimi perputhen me te dhenat e ruajtura, admini mund te shtoje produkte qe dalin automatikisht si karta ne kategori, dhe klienti i kyçur mund t'i ruaje produktet ne `wishlist` ose `cart`.

Regjistrimi i ri kerkon edhe verifikim te email-it me kod 6-shifror. Kodi vlen `30 minuta`; nese kerkohet kod i ri, kodi i meparshem skadon automatikisht. Derisa email-i te verifikohet, `Login` nuk lejohet dhe user-i ridrejtohet te faqja `Verifiko emailin`.

## Teknologjite

- Python 3
- SQLite
- HTML / CSS / JavaScript

Nuk ka dependency te jashtme.

## Njoftimet me email per bizneset

Kur konfirmohet nje porosi, sistemi tani mund t'i dergoje email biznesit qe e ka postuar produktin.

Per ta aktivizuar dergimin real te email-it, vendosi keto `environment variables` para se ta nisesh projektin:

- `TREGO_SMTP_HOST`
- `TREGO_SMTP_PORT`
- `TREGO_SMTP_USERNAME`
- `TREGO_SMTP_PASSWORD`
- `TREGO_SMTP_FROM`
- `TREGO_SMTP_USE_TLS`

Shembull:

```bash
export TREGO_SMTP_HOST="smtp.gmail.com"
export TREGO_SMTP_PORT="587"
export TREGO_SMTP_USERNAME="you@example.com"
export TREGO_SMTP_PASSWORD="app-password-here"
export TREGO_SMTP_FROM="you@example.com"
export TREGO_SMTP_USE_TLS="true"
python3 app.py
```

Nese keto mungojne, porosia ruhet normalisht ne databaze, por email-i nuk dergohet dhe sistemi kthen vetem njoftim informues.

Mund t'i vendosesh edhe ne nje file lokal `.env` ne root te projektit. Aplikacioni e lexon automatikisht kur ndizet.

Shenim per `Brevo`: `TREGO_SMTP_USE_TLS` zakonisht duhet te jete `true` per porten `587`. Nese `TREGO_SMTP_FROM` nuk punon, vendos nje email dergues qe e ke verifikuar te Brevo.

Kur SMTP nuk eshte konfiguruar ende, kodi i verifikimit te email-it printohet edhe ne terminalin lokal te serverit per testim.

## Cfare duhet te instalosh

Ne kete makine nuk ke nevoje te instalosh asgje tjeter, sepse:

- `Python 3` eshte i instaluar
- `sqlite3` eshte i instaluar

Nese e kalon projektin ne nje kompjuter tjeter, sigurohu te kesh `Python 3`.

## Si ta nisesh

```bash
cd /Users/ebsarhoxha/Documents/Playground
python3 app.py
```

Pastaj hape ne browser:

```text
http://127.0.0.1:8000
```

## GitHub dhe Vercel

Per GitHub:

- `.env` nuk duhet te futet ne repo
- perdore [`.env.example`](/Users/ebsarhoxha/Documents/Playground/.env.example) si model
- databaza lokale te `data/` eshte lene jashte repo-s

Per Vercel:

- projekti tani ka [vercel.json](/Users/ebsarhoxha/Documents/Playground/vercel.json) dhe wrapper-in [api/index.py](/Users/ebsarhoxha/Documents/Playground/api/index.py)
- route-t e faqeve dhe `api/*` jane pergatitur per deploy
- ne Vercel databaza SQLite dhe upload-et kalojne ne `/tmp`, pra jane te perkohshme dhe mund te humbin pas restart-it ose cold start-it

Pra ky setup eshte i mire per `preview/demo` ne Vercel, por jo ende zgjidhja perfundimtare per prodhim serioz.

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
- `schema.sql`
- `static/index.html`
- `static/about.html`
- `static/login.html`
- `static/forgot-password.html`
- `static/signup.html`
- `static/pets.html`
- `static/wishlist.html`
- `static/cart.html`
- `static/admin-products.html`
- `static/app.js`
- `static/style.css`

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
