# Configuração de Workstation

[![YAML Lint & Syntax Validation](https://github.com/aleknots/workstation-setup/actions/workflows/yaml-lint.yml/badge.svg?branch=main)](https://github.com/aleknots/workstation-setup/actions/workflows/yaml-lint.yml)
![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?logo=ansible&logoColor=white)
![WSL2](https://img.shields.io/badge/WSL2-Ubuntu%2026.04-4E1A3D?logo=linux&logoColor=white)
![Ubuntu](https://img.shields.io/badge/Ubuntu-24.04%20%7C%2026.04-E95420?logo=ubuntu&logoColor=white)
![Windows 11](https://img.shields.io/badge/Windows-11%20Pro-0078D4?logo=windows&logoColor=white)
![Licença](https://img.shields.io/badge/License-MIT-green.svg)

Playbooks e scripts automatizados para configuração de workstation no Windows 11 Pro, Ubuntu Desktop e Ubuntu no WSL2, sob medida para o conjunto de ferramentas de DevOps e SRE.

## Subprojetos

| Subprojeto | Caminho | Ponto de Entrada |
|---------|---------|-------------------|
| Windows 11 Pro | [windows-11-pro](./windows-11-pro/README.md) | `windows-11-pro/windows-setup.ps1` |
| Ubuntu 24.04 Desktop | [ubuntu-24.04-desktop](./ubuntu-24.04-desktop/README.md) | `ubuntu-24.04-desktop/ubuntu-desktop-setup.yml` |
| Ubuntu 26.04 Desktop | [ubuntu-26.04-desktop](./ubuntu-26.04-desktop/README.md) | `ubuntu-26.04-desktop/ubuntu-desktop-setup.yml` |
| Ubuntu 26.04 WSL2 | [ubuntu-26.04-wsl2](./ubuntu-26.04-wsl2/README.md) | `ubuntu-26.04-wsl2/ubuntu-wsl-setup.yml` |
| Extras | [extras](./extras/README.md) | Guias de Documentação e Utilitários |

## Notas Importantes

- **Script do Windows 11**: Deve ser executado a partir de um terminal PowerShell elevado (Executar como Administrador).
- **Playbooks do Ubuntu Desktop**: Destinados para instalações de desktop Linux nativas / bare-metal (não WSL2).
- **Playbook do WSL2**: Provisiona o Ubuntu 26.04 LTS executando dentro do WSL2 com integração nativa do Docker Engine.

## Licença

Distribuído sob a [Licença MIT](./LICENSE).
