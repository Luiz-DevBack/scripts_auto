#!/usr/bin/env bash
# =============================================================================
#  BigBoss v2 — canivete de sysadmin para rodar do pendrive
#  Debian/Ubuntu (completo) · RHEL/Fedora/Rocky (parcial) · qualquer Linux com bash 4+
#
#  Uso:   bash bigboos.sh                 menu interativo
#         bash bigboos.sh --diag          diagnóstico completo (relatório .txt + .html)
#         bash bigboos.sh --ajuda         todas as opções
#
#  Regras da casa:
#   - Só LÊ por padrão. Tudo que altera o sistema pede confirmação e mostra o que vai fazer.
#   - Nada é instalado para rodar: se uma ferramenta não existe, o teste é pulado ou usa alternativa.
#   - Relatórios ficam ao lado do script (no pendrive), em relatorios/<host>_<data>/.
# =============================================================================

VERSAO="2.0.0"
set -u

# ─── Localização ─────────────────────────────────────────────────────────────
SCRIPT="$(readlink -f "${BASH_SOURCE[0]}" 2>/dev/null || echo "${BASH_SOURCE[0]}")"
BASE="$(cd "$(dirname "$SCRIPT")" && pwd)"
HOST="$(hostname -s 2>/dev/null || hostname 2>/dev/null || echo host)"
CARIMBO="$(date +%Y%m%d_%H%M%S)"
if [[ "$BASE" == /usr/* ]]; then
  RAIZ_REL="${HOME:-/root}/bigboss-relatorios"          # instalado no servidor
else
  RAIZ_REL="$BASE/relatorios"                             # rodando do pendrive
fi
SESSAO=""
LOG=""
UI="texto"
MODO="menu"
PREFIXO_ROOT=()
PODE_ROOT=0
CRITICOS=()
AVISOS=()
TEMPORARIOS=()
FILHOS=()

# ─── Argumentos ──────────────────────────────────────────────────────────────
ACAO=""; FORCAR_TEXTO=0; SEM_COR=0
BK_ORIG=""; BK_DEST=""; BK_MANTER=7
WEB_ACAO=""; WEB_RESP=(); RESP_WEB=""

ajuda() {
  cat <<EOF
BigBoss v$VERSAO — canivete de sysadmin para rodar do pendrive

  bash bigboos.sh                       menu interativo
  bash bigboos.sh --diag                diagnóstico completo (sai 0=ok, 1=avisos, 2=críticos)
  bash bigboos.sh --rede                resumo e testes de rede
  bash bigboos.sh --seguranca           auditoria rápida de segurança
  bash bigboos.sh --limpeza             mostra o que dá para limpar (não apaga nada)
  bash bigboos.sh --snapshot            salva a configuração da máquina no pendrive
  bash bigboos.sh --backup ORIGEM DESTINO [--manter N]
                                        tar.gz com data + SHA256, mantém as N últimas cópias (padrão 7)

  Opções:  --texto (menus sem whiptail) · --sem-cor · --relatorios PASTA · --versao · --ajuda

Relatórios: $RAIZ_REL
EOF
}

while [ $# -gt 0 ]; do
  case "$1" in
    -d|--diag)       ACAO="diag" ;;
    --rede)          ACAO="rede" ;;
    --seguranca)     ACAO="seguranca" ;;
    --limpeza)       ACAO="limpeza" ;;
    --snapshot)      ACAO="snapshot" ;;
    --backup)        ACAO="backup"; BK_ORIG="${2:-}"; BK_DEST="${3:-}"; [ $# -ge 3 ] && shift 2 || shift $(( $# - 1 )) ;;
    --manter)        BK_MANTER="${2:-7}"; shift ;;
    --relatorios)    RAIZ_REL="${2:-$RAIZ_REL}"; shift ;;
    --texto)         FORCAR_TEXTO=1 ;;
    --sem-cor)       SEM_COR=1 ;;
    -v|--versao)     echo "BigBoss v$VERSAO"; exit 0 ;;
    -h|--ajuda|--help) ajuda; exit 0 ;;
    --web)           # usado pelo bigboss-web.py: --web AÇÃO [respostas…] (sempre o último argumento)
                     ACAO="web"; WEB_ACAO="${2:-}"; shift 2 2>/dev/null || shift; WEB_RESP=("$@"); break ;;
    *) echo "Opção desconhecida: $1 (veja --ajuda)" >&2; exit 64 ;;
  esac
  shift
done
if [ "$ACAO" = web ]; then MODO="web"; SEM_COR=1; elif [ -n "$ACAO" ]; then MODO="cli"; fi

# no modo web as respostas das perguntas chegam prontas, na ordem, pelos argumentos
_proxima_resposta() { RESP_WEB="${WEB_RESP[0]:-}"; [ ${#WEB_RESP[@]} -gt 0 ] && WEB_RESP=("${WEB_RESP[@]:1}"); return 0; }

# ─── Cores e saída ───────────────────────────────────────────────────────────
if [ -t 1 ] && [ "$SEM_COR" = 0 ] && [ -z "${NO_COLOR:-}" ]; then
  C_R=$'\e[31m'; C_G=$'\e[32m'; C_Y=$'\e[33m'; C_B=$'\e[34m'; C_C=$'\e[36m'
  C_NEG=$'\e[1m'; C_DIM=$'\e[2m'; C_N=$'\e[0m'
else
  C_R=""; C_G=""; C_Y=""; C_B=""; C_C=""; C_NEG=""; C_DIM=""; C_N=""
fi

tem()   { command -v "$1" >/dev/null 2>&1; }
_log()  { [ -n "$LOG" ] && printf '%s\n' "$1" >> "$LOG"; return 0; }
out()   { printf '%s\n' "$*"; _log "$*"; }
secao() { printf '\n%s━━━ %s ━━━%s\n' "$C_B$C_NEG" "$*" "$C_N"; _log ""; _log "### $*"; }
sub()   { printf '%s▸ %s%s\n' "$C_C" "$*" "$C_N"; _log "--- $*"; }
kv() {   # alinha pela contagem de caracteres (printf %-Ns conta bytes e desalinha acentos)
  local pad=$(( 19 - ${#1} )); [ "$pad" -lt 1 ] && pad=1
  printf '  %s%s%*s%s%s\n' "$C_DIM" "$1" "$pad" "" "$C_N" "$2"
  _log "$(printf '  %s%*s%s' "$1" "$pad" "" "$2")"
}
ok()    { printf '  %s✔%s %s\n' "$C_G" "$C_N" "$*"; _log "  [OK] $*"; }
info()  { printf '  %s•%s %s\n' "$C_B" "$C_N" "$*"; _log "  [INFO] $*"; }
aviso() { printf '  %s▲ %s%s\n' "$C_Y" "$*" "$C_N"; _log "  [AVISO] $*"; AVISOS+=("$*"); }
crit()  { printf '  %s✖ %s%s\n' "$C_R$C_NEG" "$*" "$C_N"; _log "  [CRÍTICO] $*"; CRITICOS+=("$*"); }

# stdin → tela e relatório, linha a linha (mostra ao vivo comandos demorados)
bloco() {
  local l
  while IFS= read -r l || [ -n "$l" ]; do
    printf '    %s\n' "$l"
    [ -n "$LOG" ] && printf '    %s\n' "$l" >> "$LOG"
  done
  return 0
}

limitar() { local s=$1; shift; if tem timeout; then timeout "$s" "$@"; else "$@"; fi; }

# rodar "Título" comando args…   (sem root)
rodar() {
  local t=$1; shift
  [ -n "$t" ] && sub "$t"
  tem "$1" || { info "comando '$1' não disponível — pulado"; return 127; }
  limitar 120 "$@" 2>&1 | bloco
  return "${PIPESTATUS[0]}"
}

# rodar_root "Título" comando args…   (com root, se der)
rodar_root() {
  local t=$1; shift
  [ -n "$t" ] && sub "$t"
  [ "$PODE_ROOT" = 1 ] || { info "precisa de root — pulado"; return 126; }
  tem "$1" || { info "comando '$1' não disponível — pulado"; return 127; }
  limitar 1800 ${PREFIXO_ROOT[@]+"${PREFIXO_ROOT[@]}"} "$@" 2>&1 | bloco
  return "${PIPESTATUS[0]}"
}

# R comando args…   (captura com root; falha calada se não der)
R() {
  [ "$PODE_ROOT" = 1 ] || return 126
  ${PREFIXO_ROOT[@]+"${PREFIXO_ROOT[@]}"} "$@"
}

numero() { [[ "${1:-}" =~ ^[0-9]+$ ]]; }
mb()     { awk -v k="${1:-0}" 'BEGIN{ if (k>=1048576) printf "%.1f GB", k/1048576; else if (k>=1024) printf "%.0f MB", k/1024; else printf "%d KB", k }'; }

limpar_ao_sair() {
  local p f
  for p in ${FILHOS[@]+"${FILHOS[@]}"}; do kill "$p" 2>/dev/null; done
  for f in ${TEMPORARIOS[@]+"${TEMPORARIOS[@]}"}; do rm -f "$f" 2>/dev/null; done
}
trap limpar_ao_sair EXIT
trap 'echo; echo "Interrompido."; exit 130' INT TERM

# ─── Interface (whiptail se houver, senão texto) ─────────────────────────────
if [ "$FORCAR_TEXTO" = 0 ] && [ "$MODO" = menu ] && tem whiptail && [ -t 0 ] && [ -t 1 ]; then UI="whiptail"; fi

_tam() {
  local l c
  l=$(tput lines 2>/dev/null || echo 24); c=$(tput cols 2>/dev/null || echo 80)
  ALT=$(( l - 4 )); LARG=$(( c - 6 ))
  [ "$ALT" -gt 30 ] && ALT=30; [ "$ALT" -lt 12 ] && ALT=12
  [ "$LARG" -gt 90 ] && LARG=90; [ "$LARG" -lt 60 ] && LARG=60
}

# menu "Título" "texto" tag descrição …   → ESCOLHA
menu() {
  local titulo=$1 texto=$2; shift 2
  ESCOLHA=""
  if [ "$MODO" = web ]; then _proxima_resposta; ESCOLHA=${RESP_WEB:-$1}; return 0; fi
  if [ "$UI" = whiptail ]; then
    _tam
    local n=$(( $# / 2 )) h
    h=$(( n + 9 )); [ "$h" -gt "$ALT" ] && h=$ALT
    ESCOLHA=$(whiptail --title " $titulo " --backtitle "BigBoss v$VERSAO  ·  $HOST  ·  relatórios: $RAIZ_REL" \
      --ok-button "Escolher" --cancel-button "Voltar" \
      --menu "$texto" "$h" "$LARG" $(( h - 8 )) "$@" 3>&1 1>&2 2>&3) || return 1
    return 0
  fi
  printf '\n%s%s%s\n' "$C_NEG" "$titulo" "$C_N"
  [ -n "$texto" ] && printf '%s%s%s\n' "$C_DIM" "$texto" "$C_N"
  local -a tags=()
  while [ $# -gt 0 ]; do printf '  %s%3s%s  %s\n' "$C_C" "$1" "$C_N" "$2"; tags+=("$1"); shift 2; done
  local t
  while :; do
    read -r -p "› Opção: " ESCOLHA || return 1
    [ -z "$ESCOLHA" ] && return 1
    for t in "${tags[@]}"; do [ "${t,,}" = "${ESCOLHA,,}" ] && { ESCOLHA=$t; return 0; }; done
    echo "  Opção inválida."
  done
}

confirmar() {
  if [ "$MODO" = cli ]; then return 1; fi
  if [ "$MODO" = web ]; then return 0; fi   # a página já pediu confirmação antes de disparar
  local msg; msg=$(printf '%b' "$1")
  if [ "$UI" = whiptail ]; then
    _tam; whiptail --title " Confirmar " --yes-button "Sim" --no-button "Não" --yesno "$msg" 14 "$LARG"
    return $?
  fi
  local r; printf '%s\n' "$msg"; read -r -p "Confirma? [s/N] " r || return 1
  [[ "$r" =~ ^[sSyY] ]]
}

# perguntar "texto" "padrão" → RESPOSTA
perguntar() {
  RESPOSTA=""
  if [ "$MODO" = web ]; then _proxima_resposta; RESPOSTA=${RESP_WEB:-${2:-}}; return 0; fi
  if [ "$UI" = whiptail ]; then
    _tam
    RESPOSTA=$(whiptail --title " BigBoss " --ok-button "OK" --cancel-button "Cancelar" \
      --inputbox "$1" 11 "$LARG" "${2:-}" 3>&1 1>&2 2>&3) || return 1
    return 0
  fi
  local r; read -r -p "$1 [${2:-}]: " r || return 1
  RESPOSTA="${r:-${2:-}}"
}

# marcar "Título" "texto" tag descrição ON|OFF … → MARCADOS[]
marcar() {
  local titulo=$1 texto=$2; shift 2
  MARCADOS=()
  if [ "$MODO" = web ]; then   # resposta = itens separados por vírgula; só vale o que existe na lista
    _proxima_resposta
    local pedido=",$RESP_WEB,"
    while [ $# -gt 0 ]; do [[ "$pedido" == *",$1,"* ]] && MARCADOS+=("$1"); shift 3; done
    return 0
  fi
  if [ "$UI" = whiptail ]; then
    _tam
    local n=$(( $# / 3 )) h res
    h=$(( n + 9 )); [ "$h" -gt "$ALT" ] && h=$ALT
    res=$(whiptail --title " $titulo " --separate-output --ok-button "OK" --cancel-button "Voltar" \
      --checklist "$texto (espaço marca)" "$h" "$LARG" $(( h - 8 )) "$@" 3>&1 1>&2 2>&3) || return 1
    [ -n "$res" ] && mapfile -t MARCADOS <<< "$res"
    return 0
  fi
  printf '\n%s%s%s\n%s\n' "$C_NEG" "$titulo" "$C_N" "$texto"
  local r pad
  while [ $# -gt 0 ]; do
    pad="s/N"; [ "$3" = ON ] && pad="S/n"
    read -r -p "  $2 [$pad] " r || return 1
    if [ -z "$r" ]; then [ "$3" = ON ] && MARCADOS+=("$1"); elif [[ "$r" =~ ^[sSyY] ]]; then MARCADOS+=("$1"); fi
    shift 3
  done
}

pausa() {
  [ "$MODO" = menu ] || return 0
  echo; read -r -p "  ⏎  Enter para voltar ao menu… " _ || true
}

# ─── Root / sudo ─────────────────────────────────────────────────────────────
garantir_root() {   # garantir_root "motivo"
  [ "$PODE_ROOT" = 1 ] && return 0
  if [ "$(id -u)" -eq 0 ]; then PODE_ROOT=1; PREFIXO_ROOT=(); return 0; fi
  tem sudo || return 1
  if sudo -n true 2>/dev/null; then PODE_ROOT=1; PREFIXO_ROOT=(sudo -n); return 0; fi
  [ "$MODO" != menu ] && return 1
  echo
  printf '  %s%s precisa de root para ficar completo.%s\n' "$C_Y" "${1:-Isto}" "$C_N"
  if sudo -v; then PODE_ROOT=1; PREFIXO_ROOT=(sudo -n); return 0; fi
  info "seguindo sem root: partes protegidas serão puladas"
  return 1
}

# ─── Sistema ─────────────────────────────────────────────────────────────────
DISTRO="Linux"
if [ -r /etc/os-release ]; then
  # shellcheck disable=SC1091
  DISTRO="$(. /etc/os-release; echo "${PRETTY_NAME:-Linux}")"
fi
PKG=""
if tem apt-get; then PKG=apt; elif tem dnf; then PKG=dnf; elif tem yum; then PKG=yum; elif tem zypper; then PKG=zypper; elif tem apk; then PKG=apk; fi
NCPU=$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo 2>/dev/null || echo 1)

temperatura_max() {   # °C inteiro, ou vazio
  local t
  t=$(cat /sys/class/thermal/thermal_zone*/temp 2>/dev/null | sort -n | tail -1)
  if [ -z "$t" ] && tem sensors; then
    t=$(sensors 2>/dev/null | grep -oE '\+[0-9]+\.[0-9]°C' | tr -d '+°C' | sort -n | tail -1 | cut -d. -f1)
    [ -n "$t" ] && t=$(( t * 1000 ))
  fi
  [ -n "$t" ] && numero "$t" && echo $(( t / 1000 ))
}

