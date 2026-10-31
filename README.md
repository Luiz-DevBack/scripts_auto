# BigBoss v2 — canivete de sysadmin para rodar do pendrive

Um único script Bash (`bigboos.sh`) para levar no pendrive e rodar em qualquer servidor ou
estação **Debian/Ubuntu** (RHEL/Fedora/Rocky com suporte parcial). Em poucos minutos ele diz
**o que está errado na máquina**, testa rede, disco e hardware, limpa espaço com segurança,
atualiza o sistema, faz backup e tira uma "foto" da configuração. Tudo fica salvo em
**relatórios `.txt` e `.html` no próprio pendrive**.

```
   ____  _       ____
  | __ )(_) __ _| __ )  ___  ___ ___
  |  _ \| |/ _` |  _ \ / _ \/ __/ __|
  | |_) | | (_| | |_) | (_) \__ \__ \
  |____/|_|\__, |____/ \___/|___/___/
           |___/
```

**Princípios**

- **Só lê por padrão.** Tudo que altera o sistema (limpeza, atualização, instalação, cron) mostra
  o que vai fazer e pede confirmação. Reiniciar a máquina, ele nunca faz.
- **Nada para instalar.** Usa o que a máquina já tem. Se faltar uma ferramenta, o teste é pulado ou
  usa uma alternativa (ex.: sem `sysbench` → `openssl speed`; sem `whiptail` → menus em texto).
- **Root só quando precisa.** Roda como usuário comum e pede a senha do `sudo` apenas na hora em que
  uma verificação exige.
- **Resultado que dá para mandar.** Cada ação gera um relatório com semáforo (✔ OK / ▲ aviso /
  ✖ crítico) em texto e em HTML (abre no navegador, tema claro/escuro).

---

## Sumário

- [Começando](#começando)
- [Montando o pendrive](#montando-o-pendrive)
- [Menu](#menu)
- [O que o diagnóstico verifica](#o-que-o-diagnóstico-verifica)
- [Módulos](#módulos)
- [Linha de comando e automação](#linha-de-comando-e-automação)
- [Relatórios](#relatórios)
- [Segurança e cuidados](#segurança-e-cuidados)
- [Ferramentas opcionais](#ferramentas-opcionais)
- [Problemas comuns](#problemas-comuns)
- [Estrutura do repositório](#estrutura-do-repositório)

---

## Começando

```bash
# do pendrive (funciona mesmo se o pendrive estiver montado com noexec)
bash /media/$USER/PENDRIVE/BigBoss/bigboos.sh

# ou direto do repositório
git clone https://github.com/Luiz-DevBack/scripts_auto.git
bash scripts_auto/bigboos.sh
```

Requisitos: `bash` 4+ e os utilitários básicos do Linux (`coreutils`, `procps`, `iproute2`).
Recomendado: `whiptail` (menus em janela; já vem no Debian/Ubuntu).

---

## Montando o pendrive

```
PENDRIVE/
└── BigBoss/
    ├── bigboos.sh       ← o script
    ├── README.md
    ├── pacotes/         ← .deb/.rpm para instalar offline (opcional)
    └── relatorios/      ← criada sozinha: <host>_<data>/diagnostico.txt|.html, snapshot/, backups/
```

- Qualquer sistema de arquivos serve (FAT32, exFAT, NTFS, ext4). Em FAT/exFAT/NTFS o arquivo
  perde a permissão de execução — por isso rode sempre com **`bash bigboos.sh`**.
- **Edite o script só com editor que salve em LF** (VS Code, Notepad++). Salvo com quebra de linha
  do Windows (CRLF), o Bash quebra com erros do tipo `$'\r': command not found`. Para consertar:
  `sed -i 's/\r$//' bigboos.sh`.
- Se o pendrive estiver só leitura, os relatórios vão para `/tmp/bigboss-relatorios/`.

---

## Menu

```
  1  Diagnóstico completo (gera relatório)
  2  Rede
  3  Disco e armazenamento
  4  Limpeza segura de disco
  5  Atualizações do sistema
  6  Segurança (auditoria rápida)
  7  Benchmark e estresse
  8  Backup e snapshot
  9  Pacotes e ferramentas
  R  Relatórios salvos
  I  Instalar o BigBoss neste servidor
  0  Sair
