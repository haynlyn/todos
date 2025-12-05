# Makefile for todos task management tool

# Configuration
PREFIX ?= $(HOME)/.local
SHELL := /bin/sh

# Directories
BIN_DIR := bin
LIB_DIR := lib
SHARE_DIR := share
TEST_DIR := tests

# Installation paths
INSTALL_BIN := $(PREFIX)/bin
INSTALL_LIB := $(PREFIX)/lib/todos
INSTALL_SHARE := $(PREFIX)/share/todos

# Tools
SHELLCHECK := $(shell command -v shellcheck 2>/dev/null)
SHFMT := $(shell command -v shfmt 2>/dev/null)

# Color output
RED := \033[0;31m
GREEN := \033[0;32m
YELLOW := \033[1;33m
BLUE := \033[0;34m
NC := \033[0m

# Default target
.DEFAULT_GOAL := help

.PHONY: help
help: ## Display this help message
	@echo "$(BLUE)todos - Task Management Tool$(NC)"
	@echo ""
	@echo "$(GREEN)Available targets:$(NC)"
	@awk 'BEGIN {FS = ":.*##"; printf ""} \
		/^[a-zA-Z_-]+:.*?##/ { \
			printf "  $(BLUE)%-18s$(NC) %s\n", $$1, $$2 \
		}' $(MAKEFILE_LIST)
	@echo ""
	@echo "$(YELLOW)Installation:$(NC)"
	@echo "  PREFIX=$(PREFIX) (override with PREFIX=/custom/path make install)"

.PHONY: install
install: ## Install todos to PREFIX (default: ~/.local)
	@echo "$(GREEN)Installing todos...$(NC)"
	./install.sh

.PHONY: dev-install
dev-install: ## Install with symlinks for development
	@echo "$(GREEN)Installing todos in development mode...$(NC)"
	@echo "$(YELLOW)Creating directories...$(NC)"
	@mkdir -p "$(INSTALL_BIN)"
	@mkdir -p "$(INSTALL_LIB)"
	@mkdir -p "$(INSTALL_SHARE)"
	@echo "$(YELLOW)Creating symlinks...$(NC)"
	@ln -sf "$(PWD)/$(BIN_DIR)/todos" "$(INSTALL_BIN)/todos"
	@for lib in $(LIB_DIR)/*.sh; do \
		ln -sf "$(PWD)/$$lib" "$(INSTALL_LIB)/$$(basename $$lib)"; \
	done
	@ln -sf "$(PWD)/$(SHARE_DIR)/schema.sql" "$(INSTALL_SHARE)/schema.sql"
	@echo "$(GREEN)Development installation complete!$(NC)"
	@echo "Files are symlinked - changes will take effect immediately"

.PHONY: uninstall
uninstall: ## Uninstall todos
	@echo "$(YELLOW)Uninstalling todos...$(NC)"
	./uninstall.sh

.PHONY: reinstall
reinstall: uninstall install ## Uninstall then install

.PHONY: test
test: ## Run all tests
	@echo "$(GREEN)Running all tests...$(NC)"
	@cd $(TEST_DIR) && ./run_tests.sh

.PHONY: test-unit
test-unit: ## Run only unit tests
	@echo "$(GREEN)Running unit tests...$(NC)"
	@cd $(TEST_DIR) && ./run_tests.sh --unit

.PHONY: test-integration
test-integration: ## Run only integration tests
	@echo "$(GREEN)Running integration tests...$(NC)"
	@cd $(TEST_DIR) && ./run_tests.sh --integration

.PHONY: test-verbose
test-verbose: ## Run all tests with verbose output
	@echo "$(GREEN)Running tests (verbose)...$(NC)"
	@cd $(TEST_DIR) && ./run_tests.sh --verbose

.PHONY: test-watch
test-watch: ## Continuously run tests on file changes (requires entr)
	@if ! command -v entr >/dev/null 2>&1; then \
		echo "$(RED)Error: entr not found$(NC)"; \
		echo "Install with: brew install entr (macOS) or apt-get install entr (Linux)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Watching for changes...$(NC)"
	@find $(LIB_DIR) $(BIN_DIR) $(TEST_DIR) -name '*.sh' | entr -c make test

.PHONY: lint
lint: ## Run shellcheck on all shell scripts
	@if [ -z "$(SHELLCHECK)" ]; then \
		echo "$(RED)Error: shellcheck not found$(NC)"; \
		echo "Install with: brew install shellcheck (macOS) or apt-get install shellcheck (Linux)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Running shellcheck...$(NC)"
	@find $(BIN_DIR) $(LIB_DIR) $(TEST_DIR) -name '*.sh' -o -name 'todos' | while read -r file; do \
		echo "  Checking $$file..."; \
		$(SHELLCHECK) -x "$$file" || exit 1; \
	done
	@echo "$(GREEN)Shellcheck passed!$(NC)"

.PHONY: format
format: ## Format shell scripts with shfmt
	@if [ -z "$(SHFMT)" ]; then \
		echo "$(RED)Error: shfmt not found$(NC)"; \
		echo "Install with: brew install shfmt (macOS) or go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
		exit 1; \
	fi
	@echo "$(GREEN)Formatting shell scripts...$(NC)"
	@find $(BIN_DIR) $(LIB_DIR) $(TEST_DIR) -name '*.sh' -o -name 'todos' | while read -r file; do \
		echo "  Formatting $$file..."; \
		$(SHFMT) -w -i 2 -ci "$$file"; \
	done
	@echo "$(GREEN)Formatting complete!$(NC)"

.PHONY: format-check
format-check: ## Check if shell scripts are properly formatted
	@if [ -z "$(SHFMT)" ]; then \
		echo "$(RED)Error: shfmt not found$(NC)"; \
		echo "Install with: brew install shfmt (macOS) or go install mvdan.cc/sh/v3/cmd/shfmt@latest"; \
		exit 1; \
	fi
	@echo "$(GREEN)Checking shell script formatting...$(NC)"
	@find $(BIN_DIR) $(LIB_DIR) $(TEST_DIR) -name '*.sh' -o -name 'todos' | while read -r file; do \
		$(SHFMT) -d -i 2 -ci "$$file" || exit 1; \
	done
	@echo "$(GREEN)Format check passed!$(NC)"

.PHONY: check
check: lint test ## Run linting and all tests

.PHONY: validate
validate: check ## Alias for check

.PHONY: ci
ci: lint test ## Run CI checks (lint + test)

.PHONY: clean
clean: clean-test ## Remove all generated files

.PHONY: clean-test
clean-test: ## Remove test artifacts
	@echo "$(YELLOW)Cleaning test artifacts...$(NC)"
	@rm -f $(TEST_DIR)/.todos.db
	@rm -f $(TEST_DIR)/.todos.users.db
	@rm -f $(TEST_DIR)/*.db
	@find $(TEST_DIR) -name '.todos*.db' -delete
	@find $(TEST_DIR) -name 'test_output_*' -delete
	@echo "$(GREEN)Test artifacts cleaned!$(NC)"

.PHONY: distclean
distclean: clean ## Full cleanup including installed files
	@echo "$(YELLOW)Performing full cleanup...$(NC)"
	@if [ -f "$(INSTALL_BIN)/todos" ]; then \
		echo "  Removing installed files..."; \
		$(MAKE) uninstall; \
	fi
	@echo "$(GREEN)Full cleanup complete!$(NC)"

.PHONY: docs
docs: ## Validate documentation
	@echo "$(GREEN)Validating documentation...$(NC)"
	@if ! grep -q "## Installation" README.md; then \
		echo "$(RED)Error: README.md missing Installation section$(NC)"; \
		exit 1; \
	fi
	@if ! grep -q "## Quick Start" README.md; then \
		echo "$(RED)Error: README.md missing Quick Start section$(NC)"; \
		exit 1; \
	fi
	@echo "$(GREEN)Documentation validation passed!$(NC)"

.PHONY: version
version: ## Display version information
	@echo "todos version: $$(grep '^VERSION=' install.sh | cut -d= -f2 | tr -d '"' || echo 'unknown')"

.PHONY: release
release: clean check ## Create release tarball
	@echo "$(GREEN)Creating release tarball...$(NC)"
	@VERSION=$$(grep '^VERSION=' install.sh | cut -d= -f2 | tr -d '"' || echo '0.1.0'); \
	RELEASE_NAME="todos-$$VERSION"; \
	mkdir -p "$$RELEASE_NAME"; \
	cp -r $(BIN_DIR) $(LIB_DIR) $(SHARE_DIR) README.md install.sh uninstall.sh "$$RELEASE_NAME/"; \
	tar -czf "$$RELEASE_NAME.tar.gz" "$$RELEASE_NAME"; \
	rm -rf "$$RELEASE_NAME"; \
	echo "$(GREEN)Release created: $$RELEASE_NAME.tar.gz$(NC)"

.PHONY: pre-commit
pre-commit: lint test-unit ## Run pre-commit checks (lint + unit tests)
	@echo "$(GREEN)Pre-commit checks passed!$(NC)"

.PHONY: install-hooks
install-hooks: ## Install git pre-commit hook
	@echo "$(GREEN)Installing git hooks...$(NC)"
	@if [ ! -d .git ]; then \
		echo "$(RED)Error: Not a git repository$(NC)"; \
		exit 1; \
	fi
	@echo '#!/bin/sh' > .git/hooks/pre-commit
	@echo 'make pre-commit' >> .git/hooks/pre-commit
	@chmod +x .git/hooks/pre-commit
	@echo "$(GREEN)Pre-commit hook installed!$(NC)"

.PHONY: requirements
requirements: ## Check for required tools
	@echo "$(GREEN)Checking requirements...$(NC)"
	@command -v sqlite3 >/dev/null 2>&1 && echo "  $(GREEN)✓$(NC) sqlite3" || echo "  $(RED)✗$(NC) sqlite3 (required)"
	@command -v shellcheck >/dev/null 2>&1 && echo "  $(GREEN)✓$(NC) shellcheck" || echo "  $(YELLOW)✗$(NC) shellcheck (optional, for linting)"
	@command -v shfmt >/dev/null 2>&1 && echo "  $(GREEN)✓$(NC) shfmt" || echo "  $(YELLOW)✗$(NC) shfmt (optional, for formatting)"
	@command -v entr >/dev/null 2>&1 && echo "  $(GREEN)✓$(NC) entr" || echo "  $(YELLOW)✗$(NC) entr (optional, for watch mode)"

.PHONY: debug
debug: ## Display Makefile variables for debugging
	@echo "$(BLUE)Makefile Configuration:$(NC)"
	@echo "  PREFIX        = $(PREFIX)"
	@echo "  INSTALL_BIN   = $(INSTALL_BIN)"
	@echo "  INSTALL_LIB   = $(INSTALL_LIB)"
	@echo "  INSTALL_SHARE = $(INSTALL_SHARE)"
	@echo "  SHELLCHECK    = $(SHELLCHECK)"
	@echo "  SHFMT         = $(SHFMT)"
	@echo "  SHELL         = $(SHELL)"
