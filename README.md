# Workstation Setup

[![YAML Lint & Syntax Validation](https://github.com/aleknots/workstation-setup/actions/workflows/yaml-lint.yml/badge.svg?branch=main)](https://github.com/aleknots/workstation-setup/actions/workflows/yaml-lint.yml)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?logo=ansible&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Ubuntu%2026.04-4E1A3D?logo=linux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20%7C%2026.04-E95420?logo=ubuntu&logoColor=white)
![Windows 11](https://img.shields.io/badge/Windows-11%20Pro-0078D4?logo=windows&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green.svg)

Automated workstation configuration playbooks and scripts for Windows 11 Pro, Ubuntu Desktop, and Ubuntu on WSL2 tailored for DevOps and SRE toolsets.

## Subprojects

| Subproject | Path | Entrypoint |
|---------|---------|-------------------|
| Windows 11 Pro | [windows-11-pro](./windows-11-pro/README.md) | `windows-11-pro/windows-setup.ps1` |
| Ubuntu 24.04 Desktop | [ubuntu-24.04-desktop](./ubuntu-24.04-desktop/README.md) | `ubuntu-24.04-desktop/ubuntu-desktop-setup.yml` |
| Ubuntu 26.04 Desktop | [ubuntu-26.04-desktop](./ubuntu-26.04-desktop/README.md) | `ubuntu-26.04-desktop/ubuntu-desktop-setup.yml` |
| Ubuntu 26.04 WSL2 | [ubuntu-26.04-wsl2](./ubuntu-26.04-wsl2/README.md) | `ubuntu-26.04-wsl2/ubuntu-wsl-setup.yml` |
| Extras | [extras](./extras/README.md) | Documentation & Utility Guides |

## Important Notes

- **Windows 11 Script**: Must be executed from an elevated PowerShell terminal (Run as Administrator).
- **Ubuntu Desktop Playbooks**: Intended for bare-metal / native Linux desktop installations (not WSL2).
- **WSL2 Playbook**: Provisions Ubuntu 26.04 LTS running inside WSL2 featuring native Docker Engine integration.

## License

Distributed under the [MIT License](./LICENSE).
