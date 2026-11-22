#!/usr/bin/env bash
# ==============================================================================
#  oi.sh — cPanel Reseller & Account Ownership Inspector CLI (Owner Info)
# ==============================================================================
#  Author  : Percio Castelo <percio@perciocastelo.com.br>
#  Website : https://perciocastelo.com.br
#  Project : https://perciocastelo.com.br/projetos/en/oi.html
#  Repo    : https://github.com/sr00t3d/oi
#  License : Apache-2.0
#  Version : 2.0.0
#  Notes   : Clean-room Bash + Python 3.6+ reimplementation inspired by `oi`
#            (2011, Ryan Beckwith / HostGator). Eliminates the broken Perl XS
#            `Quota` dependency. Accepts username, reseller, or domain; adds
#            `--resellers`, `-v/--verbose`, `-d/--domains`, `-c/--clients`,
#            `-q/--quotas` (disk, inodes, MySQL DB count/size), suspended/plan
#            metadata, and `table`, `json`, `csv` outputs.
# ==============================================================================

set -uo pipefail
export LC_ALL=C

readonly SCRIPT_NAME="oi.sh"
readonly SCRIPT_VERSION="2.0.0"

# Defaults
TARGET=""
MODE="basic"
LIST_RESELLERS=0
FORMAT="table"
QUIET=0
NO_COLOR=0
TIMESTAMP_UTC="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"

# Colors
RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""

init_colors() {
  if [[ "$NO_COLOR" -eq 0 && -t 1 && -z "${NO_COLOR:-}" && "$FORMAT" == "table" ]]; then
    RED=$'\033[0;31m'
    GREEN=$'\033[0;32m'
    YELLOW=$'\033[0;33m'
    CYAN=$'\033[0;36m'
    BOLD=$'\033[1m'
    RESET=$'\033[0m'
  else
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" RESET=""
  fi
}

show_help() {
  cat <<'USAGE'
oi.sh v2.0.0 — cPanel Reseller & Account Ownership Inspector CLI (Owner Info)

Usage:
  oi.sh <owner|client|domain> [options]
  oi.sh --resellers [options]

Modes:
  (default)             If <target> is a client, prints its owner/reseller.
                        If <target> is a reseller (or root), lists owned accounts + primary domain.
  -v, --verbose, --all  List owned accounts and ALL of their domains (primary + addon/parked/sub)
  -d, --domains         List all domains owned by reseller and its clients
  -c, --clients         List client usernames owned by reseller
  -q, --quotas          Show disk usage, inode usage, MySQL DB count & DB disk usage + totals
  --resellers           List all resellers on the server with account & domain counts

Options:
  -o, --output <fmt>    Output format: table (default), json, csv
  --quiet               Suppress banner header
  --no-color            Disable ANSI colors
  -V, --version         Show version and exit
  -h, --help            Show this help and exit

Examples:
  oi.sh --resellers
  oi.sh root
  oi.sh percio
  oi.sh perciocastelo.com.br
  oi.sh root -v -o json
  oi.sh root -q
USAGE
}

main() {
  command -v python3 >/dev/null 2>&1 || { printf '[ERR] python3 is required.\n' >&2; exit 1; }
  [[ "$#" -eq 0 ]] && { show_help; exit 1; }

  while [[ "$#" -gt 0 ]]; do
    case "$1" in
      -h|--help)               show_help; exit 0 ;;
      -V|--version)            printf '%s %s\n' "$SCRIPT_NAME" "$SCRIPT_VERSION"; exit 0 ;;
      -v|--verbose|-a|--all)   MODE="verbose"; shift ;;
      -d|--domain|--domains)   MODE="domains"; shift ;;
      -c|--client|--clients)   MODE="clients"; shift ;;
      -q|--quota|--quotas)     MODE="quotas"; shift ;;
      --resellers)             LIST_RESELLERS=1; shift ;;
      -o|--output)             FORMAT="${2:-table}"; shift 2 ;;
      --output=*)              FORMAT="${1#*=}"; shift ;;
      --quiet)                 QUIET=1; shift ;;
      --no-color)              NO_COLOR=1; shift ;;
      -*)                      printf '[ERR] Unknown option: %s (use -h for help)\n' "$1" >&2; exit 1 ;;
      *)
        if [[ -z "$TARGET" ]]; then
          TARGET="$1"; shift
        else
          printf '[ERR] Unexpected argument: %s\n' "$1" >&2; exit 1
        fi ;;
    esac
  done

  case "$FORMAT" in
    table|json|csv) ;;
    *) printf '[ERR] Invalid output format: %s (expected table, json, or csv)\n' "$FORMAT" >&2; exit 1 ;;
  esac

  if [[ "$LIST_RESELLERS" -eq 0 && -z "$TARGET" ]]; then
    printf '[ERR] Missing <owner|client|domain> or --resellers. Use -h for help.\n' >&2
    exit 1
  fi

  init_colors

  local py_script
  py_script="$(cat <<'PYEOF'