# ─── Relatórios ──────────────────────────────────────────────────────────────
preparar_sessao() {
  [ -n "$SESSAO" ] && return 0
  SESSAO="$RAIZ_REL/${HOST}_${CARIMBO}"
  if ! mkdir -p "$SESSAO" 2>/dev/null || ! [ -w "$SESSAO" ]; then
    SESSAO="/tmp/bigboss-relatorios/${HOST}_${CARIMBO}"
    mkdir -p "$SESSAO" || { SESSAO=""; return 1; }
    printf '  %sPasta do pendrive sem escrita — relatórios em %s%s\n' "$C_Y" "$SESSAO" "$C_N"
  fi
}

abrir_relatorio() {   # abrir_relatorio nome
  CRITICOS=(); AVISOS=()
  if preparar_sessao; then LOG="$SESSAO/$1.txt"; : > "$LOG"; else LOG=""; fi
}

resumo_tela() {
  local n_c=${#CRITICOS[@]} n_a=${#AVISOS[@]} m
  echo
  if [ "$n_c" -gt 0 ]; then
    printf '%s██ RESULTADO: %d crítico(s), %d aviso(s) ██%s\n' "$C_R$C_NEG" "$n_c" "$n_a" "$C_N"
  elif [ "$n_a" -gt 0 ]; then
    printf '%s██ RESULTADO: %d aviso(s), nenhum crítico ██%s\n' "$C_Y$C_NEG" "$n_a" "$C_N"
  else
    printf '%s██ RESULTADO: tudo OK ██%s\n' "$C_G$C_NEG" "$C_N"
  fi
  for m in ${CRITICOS[@]+"${CRITICOS[@]}"}; do printf '   %s✖%s %s\n' "$C_R" "$C_N" "$m"; done
  for m in ${AVISOS[@]+"${AVISOS[@]}"};   do printf '   %s▲%s %s\n' "$C_Y" "$C_N" "$m"; done
}

_cabecalho_txt() {
  local raiz="não"; [ "$PODE_ROOT" = 1 ] && raiz="sim"
  local m
  echo "════════════════════════════════════════════════════════════════════"
  echo " BIGBOSS v$VERSAO — $1"
  echo " Host: $HOST ($DISTRO)"
  echo " Data: $(date '+%d/%m/%Y %H:%M:%S %Z')   Usuário: $(id -un) (root: $raiz)"
  echo "════════════════════════════════════════════════════════════════════"
  echo "RESUMO: ${#CRITICOS[@]} crítico(s) · ${#AVISOS[@]} aviso(s)"
  for m in ${CRITICOS[@]+"${CRITICOS[@]}"}; do echo "  ✖ $m"; done
  for m in ${AVISOS[@]+"${AVISOS[@]}"};   do echo "  ▲ $m"; done
}

_html() {   # _html corpo.txt "Título"
  local titulo=$2 cor="ok" rotulo="Tudo OK" m itens="" raiz="não"
  [ "$PODE_ROOT" = 1 ] && raiz="sim"
  if [ ${#CRITICOS[@]} -gt 0 ]; then cor="crit"; rotulo="${#CRITICOS[@]} crítico(s) · ${#AVISOS[@]} aviso(s)"
  elif [ ${#AVISOS[@]} -gt 0 ]; then cor="aviso"; rotulo="${#AVISOS[@]} aviso(s)"; fi
  _esc() { sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'; }
  for m in ${CRITICOS[@]+"${CRITICOS[@]}"}; do itens+="<li class=\"crit\">$(printf '%s' "$m" | _esc)</li>"; done
  for m in ${AVISOS[@]+"${AVISOS[@]}"};   do itens+="<li class=\"aviso\">$(printf '%s' "$m" | _esc)</li>"; done
  cat <<EOF
<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>BigBoss · $HOST · $titulo</title>
<style>
:root{--bg:#f6f7f9;--card:#fff;--tx:#1d2330;--mut:#667085;--bd:#e3e6ea;--ok:#1f9d55;--av:#c98a00;--cr:#d64545;--ac:#2f6fde}
@media (prefers-color-scheme:dark){:root{--bg:#0f1218;--card:#171b23;--tx:#e6e9ef;--mut:#98a2b3;--bd:#2a303b;--ac:#6ea0ff}}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.5 system-ui,-apple-system,"Segoe UI",sans-serif}
main{max-width:1000px;margin:0 auto;padding:24px 16px 64px}
header{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:20px 22px;margin-bottom:18px}
h1{margin:0 0 4px;font-size:22px}.meta{color:var(--mut);font-size:13px}
.selo{display:inline-block;margin-top:12px;padding:6px 14px;border-radius:999px;font-weight:700;color:#fff}
.selo.ok{background:var(--ok)}.selo.aviso{background:var(--av)}.selo.crit{background:var(--cr)}
ul.res{margin:12px 0 0;padding-left:20px}ul.res li.crit{color:var(--cr)}ul.res li.aviso{color:var(--av)}
section{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:6px 22px 16px;margin-bottom:14px}
h2{font-size:16px;letter-spacing:.04em;color:var(--ac);border-bottom:1px solid var(--bd);padding-bottom:8px}
h3{font-size:14px;margin:16px 0 6px}
pre{background:var(--bg);border:1px solid var(--bd);border-radius:8px;padding:10px 12px;overflow-x:auto;font:12.5px/1.45 ui-monospace,Menlo,Consolas,monospace;margin:6px 0}
.st{padding:4px 10px;border-radius:6px;margin:4px 0;font-size:14px}
.st.ok{border-left:4px solid var(--ok)}.st.aviso{border-left:4px solid var(--av);background:rgba(201,138,0,.08)}
.st.crit{border-left:4px solid var(--cr);background:rgba(214,69,69,.10);font-weight:600}.st.info{border-left:4px solid var(--bd);color:var(--mut)}
.kv{font:13px ui-monospace,Menlo,Consolas,monospace;white-space:pre-wrap;margin:2px 0}
footer{color:var(--mut);font-size:12px;text-align:center;margin-top:24px}
</style></head><body><main>
<header><h1>$(printf '%s' "$titulo" | _esc) — $HOST</h1>
<div class="meta">$(printf '%s' "$DISTRO" | _esc) · $(date '+%d/%m/%Y %H:%M') · usuário $(id -un) · root: $raiz</div>
<span class="selo $cor">$rotulo</span>
<ul class="res">$itens</ul></header>
EOF
  awk '
    function esc(s){ gsub(/&/,"\\&amp;",s); gsub(/</,"\\&lt;",s); gsub(/>/,"\\&gt;",s); return s }
    function fpre(){ if(pre){ print "</pre>"; pre=0 } }
    function fsec(){ fpre(); if(sec){ print "</section>"; sec=0 } }
    /^### /        { fsec(); t=$0; sub(/^### /,"",t); print "<section><h2>" esc(t) "</h2>"; sec=1; next }
    /^--- /        { fpre(); t=$0; sub(/^--- /,"",t); print "<h3>" esc(t) "</h3>"; next }
    /^  \[OK\] /   { fpre(); t=$0; sub(/^  \[OK\] /,"",t);   print "<div class=\"st ok\">✔ " esc(t) "</div>"; next }
    /^  \[AVISO\] /{ fpre(); t=$0; sub(/^  \[AVISO\] /,"",t); print "<div class=\"st aviso\">▲ " esc(t) "</div>"; next }
    /^  \[CR/      { fpre(); t=$0; sub(/^  \[[^]]*\] /,"",t); print "<div class=\"st crit\">✖ " esc(t) "</div>"; next }
    /^  \[INFO\] / { fpre(); t=$0; sub(/^  \[INFO\] /,"",t);  print "<div class=\"st info\">" esc(t) "</div>"; next }
    /^    /        { if(!pre){ print "<pre>"; pre=1 } t=$0; sub(/^    /,"",t); print esc(t); next }
    /^  /          { fpre(); print "<div class=\"kv\">" esc($0) "</div>"; next }
    /^$/           { next }
    { fpre(); print "<p>" esc($0) "</p>" }
    END { fsec() }
  ' "$1"
  echo "<footer>Gerado pelo BigBoss v$VERSAO</footer></main></body></html>"
}

fechar_relatorio() {   # fechar_relatorio "Título"
  [ -n "$LOG" ] && [ -f "$LOG" ] || { resumo_tela; return 0; }
  local corpo="$LOG.corpo" html="${LOG%.txt}.html"
  mv "$LOG" "$corpo"
  _html "$corpo" "$1" > "$html" 2>/dev/null
  { _cabecalho_txt "$1"; cat "$corpo"; } > "$LOG"
  rm -f "$corpo"
  resumo_tela
  printf '\n  %s📄 Relatório:%s %s\n               %s\n' "$C_G" "$C_N" "$LOG" "$html"
  [ "$MODO" = web ] && printf '@@RELATORIO %s\n' "$html"
  LOG=""
}

# ═════════════════════════════════════════════════════════════════════════════
#  DIAGNÓSTICO
# ═════════════════════════════════════════════════════════════════════════════
diag_sistema() {
  secao "SISTEMA"
  kv "Host" "$(hostname -f 2>/dev/null || hostname)"
  kv "Sistema" "$DISTRO"
  kv "Kernel" "$(uname -r) ($(uname -m))"
  local virt="físico/desconhecido"
  tem systemd-detect-virt && virt=$(systemd-detect-virt 2>/dev/null || echo "nenhuma (físico)")
  kv "Virtualização" "$virt"
  local dias; dias=$(awk '{print int($1/86400)}' /proc/uptime 2>/dev/null)
  kv "Ligado há" "$(uptime -p 2>/dev/null | sed 's/^up //') ($dias dias)"
  kv "Data/hora" "$(date '+%d/%m/%Y %H:%M:%S %Z')"
  if tem timedatectl; then
    local ntp; ntp=$(timedatectl show -p NTPSynchronized --value 2>/dev/null)
    case "$ntp" in
      yes) ok "relógio sincronizado (NTP)" ;;
      no)  aviso "relógio NÃO sincronizado por NTP — logs e certificados podem falhar" ;;
    esac
  fi
  numero "${dias:-}" && [ "$dias" -gt 180 ] && aviso "ligado há $dias dias sem reiniciar (kernel pode estar sem correções)"
  [ -f /var/run/reboot-required ] && aviso "o sistema pede reinicialização ($(head -1 /var/run/reboot-required 2>/dev/null))"
  return 0
}

diag_hardware() {
  secao "HARDWARE"
  local modelo
  modelo=$(awk -F: '/model name/{sub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo 2>/dev/null)
  kv "CPU" "${modelo:-?} — $NCPU núcleo(s)"
  kv "Memória" "$(awk '/MemTotal/{printf "%.1f GB", $2/1048576}' /proc/meminfo)"
  if [ "$PODE_ROOT" = 1 ] && tem dmidecode; then
    kv "Fabricante" "$(R dmidecode -s system-manufacturer 2>/dev/null | head -1)"
    kv "Modelo" "$(R dmidecode -s system-product-name 2>/dev/null | head -1)"
    kv "Nº de série" "$(R dmidecode -s system-serial-number 2>/dev/null | head -1)"
    kv "BIOS" "$(R dmidecode -s bios-version 2>/dev/null | head -1) ($(R dmidecode -s bios-release-date 2>/dev/null | head -1))"
  elif [ -r /sys/class/dmi/id/product_name ]; then
    kv "Fabricante" "$(cat /sys/class/dmi/id/sys_vendor 2>/dev/null)"
    kv "Modelo" "$(cat /sys/class/dmi/id/product_name 2>/dev/null)"
  fi
  rodar "Discos" lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,MODEL -e7
  local t; t=$(temperatura_max)
  if [ -n "$t" ]; then
    if   [ "$t" -ge 85 ]; then crit "temperatura máxima ${t}°C (muito alta)"
    elif [ "$t" -ge 75 ]; then aviso "temperatura máxima ${t}°C (alta)"
    else ok "temperatura máxima ${t}°C"; fi
  else
    info "sem sensor de temperatura (normal em VM)"
  fi
  local bat
  for bat in /sys/class/power_supply/BAT*; do
    [ -d "$bat" ] || continue
    local cap full design saude
    cap=$(cat "$bat/capacity" 2>/dev/null)
    full=$(cat "$bat/energy_full" 2>/dev/null || cat "$bat/charge_full" 2>/dev/null)
    design=$(cat "$bat/energy_full_design" 2>/dev/null || cat "$bat/charge_full_design" 2>/dev/null)
    if numero "${full:-}" && numero "${design:-}" && [ "$design" -gt 0 ]; then
      saude=$(( full * 100 / design ))
      kv "Bateria $(basename "$bat")" "carga ${cap:-?}% · saúde ${saude}% da original"
      [ "$saude" -lt 60 ] && aviso "bateria com ${saude}% da capacidade original — considere trocar"
    fi
  done
  diag_smart
}

diag_smart() {
  if ! tem smartctl; then info "smartctl ausente — saúde SMART não verificada (pacote smartmontools)"; return 0; fi
  if [ "$PODE_ROOT" != 1 ]; then info "SMART precisa de root — pulado"; return 0; fi
  local d res
  for d in $(lsblk -dno NAME,TYPE 2>/dev/null | awk '$2=="disk"{print $1}'); do
    res=$(R smartctl -H "/dev/$d" 2>&1)
    if   grep -qiE 'PASSED|: OK' <<< "$res"; then ok "SMART /dev/$d: saudável"
    elif grep -qi 'FAILED' <<< "$res"; then crit "SMART /dev/$d: FALHANDO — troque o disco e faça backup já"
    else info "SMART /dev/$d: sem suporte (VM, RAID ou USB)"; fi
    local realoc pend
    realoc=$(R smartctl -A "/dev/$d" 2>/dev/null | awk '/Reallocated_Sector_Ct/{print $10}')
    pend=$(R smartctl -A "/dev/$d" 2>/dev/null | awk '/Current_Pending_Sector/{print $10}')
    numero "${realoc:-}" && [ "$realoc" -gt 0 ] && aviso "/dev/$d: $realoc setores realocados"
    numero "${pend:-}" && [ "$pend" -gt 0 ] && crit "/dev/$d: $pend setores pendentes (disco degradando)"
  done
  return 0
}

diag_carga() {
  secao "CPU E PROCESSOS"
  local l1 l5 l15
  read -r l1 l5 l15 _ < /proc/loadavg
  kv "Carga (1/5/15 min)" "$l1 / $l5 / $l15  (núcleos: $NCPU)"
  if   awk -v l="$l5" -v n="$NCPU" 'BEGIN{exit !(l>2*n)}'; then crit "carga média de 5 min ($l5) acima do dobro dos núcleos"
  elif awk -v l="$l5" -v n="$NCPU" 'BEGIN{exit !(l>n)}';   then aviso "carga média de 5 min ($l5) acima do nº de núcleos"
  else ok "carga normal"; fi
  sub "Top 8 por CPU"
  ps -eo pid,user,%cpu,%mem,etime,comm --sort=-%cpu 2>/dev/null | awk -v eu="$$" 'NR==1 || ($6!="ps" && $1!=eu)' | head -9 | bloco
  sub "Top 8 por memória"
  ps -eo pid,user,%mem,rss,comm --sort=-%mem 2>/dev/null | head -9 | bloco
  local z; z=$(ps -eo stat= 2>/dev/null | grep -c '^Z')
  [ "${z:-0}" -gt 0 ] && aviso "$z processo(s) zumbi"
  return 0
}

diag_memoria() {
  secao "MEMÓRIA"
  local tot disp stot slivre pct spct
  tot=$(awk '/^MemTotal:/{print $2}' /proc/meminfo); disp=$(awk '/^MemAvailable:/{print $2}' /proc/meminfo)
  stot=$(awk '/^SwapTotal:/{print $2}' /proc/meminfo); slivre=$(awk '/^SwapFree:/{print $2}' /proc/meminfo)
  pct=$(( disp * 100 / tot ))
  kv "Total" "$(mb "$tot")"
  kv "Disponível" "$(mb "$disp") ($pct%)"
  if [ "${stot:-0}" -gt 0 ]; then
    spct=$(( (stot - slivre) * 100 / stot ))
    kv "Swap" "$(mb $(( stot - slivre ))) usados de $(mb "$stot") ($spct%)"
    if [ "$spct" -ge 50 ] && [ "$pct" -lt 30 ]; then aviso "swap ${spct}% usada e pouca RAM livre — falta memória ou vazamento"
    elif [ "$spct" -ge 50 ]; then info "swap ${spct}% usada, mas há RAM livre: o kernel só moveu páginas ociosas (não é problema agora)"; fi
  else
    kv "Swap" "nenhuma"
  fi
  if   [ "$pct" -lt 10 ]; then crit "só $pct% de memória disponível"
  elif [ "$pct" -lt 20 ]; then aviso "memória disponível baixa ($pct%)"
  else ok "memória folgada ($pct% livre)"; fi
  local oom=0
  if tem journalctl; then oom=$( (R journalctl -k -b -q --no-pager 2>/dev/null || journalctl -k -b -q --no-pager 2>/dev/null) | grep -ciE 'out of memory|oom-kill')
  elif tem dmesg; then oom=$( (R dmesg 2>/dev/null || dmesg 2>/dev/null) | grep -ciE 'out of memory|oom-kill'); fi
  numero "${oom:-}" && [ "$oom" -gt 0 ] && crit "o kernel matou processos por falta de memória (OOM) $oom vez(es) desde o boot"
  return 0
}

_filtros_df=(-x tmpfs -x devtmpfs -x squashfs -x overlay -x efivarfs -x fuse.snapfuse)

diag_disco() {
  secao "DISCO"
  rodar "Uso por partição" df -hT "${_filtros_df[@]}"
  local livre pct mp
  while read -r _ _ _ _ livre pct mp; do
    pct=${pct%\%}; numero "$pct" || continue
    if   [ "$pct" -ge 90 ]; then crit "$mp com $pct% de uso ($(mb "$livre") livres)"
    elif [ "$pct" -ge 80 ]; then aviso "$mp com $pct% de uso ($(mb "$livre") livres)"; fi
  done < <(df -PTk "${_filtros_df[@]}" 2>/dev/null | tail -n +2)
  local imp
  while read -r _ _ _ _ pct imp; do
    pct=${pct%\%}; numero "$pct" || continue
    [ "$pct" -ge 90 ] && crit "$imp sem inodes ($pct% usados) — muitos arquivos pequenos"
  done < <(df -Pi "${_filtros_df[@]}" 2>/dev/null | tail -n +2)
  if awk '$2=="/" && $4 ~ /^ro(,|$)/ {f=1} END{exit !f}' /proc/mounts 2>/dev/null; then
    crit "a partição / está SOMENTE LEITURA — normalmente erro de disco/filesystem"
  fi
  local ok_disco=1 m
  for m in ${CRITICOS[@]+"${CRITICOS[@]}"} ${AVISOS[@]+"${AVISOS[@]}"}; do [[ "$m" == *"% de uso"* ]] && ok_disco=0; done
  [ "$ok_disco" = 1 ] && ok "todas as partições abaixo de 80%"
  return 0
}

diag_servicos() {
  secao "SERVIÇOS"
  if ! tem systemctl; then info "sem systemd"; return 0; fi
  local ativos falhos
  ativos=$(systemctl list-units --type=service --state=running --no-legend 2>/dev/null | wc -l)
  falhos=$(systemctl list-units --state=failed --no-legend 2>/dev/null | wc -l)
  kv "Rodando" "$ativos serviço(s)"
  if [ "$falhos" -gt 0 ]; then
    aviso "$falhos unidade(s) com falha"
    systemctl list-units --state=failed --no-legend --plain 2>/dev/null | bloco
    info "detalhe: systemctl status <unidade>  ·  journalctl -u <unidade> -b"
  else
    ok "nenhum serviço com falha"
  fi
  return 0
}

diag_logs() {
  secao "ERROS NO LOG (desde o boot)"
  if ! tem journalctl; then info "sem journald — veja /var/log/syslog"; return 0; fi
  local erros n
  erros=$(R journalctl -p err -b -q --no-pager -o short 2>/dev/null || journalctl -p err -b -q --no-pager -o short 2>/dev/null)
  n=$(printf '%s' "$erros" | grep -c .)
  kv "Mensagens de erro" "$n"
  [ "$n" -eq 0 ] && { ok "nenhum erro registrado"; return 0; }
  # padrões que sempre merecem atenção
  local c
  c=$(grep -ci 'No space left on device' <<< "$erros")
  [ "$c" -gt 0 ] && crit "o disco ENCHEU desde o boot ($c registro(s) 'No space left on device') — último: $(grep -i 'No space left' <<< "$erros" | tail -1 | awk '{print $1, $2, $3}')"
  c=$(grep -ciE 'I/O error|EXT4-fs error|XFS .*error|Buffer I/O|blk_update_request' <<< "$erros")
  [ "$c" -gt 0 ] && crit "erros de leitura/gravação no disco ($c) — verifique SMART, cabos e filesystem"
  c=$(grep -ciE 'segfault|general protection' <<< "$erros")
  [ "$c" -gt 0 ] && aviso "$c programa(s) travaram (segfault)"
  [ "$n" -gt 200 ] && aviso "$n erros no log desde o boot"
  sub "Mensagens que mais se repetem"
  printf '%s\n' "$erros" | sed -E 's/^[^ ]+ +[^ ]+ +[^ ]+ +[^ ]+ +//; s/\[[0-9]+\]//; s/[0-9]{2,}/N/g' | cut -c1-160 \
    | sort | uniq -c | sort -rn | head -8 | bloco
  sub "Últimas 10"
  printf '%s\n' "$erros" | tail -10 | cut -c1-200 | bloco
  return 0
}

diag_atualizacoes() {
  secao "ATUALIZAÇÕES"
  case "$PKG" in
    apt)
      local lista n seg idade=""
      lista=$(apt list --upgradable 2>/dev/null | grep -v '^Listing\|^Listando')
      n=$(printf '%s' "$lista" | grep -c .)
      seg=$(printf '%s' "$lista" | grep -c -- '-security')
      if [ -f /var/lib/apt/periodic/update-success-stamp ]; then
        idade=$(( ( $(date +%s) - $(stat -c %Y /var/lib/apt/periodic/update-success-stamp) ) / 86400 ))
      elif [ -d /var/lib/apt/lists ]; then
        idade=$(( ( $(date +%s) - $(stat -c %Y /var/lib/apt/lists 2>/dev/null || date +%s) ) / 86400 ))
      fi
      kv "Pendentes" "$n pacote(s), $seg de segurança"
      [ -n "$idade" ] && kv "Lista de pacotes" "atualizada há $idade dia(s)"
      if [ "$seg" -gt 0 ]; then aviso "$seg atualização(ões) de SEGURANÇA pendente(s)"
      elif [ "$n" -gt 0 ]; then info "$n atualização(ões) comuns pendentes"
      else ok "sistema em dia (pela lista local)"; fi
      numero "$idade" && [ "$idade" -gt 14 ] && aviso "lista de pacotes não é atualizada há $idade dias (apt update)"
      if dpkg -s unattended-upgrades >/dev/null 2>&1; then ok "atualizações automáticas de segurança instaladas"
      else info "unattended-upgrades não instalado (atualização automática de segurança)"; fi
      ;;
    dnf|yum)
      local n; n=$(limitar 90 "$PKG" -q check-update 2>/dev/null | grep -cE '^[A-Za-z0-9]')
      kv "Pendentes" "$n pacote(s)"
      [ "$n" -gt 0 ] && info "$n atualização(ões) pendentes" || ok "sistema em dia"
      ;;
    *) info "gerenciador de pacotes não suportado para esta checagem" ;;
  esac
  return 0
}

docker_ok() { tem docker && { docker info >/dev/null 2>&1 || R docker info >/dev/null 2>&1; }; }
D() { if docker info >/dev/null 2>&1; then docker "$@"; else R docker "$@"; fi; }

diag_docker() {
  tem docker || return 0
  secao "DOCKER"
  if ! docker_ok; then info "docker instalado, mas sem acesso (precisa de root ou do grupo docker)"; return 0; fi
  local tot rod parados unhealthy reiniciando
  tot=$(D ps -aq | wc -l); rod=$(D ps -q | wc -l); parados=$(( tot - rod ))
  unhealthy=$(D ps -q --filter health=unhealthy | wc -l)
  reiniciando=$(D ps -q --filter status=restarting | wc -l)
  kv "Containers" "$rod rodando · $parados parado(s)"
  [ "$unhealthy" -gt 0 ] && aviso "$unhealthy container(s) unhealthy"
  [ "$reiniciando" -gt 0 ] && crit "$reiniciando container(s) em loop de reinício"
  sub "Containers"
  D ps -a --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}' 2>/dev/null | head -25 | bloco
  sub "Espaço usado pelo Docker"
  D system df 2>/dev/null | bloco
  local cache_gb
  cache_gb=$(D system df --format '{{.Type}} {{.Reclaimable}}' 2>/dev/null | awk '/Build/{v=$3; if(v ~ /GB$/){sub(/GB/,"",v); print int(v)} else print 0}')
  numero "${cache_gb:-}" && [ "$cache_gb" -ge 5 ] && aviso "Docker com ~${cache_gb} GB de cache de build reaproveitável (menu Limpeza)"
  return 0
}

diag_rede_resumo() {
  secao "REDE"
  if tem ip; then
    sub "Interfaces"
    ip -br addr 2>/dev/null | grep -vE '^(veth|br-|docker|virbr|cni|flannel)' | bloco
    local virt; virt=$(ip -br link 2>/dev/null | grep -cE '^(veth|br-|docker|virbr|cni|flannel)')
    [ "$virt" -gt 0 ] && info "+ $virt interface(s) virtuais de container/bridge omitidas"
    sub "Rotas"; ip route 2>/dev/null | grep -vE 'dev (br-|docker|veth|virbr)' | head -15 | bloco
  else
    rodar "Interfaces" ifconfig -a
  fi
  local gw dns
  gw=$(ip route show default 2>/dev/null | awk '/default/{print $3; exit}')
  if tem resolvectl; then dns=$(resolvectl dns 2>/dev/null | awk -F': ' 'NF>1 && $2!=""{print $2}' | tr '\n' ' ')
  fi
  [ -z "${dns// /}" ] && dns=$(awk '/^nameserver/{printf "%s ", $2}' /etc/resolv.conf 2>/dev/null)
  kv "Gateway" "${gw:-nenhum}"
  kv "DNS" "${dns:-nenhum}"
  [ -z "$gw" ] && aviso "sem rota padrão (gateway)"
  if tem ping; then
    local r lat
    if [ -n "$gw" ]; then
      if r=$(ping -c 3 -W 2 -q "$gw" 2>/dev/null); then lat=$(awk -F/ '/rtt|round-trip/{print $5}' <<< "$r"); ok "gateway responde (${lat:-?} ms)"
      else aviso "gateway $gw não responde a ping (pode ser bloqueio de ICMP)"; fi
    fi
    if r=$(ping -c 3 -W 2 -q 1.1.1.1 2>/dev/null); then lat=$(awk -F/ '/rtt|round-trip/{print $5}' <<< "$r"); ok "internet por IP (1.1.1.1: ${lat:-?} ms)"
    else aviso "sem resposta de 1.1.1.1 (sem internet ou ICMP bloqueado)"; fi
  fi
  if getent hosts debian.org >/dev/null 2>&1; then ok "DNS resolvendo nomes"
  else crit "DNS não resolve nomes (debian.org)"; fi
  if tem curl; then
    local c; c=$(curl -s -o /dev/null -w '%{http_code}' --max-time 6 https://www.google.com 2>/dev/null)
    [[ "$c" =~ ^[23] ]] && ok "HTTPS saindo para a internet" || aviso "HTTPS para a internet falhou (proxy/firewall?)"
  fi
  if tem ss; then kv "Portas escutando" "$(ss -tulnH 2>/dev/null | wc -l)"; fi
  return 0
}

diag_completo() {
  garantir_root "O diagnóstico"
  abrir_relatorio diagnostico
  diag_sistema; diag_hardware; diag_carga; diag_memoria; diag_disco; diag_servicos
  diag_logs; diag_atualizacoes; diag_docker; diag_rede_resumo; seg_resumo
  fechar_relatorio "Diagnóstico completo"
}

# ═════════════════════════════════════════════════════════════════════════════
#  REDE
# ═════════════════════════════════════════════════════════════════════════════
host_valido()  { [[ "${1:-}" =~ ^[A-Za-z0-9._:-]+$ ]]; }

rede_porta() {
  perguntar "Host ou IP para testar" "${ULT_HOST:-192.168.0.1}" || return
  local h=$RESPOSTA; host_valido "$h" || { crit "host inválido"; return; }
  ULT_HOST=$h
  perguntar "Porta(s), separadas por espaço" "22 80 443 3389" || return
  secao "TESTE DE PORTA — $h"
  local p ini fim
  for p in $RESPOSTA; do
    numero "$p" || continue
    ini=$(date +%s%N)
    if limitar 4 bash -c 'exec 3<>"/dev/tcp/$1/$2"' _ "$h" "$p" 2>/dev/null; then
      fim=$(date +%s%N); ok "$h:$p ABERTA ($(( (fim - ini) / 1000000 )) ms)"
    else
      info "$h:$p fechada, filtrada ou sem resposta"
    fi
  done
}

rede_rota() {
  perguntar "Destino" "${ULT_HOST:-8.8.8.8}" || return
  local h=$RESPOSTA; host_valido "$h" || { crit "destino inválido"; return; }
  secao "ROTA ATÉ $h"
  if   tem mtr;        then rodar "mtr (10 ciclos)" mtr -rwc 10 "$h"
  elif tem traceroute; then rodar "traceroute" traceroute -w 2 -q 1 "$h"
  elif tem tracepath;  then rodar "tracepath" tracepath "$h"
  else info "nem mtr, traceroute ou tracepath disponíveis"; fi
}

rede_descobrir() {
  tem ping || { crit "ping não disponível"; return; }
  local -a ifs=()
  mapfile -t ifs < <(ip -o -4 addr show scope global 2>/dev/null | awk '$2 !~ /^(veth|br-|docker|virbr|cni|flannel)/ {print $2" "$4}')
  [ ${#ifs[@]} -eq 0 ] && { crit "nenhuma interface com IPv4"; return; }
  local alvo=${ifs[0]}
  if [ ${#ifs[@]} -gt 1 ]; then
    local -a opc=(); local i
    for i in "${!ifs[@]}"; do opc+=("$((i+1))" "${ifs[$i]}"); done
    menu "Descobrir hosts" "Qual rede varrer?" "${opc[@]}" || return
    alvo=${ifs[$((ESCOLHA-1))]}
  fi
  local ip=${alvo#* }; ip=${ip%/*}; local base=${ip%.*}
  confirmar "Fazer ping em $base.1 a $base.254 (rede da interface ${alvo%% *})?" || return
  secao "HOSTS NA REDE $base.0/24"
  local tmp; tmp=$(mktemp); TEMPORARIOS+=("$tmp")
  local n=0 j
  printf '  varrendo'
  for j in $(seq 1 254); do
    ( ping -c 1 -W 1 "$base.$j" >/dev/null 2>&1 && echo "$base.$j" >> "$tmp" ) &
    n=$(( n + 1 )); if [ $(( n % 64 )) -eq 0 ]; then wait; printf '.'; fi
  done
  wait; echo
  local achados; achados=$(sort -t. -k4 -n "$tmp" | uniq)
  kv "Respondendo" "$(printf '%s' "$achados" | grep -c .) host(s)"
  local h mac nome
  while read -r h; do
    [ -z "$h" ] && continue
    mac=$(ip neigh show "$h" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i=="lladdr") print $(i+1)}')
    nome=$(getent hosts "$h" 2>/dev/null | awk '{print $2}')
    [ "$h" = "$ip" ] && nome="${nome:-esta máquina} (esta máquina)"
    printf '%-16s %-18s %s\n' "$h" "${mac:--}" "${nome:-}"
  done <<< "$achados" | bloco
  info "hosts que bloqueiam ping não aparecem"
}

rede_velocidade() {
  tem curl || { crit "curl não disponível"; return; }
  secao "VELOCIDADE DA INTERNET (Cloudflare)"
  local lat dl ul
  lat=$(curl -s -o /dev/null -w '%{time_connect}' --max-time 8 'https://speed.cloudflare.com/__down?bytes=0' 2>/dev/null)
  kv "Latência (TCP)" "$(awk -v t="${lat:-0}" 'BEGIN{printf "%.0f ms", t*1000}')"
  info "baixando 50 MB…"
  dl=$(curl -s -o /dev/null -w '%{speed_download}' --max-time 40 'https://speed.cloudflare.com/__down?bytes=50000000' 2>/dev/null)
  kv "Download" "$(awk -v b="${dl:-0}" 'BEGIN{printf "%.1f Mbit/s", b*8/1000000}')"
  info "enviando 20 MB…"
  ul=$(head -c 20000000 /dev/zero | curl -s -o /dev/null -w '%{speed_upload}' --max-time 40 --data-binary @- 'https://speed.cloudflare.com/__up' 2>/dev/null)
  kv "Upload" "$(awk -v b="${ul:-0}" 'BEGIN{printf "%.1f Mbit/s", b*8/1000000}')"
}

rede_dns() {
  perguntar "Nome para resolver" "google.com" || return
  local nome=$RESPOSTA; host_valido "$nome" || { crit "nome inválido"; return; }
  secao "TESTE DE DNS — $nome"
  local -a servidores=()
  mapfile -t servidores < <(awk '/^nameserver/{print $2}' /etc/resolv.conf 2>/dev/null)
  servidores+=(1.1.1.1 8.8.8.8)
  sub "Resolvedor do sistema"
  if getent hosts "$nome" >/dev/null; then getent hosts "$nome" | bloco
  else crit "o resolvedor do sistema não resolveu $nome"; fi
  local s ini fim r
  for s in "${servidores[@]}"; do
    ini=$(date +%s%N)
    if tem dig; then r=$(dig +short +time=2 +tries=1 "@$s" "$nome" 2>/dev/null | head -3 | tr '\n' ' ')
    elif tem nslookup; then r=$(limitar 5 nslookup "$nome" "$s" 2>/dev/null | awk '/^Address/ && NR>2{print $2}' | head -3 | tr '\n' ' ')
    else info "sem dig/nslookup — só o resolvedor do sistema foi testado"; break; fi
    fim=$(date +%s%N)
    if [ -n "${r// /}" ]; then ok "$s → $r($(( (fim - ini) / 1000000 )) ms)"
    else aviso "$s não respondeu para $nome"; fi
  done
}

rede_mtu() {
  tem ping || return
  perguntar "Destino do teste de MTU" "${ULT_HOST:-8.8.8.8}" || return
  local h=$RESPOSTA; host_valido "$h" || return
  secao "MTU ATÉ $h"
  ping -c 1 -W 2 "$h" >/dev/null 2>&1 || { aviso "$h não responde a ping — teste impossível"; return; }
  local lo=1000 hi=1472 mid
  while [ $(( hi - lo )) -gt 1 ]; do
    mid=$(( (lo + hi) / 2 ))
    if ping -M "do" -c 1 -W 2 -s "$mid" "$h" >/dev/null 2>&1; then lo=$mid; else hi=$mid; fi
  done
  ping -M "do" -c 1 -W 2 -s "$hi" "$h" >/dev/null 2>&1 && lo=$hi
  kv "Maior pacote sem fragmentar" "$lo bytes de dados → MTU $(( lo + 28 ))"
  [ $(( lo + 28 )) -lt 1500 ] && aviso "MTU do caminho menor que 1500 (VPN/PPPoE?) — pode travar sites e transferências grandes"
}

rede_iperf() {
  tem iperf3 || { info "iperf3 não instalado (menu Pacotes)"; return; }
  menu "iperf3" "Teste de banda entre duas máquinas da rede" 1 "Ser o SERVIDOR (a outra máquina conecta aqui)" 2 "Ser o CLIENTE (conectar num servidor iperf3)" || return
  if [ "$ESCOLHA" = 1 ]; then
    info "servidor iperf3 na porta 5201 — Ctrl+C para parar"
    ip -br addr 2>/dev/null | bloco
    iperf3 -s
  else
    perguntar "IP do servidor iperf3" "${ULT_HOST:-}" || return
    host_valido "$RESPOSTA" || return
    secao "IPERF3 → $RESPOSTA"
    rodar "Envio (este → servidor)" iperf3 -c "$RESPOSTA" -t 10
    rodar "Recebimento (servidor → este)" iperf3 -c "$RESPOSTA" -t 10 -R
  fi
}

menu_rede() {
  while :; do
    menu "Rede" "Testes de rede" \
      1 "Resumo da rede (IP, gateway, DNS, internet)" \
      2 "Testar porta TCP de um host" \
      3 "Rota até um host (mtr/traceroute)" \
      4 "Descobrir hosts na rede local (ping)" \
      5 "Velocidade da internet" \
      6 "Teste de DNS (cada servidor)" \
      7 "Descobrir MTU do caminho" \
      8 "Portas abertas nesta máquina" \
      9 "Banda entre duas máquinas (iperf3)" \
      0 "Voltar" || return
    LOG=""
    case "$ESCOLHA" in
      1) abrir_relatorio rede; diag_rede_resumo; fechar_relatorio "Rede" ;;
      2) rede_porta ;;
      3) rede_rota ;;
      4) rede_descobrir ;;
      5) rede_velocidade ;;
      6) rede_dns ;;
      7) rede_mtu ;;
      8) garantir_root "Ver o processo de cada porta"; secao "PORTAS ESCUTANDO"
         if [ "$PODE_ROOT" = 1 ]; then rodar_root "" ss -tulpn; else rodar "" ss -tuln; fi ;;
      9) rede_iperf ;;
      0) return ;;
    esac
    pausa
  done
}