```

Com `whiptail` os menus abrem em janela (setas + Enter, Esc volta). Sem ele — ou com `--texto` —
viram menus numerados no terminal.

---

## O que o diagnóstico verifica

| Área | Verificações | Gera alerta quando |
|------|--------------|--------------------|
| **Sistema** | distro, kernel, virtualização, tempo ligado, NTP | relógio fora do NTP · mais de 180 dias sem reboot · reboot pendente |
| **Hardware** | CPU, RAM, fabricante/modelo/nº de série/BIOS (root), discos, temperatura, bateria, SMART | temp ≥ 75 °C (aviso) / ≥ 85 °C (crítico) · bateria < 60% da original · SMART falhando · setores realocados/pendentes |
| **CPU e processos** | carga 1/5/15, top 8 por CPU e por memória, zumbis | carga > nº de núcleos (aviso) / > 2× (crítico) |
| **Memória** | total, disponível, swap, mortes por OOM | < 20% livre (aviso) / < 10% (crítico) · swap alta **com** pouca RAM · OOM desde o boot |
| **Disco** | uso por partição, inodes, `/` somente leitura | ≥ 80% (aviso) / ≥ 90% (crítico) · inodes ≥ 90% · `/` em read-only |
| **Serviços** | unidades systemd rodando e com falha | qualquer unidade em falha |
| **Logs** | erros do journal desde o boot, agrupados pelos que mais se repetem | **disco encheu** (`No space left on device`) · erros de I/O/filesystem · segfaults · > 200 erros |
| **Atualizações** | pendentes, de segurança, idade da lista, atualização automática | atualizações de segurança pendentes · lista com mais de 14 dias |
| **Docker** | containers, unhealthy, em loop de reinício, espaço | container reiniciando em loop (crítico) · unhealthy · ≥ 5 GB de cache de build |
| **Rede** | interfaces (sem as virtuais do Docker), rotas, gateway, DNS, internet, HTTPS | sem gateway · DNS não resolve (crítico) · sem internet/HTTPS |
| **Segurança** | contas UID 0, contas sem senha, SSH (root/senha/porta), falhas de login 24 h, firewall, portas expostas, `/etc` gravável | UID 0 extra / conta sem senha (crítico) · `PermitRootLogin yes` · > 100 falhas SSH/24 h · sem firewall |

O `--diag` termina com **código de saída 0** (tudo ok), **1** (avisos) ou **2** (críticos) — dá
para usar em cron/monitoramento.

---

## Módulos

### Rede
Resumo (IP, gateway, DNS, internet) · **testar portas TCP** de um host (com latência) · rota até um
host (`mtr` → `traceroute` → `tracepath`) · **descobrir hosts na rede local** (ping na /24, com MAC e
nome) · **velocidade da internet** (download/upload via Cloudflare, só com `curl`) · **teste de DNS**
comparando cada servidor configurado com 1.1.1.1 e 8.8.8.8 · **descobrir o MTU** do caminho (pega
VPN/PPPoE que travam sites) · portas abertas nesta máquina (com o processo, se root) · banda entre
duas máquinas com `iperf3` (servidor ou cliente).

### Disco
Uso e inodes · **maiores pastas e arquivos** (> 500 MB) de qualquer caminho · SMART · **velocidade
de escrita/leitura** (1 GB com `fdatasync`; com root, limpa o cache antes de medir a leitura; avisa
se a pasta estiver em RAM) · discos, UUIDs e `fstab`.

### Limpeza segura
Mostra **antes** o que dá para liberar e deixa marcar item a item:

| Item | O que faz |
|------|-----------|
| apt / dnf | limpa o cache de pacotes e remove órfãos (`autoremove --purge`) |
| Journal | reduz o journal ao tamanho escolhido (padrão 200 MB) |
| Logs rotacionados | apaga `*.gz`, `*.1`, `*.old` de `/var/log` com mais de 7 dias |
| Docker | `builder prune` + imagens soltas (**nunca** toca volumes nem containers) |
| Snaps | remove revisões desativadas |
| Miniaturas | cache de miniaturas dos usuários (desmarcado por padrão) |

No fim mostra o espaço liberado em `/`. Dados de usuário, `/home` e volumes nunca entram.

### Atualizações
Ver pendentes (atualiza a lista) · `upgrade` · `full-upgrade` (avisa que pode instalar/remover) ·
"precisa reiniciar?" (pacotes que pedem reboot, kernel rodando × instalado). No apt usa
`--force-confold`: **arquivos de configuração que você alterou são mantidos**.

### Segurança
Auditoria só de leitura: o resumo do diagnóstico + usuários com shell, grupos `sudo`/`wheel`,
últimos logins, IPs com mais logins falhos, todas as portas escutando com processo, regras do
firewall (ufw/nftables).

### Benchmark e estresse
CPU (1 núcleo e todos — `sysbench` ou `openssl speed`) · **estresse de CPU** de 1 a 60 min
acompanhando carga e temperatura a cada 10 s, com alerta de superaquecimento, *throttling* e erros
de hardware (MCE) — Ctrl+C encerra · memória · disco.

### Backup e snapshot
- **Snapshot de configuração → pendrive:** `/etc` e cron em `tar.gz` (**sem** `/etc/shadow` e **sem**
  chaves privadas do SSH), lista de pacotes (`pacotes_manuais.txt` reinstala tudo com
  `xargs apt-get install -y < pacotes_manuais.txt`), serviços habilitados, rede/discos/fstab, regras
  de firewall, containers e arquivos `docker-compose` (sem os `.env`), tudo com `SHA256SUMS`.
  Ideal antes de mexer num servidor ou para documentar uma máquina de cliente.
- **Backup de pasta:** `tar.gz` com host e data no nome + `.sha256`, apaga as cópias além das *N*
  últimas, avisa se não couber.
- **Agendar backup diário:** instala o BigBoss em `/usr/local/sbin/bigboss` e cria
  `/etc/cron.d/bigboss-backup-<nome>` (log em `/var/log/bigboss-backup.log`).

### Pacotes e ferramentas
Instala com um clique as ferramentas úteis que faltam (lista abaixo) · instala **offline** os
`.deb`/`.rpm` da pasta `pacotes/` do pendrive (baixe em outra máquina com `apt-get download <pacote>`)
· procura e instala pacotes · abre o manual de um comando.

---

## Linha de comando e automação

```bash
bash bigboos.sh --diag                 # diagnóstico completo → relatório; exit 0/1/2
bash bigboos.sh --rede                 # resumo de rede
bash bigboos.sh --seguranca            # auditoria rápida
bash bigboos.sh --limpeza              # só mostra o que dá para liberar (não apaga nada)
bash bigboos.sh --snapshot             # snapshot de configuração
bash bigboos.sh --backup /etc /mnt/nas/backups --manter 14
bash bigboos.sh --texto                # menus sem whiptail
bash bigboos.sh --sem-cor              # saída sem cores (para log)
bash bigboos.sh --relatorios /outra/pasta
bash bigboos.sh --versao | --ajuda
```

Exemplo de monitoramento simples no cron:

```cron
0 7 * * * root /usr/local/sbin/bigboss --diag --sem-cor >/dev/null || echo "BigBoss: $(hostname) com alertas" | mail -s alerta ti@empresa
```

Instalado em `/usr/local/sbin`, os relatórios vão para `~/bigboss-relatorios/` de quem executou.

---

## Relatórios

```
relatorios/
└── srvweb01_20261031_140512/
    ├── diagnostico.txt   ← texto, com resumo dos alertas no topo
    ├── diagnostico.html  ← abre no navegador (claro/escuro), seções e semáforo
    ├── seguranca.txt|.html
    ├── limpeza.txt|.html
    ├── snapshot.txt|.html
    └── snapshot/         ← arquivos do snapshot + SHA256SUMS
