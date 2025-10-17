# Docker Setup Explanation - Beginner's Guide

This document explains everything we did to add Docker to this project, why we did it, and what each file does.

## Table of Contents
1. [Why Docker?](#why-docker)
2. [What is Docker?](#what-is-docker)
3. [Files We Created](#files-we-created)
4. [How Everything Works Together](#how-everything-works-together)
5. [The Complete Setup Process](#the-complete-setup-process)

---

## Why Docker?

### The Problem
Before Docker, when working on a team project, everyone had different setups:
- Person A has MySQL 8.0.30 on Windows
- Person B has MySQL 9.1.0 on Mac
- Person C has MySQL 5.7 on Linux

This caused problems:
- "It works on my machine!" (but not on yours)
- Difficult to onboard new team members
- Hard to replicate production environment
- Time wasted on environment setup

### The Solution: Docker
Docker packages your application and its dependencies (like MySQL) into **containers**. Think of containers as:
- **Lightweight virtual machines** that run the same everywhere
- **Shipping containers** for software - pack once, run anywhere
- **Isolated environments** that don't interfere with your system

With Docker, everyone runs:
- **Same MySQL version** (9.4.0)
- **Same configuration**
- **Same environment**

Just run `docker-compose up` and you're ready to work! 🎉

---

## What is Docker?

### Key Concepts

#### 1. **Container**
A running instance of your application in an isolated environment.
- Lightweight (shares OS kernel)
- Fast to start (seconds)
- Isolated from host system
- Can be stopped, started, deleted

#### 2. **Image**
A template/blueprint for creating containers.
- Like a recipe that Docker follows
- Contains your code + dependencies
- Immutable (doesn't change)
- Can be shared via Docker Hub

#### 3. **Dockerfile**
Instructions for building an image.
- Text file with commands
- Tells Docker: "copy this, install that, run this"
- Creates reproducible builds

#### 4. **Docker Compose**
Tool for running multi-container applications.
- Defines multiple services (MySQL, your app, etc.)
- Starts everything with one command
- Manages networks and volumes
- Perfect for development

#### 5. **Volume**
Persistent storage for containers.
- Data survives container restarts
- Store database files
- Share data between containers

#### 6. **Network**
Allows containers to talk to each other.
- Isolated network for your app
- Containers can use service names as hostnames
- Secure communication

---

## Files We Created

Let's understand each file and its purpose:

### 1. `docker-compose.yml`

**Purpose**: Orchestrates all services (MySQL + Go app)

**What it does**:
- Defines 2 services: `mysql` and `app`
- Sets up networking between them
- Creates persistent storage for database
- Manages startup order (MySQL before app)
- Exposes ports to your computer

**Breakdown**:

```yaml
services:
  mysql:
    image: mysql:latest              # Use official MySQL 9.4.0 image
    container_name: snippetbox-mysql # Name for easy reference
    restart: unless-stopped          # Auto-restart if crashes
    environment:                     # Environment variables
      MYSQL_ROOT_PASSWORD: rootpassword
    ports:
      - "3306:3306"                  # Map container port to host port
    volumes:
      - mysql_data:/var/lib/mysql    # Persist database files
      - ./scripts/init.sql:/docker-entrypoint-initdb.d/init.sql:ro
                                     # Run init script on first start
    healthcheck:                     # Check if MySQL is ready
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s                  # Check every 10 seconds
      timeout: 5s
      retries: 5
    networks:
      - snippetbox-network           # Join custom network

  app:
    build:
      context: .                     # Build from current directory
      dockerfile: Dockerfile         # Use this Dockerfile
    container_name: snippetbox-app
    depends_on:
      mysql:
        condition: service_healthy   # Wait for MySQL to be ready
    ports:
      - "4000:4000"                  # Expose app on port 4000
    environment:
      DSN: web:pass@tcp(mysql:3306)/snippetbox?parseTime=true
                                     # Database connection string
                                     # Note: 'mysql' is hostname (service name)
    networks:
      - snippetbox-network

volumes:
  mysql_data:                        # Named volume for persistence
    driver: local

networks:
  snippetbox-network:                # Custom network
    driver: bridge
```

**Key Points**:
- **Service names** (mysql, app) become hostnames inside the network
- **Volumes** persist data even when containers are deleted
- **Health checks** ensure MySQL is fully ready before starting the app
- **depends_on** controls startup order

---

### 2. `Dockerfile`

**Purpose**: Instructions to build your Go application image

**What it does**:
- Creates a blueprint for your app container
- Uses multi-stage build (smaller final image)
- Compiles your Go code
- Creates a minimal runtime environment

**Breakdown**:

```dockerfile
# ============ STAGE 1: BUILD ============
FROM golang:1.23-alpine AS builder
# Use official Go image with Alpine Linux (small, secure)
# 'AS builder' names this stage

RUN apk add --no-cache git
# Install git (needed for some Go dependencies)

WORKDIR /build
# Set working directory inside container

COPY go.mod go.sum* ./
# Copy dependency files first (layer caching optimization)

RUN go mod download
# Download dependencies (cached if go.mod hasn't changed)

COPY . .
# Copy all source code

RUN CGO_ENABLED=0 GOOS=linux go build -a -installsuffix cgo -o snippetbox ./cmd/web
# Compile Go code:
# - CGO_ENABLED=0: Pure Go binary (no C dependencies)
# - GOOS=linux: Build for Linux
# - -o snippetbox: Output binary name

# ============ STAGE 2: RUNTIME ============
FROM alpine:latest
# Use minimal Alpine image (only ~5MB!)

RUN apk --no-cache add ca-certificates
# Install SSL certificates (needed for HTTPS)

WORKDIR /app

COPY --from=builder /build/snippetbox .
# Copy ONLY the compiled binary from builder stage

COPY --from=builder /build/ui ./ui
# Copy UI files

EXPOSE 4000
# Document that app uses port 4000

CMD ["./snippetbox"]
# Command to run when container starts
```

**Why Multi-Stage Build?**
- **Builder stage**: Has all build tools (Go compiler, git) - Large image (~300MB)
- **Runtime stage**: Only has compiled binary - Small image (~20MB)
- Result: Fast builds, small deployable images, more secure

---

### 3. `scripts/init.sql`

**Purpose**: Initialize database on first startup

**What it does**:
- Automatically runs when MySQL container starts for the first time
- Creates database with proper UTF8MB4 encoding
- Creates tables and indexes
- Inserts sample data
- Creates restricted `web` user with limited permissions

**Key SQL Commands**:

```sql
-- 1. Create database with UTF8MB4 (supports emojis, international characters)
CREATE DATABASE IF NOT EXISTS snippetbox
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- 2. Switch to that database
USE snippetbox;

-- 3. Create table structure
CREATE TABLE snippets (
    id INTEGER NOT NULL PRIMARY KEY AUTO_INCREMENT,
    title VARCHAR(100) NOT NULL,
    content TEXT NOT NULL,
    created DATETIME NOT NULL,
    expires DATETIME NOT NULL
);

-- 4. Add index for faster queries on 'created' column
CREATE INDEX idx_snippets_created ON snippets(created);

-- 5. Insert sample data (3 haiku poems)
INSERT INTO snippets (title, content, created, expires) VALUES (...);

-- 6. Create restricted user for application
CREATE USER IF NOT EXISTS 'web'@'%' IDENTIFIED BY 'pass';
GRANT SELECT, INSERT, UPDATE, DELETE ON snippetbox.* TO 'web'@'%';
FLUSH PRIVILEGES;
```

**Security Note**:
The `web` user can only do SELECT, INSERT, UPDATE, DELETE. It **cannot**:
- Drop tables (DROP)
- Modify structure (ALTER, CREATE)
- Create users (GRANT)

This is a security best practice - if your app gets hacked, attackers can't destroy the database structure.

**How It Works**:
Docker's MySQL image automatically runs any `.sql` file placed in `/docker-entrypoint-initdb.d/` on first startup. We mount our `init.sql` file there in `docker-compose.yml`.

---

### 4. `Makefile`

**Purpose**: Convenient shortcuts for common Docker commands

**What it does**:
- Simplifies complex Docker commands
- Provides easy-to-remember commands
- Self-documenting (run `make help`)

**Example Commands**:

```makefile
up: ## Start all services
	docker-compose up -d
	@echo "Application: http://localhost:4000"

down: ## Stop all services
	docker-compose down

logs: ## View logs from all services
	docker-compose logs -f

mysql-cli: ## Connect to MySQL CLI as web user
	docker-compose exec mysql mysql -u web -ppass snippetbox

clean: ## Stop services and remove volumes
	docker-compose down -v
```

**Why Use It?**
Instead of typing:
```bash
docker-compose exec mysql mysql -u web -ppass snippetbox
```

Just type:
```bash
make mysql-cli
```

Much easier! 🎯

---

### 5. `.dockerignore`

**Purpose**: Tell Docker what files to ignore when building

**What it does**:
- Works like `.gitignore` but for Docker
- Speeds up builds (less files to copy)
- Reduces image size
- Prevents sensitive files from being copied

**Example Content**:
```
.git           # Don't copy git history
.env           # Don't copy environment variables
README.md      # Don't need docs in container
*.tmp          # Skip temporary files
node_modules   # Skip dependencies (will be downloaded fresh)
```

**Why Important?**
- **Faster builds**: Less files to copy
- **Smaller images**: Less bloat
- **Security**: Prevents copying `.env` or secrets
- **Clean builds**: Only production-needed files

---

### 6. `.gitignore`

**Purpose**: Tell Git what files not to commit

**What it does**:
- Keeps sensitive data out of version control
- Prevents committing generated files
- Keeps repository clean

**Important Entries**:
```
.env              # Database passwords (NEVER commit!)
.DS_Store         # Mac system files
*.log             # Log files
mysql_data/       # Database data
```

**Critical for Security**: The `.env` file contains passwords. If committed to GitHub, anyone can see them!

---

### 7. `README.md`

**Purpose**: Main project documentation

**What it includes**:
- Quick start guide
- Installation instructions
- How to run the project
- Troubleshooting tips
- Database connection info

**For Users Who**: Want to quickly understand and run the project

---

### 8. `DOCKER.md`

**Purpose**: Detailed Docker usage guide

**What it includes**:
- Docker-specific workflows
- Development tips
- Common commands
- Troubleshooting Docker issues

**For Users Who**: Want to understand Docker aspects in depth

---

### 9. `DATABASE.md`

**Purpose**: Database reference documentation

**What it includes**:
- Database schema
- User permissions
- Connection strings
- SQL examples
- Security notes

**For Users Who**: Need database-specific information

---

## How Everything Works Together

Let's trace what happens when you run `docker-compose up`:

### Step-by-Step Flow:

```
1. You run: docker-compose up -d
   ↓

2. Docker Compose reads: docker-compose.yml
   ↓

3. Creates network: snippetbox_snippetbox-network
   (Allows containers to communicate)
   ↓

4. Creates volume: snippetbox_mysql_data
   (Stores database files persistently)
   ↓

5. Starts MySQL service:
   a. Pulls mysql:latest image (if not cached)
   b. Creates container named: snippetbox-mysql
   c. Mounts init.sql to /docker-entrypoint-initdb.d/
   d. MySQL starts and runs init.sql (first time only)
   e. Creates snippetbox database with UTF8MB4
   f. Creates tables and sample data
   g. Creates 'web' user with permissions
   h. Health check runs (mysqladmin ping)
   i. Status becomes: Healthy ✓
   ↓

6. Builds Go app (if needed):
   a. Docker reads: Dockerfile
   b. Excludes files from: .dockerignore
   c. STAGE 1: Compiles Go code in golang:1.23-alpine
   d. STAGE 2: Copies binary to alpine:latest
   e. Creates final small image
   f. Tags image as: snippetbox-app
   ↓

7. Starts App service:
   a. Waits for MySQL to be healthy (depends_on)
   b. Creates container named: snippetbox-app
   c. Sets DSN environment variable
   d. Connects to mysql:3306 (service name as hostname)
   e. Starts web server on port 4000
   ↓

8. Services are running! ✓
   - MySQL: localhost:3306
   - App: localhost:4000
   - Both on same network
   - Data persists in volume
```

### Container Communication:

```
┌─────────────────────────────────────────────────┐
│           Your Computer (Host)                  │
│                                                 │
│  Browser → http://localhost:4000                │
│  MySQL Client → localhost:3306                  │
│                                                 │
│  ┌────────────────────────────────────────┐    │
│  │  Docker Network: snippetbox-network    │    │
│  │                                        │    │
│  │  ┌──────────────┐    ┌─────────────┐  │    │
│  │  │ Container:   │    │ Container:  │  │    │
│  │  │ snippetbox-  │───▶│ snippetbox- │  │    │
│  │  │ app          │    │ mysql       │  │    │
│  │  │              │    │             │  │    │
│  │  │ Port: 4000   │    │ Port: 3306  │  │    │
│  │  │              │    │             │  │    │
│  │  │ Hostname:    │    │ Hostname:   │  │    │
│  │  │ "app"        │    │ "mysql"     │  │    │
│  │  └──────────────┘    └─────────────┘  │    │
│  │                             │          │    │
│  │                             ▼          │    │
│  │                      ┌─────────────┐   │    │
│  │                      │  Volume:    │   │    │
│  │                      │  mysql_data │   │    │
│  │                      │  (persists) │   │    │
│  │                      └─────────────┘   │    │
│  └────────────────────────────────────────┘    │
└─────────────────────────────────────────────────┘
```

**Key Points**:
- Containers use **service names** as hostnames (`mysql`, `app`)
- Your computer accesses via **localhost:PORT**
- Inside network, app connects to `mysql:3306`
- Volume persists even when containers are deleted

---

## The Complete Setup Process

### What We Did (Step by Step):

#### Phase 1: Planning
1. Identified need for consistent MySQL version
2. Decided on Docker as solution
3. Determined requirements:
   - MySQL 9.4.0 (latest)
   - UTF8MB4 encoding
   - Restricted database user
   - Sample data from tutorial

#### Phase 2: Creating Configuration Files

1. **Created `docker-compose.yml`**
   - Defined MySQL service with latest image
   - Defined Go app service with custom build
   - Set up health checks
   - Configured networks and volumes
   - Set environment variables

2. **Created `Dockerfile`**
   - Used multi-stage build for efficiency
   - Stage 1: Build Go binary
   - Stage 2: Create minimal runtime image
   - Fixed Go version compatibility (1.23 vs 1.25.2)

3. **Created `scripts/init.sql`**
   - Database creation with UTF8MB4
   - Table schema matching tutorial
   - Sample data (3 haiku poems)
   - User creation with restricted permissions
   - Matched tutorial requirements exactly

4. **Created `.dockerignore`**
   - Excluded unnecessary files
   - Optimized build speed
   - Improved security

5. **Created `.gitignore`**
   - Protected sensitive files (.env)
   - Excluded generated files
   - Prevented committing local data

6. **Created `Makefile`**
   - Simplified common commands
   - Added help documentation
   - Made Docker more accessible

#### Phase 3: Documentation

1. **Created `README.md`**
   - Quick start guide
   - Installation steps
   - Basic usage

2. **Created `DOCKER.md`**
   - Detailed Docker guide
   - Development workflows
   - Troubleshooting

3. **Created `DATABASE.md`**
   - Database reference
   - Permission testing
   - Connection examples

4. **Created `explanation.md`** (this file!)
   - Beginner-friendly explanations
   - File-by-file breakdown
   - Concept explanations

#### Phase 4: Testing & Verification

1. Built Docker images
2. Started containers
3. Verified MySQL version (9.4.0 ✓)
4. Verified UTF8MB4 encoding ✓
5. Tested `web` user permissions:
   - SELECT ✓ (works)
   - INSERT ✓ (works)
   - UPDATE ✓ (works)
   - DELETE ✓ (works)
   - DROP ✗ (correctly denied)
6. Verified sample data loaded ✓
7. Confirmed app starts correctly ✓

---

## Common Docker Commands Explained

### Starting & Stopping

```bash
# Start all services in background
docker-compose up -d
# -d = detached mode (runs in background)

# Stop all services (keeps data)
docker-compose down

# Stop and remove all data
docker-compose down -v
# -v = volumes (deletes database data!)
```

### Viewing Logs

```bash
# View all logs
docker-compose logs

# Follow logs (live updates)
docker-compose logs -f

# View specific service
docker-compose logs app
docker-compose logs mysql

# Last 50 lines
docker-compose logs --tail=50
```

### Checking Status

```bash
# List running containers
docker-compose ps

# Detailed container info
docker ps
```

### Rebuilding

```bash
# Rebuild images
docker-compose build

# Rebuild and restart
docker-compose up -d --build

# Rebuild specific service
docker-compose build app
```

### Executing Commands

```bash
# Run command in running container
docker-compose exec mysql mysql -u root -p

# Open shell in container
docker-compose exec app sh

# Run one-off command
docker-compose run app go version
```

### Cleaning Up

```bash
# Remove stopped containers
docker-compose rm

# Remove unused images
docker image prune

# Remove everything (nuclear option)
docker system prune -a
```

---

## Benefits of Our Docker Setup

### 1. **Consistency** 🎯
- Everyone uses MySQL 9.4.0
- Same configuration everywhere
- "Works on my machine" → "Works on everyone's machine"

### 2. **Simplicity** 🚀
- One command to start: `docker-compose up -d`
- No manual MySQL installation
- No configuration hassles
- New team member ready in 5 minutes

### 3. **Isolation** 🔒
- Doesn't mess with your system
- Can run multiple projects with different MySQL versions
- Easy to completely remove (just delete containers)

### 4. **Reproducibility** 📋
- Infrastructure as code (docker-compose.yml)
- Same environment in dev, staging, production
- Easy to debug (everyone has identical setup)

### 5. **Security** 🛡️
- Restricted database user
- Isolated network
- Containers can't access your files
- Easy to reset if compromised

### 6. **Speed** ⚡
- Fast to start (seconds)
- Fast to reset (clean slate instantly)
- Fast to update (rebuild images)

---

## Beginner Tips

### Learning Docker

1. **Start Simple**
   - Use our Makefile commands first
   - Gradually learn underlying docker-compose commands
   - Read error messages carefully

2. **Common Gotchas**
   - **Port already in use**: Another app using 3306 or 4000
   - **Volume persists**: Data survives container deletion (use `down -v` to delete)
   - **Build cache**: Sometimes need `--build` to see code changes
   - **Container networking**: Use service names, not `localhost`

3. **Debugging**
   ```bash
   # Check what's running
   docker-compose ps

   # Check logs for errors
   docker-compose logs

   # Enter container to investigate
   docker-compose exec mysql sh

   # Check container health
   docker inspect snippetbox-mysql
   ```

4. **Good Practices**
   - Always use `.env` for passwords (never commit!)
   - Use `docker-compose down -v` to fully reset
   - Keep images small (multi-stage builds)
   - Use health checks
   - Name containers clearly

---

## Next Steps

Now that you understand the Docker setup:

1. **Learn More Docker**
   - [Docker Documentation](https://docs.docker.com/)
   - [Docker Compose Documentation](https://docs.docker.com/compose/)

2. **Extend This Setup**
   - Add Redis for caching
   - Add Nginx for reverse proxy
   - Add backup containers
   - Add monitoring (Prometheus/Grafana)

3. **Production Considerations**
   - Use Docker Secrets for passwords
   - Use specific version tags (not `latest`)
   - Set up proper backups
   - Use orchestration (Kubernetes, Docker Swarm)
   - Implement CI/CD pipelines

---

## Glossary

**Container**: Running instance of an image
**Image**: Template for creating containers
**Volume**: Persistent storage for containers
**Network**: Virtual network connecting containers
**Service**: Definition of a container in docker-compose.yml
**Health Check**: Test to verify service is ready
**Multi-stage Build**: Building in multiple steps to reduce image size
**DSN**: Data Source Name (database connection string)
**UTF8MB4**: Character encoding supporting all Unicode characters
**Layer Caching**: Reusing unchanged Docker layers for faster builds

---

## Summary

We successfully containerized your Snippetbox application with:

✅ **MySQL 9.4.0** in a container
✅ **Go application** in a container
✅ **Automatic database initialization**
✅ **Secure user permissions**
✅ **Easy-to-use commands** (Makefile)
✅ **Comprehensive documentation**
✅ **Production-ready setup**

**Result**: Anyone can run your exact environment with one command! 🎉

---

*Questions? Check the other documentation files or the Docker community!*