# ═════════════════════════════════════════════════════════════════════════════
#  DISCO
# ═════════════════════════════════════════════════════════════════════════════
disco_maiores() {
  perguntar "Pasta para analisar" "/" || return
  local d=$RESPOSTA; [ -d "$d" ] || { crit "pasta não existe"; return; }
  garantir_root "Ler todas as pastas"
  secao "MAIORES ITENS EM $d"
  sub "Pastas (mesmo disco)"
  if [ "$PODE_ROOT" = 1 ]; then R du -xh --max-depth=1 "$d" 2>/dev/null | sort -rh | head -20 | bloco
  else du -xh --max-depth=1 "$d" 2>/dev/null | sort -rh | head -20 | bloco; fi
  sub "Arquivos acima de 500 MB"
  { if [ "$PODE_ROOT" = 1 ]; then R find "$d" -xdev -type f -size +500M -printf '%s\t%p\n' 2>/dev/null
    else find "$d" -xdev -type f -size +500M -printf '%s\t%p\n' 2>/dev/null; fi; } \
    | sort -rn | head -15 | awk -F'\t' '{ s=$1; u="B"; split("KB MB GB TB",U," "); i=0; while(s>=1024 && i<4){s/=1024; i++; u=U[i]} printf "%8.1f %s  %s\n", s, u, $2 }' | bloco
  info "dica: o ncdu (menu Pacotes) navega nisso interativamente"
}

