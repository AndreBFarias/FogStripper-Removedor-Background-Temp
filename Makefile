.PHONY: help install dev test lint format typecheck security clean run docker-test docker-lint docker-all health

PYTHON := python3
VENV := venv
PIP := $(VENV)/bin/pip
PYTEST := $(VENV)/bin/pytest
RUFF := $(VENV)/bin/ruff
MYPY := $(VENV)/bin/mypy

help:
	@echo "Comandos disponiveis:"
	@echo ""
	@echo "  make install      - Instala dependencias"
	@echo "  make dev          - Instala dependencias de desenvolvimento"
	@echo "  make test         - Roda testes"
	@echo "  make lint         - Roda linter (ruff)"
	@echo "  make format       - Formata codigo (ruff)"
	@echo "  make typecheck    - Verifica tipos (mypy)"
	@echo "  make security     - Verifica seguranca (bandit)"
	@echo "  make clean        - Limpa arquivos temporarios"
	@echo "  make run          - Executa aplicacao"
	@echo "  make health       - Roda health check"
	@echo ""
	@echo "Docker:"
	@echo "  make docker-test  - Roda testes no Docker"
	@echo "  make docker-lint  - Roda linter no Docker"
	@echo "  make docker-all   - Roda todos os checks no Docker"

install:
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip
	$(PIP) install -r requirements.txt

dev: install
	$(PIP) install pre-commit bandit
	$(VENV)/bin/pre-commit install

test:
	$(PYTEST) src/tests/ -v --ignore=src/tests/test_workers.py

test-cov:
	$(PYTEST) src/tests/ -v --ignore=src/tests/test_workers.py --cov=src --cov-report=term-missing

test-all:
	$(PYTEST) src/tests/ -v

lint:
	$(RUFF) check src/

format:
	$(RUFF) format src/
	$(RUFF) check --fix src/

typecheck:
	$(MYPY) src/ --ignore-missing-imports

security:
	$(VENV)/bin/bandit -c pyproject.toml -r src/ --exclude src/tests/

check: lint typecheck test
	@echo "Todos os checks passaram!"

clean:
	rm -rf __pycache__
	rm -rf .pytest_cache
	rm -rf .mypy_cache
	rm -rf .ruff_cache
	rm -rf site/
	rm -rf build/
	rm -rf dist/
	rm -rf *.egg-info
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete 2>/dev/null || true

run:
	$(VENV)/bin/python src/main.py

health:
	./scripts/health_check.sh

docker-test:
	docker-compose run --rm test

docker-lint:
	docker-compose run --rm lint

docker-all:
	docker-compose run --rm all-checks
