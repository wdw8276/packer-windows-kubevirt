packer {
  required_plugins {
    qemu = {
      source  = "github.com/hashicorp/qemu"
      version = ">= 1.1.0"
    }

    windows-update = {
      source  = "github.com/rgl/windows-update"
      version = "0.15.0"
    }
  }
}

variable "accelerator" {
  type    = string
  default = "kvm"
}

variable "autounattend" {
  type    = string
  default = "./answer_files/11_ltsc_2024_kubevirt/Autounattend.xml"
}

variable "cpus" {
  type    = string
  default = "4"
}

variable "disk_size" {
  type    = string
  default = "81920"
}

variable "headless" {
  type    = string
  default = "true"
}

variable "iso_checksum" {
  type    = string
  default = "none"
}

variable "iso_url" {
  type    = string
  default = "./iso/en-us_windows_11_enterprise_ltsc_2024_x64_dvd_965cfb00.iso"
}

variable "memory_size" {
  type    = string
  default = "8192"
}

variable "shutdown_command" {
  type    = string
  default = "%WINDIR%/system32/sysprep/sysprep.exe /generalize /oobe /shutdown /unattend:C:/Windows/Temp/Autounattend.xml"
}

variable "vm_name" {
  type    = string
  default = "windows_11_ltsc_2024_kubevirt"
}

variable "winrm_password" {
  type    = string
  default = ""
}

locals {
  timestamp        = formatdate("YYYYMMDDhhmm", timestamp())
  output_directory = "output-${var.vm_name}"
  vm_name          = "${var.vm_name}-${local.timestamp}.qcow2"
  baseargs = [
    ["-cpu", "host"],
    ["-vga", "qxl"],
    ["-boot", "d"],
  ]
}

source "qemu" "win11_ltsc_2024_kubevirt" {
  iso_url      = var.iso_url
  iso_checksum = var.iso_checksum

  boot_wait    = "2s"
  boot_command = ["<enter>"]

  machine_type = "q35"
  accelerator  = var.accelerator
  cpus         = var.cpus
  memory       = var.memory_size
  net_device   = "e1000"

  disk_size      = var.disk_size
  disk_interface = "ide"
  disk_compression = true
  format         = "qcow2"

  output_directory = local.output_directory
  vm_name          = local.vm_name
  headless         = var.headless

  vtpm              = true
  efi_firmware_code = "./OVMF_CODE.ms.fd"
  efi_firmware_vars = "./OVMF_VARS.ms.fd"

  floppy_files = [
    var.autounattend,
    "./scripts/diskpart.txt",
    "./scripts/0-firstlogin-kubevirt.bat",
    "./scripts/1-fixnetwork.ps1",
    "./scripts/50-enable-winrm.ps1",
    "./answer_files/Firstboot/Firstboot-Autounattend-kubevirt.xml",
    "./packages/redhat-cert.cer",
    "./packages/redhat-cert-old.cer",
  ]

  cd_files = ["./packages/*"]
  cd_label = "CDFILES"

  qemuargs = local.baseargs

  communicator   = "winrm"
  winrm_insecure = true
  winrm_password = var.winrm_password
  winrm_timeout  = "1h"
  winrm_use_ssl  = true
  winrm_username = "vagrant"

  shutdown_command = var.shutdown_command
}

build {
  sources = ["source.qemu.win11_ltsc_2024_kubevirt"]

  provisioner "windows-shell" {
    execute_command = "{{ .Vars }} cmd /c C:/Windows/Temp/script.bat"
    remote_path     = "c:/Windows/Temp/script.bat"
    scripts         = ["./scripts/70-install-misc-kubevirt.bat", "./scripts/80-compile-dotnet-assemblies.bat"]
  }

  provisioner "windows-restart" {
    restart_check_command = "powershell -command \"& {Write-Output 'restarted.'}\""
  }

  # Install KubeVirt components: qemu-ga, balloon, CloudbaseInit, viofs, WinFsp
  provisioner "powershell" {
    scripts = ["./scripts/init-kubevirt.ps1"]
  }

  #provisioner "windows-update" {
  #}

  # Without this step, your images will be ~12-15GB
  # With this step, roughly ~8-9GB
  provisioner "windows-shell" {
    execute_command = "{{ .Vars }} cmd /c C:/Windows/Temp/script.bat"
    remote_path     = "c:/Windows/Temp/script.bat"
    scripts         = ["./scripts/85-disable-bitlocker.bat", "./scripts/90-compact.bat"]
  }

  post-processor "shell-local" {
    inline = [
      "cd ${local.output_directory}",
      "virt-sparsify --compress --convert qcow2 ${local.vm_name} ${local.vm_name}.sparse",
      "mv ${local.vm_name}.sparse ${local.vm_name}",
      "md5sum ${local.vm_name} > ${local.vm_name}.md5",
    ]
  }
}