import csv
import json
import os
import pwd
import re
import shutil
import subprocess
import sys

(
    target, mode, list_resellers_s, fmt, quiet_s,
    script_name, script_version, ts_utc,
    c_red, c_green, c_yellow, c_cyan, c_bold, c_reset
) = sys.argv[1:15]

list_resellers = list_resellers_s == "1"
quiet = quiet_s == "1"

def run_cmd(cmd, timeout=10):
    try:
        p = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, universal_newlines=True, timeout=timeout)
        return p.returncode, p.stdout.strip(), p.stderr.strip()
    except Exception:
        return 1, "", ""

def fmt_bytes(n):
    val = float(n)
    for unit in ("B", "KB", "MB", "GB", "TB"):
        if val < 1024.0 or unit == "TB":
            return f"{val:.2f} {unit}" if unit != "B" else f"{int(val)} B"
        val /= 1024.0

# Load /etc/trueuserowners
owner_of = {}
owned_by = {}
if os.path.isfile("/etc/trueuserowners"):
    with open("/etc/trueuserowners", "r", encoding="utf-8", errors="ignore") as f:
        for ln in f:
            if ":" in ln and not ln.lstrip().startswith("#"):
                u, o = [p.strip() for p in ln.split(":", 1)]
                owner_of[u] = o
                owned_by.setdefault(o, []).append(u)

# Load /etc/userdomains
domain_to_user = {}
user_domains = {}
if os.path.isfile("/etc/userdomains"):
    with open("/etc/userdomains", "r", encoding="utf-8", errors="ignore") as f:
        for ln in f:
            if ":" in ln and not ln.lstrip().startswith("#"):
                d, u = [p.strip() for p in ln.split(":", 1)]
                d = d.lower()
                if u != "nobody":
                    domain_to_user[d] = u
                    user_domains.setdefault(u, []).append(d)

def parse_cpanel_user(u):
    fpath = f"/var/cpanel/users/{u}"
    info = {"user": u, "owner": owner_of.get(u, "root"), "primary_domain": "", "domains": [], "plan": "-", "ip": "-", "suspended": False}
    if os.path.isfile(fpath):
        with open(fpath, "r", encoding="utf-8", errors="ignore") as f:
            for ln in f:
                ln = ln.strip()
                if ln.startswith("OWNER="):
                    info["owner"] = ln.split("=", 1)[1].strip()
                elif ln.startswith("DNS="):
                    info["primary_domain"] = ln.split("=", 1)[1].strip().lower()
                elif re.match(r'^DNS\d+=', ln):
                    d = ln.split("=", 1)[1].strip().lower()
                    if d and d not in info["domains"]:
                        info["domains"].append(d)
                elif ln.startswith("PLAN="):
                    info["plan"] = ln.split("=", 1)[1].strip() or "-"
                elif ln.startswith("IP="):
                    info["ip"] = ln.split("=", 1)[1].strip() or "-"
                elif ln.startswith("SUSPENDED="):
                    info["suspended"] = ln.split("=", 1)[1].strip() == "1"
    if info["primary_domain"] and info["primary_domain"] not in info["domains"]:
        info["domains"].insert(0, info["primary_domain"])
    for d in sorted(user_domains.get(u, [])):
        if d not in info["domains"]:
            info["domains"].append(d)
    if not info["primary_domain"] and info["domains"]:
        info["primary_domain"] = info["domains"][0]
    return info

def get_quota_info(u):
    disk_bytes = 0
    inodes = 0
    if shutil.which("quota"):
        rc, out, _ = run_cmd(["quota", "-u", u, "-w", "--no-wrap"])
        if rc == 0 and out:
            for ln in out.splitlines():
                parts = ln.split()
                if len(parts) >= 6 and parts[0].startswith("/"):
                    try:
                        disk_bytes += int(parts[1].rstrip("*")) * 1024
                        inodes += int(parts[4].rstrip("*"))
                    except ValueError:
                        pass
    if disk_bytes == 0:
        try:
            home = pwd.getpwnam(u).pw_dir
            if os.path.isdir(home) and shutil.which("du"):
                rc, out, _ = run_cmd(["du", "-sb", home], timeout=15)
                if rc == 0 and out:
                    disk_bytes = int(out.split()[0])
        except Exception:
            pass
    db_count = 0
    db_bytes = 0
    p_cnt = f"/var/cpanel/datastore/{u}/mysql-db-count"
    p_use = f"/var/cpanel/datastore/{u}/mysql-disk-usage"
    if os.path.isfile(p_cnt):
        try:
            db_count = int(open(p_cnt).read().strip() or "0")
        except Exception:
            pass
    if os.path.isfile(p_use):
        try:
            db_bytes = int(open(p_use).read().strip() or "0")
        except Exception:
            pass
    return {"disk_bytes": disk_bytes, "inodes": inodes, "db_count": db_count, "db_bytes": db_bytes}

