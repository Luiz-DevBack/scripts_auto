 <h1>Scripts Auto - Automação de Tarefas em Linux Debian</h1>
    <p>Este repositório contém uma coleção de <strong>scripts em Shell</strong> projetados para facilitar a automação de diversas tarefas administrativas e de manutenção em sistemas <strong>Linux Debian</strong>. Ideal para administradores de sistemas que buscam otimizar processos e evitar a repetição de comandos manuais, tornando o gerenciamento de servidores mais ágil e eficiente.</p>
    <h2>🚀 Funcionalidades</h2>
    <ul>
        <li>Automatização de tarefas administrativas: Facilite rotinas diárias como backups, atualizações de sistema, gerenciamento de usuários e permissões.</li>
        <li>Monitoramento de recursos: Scripts para verificar o uso de CPU, memória e espaço em disco, ajudando na manutenção proativa.</li>
        <li>Configuração e otimização de redes, firewall e serviços críticos.</li>
        <li>Automatização da instalação de pacotes e atualizações.</li>
        <li>Manutenção de logs: limpeza e rotação automática de logs, organizando e economizando espaço em disco.</li>
    </ul>
    <h2>📋 Pré-requisitos</h2>
    <ul>
        <li>Um sistema Debian ou baseado em Debian (Ubuntu, Mint, etc.).</li>
        <li>Acesso de superusuário (root) para executar os comandos.</li>
        <li>Terminal com privilégios administrativos.</li>
    </ul>
    <h2>⚙️ Instalação e Configuração</h2>
    <p><strong>Passo a Passo:</strong></p>
    <p>Clone o repositório:</p>
    <div class="code-block">
        <code>git clone https://github.com/Luiz-DevBack/scripts_auto.git</code>
    </div>
    <p>Navegue até o diretório:</p>
    <div class="code-block">
        <code>cd scripts_auto</code>
    </div>
    <p>Dê permissão de execução ao script:</p>
    <div class="code-block">
        <code>chmod +x nome_do_script.sh</code>
    </div>
    <p>Execute o script:</p>
    <div class="code-block">
        <code>./nome_do_script.sh</code>
    </div>
    <p><strong>Personalização dos Scripts:</strong></p>
    <p>Os scripts podem ser facilmente personalizados conforme as necessidades do administrador. Comentários dentro dos scripts explicam como ajustar variáveis, diretórios e intervalos de execução.</p>
    <h2>🛠 Tecnologias Utilizadas</h2>
    <ul>
        <li>Shell Script (Bash): A linguagem principal utilizada.</li>
        <li>Debian Linux: Testado em sistemas Debian, compatível com outras distribuições Linux.</li>
        <li>Ferramentas: AWK, Sed para manipulação de texto, Cron para agendamento de tarefas automáticas e Grep para filtragem de logs.</li>
    </ul>
    <h2>💻 Uso dos Scripts</h2>
    <h3>Exemplos de Scripts Disponíveis:</h3>
    <p><strong>Monitoramento de Recursos:</strong></p>
    <div class="code-block">
        <code>./monitor_sistema.sh</code>
    </div>
    <p><strong>Backup Automatizado:</strong></p>
    <div class="code-block">
        <code>./backup_auto.sh /diretorio/origem /diretorio/destino</code>
    </div>
    <p><strong>Gerenciamento de Pacotes:</strong></p>
    <div class="code-block">
        <code>./atualiza_sistema.sh</code>
    </div>
    <h2>Agendamento com Cron:</h2>
    <p>Para agendar a execução automática de um script, adicione ao Cron:</p>
    <div class="code-block">
        <code>crontab -e</code>
    </div>
    <p>Exemplo para rodar o monitoramento a cada hora:</p>
    <div class="code-block">
        <code>0 * * * * /caminho/para/monitor_sistema.sh</code>
    </div>
	<h2>🤝 Contribuição</h2>
    <p>Contribuições são bem-vindas! Para colaborar com o projeto:</p>
    <ul>
        <li>Faça um fork do repositório.</li>
        <li>Crie uma nova branch:</li>
        <div class="code-block">
            <code>git checkout -b minha-nova-funcionalidade</code>
        </div>
        <li>Commit suas mudanças:</li>
        <div class="code-block">
            <code>git commit -m "Adicionei nova funcionalidade"</code>
        </div>
        <li>Envie um push para a branch:</li>
        <div class="code-block">
            <code>git push origin minha-nova-funcionalidade</code>
        </div>
        <li>Abra um pull request.</li>
    </ul>
    <h2>📜 Licença</h2>
    <p>Este projeto está licenciado sob a Licença MIT. Consulte o arquivo LICENSE para mais detalhes.</p>
    <h2>📞 Contato</h2>
    <p>Se tiver dúvidas ou sugestões, sinta-se à vontade para abrir uma issue no repositório ou entrar em contato via WhatsApp (11) 93964-2769.</p>
