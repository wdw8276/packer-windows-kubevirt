# Shell settings: strict mode, fail fast, delete output on error
SHELL := bash
.ONESHELL:
.SHELLFLAGS := -eu -o pipefail -c
.DELETE_ON_ERROR:
MAKEFLAGS += --warn-undefined-variables
MAKEFLAGS += --no-builtin-rules
MAKEFLAGS += -j$(shell grep -c 'processor' /proc/cpuinfo)

# Build variables: override on the command line, e.g. make WINRM_PASSWORD=secret
HEADLESS ?= true
PACKER_LOG ?= 0
WINRM_PASSWORD ?=
TIMEZONE ?= China Standard Time

ISO_WIN11_23H2_EVAL  := iso/Windows_11_23H2_EnterpriseEval_x64.iso
ISO_WIN11_LTSC_2024  := iso/en-us_windows_11_enterprise_ltsc_2024_x64_dvd_965cfb00.iso
ISO_WIN11_25H2_PRO   := iso/Win11_25H2_English_x64_v2.iso
ISO_WIN10_LTSC_2019  := iso/en_windows_10_enterprise_ltsc_2019_x64_dvd_5795bb03.iso
ISO_WIN10_LTSC_2021  := iso/en-us_windows_10_enterprise_ltsc_2021_x64_dvd_d289cf96.iso
ISO_WIN2022_DATACENTER := iso/en_windows_server_2022x64_dvd_.iso

# Use '>' as recipe prefix instead of tab (requires GNU Make 4.0+)
ifeq ($(origin .RECIPEPREFIX), undefined)
  $(error This Make does not support .RECIPEPREFIX. Please use GNU Make 4.0 or later)
endif
.RECIPEPREFIX = >

# Default target: build all images
all: win11_23h2_eval_kubevirt win11_ltsc_2024_kubevirt win11_25h2_pro_kubevirt win10_ltsc_2019_kubevirt win10_ltsc_2021_kubevirt win2022_datacenter_kubevirt
.PHONY: all

# Validate required build variables
check-vars:
>@if [ -z "$(WINRM_PASSWORD)" ]; then \
>  echo "ERROR: WINRM_PASSWORD is required."; \
>  echo "Usage: make WINRM_PASSWORD=<password> [target]"; \
>  exit 1; \
>fi
.PHONY: check-vars

# Remove build output and generated XML files
clean:
>rm -rf output-*
>rm -f answer_files/11_23h2_eval_kubevirt/Autounattend.xml
>rm -f answer_files/11_ltsc_2024_kubevirt/Autounattend.xml
>rm -f answer_files/11_25h2_pro_kubevirt/Autounattend.xml
>rm -f answer_files/10_ltsc_2019_kubevirt/Autounattend.xml
>rm -f answer_files/10_ltsc_2021_kubevirt/Autounattend.xml
>rm -f answer_files/2022_datacenter_kubevirt/Autounattend.xml
>rm -f answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml
>rm -f answer_files/Firstboot/Firstboot-Autounattend-kubevirt-win2022.xml
.PHONY: clean

# Generate Autounattend XML files from templates, substituting WINRM_PASSWORD and TIMEZONE
answer_files/11_23h2_eval_kubevirt/Autounattend.xml: answer_files/11_23h2_eval_kubevirt/Autounattend.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/11_ltsc_2024_kubevirt/Autounattend.xml: answer_files/11_ltsc_2024_kubevirt/Autounattend.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/11_25h2_pro_kubevirt/Autounattend.xml: answer_files/11_25h2_pro_kubevirt/Autounattend.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/10_ltsc_2019_kubevirt/Autounattend.xml: answer_files/10_ltsc_2019_kubevirt/Autounattend.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/10_ltsc_2021_kubevirt/Autounattend.xml: answer_files/10_ltsc_2021_kubevirt/Autounattend.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/2022_datacenter_kubevirt/Autounattend.xml: answer_files/2022_datacenter_kubevirt/Autounattend.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml: answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

answer_files/Firstboot/Firstboot-Autounattend-kubevirt-win2022.xml: answer_files/Firstboot/Firstboot-Autounattend-kubevirt-win2022.xml.tmpl
>sed 's/{{WINRM_PASSWORD}}/$(WINRM_PASSWORD)/g; s/{{TIMEZONE}}/$(TIMEZONE)/g' $< > $@