disco_velocidade() {
  perguntar "Pasta onde gravar o arquivo de teste (1 GB, apagado no fim)" "/var/tmp" || return
  local d=$RESPOSTA
  [ -d "$d" ] && [ -w "$d" ] || { crit "sem permissão de escrita em $d"; return; }
  local livre; livre=$(df -Pk "$d" | awk 'NR==2{print $4}')
  [ "${livre:-0}" -lt 1400000 ] && { crit "pouco espaço em $d (precisa ~1,4 GB)"; return; }
  [ "$(df -PT "$d" | awk 'NR==2{print $2}')" = tmpfs ] && aviso "$d está em RAM (tmpfs): o resultado não mede o disco"
  secao "VELOCIDADE DO DISCO — $d"
  local f="$d/.bigboss_teste_$$"; TEMPORARIOS+=("$f")
  sub "Escrita sequencial (1 GB, com sync)"
  dd if=/dev/zero of="$f" bs=1M count=1024 conv=fdatasync 2>&1 | tail -1 | bloco
  sync
  if [ "$PODE_ROOT" = 1 ]; then R sh -c 'echo 3 > /proc/sys/vm/drop_caches'; fi
  sub "Leitura sequencial"
  local r
  r=$(dd if="$f" of=/dev/null bs=1M iflag=direct 2>&1) || r=$(dd if="$f" of=/dev/null bs=1M 2>&1)
  printf '%s\n' "$r" | tail -1 | bloco
  rm -f "$f"
  [ "$PODE_ROOT" = 1 ] || info "sem root o cache não é limpo: a leitura pode parecer mais rápida que o real"
  info "referência: HD 80–200 MB/s · SSD SATA 300–550 MB/s · NVMe 1–7 GB/s"
}

