[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# oi

[![Versão](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/oi/releases/tag/v2.0.0)
[![Licença](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#uso)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel%20%7C%20WHM-lightgrey.svg)](#uso)

**CLI para inspeção de revendas, contas clientes e cotas no cPanel/WHM (Owner Info).**

O `oi.sh` consulta revendedores, clientes vinculados, todos os domínios e cotas de disco/inodes/MySQL no cPanel — aceitando **revendedor, usuário cliente ou domínio** e exportando em `table`, `json` ou `csv`.

> **Inspiração Histórica:** Reimplementação em Bash + Python 3.6+ `v2.0.0` inspirada no clássico `oi` (2011, Ryan Beckwith / HostGator), eliminando o módulo XS quebrado `Quota` do Perl.

---

## Uso

```bash
./oi.sh --resellers
./oi.sh percio
./oi.sh perciocastelo.com.br
./oi.sh root -v
./oi.sh root -q -o json
```

---

## Execução Direta

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/oi/main/oi.sh) --resellers
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/oi/main/oi.sh) root -q
```

---

## Autor e Licença

- **Autor:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Página do Projeto:** [perciocastelo.com.br/projetos/br/oi.html](https://perciocastelo.com.br/projetos/br/oi.html)
- **Licença:** [Apache-2.0](LICENSE)
