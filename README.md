# 🩸 RaktaData

A full-stack blood bank management system for tracking donors, managing blood stock, and processing transfusion requests — built with PostgreSQL, Express, React, and Node.js (PERN stack).

---

## Features

- **Role-based access** — three separate panels for Admin, Staff, and Customer
- **Blood stock management** — track inventory by blood group and component type with automatic availability status (Stable / Low / Critical / Out of Stock)
- **Request workflow** — customers submit requests, stock is checked automatically via database trigger, admin approves or rejects with reason
- **Emergency requests** — flagged visually and sorted to the top of the admin queue
- **Donor management** — staff register donors, log donations, and track 90-day eligibility cooldowns via database triggers
- **Donor directory** — customers can search eligible donors by blood group and contact them directly when stock is insufficient
- **Transaction audit log** — every stock change is recorded automatically
- **Dark mode** — persistent across sessions, respects system preference on first visit
- **JWT authentication** — tokens persist across page refreshes

---

## Tech Stack

| Layer    | Technology                   |
| -------- | ---------------------------- |
| Database | PostgreSQL                   |
| Backend  | Node.js, Express.js          |
| Frontend | React 18, Vite               |
| Auth     | JWT (jsonwebtoken), bcrypt   |
| Styling  | Plain CSS with CSS variables |

---

## Project Structure

```
raktadata/
├── client/                  # React frontend (Vite)
│   └── src/
│       ├── components/      # Shared UI components
│       ├── hooks/           # Custom React hooks (useTheme)
│       ├── pages/
│       │   ├── admin/       # Admin panel pages
│       │   ├── staff/       # Staff panel pages
│       │   ├── customer/    # Customer panel
│       │   └── public/      # Public-facing pages
│       ├── styles/          # Global CSS (CSS variables, dark mode)
│       └── api.js           # Fetch wrapper for all API calls
├── server/                  # Express backend
│   ├── middleware/          # JWT auth middleware
│   ├── routes/              # auth, admin, staff, customer
│   ├── db.js                # PostgreSQL pool (pg)
│   ├── cron.js              # Scheduled job: reset donor eligibility after 90 days
│   └── server.js            # Entry point
└── database/
    ├── schema.sql           # Table definitions
    ├── views.sql            # Aggregation views
    ├── triggers.sql         # Auto-update triggers
    └── procedures.sql       # Stored procedures (approve/reject requests)
```

---

## Prerequisites

- [Node.js](https://nodejs.org/) v18 or higher
- [PostgreSQL](https://www.postgresql.org/) v14 or higher
- npm v9 or higher

---

## Local Setup

### 1. Clone the repository

```bash
git clone https://github.com/asim63/raktadata.git
cd raktadata
```

### 2. Set up the database

Open psql or your preferred PostgreSQL client and create the database:

```bash
psql -U postgres
```

```sql
CREATE DATABASE raktadata;
\c raktadata
```

Then run each SQL file in order:

```bash
psql -U postgres -d raktadata -f database/schema.sql
psql -U postgres -d raktadata -f database/views.sql
psql -U postgres -d raktadata -f database/triggers.sql
psql -U postgres -d raktadata -f database/procedures.sql
```

### 3. Configure environment variables

Copy the example environment file and fill in your values:

```bash
cp server/.env.example server/.env
```

Open `server/.env` and update the values:

```env
PORT=5000
NODE_ENV=development
DB_URL=postgresql://postgres:yourpassword@localhost:5432/raktadata
JWT_SECRET=your_super_secret_jwt_key_change_this_in_production
JWT_EXPIRES_IN=7d
CLIENT_URL=http://localhost:5173
```

> **Tip:** Generate a secure JWT secret with:
>
> ```bash
> node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
> ```

### 4. Create an admin user

The system requires at least one admin user to get started. Run this in your PostgreSQL client (requires the `pgcrypto` extension):

```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

INSERT INTO users (username, password, role)
VALUES ('admin', crypt('admin123', gen_salt('bf', 10)), 'ADMIN');

INSERT INTO admin (user_id, admin_name)
VALUES (
  (SELECT user_id FROM users WHERE username = 'admin'),
  'System Admin'
);
```

> Change the username and password before deploying to production.

### 5. Install dependencies

```bash
cd client && npm install
cd ../server && npm install
```

### 6. Start development servers

In separate terminals:

```bash
cd server && npm run dev
```

```bash
cd client && npm run dev
```

| Service  | URL                   |
| -------- | --------------------- |
| API      | http://localhost:5000 |
| Frontend | http://localhost:5173 |

---

## Deployment (Railway + Vercel)

### Deploy the API to Railway

1. Create a new Railway service from this GitHub repo.
2. Set the service **Root Directory** to `server/` (monorepo).
3. Use these commands:
   - **Build Command:** `npm ci`
   - **Start Command:** `npm start`

Required environment variables in Railway:

```env
DB_URL=postgresql://...
JWT_SECRET=replace_with_long_random_value
JWT_EXPIRES_IN=7d
NODE_ENV=production
CLIENT_URL=https://<your-vercel-app>.vercel.app
```

### Initialize the Railway database

Run the SQL files against your Railway Postgres database (in order):

```bash
psql "$DB_URL" -f database/schema.sql
psql "$DB_URL" -f database/views.sql
psql "$DB_URL" -f database/triggers.sql
psql "$DB_URL" -f database/stored_procedure.sql
```

### Point the Vercel client to Railway

Set this Vercel environment variable and redeploy:

```env
VITE_API_URL=https://<your-railway-domain>/api
```

---

## API Overview

All protected routes require an `Authorization: Bearer <token>` header.

| Prefix          | Role     | Description                                        |
| --------------- | -------- | -------------------------------------------------- |
| `/api/auth`     | Public   | Login                                              |
| `/api/customer` | Customer | Submit requests, check availability, find donors   |
| `/api/staff`    | Staff    | Register donors, log donations, view dashboard     |
| `/api/admin`    | Admin    | Full access — stock, requests, staff, transactions |

---

## Database Overview

The schema defines 8 core tables: `users`, `admin`, `staff`, `customer`, `donor`, `donation`, `blood_stock`, `blood_request`, and `stock_transaction`.

Key automation:

| Mechanism  | What it does                                                                            |
| ---------- | --------------------------------------------------------------------------------------- |
| Trigger 1  | After a donation, sets donor `eligibility_status = FALSE` and logs `last_donation_date` |
| Trigger 3  | After a request is inserted, auto-sets status to `REJECTED` or `PENDING` based on stock |
| Trigger 6  | Validates that donation blood group matches the registered donor's blood group          |
| Cron job   | Runs daily — resets `eligibility_status = TRUE` for donors 90+ days since last donation |
| Procedures | `approve_blood_request` and `reject_blood_request` run as atomic transactions           |

---

## Default Credentials (development only)

| Role  | Username | Password |
| ----- | -------- | -------- |
| Admin | admin    | admin123 |

> Staff accounts are created by admin through the Staff panel. Customer accounts are created via the public registration page.

---

## License

MIT