menu_disco() {
  while :; do
    menu "Disco" "Armazenamento" \
      1 "Uso por partição e inodes" \
      2 "Maiores pastas e arquivos" \
      3 "Saúde dos discos (SMART)" \
      4 "Velocidade de escrita/leitura" \
      5 "Discos, partições e pontos de montagem" \
      0 "Voltar" || return
    LOG=""
    case "$ESCOLHA" in
      1) diag_disco; sub "Inodes"; df -hi "${_filtros_df[@]}" 2>/dev/null | bloco ;;
      2) disco_maiores ;;
      3) garantir_root "O SMART"; secao "SMART"; diag_smart ;;
      4) garantir_root "Medir sem cache"; disco_velocidade ;;
      5) secao "DISCOS"; rodar "" lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINT; rodar "fstab" cat /etc/fstab ;;
      0) return ;;
    esac
    pausa
  done
}

# ═════════════════════════════════════════════════════════════════════════════
#  LIMPEZA
# ═════════════════════════════════════════════════════════════════════════════
LIMPA_ITENS=()
limpeza_estimar() {
  LIMPA_ITENS=()
  secao "LIMPEZA SEGURA — o que dá para liberar"
  rodar "Espaço agora" df -h "${_filtros_df[@]}"
  if [ "$PKG" = apt ]; then
    local cache orf
    cache=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
    orf=$(apt-get -s autoremove 2>/dev/null | grep -c '^Remv')
    kv "Cache do apt" "${cache:-0} · $orf pacote(s) órfão(s)"
    LIMPA_ITENS+=(apt "Cache do apt + pacotes órfãos (${cache:-0}, $orf pacotes)" ON)
  elif [ "$PKG" = dnf ] || [ "$PKG" = yum ]; then
    LIMPA_ITENS+=(dnf "Cache do $PKG + pacotes órfãos" ON)
  fi
  if tem journalctl; then
    local j; j=$( (R journalctl --disk-usage 2>/dev/null || journalctl --disk-usage 2>/dev/null) | grep -oE '[0-9.]+[KMGT]' | head -1)
    kv "Journal (logs)" "${j:-?}"
    LIMPA_ITENS+=(journal "Journal acima de 200 MB (hoje ${j:-?})" ON)
  fi
  local rot
  rot=$( (R find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -mtime +7 -printf '%s\n' 2>/dev/null \
          || find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -mtime +7 -printf '%s\n' 2>/dev/null) \
        | awk '{s+=$1} END{printf "%.0f", s/1048576}')
  kv "Logs rotacionados" "${rot:-0} MB (mais de 7 dias)"
  LIMPA_ITENS+=(logs "Logs antigos já rotacionados (*.gz, *.1…) com +7 dias (${rot:-0} MB)" ON)
  if docker_ok; then
    sub "Docker"; D system df 2>/dev/null | bloco
    LIMPA_ITENS+=(docker "Docker: cache de build + imagens soltas (nunca volumes)" ON)
  fi
  if tem snap; then
    local n; n=$(snap list --all 2>/dev/null | awk '/disabled/' | wc -l)
    kv "Snaps antigos" "$n revisão(ões)"
    [ "$n" -gt 0 ] && LIMPA_ITENS+=(snap "Revisões antigas de snaps ($n)" ON)
  fi
  LIMPA_ITENS+=(miniaturas "Cache de miniaturas dos usuários (~/.cache/thumbnails)" OFF)
  info "nada fora desta lista é tocado; dados, volumes do Docker e /home ficam intactos"
}

limpeza() {
  garantir_root "A limpeza" || { crit "a limpeza precisa de root"; return; }
  abrir_relatorio limpeza
  local antes depois it
  antes=$(df -Pk / | awk 'NR==2{print $4}')
  limpeza_estimar
  marcar "Limpeza segura" "Marque o que limpar" "${LIMPA_ITENS[@]}" || { fechar_relatorio "Limpeza (cancelada)"; return; }
  if [ ${#MARCADOS[@]} -eq 0 ]; then info "nada marcado"; fechar_relatorio "Limpeza (nada feito)"; return; fi
  confirmar "Limpar agora: ${MARCADOS[*]}?" || { fechar_relatorio "Limpeza (cancelada)"; return; }
  secao "LIMPEZA — execução"
  for it in "${MARCADOS[@]}"; do
    case "$it" in
      apt)
        rodar_root "apt-get clean" apt-get clean
        rodar_root "apt-get autoremove --purge" env DEBIAN_FRONTEND=noninteractive apt-get -y autoremove --purge ;;
      dnf)
        rodar_root "$PKG clean all" "$PKG" clean all
        rodar_root "$PKG autoremove" "$PKG" -y autoremove ;;
      journal)
        local tam="200M"
        perguntar "Quanto de journal manter? (ex.: 200M, 1G)" "200M" && [[ "$RESPOSTA" =~ ^[0-9]+[KMG]$ ]] && tam=$RESPOSTA
        rodar_root "journalctl --vacuum-size=$tam" journalctl --vacuum-size="$tam" ;;
      logs)
        rodar_root "Logs rotacionados apagados" find /var/log -type f \( -name '*.gz' -o -name '*.[0-9]' -o -name '*.old' \) -mtime +7 -print -delete ;;
      docker)
        rodar_root "docker builder prune" docker builder prune -f
        rodar_root "docker image prune (soltas)" docker image prune -f ;;
      snap)
        local -a revs=(); local s r linha
        mapfile -t revs < <(snap list --all 2>/dev/null | awk '/disabled/{print $1" "$3}')
        for linha in ${revs[@]+"${revs[@]}"}; do
          s=${linha% *}; r=${linha#* }
          rodar_root "snap remove $s (rev $r)" snap remove "$s" --revision="$r" < /dev/null
        done ;;
      miniaturas)
        rodar_root "Miniaturas" find /root/.cache/thumbnails /home -path '*/.cache/thumbnails/*' -type f -delete -print ;;
    esac
  done
  depois=$(df -Pk / | awk 'NR==2{print $4}')
  secao "RESULTADO"
  rodar "Espaço depois" df -h "${_filtros_df[@]}"
  if [ $(( depois - antes )) -gt 0 ]; then ok "liberado em /: $(mb $(( depois - antes )))"; else info "espaço em / praticamente igual"; fi
  fechar_relatorio "Limpeza"
}

