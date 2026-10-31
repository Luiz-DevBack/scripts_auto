#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
BigBoss Web — interface no navegador para o BigBoss (bigboos.sh).

    sudo python3 bigboss-web.py            só nesta máquina  → https://127.0.0.1:8765
    sudo python3 bigboss-web.py --rede     também pela rede  → https://<ip-do-servidor>:8765

Segurança:
  * Os botões só disparam AÇÕES FIXAS do bigboos.sh, com cada campo validado.
    Não existe "rodar comando livre".
  * Chave de acesso aleatória a cada execução (mostrada no terminal). Sem ela, nada responde.
  * HTTPS com certificado temporário (se houver openssl). Desliga sozinho após inatividade.
  * Só biblioteca padrão do Python 3.6+: nada para instalar.
"""
import argparse
import http.server
import ipaddress
import json
import os
import re
import secrets
import shutil
import signal
import socket
import socketserver
import ssl
import subprocess
import sys
import tempfile
import threading
import time
from urllib.parse import urlparse, parse_qs, unquote

VERSAO = "2.0.0"
BASE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(BASE, "bigboos.sh")

# ─── Ações permitidas ────────────────────────────────────────────────────────
RE_HOST = r"^[A-Za-z0-9._:-]{1,253}$"
RE_CAMINHO = r"^/[A-Za-z0-9._/ +@,-]{0,250}$"
RE_PORTAS = r"^[0-9 ]{1,80}$"
RE_NUM = r"^[0-9]{1,4}$"
RE_TAM = r"^[0-9]{1,5}[KMG]$"

LIMPEZA_ITENS = [
    ("apt", "Cache do apt/dnf + pacotes órfãos"), ("dnf", "Cache do dnf/yum + órfãos (RHEL)"),
    ("journal", "Journal acima do tamanho escolhido"), ("logs", "Logs já rotacionados com +7 dias"),
    ("docker", "Docker: cache de build + imagens soltas (nunca volumes)"), ("snap", "Revisões antigas de snaps"),
    ("miniaturas", "Cache de miniaturas dos usuários"),
]
FERRAMENTAS = [
    ("curl", "testes HTTP"), ("smartmontools", "saúde SMART"), ("sysstat", "iostat, sar"), ("htop", "processos"),
    ("ncdu", "uso de disco"), ("iperf3", "banda na rede"), ("mtr", "rota contínua"), ("dnsutils", "dig/nslookup"),
    ("lsof", "arquivos por processo"), ("tcpdump", "captura de pacotes"), ("ethtool", "placa de rede"),
    ("lm-sensors", "temperaturas"), ("sysbench", "benchmark"), ("stress-ng", "estresse"), ("nmap", "varredura"),
    ("whiptail", "menus do BigBoss"),
]


def campo(nome, rotulo, padrao="", regex=None, tipo="texto", opcoes=None):
    return {"nome": nome, "rotulo": rotulo, "padrao": padrao, "re": regex, "tipo": tipo, "opcoes": opcoes or []}


ACOES = [
    # grupo, id, título, descrição, campos, perigo (pede confirmação), texto da confirmação
    ("Diagnóstico", "diag", "Diagnóstico completo", "Sistema, hardware, CPU, memória, disco, serviços, logs, atualizações, Docker, rede e segurança. Gera relatório.", [], False, ""),
    ("Rede", "rede", "Resumo da rede", "IPs, gateway, DNS, internet e HTTPS.", [], False, ""),
    ("Rede", "porta", "Testar portas TCP", "Verifica se as portas respondem no host.", [campo("host", "Host ou IP", "192.168.0.1", RE_HOST), campo("portas", "Portas", "22 80 443 3389", RE_PORTAS)], False, ""),
    ("Rede", "rota", "Rota até um host", "mtr, traceroute ou tracepath.", [campo("host", "Destino", "8.8.8.8", RE_HOST)], False, ""),
    ("Rede", "dns", "Teste de DNS", "Resolve o nome em cada servidor DNS e compara.", [campo("nome", "Nome", "google.com", RE_HOST)], False, ""),
    ("Rede", "mtu", "Descobrir MTU", "Maior pacote sem fragmentar até o destino.", [campo("host", "Destino", "8.8.8.8", RE_HOST)], False, ""),
    ("Rede", "velocidade", "Velocidade da internet", "Download de 50 MB e upload de 20 MB (Cloudflare).", [], False, ""),
    ("Rede", "descobrir", "Descobrir hosts na rede", "Ping em toda a /24 da interface escolhida, com MAC e nome.", [campo("iface", "Interface", "1", RE_NUM, "interface")], True, "Fazer ping em todos os endereços da rede escolhida? Use só na sua rede."),
    ("Rede", "portas", "Portas abertas nesta máquina", "Tudo que está escutando (com o processo, se root).", [], False, ""),
    ("Disco", "disco-uso", "Uso e inodes", "Ocupação por partição.", [], False, ""),
    ("Disco", "disco-maiores", "Maiores pastas e arquivos", "Pastas do mesmo disco e arquivos acima de 500 MB.", [campo("pasta", "Pasta", "/", RE_CAMINHO)], False, ""),
    ("Disco", "disco-velocidade", "Velocidade do disco", "Grava e lê 1 GB (apagado no fim).", [campo("pasta", "Pasta do teste", "/var/tmp", RE_CAMINHO)], True, "Gravar um arquivo de 1 GB na pasta para medir o disco? O arquivo é apagado no fim."),
    ("Disco", "smart", "Saúde SMART", "Estado dos discos físicos.", [], False, ""),
    ("Disco", "discos", "Discos e fstab", "Partições, UUIDs e pontos de montagem.", [], False, ""),
    ("Limpeza", "limpeza-estimar", "Ver o que dá para liberar", "Só calcula — não apaga nada.", [], False, ""),
    ("Limpeza", "limpeza", "Limpar agora", "Apaga só os itens marcados. Dados, /home e volumes do Docker nunca são tocados.",
     [campo("itens", "Itens", "apt,journal,logs,docker,snap", None, "multi", LIMPEZA_ITENS), campo("journal", "Manter de journal", "200M", RE_TAM)],
     True, "Apagar agora os itens marcados? Isso não tem volta (são caches e logs antigos)."),
    ("Atualizações", "atu-lista", "Ver pendentes", "Atualiza a lista de pacotes e mostra o que há para instalar.", [], False, ""),
    ("Atualizações", "atu-upgrade", "Instalar atualizações", "upgrade — mantém seus arquivos de configuração.", [], True, "Instalar as atualizações agora? Serviços podem reiniciar durante o processo."),
    ("Atualizações", "atu-full", "Atualização completa", "full-upgrade — pode instalar ou remover pacotes.", [], True, "Rodar a atualização completa? Ela pode instalar e REMOVER pacotes. Serviços podem reiniciar."),
    ("Atualizações", "atu-reboot", "Precisa reiniciar?", "Pacotes que pedem reboot e kernel rodando × instalado.", [], False, ""),
    ("Segurança", "seguranca", "Auditoria rápida", "Contas, SSH, força bruta, firewall, portas expostas.", [], False, ""),
    ("Benchmark", "bench-cpu", "CPU", "1 núcleo e todos os núcleos.", [], False, ""),
    ("Benchmark", "bench-mem", "Memória", "Vazão de memória.", [], False, ""),
    ("Benchmark", "estresse", "Estresse de CPU", "Todos os núcleos a 100% acompanhando temperatura.", [campo("minutos", "Minutos (1–60)", "3", RE_NUM)], True, "Colocar todos os núcleos a 100%? A máquina fica lenta durante o teste."),
    ("Backup", "snapshot", "Snapshot de configuração", "/etc (sem shadow e chaves do SSH), pacotes, serviços, firewall, compose → pendrive.", [], False, ""),
    ("Backup", "backup", "Backup de uma pasta", "tar.gz com data + SHA256, mantém as N últimas cópias.",
     [campo("origem", "Pasta a copiar", "/etc", RE_CAMINHO), campo("destino", "Destino", "", RE_CAMINHO), campo("manter", "Cópias a manter", "7", RE_NUM)], True, "Criar o backup agora?"),
    ("Pacotes", "ferramentas", "Instalar ferramentas", "Ferramentas úteis de sysadmin que faltam nesta máquina.", [campo("pacotes", "Ferramentas", "", None, "multi", FERRAMENTAS)], True, "Instalar as ferramentas marcadas?"),
]
ACAO_POR_ID = {a[1]: a for a in ACOES}


def acoes_json():
    return [{"grupo": g, "id": i, "titulo": t, "desc": d, "campos": c, "perigo": p, "confirmar": cf}
            for g, i, t, d, c, p, cf in ACOES]


def validar(acao_id, valores):
    """Devolve a lista de argumentos para o bigboos.sh ou levanta ValueError."""
    if acao_id not in ACAO_POR_ID:
        raise ValueError("ação desconhecida")
    args = []
    for c in ACAO_POR_ID[acao_id][4]:
        v = str(valores.get(c["nome"], c["padrao"]) or "").strip()
        if c["tipo"] == "multi":
            permitidos = {o[0] for o in c["opcoes"]}
            itens = [x for x in v.split(",") if x]
            if not itens:
                raise ValueError("marque pelo menos um item em " + c["rotulo"])
            if any(x not in permitidos for x in itens):
                raise ValueError("item inválido em " + c["rotulo"])
            v = ",".join(itens)
        else:
            if acao_id == "backup" and c["nome"] == "destino" and not v:
                v = os.path.join(RAIZ, "backups")
            if c["re"] and not re.match(c["re"], v):
                raise ValueError("valor inválido em " + c["rotulo"])
            if c["re"] == RE_CAMINHO and ("/../" in v + "/" or v.endswith("/..")):
                raise ValueError("caminho com '..' não é aceito")
        args.append(v)
    return args


# ─── Execução (uma ação por vez) ─────────────────────────────────────────────
class Tarefa:
    def __init__(self, acao, args):
        self.id = secrets.token_hex(6)
        self.acao = acao
        self.linhas = []
        self.fim = False
        self.rc = None
        self.relatorio = None
        self.resumo = None
        self.inicio = time.time()
        env = dict(os.environ, TERM="dumb", NO_COLOR="1")
        env.setdefault("LANG", "C.UTF-8")
        self.proc = subprocess.Popen(
            ["bash", SCRIPT, "--relatorios", RAIZ, "--web", acao] + args,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, stdin=subprocess.DEVNULL,
            start_new_session=True, env=env)
        threading.Thread(target=self._ler, daemon=True).start()

    def _ler(self):
        for bruto in iter(self.proc.stdout.readline, b""):
            linha = bruto.decode("utf-8", "replace").rstrip("\n")
            if linha.startswith("@@RELATORIO "):
                caminho = linha[12:].strip()
                rel = os.path.relpath(caminho, RAIZ) if caminho.startswith(RAIZ) else None
                if rel and not rel.startswith(".."):
                    self.relatorio = "/r/" + rel.replace(os.sep, "/")
                continue
            if linha.startswith("@@FIM "):
                m = re.findall(r"(\w+)=(\d+)", linha)
                self.resumo = {k: int(v) for k, v in m}
                continue
            self.linhas.append(linha)
        self.proc.wait()
        self.rc = self.proc.returncode
        self.fim = True
        auditar("fim", self.acao, "rc=%s %.0fs" % (self.rc, time.time() - self.inicio))

    def parar(self):
        if not self.fim:
            try:
                os.killpg(self.proc.pid, 15)
                time.sleep(1)
                if self.proc.poll() is None:
                    os.killpg(self.proc.pid, 9)
            except ProcessLookupError:
                pass
            self.linhas.append("  ✖ interrompido pela interface web")


TAREFA = None
TRAVA = threading.Lock()
ULTIMO_ACESSO = time.time()


def auditar(evento, acao, detalhe=""):
    linha = "%s  %-8s %-18s %s" % (time.strftime("%Y-%m-%d %H:%M:%S"), evento, acao, detalhe)
    print("  [web] " + linha, flush=True)
    try:
        os.makedirs(RAIZ, exist_ok=True)
        with open(os.path.join(RAIZ, "web-auditoria.log"), "a", encoding="utf-8") as f:
            f.write(linha + "\n")
    except OSError:
        pass


# ─── Estado da máquina (lido direto do /proc, sem comandos) ──────────────────
_cpu_ant = None


def _cpu_pct():
    global _cpu_ant
    try:
        with open("/proc/stat") as f:
            v = [int(x) for x in f.readline().split()[1:]]
        ocioso, total = v[3] + (v[4] if len(v) > 4 else 0), sum(v)
        if _cpu_ant is None:
            _cpu_ant = (ocioso, total)
            return None
        do, dt = ocioso - _cpu_ant[0], total - _cpu_ant[1]
        _cpu_ant = (ocioso, total)
        return round(100 * (1 - do / dt), 1) if dt > 0 else None
    except (OSError, ValueError, IndexError):
        return None


def _meminfo():
    d = {}
    try:
        with open("/proc/meminfo") as f:
            for l in f:
                k, v = l.split(":", 1)
                d[k] = int(v.split()[0])
    except (OSError, ValueError):
        pass
    return d


def interfaces():
    try:
        saida = subprocess.run(["ip", "-o", "-4", "addr", "show", "scope", "global"],
                               stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, timeout=5).stdout.decode()
        # mesma lista e ordem que o rede_descobrir do bigboos.sh (sem bridges/containers)
        virtuais = ("veth", "br-", "docker", "virbr", "cni", "flannel")
        return [" ".join(l.split()[1:4:2]) for l in saida.splitlines()
                if l.strip() and not l.split()[1].startswith(virtuais)]
    except (OSError, subprocess.SubprocessError):
        return []


def distro():
    try:
        with open("/etc/os-release") as f:
            for l in f:
                if l.startswith("PRETTY_NAME="):
                    return l.split("=", 1)[1].strip().strip('"')
    except OSError:
        pass
    return "Linux"


def tem_root():
    if os.geteuid() == 0:
        return True
    try:
        return subprocess.run(["sudo", "-n", "true"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=5).returncode == 0
    except (OSError, subprocess.SubprocessError):
        return False


def estado():
    m = _meminfo()
    tot, disp = m.get("MemTotal", 0), m.get("MemAvailable", 0)
    stot, slivre = m.get("SwapTotal", 0), m.get("SwapFree", 0)
    try:
        d = shutil.disk_usage("/")
        disco = {"pct": round(100 * d.used / d.total, 1), "livre_gb": round(d.free / 2**30, 1), "total_gb": round(d.total / 2**30, 1)}
    except OSError:
        disco = None
    try:
        with open("/proc/loadavg") as f:
            carga = f.read().split()[:3]
        with open("/proc/uptime") as f:
            ligado = int(float(f.read().split()[0]))
    except OSError:
        carga, ligado = ["?"] * 3, 0
    return {
        "cpu": _cpu_pct(), "nucleos": os.cpu_count(), "carga": carga, "ligado_s": ligado,
        "mem": {"pct": round(100 * (tot - disp) / tot, 1) if tot else None, "total_gb": round(tot / 2**20, 1), "disp_gb": round(disp / 2**20, 1)},
        "swap_pct": round(100 * (stot - slivre) / stot, 1) if stot else 0,
        "disco": disco, "hora": time.strftime("%d/%m/%Y %H:%M:%S"),
        "tarefa": None if TAREFA is None else {"id": TAREFA.id, "acao": TAREFA.acao, "fim": TAREFA.fim},
    }


def relatorios():
    lista = []
    if os.path.isdir(RAIZ):
        for nome in sorted(os.listdir(RAIZ), reverse=True):
            p = os.path.join(RAIZ, nome)
            if not os.path.isdir(p) or nome == "backups":
                continue
            arqs = sorted(a for a in os.listdir(p) if a.endswith((".html", ".txt")))
            if arqs:
                lista.append({"sessao": nome, "arquivos": arqs})
    return lista[:40]


# ─── HTTP ────────────────────────────────────────────────────────────────────
class Servidor(socketserver.ThreadingMixIn, http.server.HTTPServer):
    daemon_threads = True
    allow_reuse_address = True


NOMES_LOCAIS = set()


def host_aceito(cab_host):
    """Evita DNS rebinding: só aceita IP literal, localhost ou o nome desta máquina."""
    h = (cab_host or "").strip()
    if h.startswith("["):
        h = h[1:h.find("]")]
    elif h.count(":") == 1:
        h = h.split(":")[0]
    h = h.lower()
    if h in NOMES_LOCAIS:
        return True
    try:
        ipaddress.ip_address(h)
        return True
    except ValueError:
        return False


class Manipulador(http.server.BaseHTTPRequestHandler):
    server_version = "BigBoss"
    sys_version = ""

    def log_message(self, fmt, *a):
        pass

    # utilidades
    def _cabecalhos_seguros(self):
        self.send_header("X-Frame-Options", "DENY")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.send_header("Cache-Control", "no-store")

    def _json(self, obj, codigo=200):
        corpo = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self._cabecalhos_seguros()
        self.end_headers()
        self.wfile.write(corpo)

    def _texto(self, codigo, msg):
        corpo = msg.encode("utf-8")
        self.send_response(codigo)
        self.send_header("Content-Type", "text/plain; charset=utf-8")
        self.send_header("Content-Length", str(len(corpo)))
        self._cabecalhos_seguros()
        self.end_headers()
        self.wfile.write(corpo)

    def _cookie_ok(self):
        for parte in (self.headers.get("Cookie") or "").split(";"):
            k, _, v = parte.strip().partition("=")
            if k == "bb" and secrets.compare_digest(v, TOKEN):
                return True
        return False

    def _api_ok(self):
        return self._cookie_ok() and secrets.compare_digest(self.headers.get("X-Token", ""), TOKEN)

    def _preambulo(self):
        global ULTIMO_ACESSO
        ULTIMO_ACESSO = time.time()
        if not host_aceito(self.headers.get("Host")):
            self._texto(421, "Host não permitido.")
            return False
        return True

    # rotas
    def do_GET(self):
        if not self._preambulo():
            return
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == "/":
            t = (q.get("t") or [""])[0]
            if t and secrets.compare_digest(t, TOKEN):
                self.send_response(303)
                self.send_header("Set-Cookie", "bb=%s; HttpOnly; SameSite=Strict; Path=/%s" % (TOKEN, "; Secure" if HTTPS else ""))
                self.send_header("Location", "/")
                self._cabecalhos_seguros()
                self.end_headers()
                auditar("login", "-", self.client_address[0])
                return
            if not self._cookie_ok():
                self._texto(401, "BigBoss: acesso negado.\nAbra a URL completa (com ?t=...) mostrada no terminal onde o bigboss-web.py está rodando.")
                return
            corpo = PAGINA.replace("__TOKEN__", TOKEN).replace("__VERSAO__", VERSAO).encode("utf-8")
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.send_header("Content-Length", str(len(corpo)))
            self.send_header("Content-Security-Policy", "default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; img-src 'self' data:; frame-ancestors 'none'")
            self._cabecalhos_seguros()
            self.end_headers()
            self.wfile.write(corpo)
            return
        if u.path.startswith("/r/"):
            if not self._cookie_ok():
                self._texto(401, "acesso negado")
                return
            alvo = os.path.realpath(os.path.join(RAIZ, unquote(u.path[3:])))
            raiz = os.path.realpath(RAIZ)
            if os.path.commonpath([alvo, raiz]) != raiz or not os.path.isfile(alvo) or not alvo.endswith((".html", ".txt")):
                self._texto(404, "não encontrado")
                return
            with open(alvo, "rb") as f:
                corpo = f.read()
            self.send_response(200)
            self.send_header("Content-Type", ("text/html" if alvo.endswith(".html") else "text/plain") + "; charset=utf-8")
            self.send_header("Content-Length", str(len(corpo)))
            self.send_header("Content-Security-Policy", "default-src 'none'; style-src 'unsafe-inline'")
            self._cabecalhos_seguros()
            self.end_headers()
            self.wfile.write(corpo)
            return
        if not u.path.startswith("/api/"):
            self._texto(404, "não encontrado")
            return
        if not self._api_ok():
            self._json({"erro": "não autenticado"}, 401)
            return
        if u.path == "/api/info":
            self._json({"host": socket.gethostname(), "distro": distro(), "kernel": os.uname().release,
                        "root": tem_root(), "acoes": acoes_json(), "interfaces": interfaces(),
                        "relatorios_em": RAIZ, "versao": VERSAO})
        elif u.path == "/api/estado":
            self._json(estado())
        elif u.path == "/api/tarefa":
            t = TAREFA
            if t is None or (q.get("id") or [""])[0] != t.id:
                self._json({"erro": "tarefa não encontrada"}, 404)
                return
            desde = int((q.get("desde") or ["0"])[0] or 0)
            self._json({"linhas": t.linhas[desde:], "total": len(t.linhas), "fim": t.fim, "rc": t.rc,
                        "relatorio": t.relatorio, "resumo": t.resumo, "segundos": int(time.time() - t.inicio)})
        elif u.path == "/api/relatorios":
            self._json(relatorios())
        else:
            self._json({"erro": "rota desconhecida"}, 404)

    def do_POST(self):
        global TAREFA
        if not self._preambulo():
            return
        if not self._api_ok():
            self._json({"erro": "não autenticado"}, 401)
            return
        try:
            tam = min(int(self.headers.get("Content-Length", 0)), 16384)
            dados = json.loads(self.rfile.read(tam).decode("utf-8") or "{}")
        except (ValueError, UnicodeDecodeError):
            self._json({"erro": "JSON inválido"}, 400)
            return
        caminho = urlparse(self.path).path
        if caminho == "/api/executar":
            with TRAVA:
                if TAREFA is not None and not TAREFA.fim:
                    self._json({"erro": "já existe uma ação rodando (%s)" % TAREFA.acao}, 409)
                    return
                try:
                    acao = str(dados.get("acao", ""))
                    args = validar(acao, dados.get("valores") or {})
                except ValueError as e:
                    self._json({"erro": str(e)}, 400)
                    return
                TAREFA = Tarefa(acao, args)
                auditar("executar", acao, "%s %s" % (self.client_address[0], " ".join(args)))
                self._json({"id": TAREFA.id})
        elif caminho == "/api/parar":
            if TAREFA is not None and not TAREFA.fim:
                TAREFA.parar()
                auditar("parar", TAREFA.acao, self.client_address[0])
            self._json({"ok": True})
        else:
            self._json({"erro": "rota desconhecida"}, 404)


# ─── Página (HTML + CSS + JS embutidos) ──────────────────────────────────────
PAGINA = r"""<!doctype html><html lang="pt-BR"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>BigBoss Web</title>
<style>
:root{--bg:#0e1116;--p1:#151a22;--p2:#1c222c;--bd:#2a3240;--tx:#e6e9ef;--mut:#8b96a8;--ac:#4f8cff;--ok:#2fb36d;--av:#e0a526;--cr:#ef5350;--ci:#56c7d9}
@media (prefers-color-scheme:light){:root{--bg:#f3f5f8;--p1:#fff;--p2:#f7f8fa;--bd:#dde2e8;--tx:#1b2230;--mut:#677386;--ac:#2563eb;--ci:#0e7490}}
*{box-sizing:border-box}html,body{margin:0;height:100%}body{background:var(--bg);color:var(--tx);font:14px/1.45 system-ui,-apple-system,"Segoe UI",sans-serif}
button,input,select{font:inherit;color:inherit}
header{display:flex;flex-wrap:wrap;align-items:center;gap:14px 22px;padding:12px 18px;background:var(--p1);border-bottom:1px solid var(--bd);position:sticky;top:0;z-index:5}
.marca{font-weight:800;letter-spacing:.04em;font-size:17px}.marca span{color:var(--ac)}
.maq{color:var(--mut);font-size:13px}.maq b{color:var(--tx)}
.selo{padding:2px 9px;border-radius:999px;font-size:12px;font-weight:700}.s-ok{background:rgba(47,179,109,.15);color:var(--ok)}.s-av{background:rgba(224,165,38,.15);color:var(--av)}
.gauges{display:flex;gap:16px;margin-left:auto;flex-wrap:wrap}
.g{min-width:92px}.g .r{font-size:11px;color:var(--mut);text-transform:uppercase;letter-spacing:.06em}.g .v{font-weight:700;font-variant-numeric:tabular-nums}
.barra{height:4px;background:var(--p2);border-radius:3px;margin-top:3px;overflow:hidden}.barra i{display:block;height:100%;background:var(--ok);width:0;transition:width .6s}
.app{display:grid;grid-template-columns:200px 1fr;min-height:calc(100% - 64px)}
nav{background:var(--p1);border-right:1px solid var(--bd);padding:12px 8px}
nav button{display:block;width:100%;text-align:left;background:none;border:0;padding:9px 12px;border-radius:8px;cursor:pointer;color:var(--mut)}
nav button:hover{background:var(--p2);color:var(--tx)}nav button.on{background:var(--p2);color:var(--tx);font-weight:600;box-shadow:inset 3px 0 0 var(--ac)}
main{padding:18px;display:grid;grid-template-columns:minmax(300px,1fr) minmax(340px,1.25fr);gap:18px;align-items:start}
.cards{display:grid;gap:12px}
.card{background:var(--p1);border:1px solid var(--bd);border-radius:12px;padding:14px 16px}
.card h3{margin:0 0 4px;font-size:15px}.card p{margin:0 0 10px;color:var(--mut);font-size:13px}
.campo{display:grid;gap:4px;margin:0 0 10px}.campo label{font-size:12px;color:var(--mut)}
.campo input,.campo select{background:var(--p2);border:1px solid var(--bd);border-radius:8px;padding:8px 10px;width:100%}
.multi{display:grid;grid-template-columns:repeat(auto-fill,minmax(190px,1fr));gap:4px 10px;font-size:13px}.multi label{display:flex;gap:6px;align-items:flex-start;color:var(--tx);cursor:pointer}
.btn{background:var(--ac);color:#fff;border:0;border-radius:8px;padding:8px 16px;font-weight:600;cursor:pointer}
.btn.perigo{background:var(--cr)}.btn.sec{background:var(--p2);color:var(--tx);border:1px solid var(--bd)}.btn:disabled{opacity:.45;cursor:not-allowed}
.console{background:var(--p1);border:1px solid var(--bd);border-radius:12px;position:sticky;top:82px;display:flex;flex-direction:column;max-height:calc(100vh - 100px)}
.console .topo{display:flex;align-items:center;gap:10px;padding:10px 14px;border-bottom:1px solid var(--bd)}
.console .topo b{flex:1}.tempo{color:var(--mut);font-variant-numeric:tabular-nums;font-size:12px}
#saida{margin:0;padding:12px 14px;overflow:auto;font:12.5px/1.5 ui-monospace,Menlo,Consolas,monospace;white-space:pre-wrap;word-break:break-word;flex:1;min-height:320px}
#saida .sec{color:var(--ac);font-weight:700;margin-top:6px}#saida .sub{color:var(--ci)}#saida .ok{color:var(--ok)}#saida .av{color:var(--av)}#saida .cr{color:var(--cr);font-weight:700}#saida .in{color:var(--mut)}
.res{padding:12px 14px;border-top:1px solid var(--bd);display:none;gap:10px;align-items:center;flex-wrap:wrap}.res.on{display:flex}
.res .tag{padding:4px 10px;border-radius:6px;font-weight:700}.t-ok{background:rgba(47,179,109,.15);color:var(--ok)}.t-av{background:rgba(224,165,38,.15);color:var(--av)}.t-cr{background:rgba(239,83,80,.15);color:var(--cr)}
a{color:var(--ac)}
.rel{background:var(--p1);border:1px solid var(--bd);border-radius:12px;padding:12px 16px}.rel h4{margin:6px 0 4px;font-size:13px}.rel a{margin-right:12px;font-size:13px}
.vazio{color:var(--mut);padding:20px;text-align:center}
dialog{background:var(--p1);color:var(--tx);border:1px solid var(--bd);border-radius:12px;max-width:440px;padding:20px}dialog::backdrop{background:rgba(0,0,0,.55)}
dialog .acoes{display:flex;gap:10px;justify-content:flex-end;margin-top:18px}
.aviso-root{background:rgba(224,165,38,.12);border:1px solid rgba(224,165,38,.4);color:var(--av);border-radius:10px;padding:10px 14px;margin:0 0 12px;font-size:13px}
@media (max-width:980px){main{grid-template-columns:1fr}.console{position:static;max-height:none}}
@media (max-width:640px){.app{grid-template-columns:1fr}nav{display:flex;overflow-x:auto;gap:4px;border-right:0;border-bottom:1px solid var(--bd)}nav button{white-space:nowrap;width:auto}.gauges{margin-left:0}main{padding:12px}}
</style></head><body>
<header>
  <div class="marca">BIG<span>BOSS</span> <small style="color:var(--mut);font-weight:400">web v__VERSAO__</small></div>
  <div class="maq" id="maq">carregando…</div>
  <div class="gauges">
    <div class="g"><div class="r">CPU</div><div class="v" id="g-cpu">–</div><div class="barra"><i id="b-cpu"></i></div></div>
    <div class="g"><div class="r">Memória</div><div class="v" id="g-mem">–</div><div class="barra"><i id="b-mem"></i></div></div>
    <div class="g"><div class="r">Disco /</div><div class="v" id="g-disco">–</div><div class="barra"><i id="b-disco"></i></div></div>
    <div class="g"><div class="r">Carga</div><div class="v" id="g-carga">–</div></div>
    <div class="g"><div class="r">Ligado</div><div class="v" id="g-ligado">–</div></div>
  </div>
</header>
<div class="app">
  <nav id="nav"></nav>
  <main>
    <section><div id="avisoRoot"></div><div class="cards" id="cards"></div></section>
    <section class="console">
      <div class="topo"><b id="titulo">Console</b><span class="tempo" id="tempo"></span><button class="btn sec" id="parar" disabled>Parar</button></div>
      <pre id="saida"><span class="in">Escolha uma ação à esquerda. A saída aparece aqui, ao vivo.</span></pre>
      <div class="res" id="res"></div>
    </section>
  </main>
</div>
<dialog id="dlg"><h3 id="dlgT">Confirmar</h3><p id="dlgM"></p><div class="acoes"><button class="btn sec" id="dlgN">Cancelar</button><button class="btn perigo" id="dlgS">Executar</button></div></dialog>
<script>
const TOKEN="__TOKEN__";
let INFO=null, GRUPO="Diagnóstico", TID=null, VISTO=0, RODANDO=false;
const $=s=>document.querySelector(s);
const api=(u,o={})=>fetch(u,Object.assign({headers:{"X-Token":TOKEN,"Content-Type":"application/json"}},o)).then(async r=>{const j=await r.json().catch(()=>({}));if(!r.ok)throw new Error(j.erro||r.status);return j});
const el=(t,a={},...f)=>{const e=document.createElement(t);for(const k in a){if(k==="class")e.className=a[k];else if(k.startsWith("on"))e.addEventListener(k.slice(2),a[k]);else e.setAttribute(k,a[k])}f.forEach(x=>e.append(x));return e};
function dur(s){const d=Math.floor(s/86400),h=Math.floor(s%86400/3600),m=Math.floor(s%3600/60);return d?`${d}d ${h}h`:h?`${h}h ${m}m`:`${m}m`}
function cor(p){return p>=90?"var(--cr)":p>=80?"var(--av)":"var(--ok)"}
function gauge(id,p,txt){$("#g-"+id).textContent=txt;const b=$("#b-"+id);if(b){b.style.width=(p||0)+"%";b.style.background=cor(p||0)}}
async function estado(){try{const e=await api("/api/estado");
  gauge("cpu",e.cpu,e.cpu==null?"…":e.cpu+"%");
  gauge("mem",e.mem.pct,e.mem.pct+"% · "+e.mem.disp_gb+" GB livres");
  if(e.disco)gauge("disco",e.disco.pct,e.disco.pct+"% · "+e.disco.livre_gb+" GB livres");
  $("#g-carga").textContent=e.carga.join(" ")+" ("+e.nucleos+" núcl.)";$("#g-ligado").textContent=dur(e.ligado_s);
  if(e.tarefa&&!e.tarefa.fim&&!TID){TID=e.tarefa.id;VISTO=0;$("#titulo").textContent=e.tarefa.acao;$("#saida").textContent="";acompanhar()}
}catch(x){}}
function grupos(){return [...new Set(INFO.acoes.map(a=>a.grupo)),"Relatórios"]}
function menu(){const n=$("#nav");n.innerHTML="";grupos().forEach(g=>n.append(el("button",{class:g===GRUPO?"on":"",onclick:()=>{GRUPO=g;menu();cards()}},g)))}
function campoEl(a,c){
  const id=a.id+"-"+c.nome, w=el("div",{class:"campo"},el("label",{for:id},c.rotulo));
  if(c.tipo==="multi"){const m=el("div",{class:"multi",id});const pad=(c.padrao||"").split(",");
    c.opcoes.forEach(([v,r])=>{const cb=el("input",{type:"checkbox",value:v});if(pad.includes(v))cb.checked=true;m.append(el("label",{},cb,el("span",{},v+" — "+r)))});w.append(m)}
  else if(c.tipo==="interface"){const s=el("select",{id});(INFO.interfaces.length?INFO.interfaces:["(nenhuma)"]).forEach((x,i)=>s.append(el("option",{value:String(i+1)},x)));w.append(s)}
  else{let pad=c.padrao;if(a.id==="backup"&&c.nome==="destino")pad=INFO.relatorios_em+"/backups";w.append(el("input",{id,value:pad,autocomplete:"off",spellcheck:"false"}))}
  return w}
function valores(a){const v={};a.campos.forEach(c=>{const e=document.getElementById(a.id+"-"+c.nome);
  v[c.nome]=c.tipo==="multi"?[...e.querySelectorAll("input:checked")].map(x=>x.value).join(","):e.value});return v}
function cards(){const box=$("#cards");box.innerHTML="";
  if(GRUPO==="Relatórios"){return relatorios(box)}
  INFO.acoes.filter(a=>a.grupo===GRUPO).forEach(a=>{
    const b=el("button",{class:"btn"+(a.perigo?" perigo":""),onclick:()=>disparar(a)},a.perigo?"Executar…":"Executar");
    const c=el("div",{class:"card"},el("h3",{},a.titulo),el("p",{},a.desc));a.campos.forEach(f=>c.append(campoEl(a,f)));c.append(b);box.append(c)});
  travar()}
async function relatorios(box){const r=await api("/api/relatorios");const d=el("div",{class:"rel"},el("p",{style:"color:var(--mut);margin:0 0 6px"},"Pasta: "+INFO.relatorios_em));
  if(!r.length)d.append(el("div",{class:"vazio"},"Nenhum relatório ainda."));
  r.forEach(s=>{d.append(el("h4",{},s.sessao));const l=el("div");s.arquivos.forEach(a=>l.append(el("a",{href:"/r/"+encodeURIComponent(s.sessao)+"/"+encodeURIComponent(a),target:"_blank",rel:"noopener"},a)));d.append(l)});box.append(d)}
function travar(){document.querySelectorAll(".card .btn").forEach(b=>b.disabled=RODANDO);$("#parar").disabled=!RODANDO}
function confirmar(t,m){return new Promise(ok=>{$("#dlgT").textContent=t;$("#dlgM").textContent=m;const d=$("#dlg");
  const fim=v=>{d.close();$("#dlgS").onclick=$("#dlgN").onclick=null;ok(v)};$("#dlgS").onclick=()=>fim(true);$("#dlgN").onclick=()=>fim(false);d.showModal()})}
async function disparar(a){const v=valores(a);
  if(a.perigo&&!await confirmar(a.titulo,a.confirmar))return;
  try{const r=await api("/api/executar",{method:"POST",body:JSON.stringify({acao:a.id,valores:v})});
    TID=r.id;VISTO=0;$("#titulo").textContent=a.titulo;$("#saida").textContent="";$("#res").className="res";acompanhar()}
  catch(x){alerta(x.message)}}
function alerta(m){const s=$("#saida");s.append(el("div",{class:"cr"},"✖ "+m))}
function classe(l){if(/━━━/.test(l))return"sec";if(/^\s*✖/.test(l))return"cr";if(/^\s*▲/.test(l))return"av";if(/^\s*✔/.test(l))return"ok";if(/^▸/.test(l))return"sub";if(/^\s*•/.test(l))return"in";if(/██/.test(l))return /crítico/.test(l)?"cr":/aviso/.test(l)?"av":"ok";return""}
async function acompanhar(){RODANDO=true;travar();const s=$("#saida");
  while(TID){let j;try{j=await api("/api/tarefa?id="+TID+"&desde="+VISTO)}catch(x){await new Promise(r=>setTimeout(r,1500));continue}
    const fundo=s.scrollTop+s.clientHeight>=s.scrollHeight-30;
    j.linhas.forEach(l=>s.append(el("div",{class:classe(l)},l||" ")));VISTO=j.total;if(fundo)s.scrollTop=s.scrollHeight;
    $("#tempo").textContent=j.segundos+" s";
    if(j.fim){fim(j);break}await new Promise(r=>setTimeout(r,700))}
  RODANDO=false;TID=null;travar()}
function fim(j){const r=$("#res");r.innerHTML="";const z=j.resumo||{};let t,c;
  if(z.criticos>0){t=z.criticos+" crítico(s) · "+(z.avisos||0)+" aviso(s)";c="t-cr"}else if(z.avisos>0){t=z.avisos+" aviso(s)";c="t-av"}else{t=j.rc===0?"Concluído":"Terminou (código "+j.rc+")";c=j.rc===0?"t-ok":"t-av"}
  r.append(el("span",{class:"tag "+c},t));if(j.relatorio)r.append(el("a",{href:j.relatorio,target:"_blank",rel:"noopener"},"Abrir relatório HTML ↗"));r.className="res on"}
$("#parar").onclick=async()=>{if(await confirmar("Parar","Interromper a ação em andamento?"))api("/api/parar",{method:"POST",body:"{}"})};
(async()=>{INFO=await api("/api/info");
  $("#maq").innerHTML="";$("#maq").append(el("b",{},INFO.host)," · "+INFO.distro+" · "+INFO.kernel+" ",el("span",{class:"selo "+(INFO.root?"s-ok":"s-av")},INFO.root?"root":"sem root"));
  if(!INFO.root)$("#avisoRoot").append(el("div",{class:"aviso-root"},"Rodando sem root: SMART, limpeza, atualizações e partes da auditoria serão puladas. Para tudo, inicie com: sudo python3 bigboss-web.py"));
  menu();cards();estado();setInterval(estado,4000)})();
</script></body></html>"""


# ─── Principal ───────────────────────────────────────────────────────────────
def gerar_certificado(pasta):
    if not shutil.which("openssl"):
        return None
    cert, chave = os.path.join(pasta, "c.pem"), os.path.join(pasta, "k.pem")
    r = subprocess.run(["openssl", "req", "-x509", "-newkey", "rsa:2048", "-nodes", "-keyout", chave, "-out", cert,
                        "-days", "2", "-subj", "/CN=bigboss"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return (cert, chave) if r.returncode == 0 else None


def main():
    global TOKEN, RAIZ, HTTPS
    ap = argparse.ArgumentParser(description="BigBoss Web — interface no navegador para o bigboos.sh")
    ap.add_argument("--rede", action="store_true", help="aceitar conexões da rede (padrão: só esta máquina)")
    ap.add_argument("--ip", default=None, help="IP específico para escutar (ex.: 192.168.0.210)")
    ap.add_argument("--porta", type=int, default=8765)
    ap.add_argument("--sem-https", action="store_true", help="usar HTTP puro (a chave trafega sem criptografia)")
    ap.add_argument("--inativo", type=int, default=60, help="minutos sem uso até desligar sozinho (0 = nunca)")
    ap.add_argument("--relatorios", default=None, help="pasta dos relatórios (padrão: relatorios/ ao lado do script)")
    a = ap.parse_args()

    if not os.path.isfile(SCRIPT):
        sys.exit("bigboos.sh não encontrado em " + BASE)
    RAIZ = os.path.abspath(a.relatorios or (os.path.join(os.path.expanduser("~"), "bigboss-relatorios") if BASE.startswith("/usr/") else os.path.join(BASE, "relatorios")))
    try:
        os.makedirs(RAIZ, exist_ok=True)
    except OSError:
        RAIZ = "/tmp/bigboss-relatorios"
        os.makedirs(RAIZ, exist_ok=True)
    TOKEN = secrets.token_urlsafe(18)
    nome = socket.gethostname().lower()
    NOMES_LOCAIS.update({"localhost", nome, nome.split(".")[0], socket.getfqdn().lower()})

    ip = a.ip or ("0.0.0.0" if a.rede else "127.0.0.1")
    srv = None
    for porta in range(a.porta, a.porta + 10):
        try:
            srv = Servidor((ip, porta), Manipulador)
            break
        except OSError:
            continue
    if srv is None:
        sys.exit("nenhuma porta livre entre %d e %d" % (a.porta, a.porta + 9))

    tmp = tempfile.mkdtemp(prefix="bigboss-web-")
    HTTPS = False
    if not a.sem_https:
        par = gerar_certificado(tmp)
        if par:
            ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
            ctx.load_cert_chain(*par)
            srv.socket = ctx.wrap_socket(srv.socket, server_side=True)
            HTTPS = True
        else:
            print("  ! openssl não encontrado: usando HTTP (use só em rede confiável ou por túnel SSH)")
    # o certificado já está na memória: apaga a chave do disco agora (não sobra nem com kill -9)
    shutil.rmtree(tmp, ignore_errors=True)
    esquema = "https" if HTTPS else "http"
    porta = srv.server_address[1]

    print("\n  BIGBOSS WEB v%s — %s" % (VERSAO, socket.gethostname()))
    print("  " + ("root ✔" if os.geteuid() == 0 else "sem root (inicie com sudo para ter tudo)"))
    if ip in ("0.0.0.0",):
        enderecos = [i.split()[1].split("/")[0] for i in interfaces()] or ["<ip-desta-máquina>"]
    else:
        enderecos = [ip]
    print("\n  Abra no navegador (a chave vale só nesta execução):")
    for e in enderecos:
        print("    %s://%s:%d/?t=%s" % (esquema, e, porta, TOKEN))
    if ip == "127.0.0.1":
        print("\n  Só esta máquina acessa. Do seu notebook, faça um túnel:")
        print("    ssh -L %d:127.0.0.1:%d %s@<ip-do-servidor>   e abra a URL acima no notebook" % (porta, porta, os.environ.get("SUDO_USER") or os.environ.get("USER", "usuario")))
        print("  ou reinicie com --rede para aceitar conexões da rede.")
    if HTTPS:
        print("\n  O certificado é temporário: o navegador vai avisar — clique em 'Avançado' › 'Continuar'.")
    print("  Relatórios: %s\n  Ctrl+C para encerrar.%s\n" % (RAIZ, "" if not a.inativo else " Desliga sozinho após %d min sem uso." % a.inativo))

    def vigia():
        while a.inativo:
            time.sleep(30)
            ocupado = TAREFA is not None and not TAREFA.fim
            if not ocupado and time.time() - ULTIMO_ACESSO > a.inativo * 60:
                print("  [web] %d min sem uso — encerrando." % a.inativo, flush=True)
                srv.shutdown()
                return
    threading.Thread(target=vigia, daemon=True).start()

    def encerrar(*_):
        raise KeyboardInterrupt
    # kill/pkill/systemctl e queda do SSH encerram igual ao Ctrl+C (para a tarefa e registra);
    # com nohup o SIGHUP vem ignorado e continua assim
    signal.signal(signal.SIGTERM, encerrar)
    if signal.getsignal(signal.SIGHUP) != signal.SIG_IGN:
        signal.signal(signal.SIGHUP, encerrar)
    auditar("inicio", "-", "%s://%s:%d" % (esquema, ip, porta))
    try:
        srv.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        if TAREFA is not None and not TAREFA.fim:
            TAREFA.parar()
        srv.server_close()
        shutil.rmtree(tmp, ignore_errors=True)
        auditar("fim-web", "-", "")
        print("\n  BigBoss Web encerrado.")


TOKEN = ""
RAIZ = ""
HTTPS = False

if __name__ == "__main__":
    main()
