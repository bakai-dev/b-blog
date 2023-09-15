init: docker-down-clear api-clear docker-pull docker-build docker-up api-init
up: docker-up
down: docker-down
restart: down up
check: lint analyze test
lint: api-lint
fix: api-fix
analyze: api-analyze
test: api-test

docker-up:
	docker compose up -d
docker-down:
	docker compose down --remove-orphans
docker-down-clear:
	docker compose down -v --remove-orphans
docker-pull:
	docker compose pull
docker-build:
	docker compose build

## Api init
api-init: api-permissions api-composer-install api-wait-db api-migrations api-fixtures

api-permissions:
	docker run --rm -v ${PWD}/api:/app -w /app alpine chmod 777 -R bootstrap/cache

api-clear:
	docker run --rm -v ${PWD}/api:/app -w /app alpine sh -c 'rm -rf bootstrap/cache/* var/cache/* var/log/* var/test/*'

api-composer-install:
	docker compose run --rm api-php-cli composer install

api-wait-db:
	docker compose run --rm api-php-cli wait-for-it api-postgres:5432 -t 30

api-migrations:
	docker compose run --rm api-php-cli php artisan migrate

api-fixtures:
	docker compose run --rm api-php-cli php artisan db:seed

## Server init
server-init: api-migrations api-fixtures

## Check code PSR12 style
api-lint:
	docker compose run --rm api-php-cli composer cs-check

## Check code error
api-analyze:
	docker compose run --rm api-php-cli composer psalm
	docker compose run --rm api-php-cli composer lint

## Parser
parser: api-parsed-save api-elasticsearch-reindex

api-parsed-save:
	docker compose run --rm api-php-cli php artisan parser:start

## Fix code PSR12 style
api-fix:
	docker compose run --rm api-php-cli composer psalter --issues=MissingReturnType --php-version=8.1

	docker compose run --rm api-php-cli composer cs-fix
	docker compose run --rm api-php-cli composer pint

api-test:
	docker compose run --rm api-php-cli php artisan test

## Build docker
build: build-gateway build-api build-frontend build-parser

build-gateway:
	docker --log-level=debug build --pull --file=gateway/docker/production/nginx/Dockerfile --tag=${REGISTRY}/baa-gateway:${IMAGE_TAG} gateway/docker

build-frontend:
	docker --log-level=debug build --pull --file=frontend/docker/production/nginx/Dockerfile --tag=${REGISTRY}/baa-frontend:${IMAGE_TAG} frontend

build-frontend-node:
	docker --log-level=debug build --pull --file=frontend/docker/production/node/Dockerfile --tag=${REGISTRY}/baa-frontend-node:${IMAGE_TAG} frontend

build-parser:
	docker --log-level=debug build --pull --file=parser/docker/production/node/Dockerfile --tag=${REGISTRY}/baa-parser:${IMAGE_TAG} parser

build-api:
	docker --log-level=debug build --pull --file=api/docker/production/nginx/Dockerfile --tag=${REGISTRY}/baa-api:${IMAGE_TAG} api
	docker --log-level=debug build --pull --file=api/docker/production/php-fpm/Dockerfile --tag=${REGISTRY}/baa-api-php-fpm:${IMAGE_TAG} api
	docker --log-level=debug build --pull --file=api/docker/production/php-cli/Dockerfile --tag=${REGISTRY}/baa-api-php-cli:${IMAGE_TAG} api

try-build:
	REGISTRY=localhost IMAGE_TAG=0 make build

push: push-gateway push-frontend push-parser push-api

push-gateway:
	docker push ${REGISTRY}/baa-gateway:${IMAGE_TAG}

push-frontend:
	docker push ${REGISTRY}/baa-frontend:${IMAGE_TAG}

push-frontend-node:
	docker push ${REGISTRY}/baa-frontend-node:${IMAGE_TAG}

push-parser:
	docker push ${REGISTRY}/baa-parser:${IMAGE_TAG}

push-api:
	docker push ${REGISTRY}/baa-api:${IMAGE_TAG}
	docker push ${REGISTRY}/baa-api-php-fpm:${IMAGE_TAG}
	docker push ${REGISTRY}/baa-api-php-cli:${IMAGE_TAG}

deploy:
	ssh ${HOST} -p ${PORT} 'rm -rf site_${BUILD_NUMBER}'
	ssh ${HOST} -p ${PORT} 'mkdir site_${BUILD_NUMBER}'
	scp -P ${PORT} docker-compose-production.yml ${HOST}:site_${BUILD_NUMBER}/docker-compose.yml
	scp -P ${PORT} Makefile ${HOST}:site_${BUILD_NUMBER}/Makefile
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && echo "COMPOSE_PROJECT_NAME=baa" >> .env'
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && echo "REGISTRY=${REGISTRY}" >> .env'
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && echo "IMAGE_TAG=${IMAGE_TAG}" >> .env'
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && docker compose pull'
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && docker compose up --build --remove-orphans -d'
	ssh ${HOST} -p ${PORT} 'rm -f site'
	ssh ${HOST} -p ${PORT} 'ln -sr site_${BUILD_NUMBER} site'

rollback:
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && docker compose pull'
	ssh ${HOST} -p ${PORT} 'cd site_${BUILD_NUMBER} && docker compose up --build --remove-orphans -d'
	ssh ${HOST} -p ${PORT} 'rm -f site'
	ssh ${HOST} -p ${PORT} 'ln -sr site_${BUILD_NUMBER} site'