# ═════════════════════════════════════════════════════════════════════════════
#  ATUALIZAÇÕES
# ═════════════════════════════════════════════════════════════════════════════
apt_ni() { rodar_root "$1" env DEBIAN_FRONTEND=noninteractive apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold "${@:2}"; }

atu_lista() {
  garantir_root "Atualizar a lista" || { crit "precisa de root"; return 1; }
  secao "ATUALIZAÇÕES PENDENTES"
  case "$PKG" in
    apt) rodar_root "apt-get update" apt-get update; sub "Pendentes"; apt list --upgradable 2>/dev/null | tail -n +2 | bloco
         kv "Total" "$(apt list --upgradable 2>/dev/null | tail -n +2 | wc -l) pacote(s), $(apt list --upgradable 2>/dev/null | grep -c -- '-security') de segurança" ;;
    *)   rodar_root "check-update" "$PKG" check-update ;;
  esac
}

atu_instalar() {   # atu_instalar upgrade|full-upgrade
  local tipo=${1:-upgrade}
  garantir_root "Instalar atualizações" || { crit "precisa de root"; return 1; }
  confirmar "Rodar $PKG $tipo agora?\n\nArquivos de configuração alterados por você são mantidos.\nServiços podem reiniciar durante a atualização." || return 0
  abrir_relatorio "atualizacao"
  secao "ATUALIZAÇÃO ($tipo)"
  case "$PKG" in
    apt) rodar_root "apt-get update" apt-get update; apt_ni "apt-get $tipo" "$tipo" ;;
    dnf|yum) rodar_root "$PKG upgrade" "$PKG" -y upgrade ;;
    zypper) rodar_root "zypper update" zypper -n update ;;
    apk) rodar_root "apk upgrade" apk upgrade ;;
  esac
  [ -f /var/run/reboot-required ] && aviso "reinicialização necessária para concluir"
  fechar_relatorio "Atualização"
}

atu_reboot() {
  secao "REINICIALIZAÇÃO"
  if [ -f /var/run/reboot-required ]; then aviso "sim — $(cat /var/run/reboot-required.pkgs 2>/dev/null | tr '\n' ' ')"
  elif tem needs-restarting; then R needs-restarting -r 2>&1 | bloco
  else ok "nenhum aviso de reinicialização pendente"; fi
  kv "Kernel rodando" "$(uname -r)"
  if [ "$PKG" = apt ]; then kv "Kernel mais novo instalado" "$(ls -1 /boot/vmlinuz-* 2>/dev/null | sed 's#.*/vmlinuz-##' | sort -V | tail -1)"; fi
  info "reboot de servidor/roteador: avise quem usa e faça você mesmo — o BigBoss nunca reinicia sozinho"
}

menu_atualizacoes() {
  [ -n "$PKG" ] || { crit "gerenciador de pacotes não identificado"; pausa; return; }
  while :; do
    menu "Atualizações ($PKG)" "Sistema: $DISTRO" \
      1 "Ver atualizações pendentes (atualiza a lista)" \
      2 "Instalar atualizações (upgrade)" \
      3 "Atualização completa (full-upgrade: pode instalar/remover pacotes)" \
      4 "Precisa reiniciar?" \
      0 "Voltar" || return
    LOG=""
    case "$ESCOLHA" in
      1) atu_lista ;;
      2) atu_instalar upgrade ;;
      3) atu_instalar full-upgrade ;;
      4) atu_reboot ;;
      0) return ;;
    esac
    pausa
  done
}

# ═════════════════════════════════════════════════════════════════════════════
#  SEGURANÇA
# ═════════════════════════════════════════════════════════════════════════════
seg_resumo() {
  secao "SEGURANÇA (resumo)"
  local crits_antes=${#CRITICOS[@]}
  local extra; extra=$(awk -F: '$3==0 && $1!="root"{printf "%s ", $1}' /etc/passwd)
  [ -n "$extra" ] && crit "contas com UID 0 além do root: $extra"
  if [ "$PODE_ROOT" = 1 ]; then
    local vazias; vazias=$(R awk -F: '($2==""){printf "%s ", $1}' /etc/shadow 2>/dev/null)
    [ -n "$vazias" ] && crit "contas SEM SENHA: $vazias"
  fi
  if tem sshd || [ -x /usr/sbin/sshd ]; then
    local cfg prl pa porta
    cfg=$(R /usr/sbin/sshd -T 2>/dev/null)
    if [ -n "$cfg" ]; then
      prl=$(awk '$1=="permitrootlogin"{print $2}' <<< "$cfg"); pa=$(awk '$1=="passwordauthentication"{print $2}' <<< "$cfg")
      porta=$(awk '$1=="port"{printf "%s ", $2}' <<< "$cfg")
      kv "SSH" "porta $porta· root: $prl · senha: $pa"
      [ "$prl" = yes ] && aviso "SSH aceita login direto como root com senha (PermitRootLogin yes)"
      [ "$pa" = yes ] && info "SSH aceita senha (chave é mais seguro)"
    fi
    local falhas
    falhas=$( { R journalctl -u ssh -u sshd --since "24 hours ago" -q --no-pager 2>/dev/null \
               || grep -h "$(date '+%b %e')" /var/log/auth.log /var/log/secure 2>/dev/null; } | grep -cE 'Failed password|Invalid user')
    if numero "${falhas:-}" && [ "$falhas" -gt 0 ]; then
      kv "SSH falhas 24h" "$falhas tentativa(s)"
      [ "$falhas" -gt 100 ] && aviso "$falhas tentativas de login SSH falharam em 24 h (força bruta?)"
    fi
  fi
  local fw="nenhum"
  if tem ufw && R ufw status 2>/dev/null | grep -q 'Status: active'; then fw="ufw ativo"
  elif tem firewall-cmd && R firewall-cmd --state 2>/dev/null | grep -q running; then fw="firewalld ativo"
  elif tem nft && [ "$(R nft list ruleset 2>/dev/null | grep -c 'chain')" -gt 0 ]; then fw="nftables com regras"
  elif tem iptables && [ "$(R iptables -S 2>/dev/null | grep -vc '^-P')" -gt 0 ]; then fw="iptables com regras"; fi
  kv "Firewall" "$fw"
  if [ "$fw" = nenhum ]; then
    if [ "$PODE_ROOT" = 1 ]; then aviso "nenhum firewall local ativo"; else info "firewall não verificado (sem root)"; fi
  fi
  if tem ss; then
    local exp; exp=$(ss -tlnH 2>/dev/null | awk '$4 ~ /^(0\.0\.0\.0|\*|\[::\]):/{split($4,a,":"); printf "%s ", a[length(a)]}' | tr ' ' '\n' | sort -nu | tr '\n' ' ')
    kv "TCP em todas as IPs" "${exp:-nenhuma}"
  fi
  local ww; ww=$(find /etc -xdev -type f -perm -0002 2>/dev/null | head -5 | tr '\n' ' ')
  [ -n "$ww" ] && aviso "arquivos em /etc graváveis por qualquer usuário: $ww"
  [ ${#CRITICOS[@]} -eq "$crits_antes" ] && ok "nenhum problema grave de conta encontrado"
  return 0
}

seguranca() {
  garantir_root "A auditoria"
  abrir_relatorio seguranca
  seg_resumo
  secao "CONTAS"
  sub "Usuários com shell de login"
  awk -F: '$7 !~ /(nologin|false|sync|shutdown|halt)$/ {printf "%-16s uid=%-6s %s\n", $1, $3, $6}' /etc/passwd | bloco
  sub "Grupos administrativos"
  getent group sudo wheel admin 2>/dev/null | bloco
  rodar "Últimos logins" last -n 10 -a -w
  if [ "$PODE_ROOT" = 1 ] && tem lastb; then
    sub "IPs com mais logins falhos"
    R lastb -w 2>/dev/null | awk 'NF>3{print $3}' | sort | uniq -c | sort -rn | head -8 | bloco
  fi
  secao "PORTAS"
  if [ "$PODE_ROOT" = 1 ]; then rodar_root "Escutando (com processo)" ss -tulpn; else rodar "Escutando" ss -tuln; fi
  secao "FIREWALL"
  if tem ufw; then rodar_root "ufw" ufw status verbose; fi
  if tem nft; then sub "nftables (resumo)"; R nft list ruleset 2>/dev/null | grep -E 'table|chain|policy' | head -30 | bloco; fi
  fechar_relatorio "Auditoria de segurança"
}

# ═════════════════════════════════════════════════════════════════════════════
#  BENCHMARK
# ═════════════════════════════════════════════════════════════════════════════
bench_cpu() {
  secao "BENCHMARK DE CPU"
  kv "CPU" "$(awk -F: '/model name/{sub(/^ +/,"",$2); print $2; exit}' /proc/cpuinfo) ($NCPU núcleos)"
  if tem sysbench; then
    sub "sysbench — 1 núcleo (10 s)"
    sysbench cpu --threads=1 --time=10 run 2>/dev/null | grep -E 'events per second' | bloco
    sub "sysbench — todos os núcleos (10 s)"
    sysbench cpu --threads="$NCPU" --time=10 run 2>/dev/null | grep -E 'events per second' | bloco
  elif tem openssl; then
    sub "openssl sha256 — 1 núcleo"
    openssl speed -seconds 3 sha256 2>/dev/null | tail -1 | bloco
    sub "openssl sha256 — $NCPU núcleos"
    openssl speed -seconds 3 -multi "$NCPU" sha256 2>/dev/null | tail -1 | bloco
    info "valores em kB/s por tamanho de bloco — maior é melhor; compare entre máquinas"
  else
    local ini fim; ini=$(date +%s%N)
    local i=0; while [ $i -lt 300000 ]; do i=$(( i + 1 )); done
    fim=$(date +%s%N)
    kv "Laço bash (300 mil)" "$(( (fim - ini) / 1000000 )) ms (menor é melhor)"
  fi
}

bench_memoria() {
  secao "BENCHMARK DE MEMÓRIA"
  if tem sysbench; then
    sysbench memory --memory-total-size=8G run 2>/dev/null | grep -E 'transferred' | bloco
  else
    sub "dd 8 GB /dev/zero → /dev/null"
    dd if=/dev/zero of=/dev/null bs=1M count=8192 2>&1 | tail -1 | bloco
  fi
}

bench_estresse() {
  perguntar "Duração do estresse em minutos (1–60)" "3" || return
  numero "$RESPOSTA" && [ "$RESPOSTA" -ge 1 ] && [ "$RESPOSTA" -le 60 ] || { crit "duração inválida"; return; }
  local seg=$(( RESPOSTA * 60 )) tmax tini t
  confirmar "Colocar os $NCPU núcleos a 100% por $RESPOSTA min?\nNão faça isso em servidor de produção em horário de uso." || return
  abrir_relatorio estresse
  secao "ESTRESSE DE CPU — $RESPOSTA min"
  tini=$(temperatura_max); tmax=${tini:-0}
  kv "Temperatura inicial" "${tini:-sem sensor}${tini:+°C}"
  FILHOS=()
  if tem stress-ng; then
    stress-ng --cpu 0 --timeout "${seg}s" >/dev/null 2>&1 & FILHOS+=($!)
  else
    local _k; for _k in $(seq 1 "$NCPU"); do ( while :; do :; done ) & FILHOS+=($!); done
  fi
  local parar=0 ini; ini=$(date +%s)
  trap 'parar=1' INT
  info "rodando… Ctrl+C encerra antes"
  while [ "$parar" = 0 ] && [ $(( $(date +%s) - ini )) -lt "$seg" ]; do
    sleep 10
    t=$(temperatura_max)
    [ -n "$t" ] && [ "$t" -gt "$tmax" ] && tmax=$t
    printf '%3ds  carga %s  temp %s\n' "$(( $(date +%s) - ini ))" "$(cut -d' ' -f1 /proc/loadavg)" "${t:-–}${t:+°C}" | bloco
  done
  trap 'echo; echo "Interrompido."; exit 130' INT
  local p; for p in ${FILHOS[@]+"${FILHOS[@]}"}; do kill "$p" 2>/dev/null; done; FILHOS=()
  wait 2>/dev/null
  kv "Duração real" "$(( $(date +%s) - ini )) s"
  if [ -n "$tini" ]; then
    kv "Temperatura máxima" "${tmax}°C"
    if   [ "$tmax" -ge 90 ]; then crit "chegou a ${tmax}°C — limpeza/pasta térmica/ventilação"
    elif [ "$tmax" -ge 80 ]; then aviso "chegou a ${tmax}°C sob carga"
    else ok "temperatura sob controle (${tmax}°C)"; fi
  fi
  if tem journalctl && R journalctl -k --since "-$(( RESPOSTA + 1 )) min" -q --no-pager 2>/dev/null | grep -qi 'throttl'; then
    aviso "o kernel registrou throttling térmico (CPU reduziu a velocidade)"
  fi
  if (R journalctl -k --since "-$(( RESPOSTA + 1 )) min" -q --no-pager 2>/dev/null || dmesg 2>/dev/null) | grep -qiE 'mce|machine check|hardware error'; then
    crit "erro de hardware (MCE) registrado durante o teste"
  fi
  fechar_relatorio "Estresse de CPU"
}

menu_benchmark() {
  while :; do
    menu "Benchmark" "Medir e estressar" \
      1 "CPU (rápido)" \
      2 "Estresse de CPU + temperatura" \
      3 "Memória" \
      4 "Disco (escrita/leitura)" \
      0 "Voltar" || return
    LOG=""
    case "$ESCOLHA" in
      1) bench_cpu ;;
      2) garantir_root "Ler sensores e log do kernel"; bench_estresse ;;
      3) bench_memoria ;;
      4) garantir_root "Medir sem cache"; disco_velocidade ;;
      0) return ;;
    esac
    pausa
  done
}