def print_banner(subtitle):
    if fmt == "table" and not quiet:
        print(f"{c_cyan}{'=' * 96}{c_reset}")
        print(f" {c_bold}{script_name} v{script_version}{c_reset} | {subtitle} | {ts_utc}")
        print(f"{c_cyan}{'=' * 96}{c_reset}")

if list_resellers:
    rows = []
    for owner in sorted(owned_by.keys()):
        accts = sorted(owned_by[owner])
        dom_total = sum(len(parse_cpanel_user(a)["domains"]) for a in accts)
        rows.append({"reseller": owner, "accounts": len(accts), "domains": dom_total, "clients": accts})
    if fmt == "json":
        print(json.dumps({"tool": script_name, "version": script_version, "mode": "resellers", "resellers": rows}, indent=2))
    elif fmt == "csv":
        w = csv.writer(sys.stdout)
        w.writerow(["reseller", "accounts", "domains"])
        for r in rows:
            w.writerow([r["reseller"], r["accounts"], r["domains"]])
    else:
        print_banner("cPanel Resellers Overview")
        print(f"{'RESELLER':<20} {'ACCOUNTS':>10} {'DOMAINS':>10}")
        print(f"{'-'*20} {'-'*10} {'-'*10}")
        for r in rows:
            print(f"{c_cyan}{r['reseller']:<20}{c_reset} {r['accounts']:>10} {r['domains']:>10}")
    sys.exit(0)

# Resolve domain -> user if target contains a dot
resolved_from_domain = ""
if "." in target:
    dom_l = target.lower().lstrip("www.")
    if dom_l in domain_to_user:
        resolved_from_domain = dom_l
        target = domain_to_user[dom_l]
    else:
        sys.stderr.write(f"[ERR] Domain not found in /etc/userdomains: {target}\n")
        sys.exit(1)

# Determine whether target is a reseller/owner or a client account
is_owner = target in owned_by
has_user_file = os.path.isfile(f"/var/cpanel/users/{target}")

if not is_owner and not has_user_file:
    sys.stderr.write(f"[ERR] cPanel user/reseller not found: {target}\n")
    sys.exit(1)

if not is_owner:
    uinfo = parse_cpanel_user(target)
    if fmt == "json":
        print(json.dumps({"tool": script_name, "version": script_version, "mode": "lookup", "resolved_from_domain": resolved_from_domain or None, "account": uinfo}, indent=2))
    elif fmt == "csv":
        w = csv.writer(sys.stdout)
        w.writerow(["user", "owner", "primary_domain", "plan", "ip", "suspended"])
        w.writerow([uinfo["user"], uinfo["owner"], uinfo["primary_domain"], uinfo["plan"], uinfo["ip"], int(uinfo["suspended"])])
    else:
        if quiet:
            print(uinfo["owner"])
        else:
            print_banner(f"Account Ownership Lookup: {target}")
            print(f"User           : {c_bold}{uinfo['user']}{c_reset}")
            print(f"Owner/Reseller : {c_green}{uinfo['owner']}{c_reset}")
            print(f"Primary Domain : {uinfo['primary_domain'] or '-'}")
            print(f"Plan / IP      : {uinfo['plan']} | {uinfo['ip']}")
            print(f"Status         : {c_red + 'SUSPENDED' + c_reset if uinfo['suspended'] else c_green + 'ACTIVE' + c_reset}")
            if len(uinfo["domains"]) > 1:
                print(f"All Domains    : {', '.join(uinfo['domains'])}")
    sys.exit(0)

clients = sorted(owned_by.get(target, []))
accounts = [parse_cpanel_user(c) for c in clients]

if mode == "clients":
    if fmt == "json":
        print(json.dumps({"tool": script_name, "version": script_version, "owner": target, "mode": "clients", "clients": clients}, indent=2))
    elif fmt == "csv":
        w = csv.writer(sys.stdout)
        w.writerow(["client"])
        for c in clients:
            w.writerow([c])
    else:
        for c in clients:
            print(c)
