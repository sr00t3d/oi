[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# oi

[![Versión](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/oi/releases/tag/v2.0.0)
[![Licencia](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#uso)
[![Plataforma](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel%20%7C%20WHM-lightgrey.svg)](#uso)

**CLI para inspección de revendedores, cuentas clientes y cuotas en cPanel/WHM (Owner Info).**

`oi.sh` consulta revendedores, clientes, todos los dominios y cuotas de disco/inodes/MySQL aceptando un **revendedor, cliente o dominio** y exportando en `table`, `json` o `csv`.

---

## Uso

```bash
./oi.sh --resellers
./oi.sh percio
./oi.sh root -v
./oi.sh root -q -o json
```

---

## Ejecución Directa

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/oi/main/oi.sh) --resellers
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/oi/main/oi.sh) root -q
```

---

## Autor y Licencia

- **Autor:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Página del Proyecto:** [perciocastelo.com.br/projetos/en/oi.html](https://perciocastelo.com.br/projetos/en/oi.html)
- **Licencia:** [Apache-2.0](LICENSE)
