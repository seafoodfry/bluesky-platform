POETRY := ~/.poetry/bin/poetry
PACKAGE_NAME := scraper_bluesky
IMG := scraper
CONATINER_OPTS := --rm \
	-v ./screenshots:/home/pwuser/src/screenshots \
	-v /tmp/.X11-unix:/tmp/.X11-unix \
	-e DISPLAY=host.docker.internal:0 \
	-e OTEL_SERVICE_NAME="scraper" \
	-e OTEL_EXPORTER_OTLP_ENDPOINT="https://api.honeycomb.io" \
	-e OTEL_EXPORTER_OTLP_PROTOCOL="http/protobuf" \
	-e OTEL_EXPORTER_OTLP_HEADERS="x-honeycomb-team=$$(op read 'op://eng-vault/honeycomb-api-key/password')"
	--ipc=host \
	--user pwuser \
	--security-opt seccomp=seccomp_profile.json \


.DEFAULT_GOAL := help

help:  ## Display this help message
	@awk 'BEGIN {FS = ":.*##"; printf "\nUsage:\n  make \033[36m<target>\033[0m\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)


##@ Local Development.
.PHONY: build-dev
build-dev:  ## Build the dev container image
	docker build -t $(IMG)-dev -f Dockerfile.playwright .

.PHONY: debug
debug: build-dev  ## Run the dev container
	xhost +localhost
	export DISPLAY=host.docker.internal:0
	docker run -it $(CONATINER_OPTS) $(IMG)-dev ipython

.PHONY: build
build:  ## Build the prod container image
	docker build -t $(IMG) .

.PHONY: run
run: build  ## Run the prod container
	docker run -it $(CONATINER_OPTS) $(IMG)


##@ QSource Code Management.
.PHONY: update
update:  ## Update project dependencies
	$(POETRY) update

.PHONY: fmt
fmt:  ## Format code using black and isort
	$(POETRY) run ruff format .
	$(POETRY) run ruff check --fix .

.PHONY: lint
lint:  ## Run code linting using ruff
	$(POETRY) run ruff check .

.PHONY: type-check
type-check:  ## Run static type checking using mypy
	$(POETRY) run mypy $(PACKAGE_NAME) tests

.PHONY: test
test:  ## Run tests with pytest
	$(POETRY) run pytest tests/ -v

.PHONY: security
security:  ## Run security checks
	$(POETRY) run bandit -r $(PACKAGE_NAME)
	$(POETRY) run pip-audit

##@ Quality Assurance.
.PHONY: qa
qa: fmt lint type-check test security  ## Run all quality assurance checks


.PHONY: qa-test
qa-test: lint type-check test security  ## Run all quality assurance checks except for fmt (mean for CI)



##@ Development Cleanup.
.PHONY: clean
clean:  ## RDelete artifact files that were created by running 'make qa'
	rm -f ./screenshots/*
	find . \( -name '*.pyc' -o -name '__pycache__' \) -not -path './.venv/*' -print
	find . \( -name '*.pyc' -o -name '__pycache__' \) -not -path './.venv/*' -print | xargs rm -rf