Scripts Auto 

Automação de Tarefas em Linux Debian
Este repositório contém uma coleção de scripts em Shell projetados para facilitar a automação de diversas tarefas administrativas e de manutenção em sistemas Linux Debian. Ideal para administradores de sistemas que buscam otimizar processos e evitar a repetição de comandos manuais, tornando o gerenciamento de servidores mais ágil e eficiente.


🚀 Funcionalidades
Automatização de tarefas administrativas: Facilite rotinas diárias como backups, atualizações de sistema, gerenciamento de usuários e permissões.
Monitoramento de recursos: Scripts para verificar o uso de CPU, memória e espaço em disco, ajudando na manutenção proativa.
Configuração e otimização: Scripts para configuração de redes, firewall e otimização de serviços críticos.
Gerenciamento de pacotes: Automatize a instalação de pacotes e atualizações, garantindo que o sistema esteja atualizado.
Manutenção de logs: Automatize a limpeza e rotação de logs, organizando e economizando espaço em disco.


📋 Pré-requisitos
Antes de começar a usar os scripts, você precisará de:


Um sistema Debian ou baseado em Debian (Ubuntu, Mint, etc.).
Acesso de superusuário (root) para executar os comandos.
Um terminal com privilégios administrativos.


⚙️ Instalação e Configuração
Passo a Passo:
Clone o repositório:


git clone https://github.com/Luiz-DevBack/scripts_auto.git
Navegue até o diretório:


cd scripts_auto
Dê permissão de execução ao script:


chmod +x nome_do_script.sh
Execute o script:


./nome_do_script.sh
Personalização dos Scripts:
Os scripts podem ser facilmente personalizados conforme as necessidades do administrador. Comentários dentro dos scripts explicam como ajustar variáveis, diretórios e intervalos de execução.


🛠 Tecnologias Utilizadas
Shell Script (Bash): A linguagem principal utilizada.
Debian Linux: Testado em sistemas Debian, compatível com outras distribuições Linux.
Ferramentas: Utilização de AWK, Sed para manipulação de texto, Cron para agendamento de tarefas automáticas e Grep para filtragem de logs.


💻 Uso dos Scripts
Exemplos de Scripts Disponíveis:
Monitoramento de Recursos

Verifica o uso de memória, CPU e espaço em disco:

./monitor_sistema.sh
Backup Automatizado

Cria backups automáticos de diretórios:

./backup_auto.sh /diretorio/origem /diretorio/destino
Gerenciamento de Pacotes

Atualiza pacotes e remove os antigos:

./atualiza_sistema.sh
Agendamento com Cron:
Para agendar a execução automática de um script, adicione ao Cron:

crontab -e
Exemplo para rodar o monitoramento a cada hora:

0 * * * * /caminho/para/monitor_sistema.sh

🤝 Contribuição
Contribuições são bem-vindas! Para colaborar com o projeto:

Faça um fork do repositório.
Crie uma nova branch:

git checkout -b minha-nova-funcionalidade
Commit suas mudanças:

git commit -m "Adicionei nova funcionalidade"
Envie um push para a branch:

git push origin minha-nova-funcionalidade
Abra um pull request.

📜 Licença
Este projeto está licenciado sob a Licença MIT. Consulte o arquivo LICENSE para mais detalhes.

📞 Contato
Se tiver dúvidas ou sugestões, fique à vontade para abrir uma issue no repositório ou entrar em contato via whatsapp (11) 93954-2769
