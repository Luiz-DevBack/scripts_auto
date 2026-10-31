# scripts_auto — "All in One" de administração para Debian

Script único em Bash (`bigboos.sh`) com **menu interativo em modo texto** (`dialog`/`whiptail`) que
junta tarefas comuns de quem administra uma máquina Debian/Ubuntu: instalar pacotes, atualizar o
sistema, consultar manuais e rodar testes rápidos de CPU, disco e rede, salvando o resultado de cada
teste num arquivo `.txt`.

Foi escrito como projeto de estudo de Shell Script — serve como canivete para máquina de laboratório,
não como ferramenta de produção (veja [Limitações conhecidas](#limitações-conhecidas)).

---

## Sumário

- [Requisitos](#requisitos)
- [Como usar](#como-usar)
- [Menu principal](#menu-principal)
- [O que cada opção faz](#o-que-cada-opção-faz)
- [Arquivos gerados](#arquivos-gerados)
- [Funções ainda não ligadas ao menu](#funções-ainda-não-ligadas-ao-menu)
- [Limitações conhecidas](#limitações-conhecidas)
- [Estrutura do repositório](#estrutura-do-repositório)
- [Contato](#contato)

---

## Requisitos

| Item | Por quê |
|------|---------|
| Debian ou derivado (Ubuntu, Mint…) | usa `apt`, `apt-get` e `dpkg` |
| Usuário com `sudo` | instalação, atualização e `hdparm` pedem root |
| `dialog` e `whiptail` | caixas de menu/entrada/mensagem |
| `figlet` | banner da opção 2 |
| `logsave` (pacote `e2fsprogs`, já vem no Debian) | grava a saída dos testes em arquivo |
| `sysbench` e `stress` | opção 7 (o próprio script oferece instalar) |
| `hdparm` | opção 8 (o script oferece instalar) |
| `python3` + `wget` | opção 9 baixa o `speedtest-cli` |

Instalação das dependências de interface de uma vez:

```bash
sudo apt install dialog whiptail figlet
```

---

## Como usar

```bash
git clone https://github.com/Luiz-DevBack/scripts_auto.git
cd scripts_auto
chmod +x bigboos.sh
./bigboos.sh
```

O script limpa a tela, mostra o menu e espera o número da opção. Ao fim de cada ação ele pergunta
**"Deseja voltar ao menu principal?"** — *Sim* reabre o menu, *Não* encerra. Qualquer número fora da
lista também encerra.

> Rode a partir da própria pasta do repositório: os testes gravam os `.txt` e o `speedtest-cli` no
> diretório atual.

---

## Menu principal

```
|====================================================|
|============= OLÁ <hostname> SEJÁ BEM VINDO ========|
|  Instalação de programas | Pacotes | Atualização   |
|         [1] Instalar pacotes                       |
|         [2] Instalar programa                      |
|         [3] Procurar atualização                   |
|         [4] Instalar atualização                   |
|         [5] Atualizacao boa                        |
|                 CONSULTAR MANUAIS                  |
|         [6] Consultar manual                       |
|             TESTE DE REDES | HARDWARE              |
|         [7] CPU Benchmark...                       |
|         [8] HD Benchmark...                        |
|         [9] Teste de rede                          |
```

---

## O que cada opção faz

### Pacotes e atualização

| Opção | Função no script | Comando executado |
|-------|------------------|-------------------|
| **1** Instalar pacotes | `Instalar_pacotes` | Pede o nome de um `.deb` que esteja em `~/Downloads` → `sudo dpkg -i ~/Downloads/<arquivo>` + `apt-get -f install` para resolver dependências |
| **2** Instalar programa | `Instalar_programa_terminal` | Pede o nome do pacote → `apt-get install <pacote>` e em seguida abre `man <pacote>` |
| **3** Procurar atualização | `Procurar_atualizacao` | `sudo apt update` |
| **4** Instalar atualização | `Instalar_atualizacao` | `sudo apt upgrade` |
| **5** Atualização "boa" | `Atualizacao` | Confirma e roda `sudo apt dist-upgrade` (pode instalar/remover pacotes para resolver dependências — mais completa e mais arriscada). A saída fica em `superate.txt` |

### Manuais

| Opção | Função | O que faz |
|-------|--------|-----------|
| **6** Consultar manual | `All_manual` | Submenu: **1** abre `man` do programa digitado (`Escolha_manual`); **2** lista os pacotes instalados com `dpkg -l` (`Lista_de_app`) |

### Testes de hardware e rede

Antes de cada teste o script pergunta se o software já está instalado. Se a resposta for *Não*, ele
oferece instalar. Depois pede um **nome de arquivo** e grava o resultado em `<nome>.txt`, mostra numa
caixa de texto e pergunta se quer manter o arquivo (se *Não*, apaga e sai).

| Opção | Submenu | Comando |
|-------|---------|---------|
| **7** CPU Benchmark | 1 — Cálculo de primos | `sysbench --test=cpu --num-threads=4 --cpu-max-prime=9999 run` |
| | 2 — Stress multi-thread (5 min) | `stress --cpu 4 --timeout 300s` |
| **8** HD Benchmark | 1 — Velocidade de escrita | `dd bs=16k count=102400 oflag=direct if=/dev/zero of=arquivo_teste` (≈1,6 GB); ao final oferece o teste de **leitura** (`dd ... iflag=direct if=arquivo_teste of=/dev/null`) e apaga `arquivo_teste` |
| | 2 — Desempenho do disco | `sudo hdparm -t /dev/sda` |
| **9** Teste de rede | — | Baixa o `speedtest-cli` (sivel/speedtest-cli) para a pasta atual e roda `./speedtest-cli` |

> O teste de stress e o de cálculo usam **4 threads fixas**. Em CPU com mais ou menos núcleos, ajuste
> `--cpu 4` / `--num-threads=4` no script.

---

## Arquivos gerados

| Arquivo | Origem |
|---------|--------|
| `<nome>.txt` | resultado de cada teste (opções 7, 8 e 9) |
| `superate.txt` | saída do `dist-upgrade` (opção 5) |
| `arquivo_teste` | arquivo temporário de ~1,6 GB do teste de disco (apagado após o teste de leitura) |
| `speedtest-cli` | script Python baixado na opção 9 |
| `limpeza.txt` | saída das funções de limpeza (ainda fora do menu) |

---

## Funções ainda não ligadas ao menu

O arquivo já tem código para estas rotinas, mas elas **não aparecem no menu principal** (estão em
desenvolvimento):

| Função | Ideia |
|--------|-------|
| `Utilitarios_menu` | Submenu Backup / Limpeza / Scans |
| `Backup_tipo`, `Backup_automatico`, `Backup_targz` | Backup agendado via cron e `tar.gz` de `/home/data` com data no nome. A opção oculta **10** do `case` chama `Backup_tipo` |
| `Limpeza_menu`, `Limpeza_autoremove`, `Limpeza_clean`, `limpeza_autoclean`, `Limpeza_geral` | `apt autoremove`, `apt clean`, `apt autoclean` |
| `Scann_menu` | Instalaria `openvas` e `nmap` |

---

## Limitações conhecidas

Para quem for mexer no script:

- **Caminho fixo:** as caixas de resultado leem `/home/killian/projeto_script/<arquivo>.txt`. Em
  outra máquina/usuário a caixa aparece vazia (o arquivo existe na pasta atual). Troque por
  `"$PWD/$nome.txt"`.
- **Disco fixo:** `hdparm -t /dev/sda` — em NVMe o disco é `/dev/nvme0n1`.
- **`break` fora de laço:** os submenus usam `[ $? -ne 0 ] && break` ao cancelar; o Bash avisa
  ("only meaningful in a loop") e segue. `return` seria o correto.
- **Backups (opção 10):** `if [$? = 0 ]` sem espaço depois do `[`, `data` no lugar de `date` e a linha
  do cron que monta o comando mas não grava no `crontab` — não funciona ainda.
- **`Utilitarios_menu`/`Limpeza_menu`** testam a variável `$opchd` (de outro menu) em vez da própria.
- As opções 1 e 2 não usam `sudo` em `apt-get` — rode o script com um usuário que possa instalar, ou
  ajuste.

---

## Estrutura do repositório

```
scripts_auto/
├── bigboos.sh    # script principal (menu + todas as funções)
├── README.md
└── .gitignore
```

---

## Contato

Dúvidas ou sugestões: abra uma *issue* neste repositório.
Autor: [Luiz-DevBack](https://github.com/Luiz-DevBack) — WhatsApp (11) 93964-2769.