elif mode == "domains":
    all_doms = []
    for a in accounts:
        for d in a["domains"]:
            all_doms.append({"domain": d, "user": a["user"]})
    if fmt == "json":
        print(json.dumps({"tool": script_name, "version": script_version, "owner": target, "mode": "domains", "count": len(all_doms), "domains": all_doms}, indent=2))
    elif fmt == "csv":
        w = csv.writer(sys.stdout)
        w.writerow(["domain", "user"])
        for r in all_doms:
            w.writerow([r["domain"], r["user"]])
    else:
        for r in all_doms:
            print(r["domain"])
elif mode == "quotas":
    qrows = []
    tot_disk = tot_inodes = tot_dbc = tot_dbb = 0
    for a in accounts:
        q = get_quota_info(a["user"])
        tot_disk += q["disk_bytes"]
        tot_inodes += q["inodes"]
        tot_dbc += q["db_count"]
        tot_dbb += q["db_bytes"]
        qrows.append({"user": a["user"], "primary_domain": a["primary_domain"], **q})
    if fmt == "json":
        print(json.dumps({
            "tool": script_name, "version": script_version, "owner": target, "mode": "quotas",
            "totals": {"disk_bytes": tot_disk, "inodes": tot_inodes, "db_count": tot_dbc, "db_bytes": tot_dbb},
            "accounts": qrows,
        }, indent=2))
    elif fmt == "csv":
        w = csv.writer(sys.stdout)
        w.writerow(["user", "primary_domain", "disk_bytes", "inodes", "db_count", "db_bytes"])
        for r in qrows:
            w.writerow([r["user"], r["primary_domain"], r["disk_bytes"], r["inodes"], r["db_count"], r["db_bytes"]])
    else:
        print_banner(f"Reseller Quota Summary: {target} ({len(qrows)} accounts)")
        print(f"{'USER':<18} {'DISK USE':>14} {'INODES':>12} {'DB COUNT':>10} {'DB SIZE':>14}  {'PRIMARY DOMAIN'}")
        print(f"{'-'*18} {'-'*14} {'-'*12} {'-'*10} {'-'*14}  {'-'*24}")
        for r in qrows:
            print(f"{c_cyan}{r['user']:<18}{c_reset} {fmt_bytes(r['disk_bytes']):>14} {r['inodes']:>12,} {r['db_count']:>10,} {fmt_bytes(r['db_bytes']):>14}  {r['primary_domain']}")
        print(f"{'-'*96}")
        print(f"{c_bold}{'TOTAL':<18}{c_reset} {fmt_bytes(tot_disk):>14} {tot_inodes:>12,} {tot_dbc:>10,} {fmt_bytes(tot_dbb):>14}")
else:
    if fmt == "json":
        print(json.dumps({"tool": script_name, "version": script_version, "owner": target, "mode": mode, "count": len(accounts), "accounts": accounts}, indent=2))
    elif fmt == "csv":
        w = csv.writer(sys.stdout)
        w.writerow(["user", "primary_domain", "domains_count", "plan", "ip", "suspended"])
        for a in accounts:
            w.writerow([a["user"], a["primary_domain"], len(a["domains"]), a["plan"], a["ip"], int(a["suspended"])])
    else:
        print_banner(f"Reseller Accounts: {target} ({len(accounts)} account(s))")
        print(f"{'USER':<16} {'PRIMARY DOMAIN':<32} {'PLAN':<16} {'IP':<16} {'STATUS'}")
        print(f"{'-'*16} {'-'*32} {'-'*16} {'-'*16} {'-'*10}")
        for a in accounts:
            st = (c_red + "SUSPENDED" + c_reset) if a["suspended"] else (c_green + "ACTIVE" + c_reset)
            print(f"{c_cyan}{a['user']:<16}{c_reset} {a['primary_domain']:<32} {a['plan']:<16} {a['ip']:<16} {st}")
            if mode == "verbose" and len(a["domains"]) > 1:
                for extra in a["domains"][1:]:
                    print(f"  {'':<14} |- {extra}")
PYEOF
)"

  python3 -c "$py_script" \
    "$TARGET" "$MODE" "$LIST_RESELLERS" "$FORMAT" "$QUIET" \
    "$SCRIPT_NAME" "$SCRIPT_VERSION" "$TIMESTAMP_UTC" \
    "$RED" "$GREEN" "$YELLOW" "$CYAN" "$BOLD" "$RESET"
}

main "$@"
