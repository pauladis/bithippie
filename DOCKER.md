# Docker PostgreSQL Setup

This project uses Docker and Docker Compose to manage a PostgreSQL database.

## Prerequisites

- Docker: https://docs.docker.com/get-docker/
- Docker Compose: https://docs.docker.com/compose/install/

## Quick Start

### 1. Start the PostgreSQL container

```bash
docker-compose up -d
```

This will:
- Pull the PostgreSQL 15 Alpine image
- Create and start the container
- Initialize the database
- Expose PostgreSQL on `localhost:5432`

### 2. Verify the container is running

```bash
docker-compose ps
```

You should see the `bithippie_postgres` container with status "Up".

### 3. Connect to PostgreSQL

Using `psql`:
```bash
docker-compose exec postgres psql -U postgres -d bithippie_db
```

Or from your application:
```
Host: localhost
Port: 5432
User: postgres
Password: postgres
Database: bithippie_db
```

## Common Commands

### View logs
```bash
docker-compose logs -f postgres
```

### Stop the container
```bash
docker-compose down
```

### Stop and remove all data
```bash
docker-compose down -v
```

### Rebuild the image
```bash
docker-compose build --no-cache
```

## Environment Variables

Configure PostgreSQL credentials in `.env.docker`:
- `POSTGRES_USER`: Database user
- `POSTGRES_PASSWORD`: Database password
- `POSTGRES_DB`: Initial database name

## Initialization Scripts

To run SQL scripts on container startup, add `.sql` files to an `init-scripts/` directory and uncomment the COPY line in the Dockerfile.

## Connecting from Applications

### Python
```python
import psycopg2
conn = psycopg2.connect(
    host="localhost",
    database="bithippie_db",
    user="postgres",
    password="postgres"
)
```

### Node.js
```javascript
const { Client } = require('pg');
const client = new Client({
  user: 'postgres',
  password: 'postgres',
  host: 'localhost',
  port: 5432,
  database: 'bithippie_db',
});
await client.connect();
```

## Troubleshooting

If the container fails to start:
```bash
docker-compose logs postgres
```

To reset everything:
```bash
docker-compose down -v
docker system prune
docker-compose up -d
```