```

Cada execução do script abre uma pasta nova `<host>_<data>`. O item **R** do menu lista e abre os
relatórios salvos. Os `.html` podem ser abertos direto no Windows depois de plugar o pendrive.

---

## Segurança e cuidados

- O snapshot e os backups podem conter **senhas em arquivos de configuração** de serviços. Trate o
  pendrive como um cofre (criptografe-o se possível).
- "Descobrir hosts" e "testar portas" são para a **sua** rede. Fazer isso em rede de terceiros sem
  autorização pode violar políticas e leis.
- O estresse de CPU deixa a máquina lenta durante o teste — não rode em produção em horário de uso.
- Atualizações reiniciam serviços. Reinicializações ficam sempre por sua conta.

---

## Ferramentas opcionais

O BigBoss funciona sem elas, mas fica mais completo (todas instaláveis pelo menu 9):

| Pacote | Habilita |
|--------|----------|
| `whiptail` | menus em janela |
| `smartmontools` | saúde SMART dos discos |
| `lm-sensors` | temperaturas em mais placas |
| `sysbench`, `stress-ng` | benchmark e estresse mais precisos |
| `mtr`, `dnsutils` | rota contínua e `dig` nos testes de DNS |
| `iperf3` | banda entre duas máquinas |
| `curl` | velocidade da internet e teste HTTPS |
| `htop`, `ncdu`, `sysstat`, `lsof`, `tcpdump`, `ethtool`, `nmap` | investigação manual |

---

## Problemas comuns

| Sintoma | Solução |
|---------|---------|
| `$'\r': command not found` | arquivo salvo com CRLF no Windows → `sed -i 's/\r$//' bigboos.sh` |
| `Permission denied` ao rodar `./bigboos.sh` | pendrive FAT/NTFS não guarda permissão → use `bash bigboos.sh` |
| `sudo: a terminal is required` | rodou por pipe/sem terminal: o BigBoss segue sem root; rode num terminal ou como root |
| Menus feios ou caracteres estranhos | terminal sem UTF-8 → `export LANG=C.UTF-8` ou use `--texto` |
| Velocidade de leitura de disco irreal | sem root o cache não é limpo; rode com sudo |
| Relatório em `/tmp/bigboss-relatorios` | o pendrive está só leitura ou sem espaço |

---

## Estrutura do repositório

```
scripts_auto/
├── bigboos.sh            # BigBoss v2
├── legado/
│   └── bigboos_v1.sh     # versão 1 (menu original), mantida como referência
├── README.md
├── .gitattributes        # força LF nos .sh
└── .gitignore
```

Testado em Ubuntu 24.04 (bash 5.2) e validado com ShellCheck.

---

Autor: [Luiz-DevBack](https://github.com/Luiz-DevBack) — dúvidas e sugestões: abra uma *issue* ou
WhatsApp (11) 93964-2769.
