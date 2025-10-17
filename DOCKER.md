# Docker Setup Guide

This project uses Docker and Docker Compose to ensure everyone runs the same version of MySQL.

## What's Included

- **MySQL**: Latest version running in a container
- **Go Application**: Your snippetbox app containerized
- **Init Script**: Automatically sets up the database schema and sample data
- **Health Checks**: Ensures MySQL is ready before starting the app

## Quick Start

### 1. Create your environment file

Since `.env` is gitignored, create it from the example:

```bash
cp .env.example .env
```

Or create `.env` manually with these contents:

```env
# MySQL Configuration
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_DATABASE=snippetbox
MYSQL_USER=webuser
MYSQL_PASSWORD=password
MYSQL_PORT=3306

# Application Configuration
APP_PORT=4000
```

### 2. Start everything

```bash
docker-compose up -d
```

Or use the Makefile:

```bash
make up
```

### 3. Check the status

```bash
docker-compose ps
```

You should see both `mysql` and `app` services running and healthy.

### 4. Access your application

- **Web App**: http://localhost:4000
- **MySQL**: `localhost:3306`

## Common Commands

### Using Make (recommended)

```bash
make help          # Show all available commands
make up            # Start all services
make down          # Stop all services
make logs          # View all logs
make logs-app      # View app logs only
make logs-mysql    # View MySQL logs only
make restart       # Restart all services
make restart-app   # Rebuild and restart app only
make clean         # Stop and remove all containers and volumes
make mysql-cli     # Connect to MySQL as webuser
make mysql-root    # Connect to MySQL as root
make dev           # Run only MySQL (for local development)
```

### Using Docker Compose directly

```bash
# Start services
docker-compose up -d

# Stop services
docker-compose down

# View logs
docker-compose logs -f

# Rebuild and restart
docker-compose up -d --build

# Remove everything including volumes
docker-compose down -v
```

## Database Connection

### From Your Local Machine

When developing locally (not in Docker), use:

```go
dsn := "webuser:password@tcp(localhost:3306)/snippetbox?parseTime=true"
```

### From Inside Docker

When running in Docker, the app automatically uses:

```
webuser:password@tcp(mysql:3306)/snippetbox?parseTime=true
```

Note: `mysql` is the service name in docker-compose.yml and acts as the hostname.

## Database Schema

The database is automatically initialized with:

1. A `snippets` table with columns: id, title, content, created, expires
2. An index on the `created` column
3. Three sample snippets

See `scripts/init.sql` for the full schema.

## Development Workflow

### Option 1: Full Docker (recommended for consistency)

```bash
# Start everything
make up

# Make changes to your code
# Rebuild and restart
make restart-app

# View logs
make logs-app
```

### Option 2: Local Go, Dockerized MySQL

```bash
# Start only MySQL
make dev

# Run your app locally
go run ./cmd/web -addr=:4000
```

This is useful when you want fast iteration without rebuilding containers.

## Troubleshooting

### Port Already in Use

If port 3306 or 4000 is already in use, change it in `.env`:

```env
MYSQL_PORT=3307
APP_PORT=4001
```

Then restart:

```bash
make down
make up
```

### MySQL Not Ready

On first startup, MySQL takes time to initialize. The health check ensures the app waits, but you can monitor progress:

```bash
make logs-mysql
```

Wait until you see: `ready for connections`

### Reset Everything

To start fresh:

```bash
make clean  # Removes containers and all database data
make up     # Starts fresh
```

### Check Container Status

```bash
docker-compose ps
```

Healthy containers show "Up" and "healthy" status.

## MySQL Version

This setup uses `mysql:latest` which currently points to MySQL 8.x. To pin to a specific version, edit `docker-compose.yml`:

```yaml
services:
  mysql:
    image: mysql:8.0.35  # Specific version
```

## Data Persistence

Database data is stored in a Docker volume named `mysql_data`. This persists between restarts unless you run:

```bash
make clean  # or docker-compose down -v
```

## Security Notes

- The `.env` file is gitignored to protect credentials
- Change default passwords in production
- The init script is mounted read-only for security
- Never commit `.env` files to version control

## Adding New Migrations

To add new database migrations:

1. Create a new SQL file in `scripts/` (e.g., `scripts/002_add_users.sql`)
2. Mount it in `docker-compose.yml` under the mysql service volumes
3. Restart MySQL or run the script manually:

```bash
docker-compose exec mysql mysql -u root -prootpassword snippetbox < scripts/002_add_users.sql
```

## Next Steps

- Update your Go code to use the DSN from environment variables
- Add a MySQL driver to `go.mod` if not already present: `github.com/go-sql-driver/mysql`
- Implement database connections in your handlers

