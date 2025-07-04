include .envrc

# ==================================================================================== # 
# HELPERS
# ==================================================================================== #

## help: print this help message
.PHONY: help
help:
	@echo 'Usage:'
	@sed -n 's/^##//p' ${MAKEFILE_LIST} | column -t -s ':' | sed -e 's/^/ /'

.PHONY: confirm
confirm:
	@echo 'Are you sure? [y/N] \c' && read ans && [ $${ans:-N} = y ]

# ==================================================================================== # 
# DEVELOPMENT
# ==================================================================================== #

# it’s possible to suppress commands from being echoed by prefixing 
# them with the @ character -> @go run ./cmd/api
## run/api: run the cmd/api application
.PHONY: run/api
run/api:
	@go run ./cmd/api -db-dsn=${GREENLIGHT_DB_DSN} -jwt-secret=${JWT_SECRET}

## db/psql: connect to the database using psql
.PHONY: db/psql
db/psql:
	psql ${GREENLIGHT_DB_DSN}

## db/migrations/new name=$1: create a new database migration
.PHONY: db/migrations/new
db/migrations/new:
	@echo 'Creating migration files for ${name}...'
	migrate create -seq -ext=.sql -dir=./migrations ${name}

## db/migrations/up: apply all up database migrations
.PHONY: db/migrations/up
db/migrations/up: confirm
	@echo 'Running up migrations...'
	migrate -path ./migrations -database ${GREENLIGHT_DB_DSN} up

# ==================================================================================== # 
# QUALITY CONTROL
# ==================================================================================== #

## audit: tidy dependencies and format, vet and test all code
.PHONY: audit 
audit: vendor
	@echo 'Formatting code...'
	go fmt ./...
	@echo 'Vetting code...'
	go vet ./...
	staticcheck ./...
	@echo 'Running tests...'
	go test -race -vet=off ./...

## vendor: tidy and vendor dependencies
.PHONY: vendor 
vendor:
	@echo 'Tidying and verifying module dependencies...' 
	go mod tidy
	go mod verify
	@echo 'Vendoring dependencies...'
	go mod vendor

# ==================================================================================== # 
# BUILD
# ==================================================================================== #

# current_time = $(shell date --iso-8601=seconds)
current_time = $(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
git_description = $(shell git describe --always --dirty --tags --long)
linker_flags = '-s -X main.buildTime=${current_time} -X main.version=${git_description}'

# reduce the binary size by around 25% by instructing the Go linker to strip 
# the DWARF debugging information and symbol table from the binary -> -ldflags='-s'
## build/api: build the cmd/api application
.PHONY: build/api
build/api:
	@echo 'Building cmd/api...'
	go build -ldflags=${linker_flags} -o=./bin/api ./cmd/api
	GOOS=linux GOARCH=amd64 go build -ldflags=${linker_flags} -o=./bin/linux_amd64/api ./cmd/api

# ==================================================================================== # 
# PRODUCTION
# ==================================================================================== #

production_host_ip = '35.181.152.191'

## production/connect: connect to the production server
.PHONY: production/connect 
production/connect:
	ssh greenlight@${production_host_ip}

## production/deploy/api: deploy the api to production
# .PHONY: production/deploy/api 
# production/deploy/api:
# 	rsync -rP --delete ./bin/linux_amd64/api ./migrations greenlight@${production_host_ip}:~
# 	ssh -t greenlight@${production_host_ip} 'migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up'

## production/configure/api.service: configure the production systemd api.service file
# .PHONY: production/configure/api.service 
# production/configure/api.service:
# 	rsync -P ./remote/production/api.service greenlight@${production_host_ip}:~ 
# 	ssh -t greenlight@${production_host_ip} '\
# 	sudo mv ~/api.service /etc/systemd/system/ \ 
# 	&& sudo systemctl enable api \
# 	&& sudo systemctl restart api \
# 	'

## production/configure/caddyfile: configure the production Caddyfile
# .PHONY: production/configure/caddyfile 
# production/configure/caddyfile:
# 	rsync -P ./remote/production/Caddyfile greenlight@${production_host_ip}:~ 
# 	ssh -t greenlight@${production_host_ip} '\
# 	sudo mv ~/Caddyfile /etc/caddy/ \
# 	&& sudo systemctl reload caddy \ 
# 	'

## production/deploy/api: deploy the api to production
.PHONY: production/deploy/api 
production/deploy/api:
	rsync -rP --delete ./bin/linux_amd64/api ./migrations greenlight@${production_host_ip}:~
	rsync -P ./remote/production/api.service greenlight@${production_host_ip}:~
	rsync -P ./remote/production/Caddyfile greenlight@${production_host_ip}:~
	ssh -t greenlight@${production_host_ip} '\
	migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up \
	&& sudo mv ~/api.service /etc/systemd/system/ \
	&& sudo systemctl enable api \
	&& sudo systemctl restart api \
	&& sudo mv ~/Caddyfile /etc/caddy/ \
	&& sudo systemctl reload caddy \
	'

# .PHONY: production/deploy/api 
# production/deploy/api:
# 	rsync -P ./bin/linux_amd64/api greenlight@${production_host_ip}:~
# 	rsync -rP --delete ./migrations greenlight@${production_host_ip}:~
# 	rsync -P ./remote/production/api.service greenlight@${production_host_ip}:~
# 	rsync -P ./remote/production/Caddyfile greenlight@${production_host_ip}:~
# 	ssh -t greenlight@${production_host_ip} '\
# 	migrate -path ~/migrations -database $$GREENLIGHT_DB_DSN up \
# 	&& sudo mv ~/api.service /etc/systemd/system/ \
# 	&& sudo systemctl enable api \
# 	&& sudo systemctl restart api \
# 	&& sudo mv ~/Caddyfile /etc/caddy/ \
# 	&& sudo systemctl reload caddy \
# 	'