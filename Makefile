.PHONY: help build up down logs clean restart mysql-cli

help: ## Show this help message
	@echo 'Usage: make [target]'
	@echo ''
	@echo 'Available targets:'
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-15s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

build: ## Build the Docker images
	docker-compose build

up: ## Start all services
	docker-compose up -d
	@echo "Waiting for services to be ready..."
	@sleep 5
	@echo "Application: http://localhost:4000"
	@echo "MySQL: localhost:3306"

down: ## Stop all services
	docker-compose down

logs: ## View logs from all services
	docker-compose logs -f

logs-app: ## View logs from app service only
	docker-compose logs -f app

logs-mysql: ## View logs from MySQL service only
	docker-compose logs -f mysql

clean: ## Stop services and remove volumes
	docker-compose down -v
	@echo "All containers and volumes removed"

restart: ## Restart all services
	docker-compose restart

restart-app: ## Rebuild and restart only the app service
	docker-compose up -d --build app

mysql-cli: ## Connect to MySQL CLI as web user
	docker-compose exec mysql mysql -u web -ppass snippetbox

mysql-root: ## Connect to MySQL CLI as root
	docker-compose exec mysql mysql -u root -prootpassword

ps: ## Show running containers
	docker-compose ps

dev: ## Run app locally (MySQL in Docker)
	docker-compose up -d mysql
	@echo "MySQL is running. Start your app with: go run ./cmd/web"

