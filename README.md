<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Scripts Auto - Automação de Tarefas em Linux Debian</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background-color: #f4f4f9;
            margin: 0;
            padding: 20px;
        }
        h1, h2, h3 {
            color: #333;
        }
        h1 {
            font-size: 2.5em;
        }
        h2 {
            margin-top: 30px;
            border-bottom: 2px solid #ddd;
            padding-bottom: 10px;
        }
        p {
            color: #666;
            font-size: 1.1em;
        }
        code {
            background-color: #eee;
            padding: 5px;
            border-radius: 4px;
            font-family: Consolas, "Courier New", monospace;
        }
        .container {
            max-width: 800px;
            margin: 0 auto;
            background: #fff;
            padding: 20px;
            border-radius: 8px;
            box-shadow: 0 0 10px rgba(0, 0, 0, 0.1);
        }
        .code-block {
            background-color: #272822;
            color: #f8f8f2;
            padding: 10px;
            border-radius: 5px;
            margin: 15px 0;
            overflow-x: auto;
        }
        .code-block code {
            color: #66d9ef;
        }
        .note {
            background-color: #fdf2c4;
            padding: 10px;
            border-left: 5px solid #ffd700;
            margin: 10px 0;
            border-radius: 4px;
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Scripts Auto - Automação de Tarefas em Linux Debian</h1>

        <p>Este repositório contém uma coleção de <strong>scripts em Shell</strong> projetados para facilitar a automação de diversas tarefas administrativas e de manutenção em sistemas <strong>Linux Debian</strong>. Ideal para administradores de sistemas que buscam otimizar processos e evitar a repetição de comandos manuais, tornando o gerenciamento de servidores mais ágil e eficiente.</p>

        <h2>🚀 Funcionalidades</h2>
        <ul>
            <li>Automatização de tarefas administrativas: backups, atualizações, gerenciamento de usuários e permissões.</li>
            <li>Monitoramento de recursos: verificação de uso de CPU, memória e espaço em disco.</li>
            <li>Configuração e otimização do sistema: configuração de redes, firewall e serviços críticos.</li>
            <li>Gerenciamento de pacotes e atualizações: instalação e atualização automatizada de pacotes.</li>
            <li>Manutenção de logs: limpeza e rotação automática de logs.</li>
        </ul>

        <h2>📋 Pré-requisitos</h2>
        <ul>
            <li>Um sistema Debian ou qualquer distribuição baseada em Debian (Ubuntu, Mint, etc.).</li>
            <li>Acesso de superusuário (root) para execução dos comandos.</li>
            <li>Terminal com privilégios de root.</li>
        </ul>

        <h2>⚙️ Instalação e Configuração</h2>
        <p><strong>Passo a Passo para Instalação:</strong></p>
        <div class="code-block">
            <code>
                git clone https://github.com/Luiz-DevBack/scripts_auto.git <br>
                cd scripts_auto <br>
                chmod +x nome_do_script.sh <br>
                ./nome_do_script.sh
            </code>
        </div>
        <p><strong>Personalização dos Scripts:</strong></p>
        <p>Os scripts podem ser facilmente editados para atender às necessidades específicas do administrador. Comentários dentro dos arquivos orientam sobre as seções configuráveis, como caminhos de diretórios e variáveis de ambiente.</p>

        <h2>🛠 Tecnologias Utilizadas</h2>
        <ul>
            <li>Shell Script (Bash)</li>
            <li>Debian Linux</li>
            <li>AWK e Sed para manipulação de textos</li>
            <li>Cron para agendamento de tarefas automáticas</li>
            <li>Grep para filtragem de logs</li>
        </ul>

        <h2>🚀 Uso dos Scripts</h2>
        <h3>Monitoramento de Recursos:</h3>
        <div class="code-block">
            <code>
                ./monitor_sistema.sh
            </code>
        </div>
        <h3>Backup Automatizado:</h3>
        <div class="code-block">
            <code>
                ./backup_auto.sh /diretorio/origem /diretorio/destino
            </code>
        </div>
        <h3>Gerenciamento de Pacotes:</h3>
        <div class="code-block">
            <code>
                ./atualiza_sistema.sh
            </code>
        </div>

        <h2>🔧 Contribuição</h2>
        <div class="note">
            <p><strong>Contribuições são bem-vindas!</strong> Para colaborar com este projeto, siga os passos abaixo:</p>
        </div>
        <ol>
            <li>Faça um fork do projeto.</li>
            <li>Crie uma branch para sua funcionalidade: <code>git checkout -b minha-nova-funcionalidade</code></li>
            <li>Commit suas mudanças: <code>git commit -m "Adiciona nova funcionalidade"</code></li>
            <li>Envie um push para a branch: <code>git push origin minha-nova-funcionalidade</code></li>
            <li>Abra um pull request.</li>
        </ol>

        <h2>📜 Licença</h2>
        <p>Este projeto está licenciado sob a Licença MIT. Consulte o arquivo <a href="LICENSE">LICENSE</a> para mais detalhes.</p>

        <h2>📞 Contato</h2>
        <p>Se tiver dúvidas ou sugestões, sinta-se à vontade para abrir uma <strong>issue</strong> no repositório ou entrar em contato através do WhatsApp: (11) 93954-2769.</p>
    </div>
</body>
</html>
