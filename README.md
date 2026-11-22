[![🇺🇸 English](https://img.shields.io/badge/lang-English-blue.svg)](README.md) [![🇧🇷 Português](https://img.shields.io/badge/lang-Português-green.svg)](README-ptbr.md) [![🇪🇸 Español](https://img.shields.io/badge/lang-Español-yellow.svg)](README-es.md)

# oi

![oi cover](oi-cover.webp)

[![Version](https://img.shields.io/badge/version-2.0.0-blue.svg)](https://github.com/sr00t3d/oi/releases/tag/v2.0.0)
[![License](https://img.shields.io/badge/license-Apache--2.0-green.svg)](LICENSE)
[![Bash](https://img.shields.io/badge/bash-4.0%2B-orange.svg)](#requirements)
[![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20cPanel%20%7C%20WHM-lightgrey.svg)](#requirements)

**cPanel Reseller & Account Ownership Inspector CLI (Owner Info).**

`oi.sh` inspects cPanel/WHM resellers, owned client accounts, all domains, and per-account disk/inode/MySQL quotas — accepting a **reseller, client username, or domain name** and exporting clean `table`, `json`, or `csv` reports.

> **Historical Inspiration:** Clean-room Bash + Python 3.6+ `v2.0.0` reimplementation inspired by `oi` (2011, Ryan Beckwith / HostGator). Eliminates the broken Perl XS `Quota` module dependency, adds domain-to-owner lookup, `--resellers` overview, plan/IP/suspended status, `du` fallback for containers/XFS without quotas, and `table`/`json`/`csv` outputs.

---

## Requirements

- Linux cPanel/WHM server with Bash 4.0+ and Python 3.6+

---

## Usage

```bash
# List all resellers on the server with account & domain counts
./oi.sh --resellers

# Look up the owner/reseller of a client account or domain
./oi.sh percio
./oi.sh perciocastelo.com.br

# List all accounts owned by a reseller (or root)
./oi.sh root

# List owned accounts and ALL of their domains (primary + addon/parked/sub)
./oi.sh root -v

# Show disk usage, inodes, MySQL DB count & DB disk usage with totals
./oi.sh root -q

# Flat list of clients (-c) or domains (-d), or structured JSON/CSV
./oi.sh root -c
./oi.sh root -d
./oi.sh root -q -o json
./oi.sh root -o csv
```

---

## Direct Execution

Run directly without cloning the repository:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/oi/main/oi.sh) --resellers
bash <(curl -fsSL https://raw.githubusercontent.com/sr00t3d/oi/main/oi.sh) root -q
```

---

## Real Output Example

```text
================================================================================================
 oi.sh v2.0.0 | Reseller Quota Summary: root (1 accounts) | 2026-11-22T06:28:00Z
================================================================================================
USER                     DISK USE       INODES   DB COUNT        DB SIZE  PRIMARY DOMAIN
------------------ -------------- ------------ ---------- --------------  ------------------------
percio                   24.50 KB            0          0            0 B  perciocastelo.com.br
------------------------------------------------------------------------------------------------
TOTAL                    24.50 KB            0          0            0 B
```

---

## Author & License

- **Author:** Percio Castelo — [perciocastelo.com.br](https://perciocastelo.com.br)
- **Project Page:** [perciocastelo.com.br/projetos/en/oi.html](https://perciocastelo.com.br/projetos/en/oi.html)
- **License:** [Apache-2.0](LICENSE)
