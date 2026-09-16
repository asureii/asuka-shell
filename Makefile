# Quickshell Evangelion Rice Makefile
# Builds native telemetry & desktop entry helper binaries

CXX ?= g++
CXXFLAGS ?= -O3 -std=c++17 -Wall -Wextra

BIN_DIR = scripts
TARGETS = $(BIN_DIR)/get_applications $(BIN_DIR)/nerv_vitals

.PHONY: all binaries clean lint check install-sddm-intro install-sddm-asuka test-sddm-intro test-sddm-asuka help

all: binaries

binaries: $(TARGETS)

$(BIN_DIR)/get_applications: $(BIN_DIR)/get_applications.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

$(BIN_DIR)/nerv_vitals: $(BIN_DIR)/nerv_vitals.cpp
	$(CXX) $(CXXFLAGS) $< -o $@

clean:
	rm -f $(BIN_DIR)/get_applications $(BIN_DIR)/nerv_vitals

lint:
	@echo "Running qmllint on all QML files..."
	@find . -name "*.qml" -not -path "./.agents/*" -exec qmllint {} +
	@echo "All QML files passed qmllint successfully."

check: lint binaries
	@echo "Validating native helper execution..."
	@$(BIN_DIR)/nerv_vitals > /dev/null && echo "[OK] nerv_vitals functioning"
	@$(BIN_DIR)/get_applications > /dev/null && echo "[OK] get_applications functioning"
	@echo "All components and binaries verified."

install-sddm-intro:
	@bash scripts/install_sddm_intro_theme.sh

install-sddm-asuka:
	@bash scripts/install_sddm_theme.sh

test-sddm-intro:
	sddm-greeter-qt6 --test-mode --theme ./sddm/evangelion-intro

test-sddm-asuka:
	sddm-greeter-qt6 --test-mode --theme ./sddm/evangelion-asuka

help:
	@echo "Available targets:"
	@echo "  make               - Build native C++ helper binaries"
	@echo "  make binaries      - Build get_applications and nerv_vitals"
	@echo "  make clean         - Remove compiled binary executables"
	@echo "  make lint          - Run qmllint on all QML source files"
	@echo "  make check         - Run linting and test native helpers"
	@echo "  make install-sddm-intro - Install Evangelion Intro SDDM theme (requires sudo)"
	@echo "  make install-sddm-asuka - Install Evangelion Asuka SDDM theme (requires sudo)"
	@echo "  make test-sddm-intro    - Test Evangelion Intro SDDM theme in windowed mode"
	@echo "  make test-sddm-asuka    - Test Evangelion Asuka SDDM theme in windowed mode"