# ═════════════════════════════════════════════════════════════════════════════
#  BACKUP E SNAPSHOT
# ═════════════════════════════════════════════════════════════════════════════
backup_pasta() {   # backup_pasta ORIGEM DESTINO MANTER
  local orig=${1%/} dest=${2%/} manter=${3:-7}
  [ -z "$orig" ] && orig="/"
  [ -e "$orig" ] || { crit "origem não existe: $orig"; return 1; }
  numero "$manter" && [ "$manter" -ge 1 ] || manter=7
  mkdir -p "$dest" 2>/dev/null || R mkdir -p "$dest" || { crit "não consegui criar $dest"; return 1; }
  local nome; nome=$(basename "$orig"); nome=${nome//[^A-Za-z0-9._-]/_}
  local arq="$dest/${HOST}_${nome}_$(date +%Y%m%d_%H%M%S).tar.gz"
  local precisa livre
  precisa=$(du -sk "$orig" 2>/dev/null | awk '{print $1}'); livre=$(df -Pk "$dest" | awk 'NR==2{print $4}')
  kv "Origem" "$orig ($(mb "${precisa:-0}") sem compressão)"
  kv "Destino" "$arq"
  numero "${precisa:-}" && numero "${livre:-}" && [ "$precisa" -gt "$livre" ] && aviso "a origem é maior que o espaço livre no destino ($(mb "$livre")) — a compressão pode ou não salvar"
  local rc=0 err; err=$(mktemp); TEMPORARIOS+=("$err")
  if [ "$(id -u)" -eq 0 ] || [ "$PODE_ROOT" != 1 ]; then
    tar -czf "$arq" -C "$(dirname "$orig")" "$(basename "$orig")" 2> "$err" || rc=$?
  else
    R tar -czf - -C "$(dirname "$orig")" "$(basename "$orig")" 2> "$err" > "$arq" || rc=$?
  fi
  if [ "$rc" -ge 2 ]; then crit "tar falhou (código $rc)"; tail -5 "$err" | bloco; rm -f "$arq"; return 1; fi
  [ "$rc" = 1 ] && aviso "alguns arquivos mudaram durante a cópia (normal em pastas em uso)"
  grep -q 'Permission denied\|Permissão negada' "$err" && aviso "arquivos sem permissão de leitura ficaram de fora"
  ( cd "$dest" && sha256sum "$(basename "$arq")" > "$(basename "$arq").sha256" )
  ok "backup criado: $(du -h "$arq" | cut -f1) · SHA256 em $(basename "$arq").sha256"
  local velho
  while IFS= read -r velho; do
    [ -n "$velho" ] || continue
    rm -f "$velho" "$velho.sha256"; info "cópia antiga removida: $(basename "$velho")"
  done < <(ls -1t "$dest/${HOST}_${nome}_"*.tar.gz 2>/dev/null | tail -n +$(( manter + 1 )))
  info "restaurar: tar -xzf $(basename "$arq") -C /pasta/destino   ·   conferir: sha256sum -c $(basename "$arq").sha256"
}

snapshot() {
  garantir_root "O snapshot de /etc e cron"
  abrir_relatorio snapshot
  local d; if [ -n "$SESSAO" ]; then d="$SESSAO/snapshot"; else d="/tmp/bigboss-snapshot-$CARIMBO"; fi
  mkdir -p "$d" || { crit "não consegui criar $d"; return; }
  secao "SNAPSHOT DE CONFIGURAÇÃO"
  kv "Pasta" "$d"
  { echo "== $DISTRO"; uname -a; echo; ip addr 2>/dev/null; echo; ip route 2>/dev/null; echo; cat /etc/resolv.conf 2>/dev/null
    echo; df -hT 2>/dev/null; echo; lsblk -f 2>/dev/null; echo; cat /etc/fstab 2>/dev/null; echo; cat /etc/hosts 2>/dev/null; } > "$d/sistema.txt" 2>&1
  ok "sistema.txt (rede, discos, fstab, hosts)"
  if tem dpkg-query; then
    dpkg-query -W -f='${Package}\t${Version}\n' > "$d/pacotes.txt" 2>/dev/null
    apt-mark showmanual > "$d/pacotes_manuais.txt" 2>/dev/null
    ok "pacotes.txt ($(wc -l < "$d/pacotes.txt") pacotes) + pacotes_manuais.txt (reinstalar: xargs apt-get install -y < pacotes_manuais.txt)"
  elif tem rpm; then rpm -qa | sort > "$d/pacotes.txt"; ok "pacotes.txt"; fi
  if tem systemctl; then systemctl list-unit-files --state=enabled --no-pager > "$d/servicos_habilitados.txt" 2>/dev/null; ok "servicos_habilitados.txt"; fi
  { echo "== crontab de $(id -un)"; crontab -l 2>/dev/null; } > "$d/cron.txt"
  if [ "$PODE_ROOT" = 1 ]; then
    { R iptables-save 2>/dev/null; } > "$d/firewall_iptables.txt"
    { R nft list ruleset 2>/dev/null; } > "$d/firewall_nft.txt"
    tem ufw && { R ufw status verbose 2>/dev/null; } > "$d/firewall_ufw.txt"
    ok "regras de firewall"
  fi
  if docker_ok; then
    { echo "== containers"; D ps -a; echo; echo "== imagens"; D images; echo; echo "== redes"; D network ls; echo; echo "== volumes"; D volume ls; } > "$d/docker.txt" 2>&1
    local lista; lista=$(mktemp); TEMPORARIOS+=("$lista")
    (R find /home /opt /srv /root -maxdepth 4 \( -name 'docker-compose*.y*ml' -o -name 'compose.y*ml' \) 2>/dev/null \
      || find /home /opt /srv -maxdepth 4 \( -name 'docker-compose*.y*ml' -o -name 'compose.y*ml' \) 2>/dev/null) > "$lista"
    if [ -s "$lista" ]; then
      (R tar -czf - -T "$lista" 2>/dev/null || tar -czf - -T "$lista" 2>/dev/null) > "$d/docker_compose.tar.gz"
      ok "docker.txt + $(wc -l < "$lista") arquivo(s) compose (os .env NÃO são copiados)"
    else ok "docker.txt"; fi
  fi
  local -a pastas=(etc)
  [ -d /var/spool/cron ] && pastas+=(var/spool/cron)
  local ex=(--exclude=etc/shadow --exclude=etc/shadow- --exclude=etc/gshadow --exclude=etc/gshadow- --exclude='etc/ssh/ssh_host_*_key')
  if [ "$PODE_ROOT" = 1 ]; then R tar -czf - "${ex[@]}" -C / "${pastas[@]}" 2>/dev/null > "$d/etc.tar.gz"
  else tar -czf - "${ex[@]}" -C / "${pastas[@]}" 2>/dev/null > "$d/etc.tar.gz"; aviso "sem root: arquivos protegidos de /etc ficaram de fora"; fi
  ok "etc.tar.gz ($(du -h "$d/etc.tar.gz" | cut -f1)) — sem /etc/shadow e sem chaves privadas do SSH"
  ( cd "$d" && sha256sum ./* > SHA256SUMS 2>/dev/null )
  ok "SHA256SUMS"
  info "configurações podem conter senhas (ex.: arquivos de serviços) — guarde o pendrive com cuidado"
  fechar_relatorio "Snapshot de configuração"
}

instalar_no_servidor() {
  garantir_root "Instalar" || { crit "precisa de root"; return 1; }
  rodar_root "Copiando para /usr/local/sbin/bigboss" install -m 0755 "$SCRIPT" /usr/local/sbin/bigboss && ok "instalado: rode 'sudo bigboss' de qualquer pasta"
}

agendar_backup() {
  garantir_root "Agendar no cron" || { crit "precisa de root"; return; }
  perguntar "Pasta a copiar" "/etc" || return; local orig=$RESPOSTA
  perguntar "Destino (num disco do servidor ou montagem de rede, não o pendrive)" "/var/backups/bigboss" || return; local dest=$RESPOSTA
  perguntar "Quantas cópias manter" "14" || return; local manter=$RESPOSTA
  perguntar "Horário diário (HH:MM)" "02:30" || return; local hora=$RESPOSTA
  [[ "$hora" =~ ^([01][0-9]|2[0-3]):([0-5][0-9])$ ]] || { crit "horário inválido"; return; }
  numero "$manter" || { crit "quantidade inválida"; return; }
  if [[ "$orig$dest" == *[\'\"%\\]* ]]; then crit "caminhos com aspas, % ou \\ não são aceitos no cron"; return; fi
  [[ "$dest" == "$BASE"* ]] && aviso "o destino está no pendrive — quando ele sair, o backup agendado falha"
  local h=${hora%:*} m=${hora#*:} nome
  nome=$(basename "$orig"); nome=${nome//[^A-Za-z0-9_-]/_}
  local arq="/etc/cron.d/bigboss-backup-$nome"
  confirmar "Criar $arq?\n\nTodo dia às $hora: $orig → $dest (manter $manter)" || return
  instalar_no_servidor || return
  printf '%s\n' "# Criado pelo BigBoss v$VERSAO em $(date '+%d/%m/%Y %H:%M')" \
    "SHELL=/bin/bash" "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin" \
    "$((10#$m)) $((10#$h)) * * * root /usr/local/sbin/bigboss --backup '$orig' '$dest' --manter $manter --sem-cor >> /var/log/bigboss-backup.log 2>&1" \
    | R tee "$arq" >/dev/null && R chmod 644 "$arq"
  ok "agendado: $arq"
  info "testar agora: sudo /usr/local/sbin/bigboss --backup '$orig' '$dest' --manter $manter"
  info "log: /var/log/bigboss-backup.log  ·  remover: sudo rm $arq"
}

menu_backup() {
  while :; do
    menu "Backup" "Cópias e snapshot" \
      1 "Snapshot da configuração desta máquina → pendrive" \
      2 "Backup de uma pasta (tar.gz + SHA256)" \
      3 "Agendar backup diário no servidor (cron)" \
      4 "Ver backups agendados pelo BigBoss" \
      0 "Voltar" || return
    LOG=""
    case "$ESCOLHA" in
      1) snapshot ;;
      2) perguntar "Pasta a copiar" "/etc" || continue; local o=$RESPOSTA
         preparar_sessao; perguntar "Destino" "$RAIZ_REL/backups" || continue; local de=$RESPOSTA
         perguntar "Quantas cópias manter" "7" || continue
         garantir_root "Ler todos os arquivos"
         secao "BACKUP"; backup_pasta "$o" "$de" "$RESPOSTA" ;;
      3) agendar_backup ;;
      4) secao "BACKUPS AGENDADOS"
         if ls /etc/cron.d/bigboss-* >/dev/null 2>&1; then
           local c; for c in /etc/cron.d/bigboss-*; do sub "$c"; grep -v '^#' "$c" | bloco; done
         else info "nenhum"; fi ;;
      0) return ;;
    esac
    pausa
  done
}

# ═════════════════════════════════════════════════════════════════════════════
#  PACOTES
# ═════════════════════════════════════════════════════════════════════════════
nome_pacote() {   # nome genérico → nome no gerenciador atual
  case "$PKG:$1" in
    apt:mtr) echo mtr-tiny ;;  dnf:dnsutils|yum:dnsutils) echo bind-utils ;;
    dnf:lm-sensors|yum:lm-sensors) echo lm_sensors ;;  dnf:whiptail|yum:whiptail) echo newt ;;
    *) echo "$1" ;;
  esac
}

instalar_pacotes() {   # instalar_pacotes nome…
  garantir_root "Instalar pacotes" || { crit "precisa de root"; return 1; }
  case "$PKG" in
    apt) rodar_root "apt-get update" apt-get update; apt_ni "apt-get install" install "$@" ;;
    dnf|yum) rodar_root "$PKG install" "$PKG" -y install "$@" ;;
    zypper) rodar_root "zypper install" zypper -n install "$@" ;;
    apk) rodar_root "apk add" apk add "$@" ;;
    *) crit "gerenciador não suportado"; return 1 ;;
  esac
}

menu_pacotes() {
  while :; do
    menu "Pacotes e ferramentas" "Gerenciador: ${PKG:-?}" \
      1 "Instalar ferramentas úteis de sysadmin" \
      2 "Instalar pacotes .deb/.rpm da pasta pacotes/ do pendrive (offline)" \
      3 "Procurar um pacote" \
      4 "Instalar um pacote pelo nome" \
      5 "Ver o manual de um comando" \
      0 "Voltar" || return
    LOG=""
    case "$ESCOLHA" in
      1)
        local -a lista=() fer=(
          "curl:testes HTTP e downloads" "smartmontools:saúde SMART dos discos" "sysstat:iostat, sar, mpstat"
          "htop:monitor de processos" "ncdu:uso de disco interativo" "iperf3:banda entre duas máquinas"
          "mtr:traceroute contínuo" "dnsutils:dig e nslookup" "lsof:arquivos e portas por processo"
          "tcpdump:captura de pacotes" "ethtool:diagnóstico da placa de rede" "lm-sensors:temperaturas"
          "sysbench:benchmark" "stress-ng:teste de estresse" "nmap:varredura de rede" "whiptail:menus do BigBoss")
        local item n
        for item in "${fer[@]}"; do
          n=${item%%:*}
          local cmd=$n estado=ON
          case "$n" in smartmontools) cmd=smartctl ;; dnsutils) cmd=dig ;; lm-sensors) cmd=sensors ;; sysstat) cmd=iostat ;; esac
          tem "$cmd" && estado=OFF
          lista+=("$n" "${item#*:}$( [ "$estado" = OFF ] && echo ' (já instalado)')" "$estado")
        done
        marcar "Ferramentas" "Marcadas = ainda não instaladas" "${lista[@]}" || continue
        [ ${#MARCADOS[@]} -eq 0 ] && continue
        local -a nomes=(); for n in "${MARCADOS[@]}"; do nomes+=("$(nome_pacote "$n")"); done
        confirmar "Instalar: ${nomes[*]}?" || continue
        secao "INSTALAÇÃO"; instalar_pacotes "${nomes[@]}" ;;
      2)
        local pasta="$BASE/pacotes"
        if ! ls "$pasta"/*.deb "$pasta"/*.rpm >/dev/null 2>&1; then
          info "coloque arquivos .deb/.rpm em $pasta (baixe em outra máquina com: apt-get download <pacote>)"; pausa; continue
        fi
        local -a arqs=() itens=(); local a
        mapfile -t arqs < <(ls -1 "$pasta"/*.deb "$pasta"/*.rpm 2>/dev/null)
        for a in "${arqs[@]}"; do itens+=("$(basename "$a")" "" OFF); done
        marcar "Pacotes do pendrive" "$pasta" "${itens[@]}" || continue
        [ ${#MARCADOS[@]} -eq 0 ] && continue
        garantir_root "Instalar" || { crit "precisa de root"; pausa; continue; }
        secao "INSTALAÇÃO OFFLINE"
        local -a cam=(); for a in "${MARCADOS[@]}"; do cam+=("$pasta/$a"); done
        if [ "$PKG" = apt ]; then apt_ni "apt-get install (resolve dependências se houver internet)" install "${cam[@]}" || rodar_root "dpkg -i" dpkg -i "${cam[@]}"
        else rodar_root "$PKG install" "$PKG" -y install "${cam[@]}"; fi ;;
      3) perguntar "Procurar" "" || continue; [ -z "$RESPOSTA" ] && continue
         secao "BUSCA: $RESPOSTA"
         case "$PKG" in apt) apt-cache search "$RESPOSTA" 2>/dev/null | head -40 | bloco ;; dnf|yum) "$PKG" -q search "$RESPOSTA" 2>/dev/null | head -40 | bloco ;; *) info "não suportado" ;; esac ;;
      4) perguntar "Nome do pacote" "" || continue; [[ "$RESPOSTA" =~ ^[A-Za-z0-9.+_:-]+$ ]] || continue
         confirmar "Instalar $RESPOSTA?" || continue
         secao "INSTALAÇÃO"; instalar_pacotes "$RESPOSTA" ;;
      5) perguntar "Comando" "ss" || continue; [[ "$RESPOSTA" =~ ^[A-Za-z0-9._-]+$ ]] || continue
         man "$RESPOSTA" 2>/dev/null || "$RESPOSTA" --help 2>&1 | ${PAGER:-less} ;;
      0) return ;;
    esac
    pausa
  done
}

# ═════════════════════════════════════════════════════════════════════════════
#  RELATÓRIOS SALVOS
# ═════════════════════════════════════════════════════════════════════════════
ver_relatorios() {
  [ -d "$RAIZ_REL" ] || { info "nenhum relatório em $RAIZ_REL"; pausa; return; }
  local -a dirs=() opc=(); local i
  mapfile -t dirs < <(ls -1t "$RAIZ_REL" 2>/dev/null | grep -v '^backups$' | head -30)
  [ ${#dirs[@]} -eq 0 ] && { info "nenhum relatório ainda"; pausa; return; }
  for i in "${!dirs[@]}"; do opc+=("$((i+1))" "${dirs[$i]}"); done
  menu "Relatórios" "$RAIZ_REL" "${opc[@]}" || return
  local d="$RAIZ_REL/${dirs[$((ESCOLHA-1))]}"
  local -a arqs=() o2=()
  mapfile -t arqs < <(ls -1 "$d"/*.txt 2>/dev/null)
  [ ${#arqs[@]} -eq 0 ] && { info "sem .txt em $d"; pausa; return; }
  for i in "${!arqs[@]}"; do o2+=("$((i+1))" "$(basename "${arqs[$i]}")"); done
  menu "Arquivos" "$d  (os .html abrem no navegador do Windows)" "${o2[@]}" || return
  ${PAGER:-less} "${arqs[$((ESCOLHA-1))]}" 2>/dev/null || cat "${arqs[$((ESCOLHA-1))]}"
}

# ═════════════════════════════════════════════════════════════════════════════
#  PRINCIPAL
# ═════════════════════════════════════════════════════════════════════════════
banner() {
  local onde="" fst
  fst=$(findmnt -no FSTYPE -T "$BASE" 2>/dev/null)
  case "$fst" in vfat|exfat|ntfs|ntfs3|fuseblk) onde=" (pendrive · $fst)" ;; esac
  printf '%s' "$C_C$C_NEG"
  cat <<'EOF'
   ____  _       ____
  | __ )(_) __ _| __ )  ___  ___ ___
  |  _ \| |/ _` |  _ \ / _ \/ __/ __|
  | |_) | | (_| | |_) | (_) \__ \__ \
  |____/|_|\__, |____/ \___/|___/___/
           |___/
EOF
  printf '%s' "$C_N"
  printf '  %sv%s · %s · %s%s\n' "$C_DIM" "$VERSAO" "$HOST" "$DISTRO" "$C_N"
  printf '  %srelatórios: %s%s%s\n' "$C_DIM" "$RAIZ_REL" "$onde" "$C_N"
  [ "$(id -u)" -eq 0 ] || printf '  %srodando sem root: o BigBoss pede a senha do sudo só quando precisar%s\n' "$C_DIM" "$C_N"
}

principal() {
  banner
  while :; do
    menu "BigBoss v$VERSAO" "O que vamos fazer em $HOST?" \
      1 "Diagnóstico completo (gera relatório)" \
      2 "Rede" \
      3 "Disco e armazenamento" \
      4 "Limpeza segura de disco" \
      5 "Atualizações do sistema" \
      6 "Segurança (auditoria rápida)" \
      7 "Benchmark e estresse" \
      8 "Backup e snapshot" \
      9 "Pacotes e ferramentas" \
      R "Relatórios salvos" \
      I "Instalar o BigBoss neste servidor" \
      0 "Sair" || { [ "$UI" = whiptail ] && break; continue; }
    LOG=""
    case "$ESCOLHA" in
      1) diag_completo; pausa ;;
      2) menu_rede ;;
      3) menu_disco ;;
      4) limpeza; pausa ;;
      5) menu_atualizacoes ;;
      6) seguranca; pausa ;;
      7) menu_benchmark ;;
      8) menu_backup ;;
      9) menu_pacotes ;;
      R) ver_relatorios ;;
      I) instalar_no_servidor; pausa ;;
      0) break ;;
    esac
  done
  [ -n "$SESSAO" ] && printf '\n  Relatórios desta sessão: %s\n' "$SESSAO"
  echo "  Até a próxima."
}

if [ "$MODO" = cli ]; then
  case "$ACAO" in
    diag)      diag_completo
               [ ${#CRITICOS[@]} -gt 0 ] && exit 2; [ ${#AVISOS[@]} -gt 0 ] && exit 1; exit 0 ;;
    rede)      abrir_relatorio rede; diag_rede_resumo; fechar_relatorio "Rede" ;;
    seguranca) seguranca ;;
    limpeza)   garantir_root "A estimativa"; limpeza_estimar; info "para limpar de fato, use o menu (opção 4)" ;;
    snapshot)  snapshot ;;
    backup)    [ -n "$BK_ORIG" ] && [ -n "$BK_DEST" ] || { echo "uso: --backup ORIGEM DESTINO [--manter N]" >&2; exit 64; }
               garantir_root "O backup"
               echo "[$(date '+%F %T')] backup $BK_ORIG → $BK_DEST (manter $BK_MANTER)"
               backup_pasta "$BK_ORIG" "$BK_DEST" "$BK_MANTER" || exit 1 ;;
  esac
  exit 0
fi

# ─── Modo web: chamado pelo bigboss-web.py com uma ação da lista fixa ─────────
if [ "$MODO" = web ]; then
  garantir_root "A interface web" >/dev/null 2>&1
  [ "$PODE_ROOT" = 1 ] || info "a interface web está rodando sem root: ações protegidas serão puladas (inicie com sudo)"
  case "$WEB_ACAO" in
    diag)             diag_completo ;;
    rede)             abrir_relatorio rede; diag_rede_resumo; fechar_relatorio "Rede" ;;
    porta)            rede_porta ;;
    rota)             rede_rota ;;
    dns)              rede_dns ;;
    mtu)              rede_mtu ;;
    velocidade)       rede_velocidade ;;
    descobrir)        rede_descobrir ;;
    portas)           secao "PORTAS ESCUTANDO"; if [ "$PODE_ROOT" = 1 ]; then rodar_root "" ss -tulpn; else rodar "" ss -tuln; fi ;;
    disco-uso)        diag_disco; sub "Inodes"; df -hi "${_filtros_df[@]}" 2>/dev/null | bloco ;;
    disco-maiores)    disco_maiores ;;
    disco-velocidade) disco_velocidade ;;
    smart)            secao "SMART"; diag_smart ;;
    discos)           secao "DISCOS"; rodar "" lsblk -o NAME,SIZE,TYPE,FSTYPE,LABEL,UUID,MOUNTPOINT; rodar "fstab" cat /etc/fstab ;;
    limpeza-estimar)  limpeza_estimar ;;
    limpeza)          limpeza ;;
    atu-lista)        atu_lista ;;
    atu-upgrade)      atu_instalar upgrade ;;
    atu-full)         atu_instalar full-upgrade ;;
    atu-reboot)       atu_reboot ;;
    seguranca)        seguranca ;;
    bench-cpu)        bench_cpu ;;
    bench-mem)        bench_memoria ;;
    estresse)         bench_estresse ;;
    snapshot)         snapshot ;;
    backup)           _proxima_resposta; o=$RESP_WEB; _proxima_resposta; de=$RESP_WEB; _proxima_resposta
                      secao "BACKUP"; backup_pasta "$o" "$de" "${RESP_WEB:-7}" ;;
    ferramentas)      _proxima_resposta; _validos=" curl smartmontools sysstat htop ncdu iperf3 mtr dnsutils lsof tcpdump ethtool lm-sensors sysbench stress-ng nmap whiptail "
                      _pk=(); for _n in ${RESP_WEB//,/ }; do [[ "$_validos" == *" $_n "* ]] && _pk+=("$(nome_pacote "$_n")"); done
                      if [ ${#_pk[@]} -gt 0 ]; then secao "INSTALAÇÃO"; instalar_pacotes "${_pk[@]}"; else crit "nenhuma ferramenta válida"; fi ;;
    *)                crit "ação desconhecida: $WEB_ACAO"; exit 64 ;;
  esac
  printf '@@FIM criticos=%d avisos=%d\n' "${#CRITICOS[@]}" "${#AVISOS[@]}"
  exit 0
fi

principal
