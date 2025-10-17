# Database Setup

This project uses MySQL 9.4.0 running in Docker with proper UTF8MB4 encoding.

## Database Details

- **Database Name**: `snippetbox`
- **Character Set**: `utf8mb4`
- **Collation**: `utf8mb4_unicode_ci`
- **MySQL Version**: 9.4.0 (latest)

## Users and Permissions

### Root User
- **Username**: `root`
- **Password**: `rootpassword`
- **Permissions**: Full administrative access

### Web User (Application User)
- **Username**: `web`
- **Password**: `pass`
- **Permissions**: Restricted to `SELECT`, `INSERT`, `UPDATE`, `DELETE` only
- **Purpose**: Used by the web application for security

The `web` user **cannot** perform dangerous operations like:
- `DROP TABLE`
- `CREATE TABLE`
- `ALTER TABLE`
- `GRANT`
- `CREATE USER`

## Database Schema

### `snippets` Table

```sql
CREATE TABLE snippets (
    id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created DATETIME NOT NULL,
    expires DATETIME NOT NULL
);

CREATE INDEX idx_snippets_created ON snippets(created);
```

## Connecting to MySQL

### Using Make Commands

```bash
# Connect as web user (recommended for testing)
make mysql-cli

# Connect as root (for administrative tasks)
make mysql-root
```

### Using Docker Compose Directly

```bash
# Connect as web user
docker-compose exec mysql mysql -u web -ppass snippetbox

# Connect as root
docker-compose exec mysql mysql -u root -prootpassword
```

### From Your Go Application

When running locally (outside Docker):
```go
dsn := "web:pass@tcp(localhost:3306)/snippetbox?parseTime=true"
```

When running in Docker:
```go
dsn := "web:pass@tcp(mysql:3306)/snippetbox?parseTime=true"
```

The DSN is automatically set via environment variable in `docker-compose.yml`.

## Testing User Permissions

### Verify SELECT Works
```bash
docker-compose exec mysql mysql -u web -ppass snippetbox \
  -e "SELECT id, title, expires FROM snippets;"
```

Expected output:
```
+----+------------------------+---------------------+
| id | title                  | expires             |
+----+------------------------+---------------------+
|  1 | An old silent pond     | 2026-10-17 12:42:44 |
|  2 | Over the wintry forest | 2026-10-17 12:42:44 |
|  3 | First autumn morning   | 2025-10-24 12:42:44 |
+----+------------------------+---------------------+
```

### Verify DROP is Denied
```bash
docker-compose exec mysql mysql -u web -ppass snippetbox \
  -e "DROP TABLE snippets;"
```

Expected output:
```
ERROR 1142 (42000): DROP command denied to user 'web'@'localhost' for table 'snippets'
```

## Sample Data

The database is initialized with 3 sample snippets (haiku poems):

1. **An old silent pond** - by Matsuo Bashō (expires in 365 days)
2. **Over the wintry forest** - by Natsume Soseki (expires in 365 days)
3. **First autumn morning** - by Murakami Kijo (expires in 7 days)

## Resetting the Database

To completely reset the database (deletes all data):

```bash
make clean  # Stops containers and removes volumes
make up     # Starts fresh with initialized database
```

## Database Initialization

The database is automatically initialized by the `scripts/init.sql` file on first startup. This script:

1. Creates the `snippetbox` database with UTF8MB4 encoding
2. Creates the `snippets` table with proper schema
3. Adds an index on the `created` column
4. Inserts 3 sample records
5. Creates the `web` user with restricted permissions

## Changing Passwords

To change the passwords, you have two options:

### Option 1: Before First Start (Easy)

Create a `.env` file before running `docker-compose up`:

```bash
# .env
MYSQL_ROOT_PASSWORD=your_root_password
MYSQL_USER=web
MYSQL_PASSWORD=your_app_password
```

And update `scripts/init.sql` to match your password.

### Option 2: After Database is Running

Connect as root and run:

```sql
ALTER USER 'web'@'%' IDENTIFIED BY 'new_password';
FLUSH PRIVILEGES;
```

Then update your `.env` file and restart the app.

## Troubleshooting

### Can't Connect to Database

Wait for MySQL to fully start:
```bash
docker-compose logs -f mysql
```

Look for: `ready for connections`

### Permission Denied Errors

Make sure you're using the correct user:
- Use `web` user for application queries
- Use `root` user only for administrative tasks

### Character Encoding Issues

Verify the database encoding:
```bash
docker-compose exec mysql mysql -u root -prootpassword \
  -e "SHOW CREATE DATABASE snippetbox;"
```

Should show:
```
DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci
```

## Security Notes

⚠️ **Important**: The default passwords (`rootpassword` and `pass`) are for development only.

For production:
1. Use strong, unique passwords
2. Store passwords in environment variables
3. Never commit `.env` files to version control
4. Consider using secrets management tools
5. Restrict network access to MySQL port