# Phony aliases for each image build
win11_23h2_eval_kubevirt: check-vars output-win11_23h2_eval_kubevirt/win11_23h2_eval_kubevirt
.PHONY: win11_23h2_eval_kubevirt
win11_ltsc_2024_kubevirt: check-vars output-windows_11_ltsc_2024_kubevirt/win11_ltsc_2024_kubevirt
.PHONY: win11_ltsc_2024_kubevirt
win11_25h2_pro_kubevirt: check-vars output-windows_11_25h2_pro_kubevirt/win11_25h2_pro_kubevirt
.PHONY: win11_25h2_pro_kubevirt
win10_ltsc_2019_kubevirt: check-vars output-windows_10_ltsc_2019_kubevirt/win10_ltsc_2019_kubevirt
.PHONY: win10_ltsc_2019_kubevirt
win10_ltsc_2021_kubevirt: check-vars output-windows_10_ltsc_2021_kubevirt/win10_ltsc_2021_kubevirt
.PHONY: win10_ltsc_2021_kubevirt
win2022_datacenter_kubevirt: check-vars output-windows_2022_datacenter_kubevirt/win2022_datacenter_kubevirt
.PHONY: win2022_datacenter_kubevirt

# Packer build rules: XML files are generated first, then packer is invoked
output-win11_23h2_eval_kubevirt/win11_23h2_eval_kubevirt: \
  answer_files/11_23h2_eval_kubevirt/Autounattend.xml \
  answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml
>@if [ ! -f "$(ISO_WIN11_23H2_EVAL)" ]; then \
>  echo "ERROR: ISO not found: $(ISO_WIN11_23H2_EVAL)"; \
>  echo "Download Windows 11 23H2 Enterprise Evaluation and place it in the iso/ directory."; \
>  exit 1; \
>fi
>rm -rf output-win11_23h2_eval_kubevirt
>PACKER_LOG=$(PACKER_LOG) packer build -var=headless=$(HEADLESS) -var=winrm_password=$(WINRM_PASSWORD) win11_23h2_eval_kubevirt.pkr.hcl

# LTSC 2024 requires UEFI firmware files copied locally before build
output-windows_11_ltsc_2024_kubevirt/win11_ltsc_2024_kubevirt: \
  answer_files/11_ltsc_2024_kubevirt/Autounattend.xml \
  answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml
>@if [ ! -f "$(ISO_WIN11_LTSC_2024)" ]; then \
>  echo "ERROR: ISO not found: $(ISO_WIN11_LTSC_2024)"; \
>  echo "Download Windows 11 Enterprise LTSC 2024 and place it in the iso/ directory."; \
>  exit 1; \
>fi
>@for f in /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_VARS_4M.ms.fd; do \
>  if [ ! -f "$$f" ]; then \
>    echo "ERROR: OVMF firmware file not found: $$f"; \
>    echo "Install it with: apt install ovmf"; \
>    exit 1; \
>  fi; \
>done
>rm -rf output-windows_11_ltsc_2024_kubevirt
>cp /usr/share/OVMF/OVMF_CODE_4M.ms.fd ./OVMF_CODE.ms.fd
>cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd ./OVMF_VARS.ms.fd
>PACKER_LOG=$(PACKER_LOG) packer build -var=headless=$(HEADLESS) -var=winrm_password=$(WINRM_PASSWORD) win11_ltsc_2024_kubevirt.pkr.hcl

# Win11 25H2 Pro requires UEFI firmware files copied locally before build
output-windows_11_25h2_pro_kubevirt/win11_25h2_pro_kubevirt: \
  answer_files/11_25h2_pro_kubevirt/Autounattend.xml \
  answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml
>@if [ ! -f "$(ISO_WIN11_25H2_PRO)" ]; then \
>  echo "ERROR: ISO not found: $(ISO_WIN11_25H2_PRO)"; \
>  echo "Download Windows 11 25H2 Pro and place it in the iso/ directory."; \
>  exit 1; \
>fi
>@for f in /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_VARS_4M.ms.fd; do \
>  if [ ! -f "$$f" ]; then \
>    echo "ERROR: OVMF firmware file not found: $$f"; \
>    echo "Install it with: apt install ovmf"; \
>    exit 1; \
>  fi; \
>done
>rm -rf output-windows_11_25h2_pro_kubevirt
>cp /usr/share/OVMF/OVMF_CODE_4M.ms.fd ./OVMF_CODE.ms.fd
>cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd ./OVMF_VARS.ms.fd
>PACKER_LOG=$(PACKER_LOG) packer build -var=headless=$(HEADLESS) -var=winrm_password=$(WINRM_PASSWORD) win11_25h2_pro_kubevirt.pkr.hcl

# Win10 LTSC 2019 requires UEFI firmware files copied locally before build
output-windows_10_ltsc_2019_kubevirt/win10_ltsc_2019_kubevirt: \
  answer_files/10_ltsc_2019_kubevirt/Autounattend.xml \
  answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml
>@if [ ! -f "$(ISO_WIN10_LTSC_2019)" ]; then \
>  echo "ERROR: ISO not found: $(ISO_WIN10_LTSC_2019)"; \
>  echo "Download Windows 10 Enterprise LTSC 2019 and place it in the iso/ directory."; \
>  exit 1; \
>fi
>@if [ ! -f "packages/ndp48-x86-x64-allos-enu.exe" ]; then \
>  echo "ERROR: packages/ndp48-x86-x64-allos-enu.exe not found."; \
>  echo "Download from: https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe"; \
>  exit 1; \
>fi
>@for f in /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_VARS_4M.ms.fd; do \
>  if [ ! -f "$$f" ]; then \
>    echo "ERROR: OVMF firmware file not found: $$f"; \
>    echo "Install it with: apt install ovmf"; \
>    exit 1; \
>  fi; \
>done
>rm -rf output-windows_10_ltsc_2019_kubevirt
>cp /usr/share/OVMF/OVMF_CODE_4M.ms.fd ./OVMF_CODE.ms.fd
>cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd ./OVMF_VARS.ms.fd
>PACKER_LOG=$(PACKER_LOG) packer build -var=headless=$(HEADLESS) -var=winrm_password=$(WINRM_PASSWORD) win10_ltsc_2019_kubevirt.pkr.hcl

# Win10 LTSC 2021 requires UEFI firmware files copied locally before build
output-windows_10_ltsc_2021_kubevirt/win10_ltsc_2021_kubevirt: \
  answer_files/10_ltsc_2021_kubevirt/Autounattend.xml \
  answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml
>@if [ ! -f "$(ISO_WIN10_LTSC_2021)" ]; then \
>  echo "ERROR: ISO not found: $(ISO_WIN10_LTSC_2021)"; \
>  echo "Download Windows 10 Enterprise LTSC 2021 and place it in the iso/ directory."; \
>  exit 1; \
>fi
>@if [ ! -f "packages/ndp48-x86-x64-allos-enu.exe" ]; then \
>  echo "ERROR: packages/ndp48-x86-x64-allos-enu.exe not found."; \
>  echo "Download from: https://download.visualstudio.microsoft.com/download/pr/2d6bb6b2-226a-4baa-bdec-798822606ff1/8494001c276a4b96804cde7829c04d7f/ndp48-x86-x64-allos-enu.exe"; \
>  exit 1; \
>fi
>@for f in /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_VARS_4M.ms.fd; do \
>  if [ ! -f "$$f" ]; then \
>    echo "ERROR: OVMF firmware file not found: $$f"; \
>    echo "Install it with: apt install ovmf"; \
>    exit 1; \
>  fi; \
>done
>rm -rf output-windows_10_ltsc_2021_kubevirt
>cp /usr/share/OVMF/OVMF_CODE_4M.ms.fd ./OVMF_CODE.ms.fd
>cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd ./OVMF_VARS.ms.fd
>PACKER_LOG=$(PACKER_LOG) packer build -var=headless=$(HEADLESS) -var=winrm_password=$(WINRM_PASSWORD) win10_ltsc_2021_kubevirt.pkr.hcl

# Win Server 2022 Datacenter requires UEFI firmware files copied locally before build
output-windows_2022_datacenter_kubevirt/win2022_datacenter_kubevirt: \
  answer_files/2022_datacenter_kubevirt/Autounattend.xml \
  answer_files/Firstboot/Firstboot-Autounattend-kubevirt-win2022.xml
>@if [ ! -f "$(ISO_WIN2022_DATACENTER)" ]; then \
>  echo "ERROR: ISO not found: $(ISO_WIN2022_DATACENTER)"; \
>  echo "Download Windows Server 2022 and place it in the iso/ directory."; \
>  exit 1; \
>fi
>@for f in /usr/share/OVMF/OVMF_CODE_4M.ms.fd /usr/share/OVMF/OVMF_VARS_4M.ms.fd; do \
>  if [ ! -f "$$f" ]; then \
>    echo "ERROR: OVMF firmware file not found: $$f"; \
>    echo "Install it with: apt install ovmf"; \
>    exit 1; \
>  fi; \
>done
>rm -rf output-windows_2022_datacenter_kubevirt
>cp /usr/share/OVMF/OVMF_CODE_4M.ms.fd ./OVMF_CODE.ms.fd
>cp /usr/share/OVMF/OVMF_VARS_4M.ms.fd ./OVMF_VARS.ms.fd
>PACKER_LOG=$(PACKER_LOG) packer build -var=headless=$(HEADLESS) -var=winrm_password=$(WINRM_PASSWORD) win2022_datacenter_kubevirt.pkr.hcl
