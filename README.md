# Snippetbox

A web application built with Go for managing code snippets.

## Prerequisites

- Docker
- Docker Compose

## Getting Started

### 1. Clone the repository

```bash
git clone <repository-url>
cd snippetbox
```

### 2. Set up environment variables (Optional)

The docker-compose.yml has sensible defaults. If you want to customize:

```bash
# Create .env file
cat > .env << 'EOF'
MYSQL_ROOT_PASSWORD=rootpassword
MYSQL_USER=web
MYSQL_PASSWORD=pass
MYSQL_DATABASE=snippetbox
MYSQL_PORT=3306
APP_PORT=4000
EOF
```

### 3. Start the application

```bash
docker-compose up -d
```

This will:
- Pull the latest MySQL image
- Build the Go application
- Initialize the database with the schema
- Start both services

### 4. Access the application

- Application: http://localhost:4000
- MySQL: localhost:3306

### 5. View logs

```bash
# All services
docker-compose logs -f

# Just the app
docker-compose logs -f app

# Just MySQL
docker-compose logs -f mysql
```

### 6. Stop the application

```bash
docker-compose down
```

To remove volumes (database data) as well:

```bash
docker-compose down -v
```

## Database Access

The database uses a restricted `web` user with only SELECT, INSERT, UPDATE, DELETE permissions for security.

### Connect as web user (recommended):
```bash
make mysql-cli
# OR
docker-compose exec mysql mysql -u web -ppass snippetbox
```

### Connect as root (administrative tasks only):
```bash
make mysql-root
# OR
docker-compose exec mysql mysql -u root -prootpassword
```

### Test the setup:
```bash
# This should work
docker-compose exec mysql mysql -u web -ppass snippetbox \
  -e "SELECT id, title FROM snippets;"

# This should fail (permission denied)
docker-compose exec mysql mysql -u web -ppass snippetbox \
  -e "DROP TABLE snippets;"
```

For detailed database information, see [DATABASE.md](DATABASE.md).

## Development

### Running without Docker

If you want to run the app locally without Docker but still use the MySQL container:

```bash
# Start only MySQL
docker-compose up -d mysql

# Run the app locally
go run ./cmd/web -addr=:4000
```

### Rebuilding the application

If you make changes to the Go code:

```bash
docker-compose up -d --build app
```

## Project Structure

```
.
├── cmd/
│   └── web/          # Application entry point
├── ui/
│   ├── html/         # HTML templates
│   └── static/       # Static assets (CSS, JS, images)
├── scripts/
│   └── init.sql      # Database initialization script
├── docker-compose.yml
├── Dockerfile
└── README.md
```

## Database Details

- **MySQL Version**: 9.4.0 (latest)
- **Character Set**: UTF8MB4
- **Web User**: `web` / `pass` (restricted permissions)
- **Root User**: `root` / `rootpassword` (full access)

See [DATABASE.md](DATABASE.md) for complete database documentation.

## Troubleshooting

### MySQL container fails to start

Check if port 3306 is already in use:

```bash
lsof -i :3306
```

Change the port in `.env` if needed:

```
MYSQL_PORT=3307
```

### App cannot connect to database

Wait for MySQL to be fully initialized (first startup takes longer). Check health:

```bash
docker-compose ps
```

The MySQL service should show "healthy" status.

