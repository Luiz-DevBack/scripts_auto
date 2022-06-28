#!/bin/bash 

#PROJETO SCRIPT ALL IN ONE

clear

#Command 2>&1 | tee relatorio.txt

Menu(){
echo "|====================================================|"
echo "|============= OLÁ $USER SEJÁ BEM VINDO ==============|"
echo "|================ Escolha uma opção =================|"
echo "|====================================================|"

echo "_____________________________________________________"
echo "|  Instalação de programas | Pacotes | Atualização  |"
echo "|                                                   |"
echo "|         [1] Instalar pacotes                      |"
echo "|         [2] Instalar programa                     |"
echo "|         [3] Procurar atualização                  |"
echo "|         [4] Instalar atualização                  |"
echo "|         [5] Atualizacao boa                       |"
echo "|                                                   |"
echo "|                 CONSULTAR MANUAIS                 |"
echo "|                                                   |"
echo "|         [6] Consultar manual                      |"
echo "|                                                   |"
echo "|             TESTE DE REDES | HARDWARE             |"
echo "|                                                   |"
echo "|         [7] CPU Benchmark...                      |"
echo "|         [8] HD Benchmark...                       |"
echo "|         [9] Teste de rede                         |"
echo "|___________________________________________________|"
echo 
echo -n "Qual a opcao desejada ? "
echo "   "
read opc
case $opc in
        1) Instalar_pacotes  ;; #arquivos .deb

        2) Instalar_programa_terminal ;;

        3) Procurar_atualizacao ;;

        4) Instalar_atualizacao ;;

        5) Atualizacao ;;

        6) All_manual ;;

        7) CPU_Benchmark ;;

        8) HD_Benchmarkmenu ;;
        
        9) Rede_teste ;;

        10) Backup_tipo ;;

        *) Sair ;;

esac
}

Instalar_pacotes() {
package=$(whiptail --title " instalador de pacote " --inputbox "Digite o nome do pacote a ser instalado com .deb no final" 10 60 3>&1 1>&2 2>&3)
#package (arquivo deb na pasta download)
sudo dpkg -i /home/$USER/Downloads/$package
apt-get -f install

sleep 20
#dialog --infobox 'Aguarde a instalação do seu arquivo' 7 40
sleep 20
clear
dialog --msgbox 'Programa instalado' 7 40
clear

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                        clear
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                                                clear
                        fi             

}

Instalar_programa_terminal() {
programa=$(whiptail --title " instalador de pacote " --inputbox "Digite o nome do pacote a ser instalado com .deb no final" 10 60 3>&1 1>&2 2>&3)

apt-get install $programa
# dialog --infobox '$programa instalado com sucesso' 10 20
# dialog --textbox /etc/$programa/$programa.conf 40 60
figlet Manual do comando se divirta
sleep 5
man $programa

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                        clear
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                                                clear
                        fi          
}
 
Procurar_atualizacao() {
dialog --infobox 'buscando atualização aguarde'
sudo apt update
dialog --infobox 'busca terminada agora apenas Atualizar' 40 60
sleep 2

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                                clear

                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                                                clear

                        fi          
}
 
Instalar_atualizacao() {
dialog --infobox 'Atualização em andamento'
sudo apt upgrade
dialog --infobox 'programas atualizados' 40 60

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                                clear
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                                                clear
                        fi          
}
 #O comando dist-upgrade também atualiza os pacotes, porém,
 #remove e instala pacotes se for necessário.
 #Muitas vezes alguns softwares precisam ser instalados como dependências para certos aplicativos,
 #essa opção faz isso. O dist-upgrade é uma atualização mais completa, porém,
 #“mais arriscada”, já que modificará o sistema profundamente.

Atualizacao() {
dialog --yesno 'Deseja fazer a atualização mais pesada de pacotes' 7 40
if [ $? = 0 ]; then
    
    dialog --infobox 'Instalando......' 7 40
    sudo apt dist-upgrade > superate.txt
    cat superate.txt
    sleep 10
    dialog --infobox 'SUPER ATUALIZAÇÃO FEITA' 3 40
    clear

    else
        #dialog --infobox 'VOLTE EM OUTRO MOMENTO' 10 40
        whiptail --title "Não foi possivel atualizar" --msgbox "Você escolheu sair" 10 60
      clear
fi
#zero sempre sera sim neste caso

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                        clear
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                                                clear
                        fi          
}

#==================================//=======================================
                                #manual das aplicações 
All_manual(){

# Mostra o menu na tela, com as ações disponíveis
    opcman=$(
      dialog --stdout               \
             --title 'Menu de escolha'  \
             --menu ' MANUAIS ' \
            0 0 0                   \
            1 'Escolha manual' \
            2 'Listar Aplicativos'  \
            0 'Sair'                )

    # Usuario apertou CANCELAR ou ESC, então vamos sair...
    [ $? -ne 0 ] && break

    # De acordo com a opção escolhida, dispara função
    case "$opcman" in
         1) Escolha_manual ;;
         2) Lista_de_app ;;
         *) Valor_man_invalido ;;
         0) break ;;
    esac


}

Escolha_manual(){

appman=$(whiptail --title " Manual " --inputbox "Manual do programa " 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    echo "Insira o nome do programa para escolher o manual: " $appman
        man $appman
        else
                echo "Voce escolheu sair."
fi

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

Lista_de_app(){
dialog --infobox 'Clique em qualquer letra para sair' 5 40
        sleep 6
sudo dpkg -l

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

Valor_man_invalido() {
 whiptail --infobox "Você digitou um valor incorreto saindo..." 10 60  
        sleep 4
        exit        
}
                                #FIM CODE MANUAL APLICAÇÕES
#==========================================\\==========================================================

#==========================================\\==========================================================
                                #TESTE DE REDES E HARDWARE

CPU_Benchmark(){
dialog --yesno 'O equipamento possui o software de teste de Benchmark?' 7 60

if [ $? = 0 ]; then
  
opccpu=$(
      dialog --stdout               \
             --title 'Menu de escolha'  \
             --menu ' MANUAIS ' \
            0 0 0                   \
            1 'Teste de cálculo de número primo dentro de um determinado intervalo ' \
            2 'Teste de stress de CPU (Multi threaded)'  \
            0 'Sair'                )

    # Usuario apertou CANCELAR ou ESC, então vamos sair...
    [ $? -ne 0 ] && break

    # De acordo com a opção escolhida, dispara função
    case "$opccpu" in
         1) Teste_de_calculo ;;
         2) Teste_stress ;;
         0) break ;;
    esac
                else
                        dialog --yesno 'Deseja instalar o software de Benchmark? ' 7 40
                        if [ $? = 0 ];then
                                sudo apt-get install sysbench 
                                sudo apt-get install stress

                                dialog --title 'Baixando software' 8 40 
                                dialog --infobox 'Software instalado com sucesso' 3 40
                                sleep 5
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi                        
fi
}

#funções do teste de hardware

Teste_de_calculo(){
nomeben=$(whiptail --title " Benchmark " --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    dialog --infobox "O nome do seu arquivo é $nomeben.txt " 7 40
    sleep 4
    clear
        sysbench --test=cpu --num-threads=4 --cpu-max-prime=9999 run > $nomeben.txt
        #desta forma com whiptail ele le o
         whiptail --title 'Resultado Benchmark' --textbox /home/killian/projeto_script/$nomeben.txt 40 80
                dialog --yesno "Deseja manter o arquivo $nomeben.txt " 7 40
                        if [ $? = 0 ];then
                        clear
                                        echo "aquivo salvo na pasta: "
                                        pwd 
                                        else
                                                rm $nomeben.txt
                                                
                                                dialog --title 'Arquivo apagado com sucesso' --msgbox 'Até outro momento' 7 40 
                                                
                                                
                                                exit
                        fi       

                else
                        echo "Voce escolheu sair."
fi

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}


Teste_stress(){

dialog --infobox 'Este comando é para colocar uma carga Multi threaded sobre a CPU durante 5 minutos 300s. De acordo com seu computador, altere o parâmetro –cpu. Por exemplo, se você tiver um processador de 8 núcleos, use –cpu 8 😉' 30 40
sleep 30
#numnucleos=$(whiptail --title " Seja bem vindo ao teste de stress " --inputbox "Informe o numero de nucleos da sua CPU" 10 60 3>&1 1>&2 2>&3)

nomestress=$(whiptail --title " Benchmark " --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
  
    dialog --infobox "O nome do seu arquivo é $nomestress " 7 40
    sleep 4
    clear
       logsave $nomestress.txt stress --cpu 4 --timeout 300s
         whiptail --title 'Resultado Benchmark' --textbox /home/killian/projeto_script/$nomestress.txt 40 80
                dialog --yesno "Deseja manter o arquivo  $nomestress" 7 40
                        if [ $? = 0 ];then
                        clear
                                        echo "aquivo salvo na pasta: "
                                        pwd 
                                        else
                                                rm $nomestress.txt
                                                
                                                dialog --title 'Arquivo apagado com sucesso' --msgbox 'Até outro momento' 7 40 
                                                
                                                
                                                exit
                        fi       

                else
                        echo "Voce escolheu sair."
fi

  #

  dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}
#======================================================= teste de hd ==================================================
HD_Benchmarkmenu(){
dialog --title 'Sobre teste de HD' --msgbox 'O desempenho de leitura/escrita do disco rígido (HD) tem um grande impacto no desempenho do sistema Linux e na experiência do usuário. Simplesmente, quanto mais rápido for o HD melhor desempenho terá o sistema.' 20 60
dialog --yesno 'O equipamento possui o software de teste de Benchmark?' 7 60

if [ $? = 0 ]; then
  
opchd=$(
      dialog --stdout               \
             --title 'Menu de escolha'  \
             --menu ' MANUAIS ' \
            0 0 0                   \
            1 ' Velocidade de escrita usando o dd' \
            2 ' Verificar o desempenho do HD ' \
            0 'Sair'                )

    # Usuario apertou CANCELAR ou ESC, então vamos sair...
    [ $? -ne 0 ] && break

    # De acordo com a opção escolhida, dispara função
    case "$opchd" in
         1) Velocidade_escrita ;;
         2) Desempenho_hd ;;
         0) break ;;
    esac
                else
                        dialog --yesno 'Deseja instalar o software de Benchmark? ' 7 40
                        if [ $? = 0 ];then
                                sudo apt-get install hdparm

                                dialog --title 'Baixando software' 8 40 
                                dialog --infobox 'Software instalado com sucesso' 3 40
                                sleep 5
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi                        
fi

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

Velocidade_escrita(){
velozec=$(whiptail --title " Benchmark " --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    dialog --infobox "O nome do seu arquivo é $velozec.txt " 7 40
    sleep 4
    clear
echo "TESTANDO SEU HD AGUARDE..."
      logsave $velozec.txt dd bs=16k count=102400 oflag=direct if=/dev/zero of=arquivo_teste
              
                #desta forma com whiptail ele le o
         whiptail --title 'Resultado Benchmark' --textbox /home/killian/projeto_script/$velozec.txt 40 80
                dialog --yesno "Deseja manter o arquivo $velozec.txt " 7 40
                
                        if [ $? = 0 ];then
                        clear
                                        echo "aquivo salvo na pasta: "
                                        pwd 
                                        dialog --yesno "Deseja executar o teste de leitura do HD? " 7 40
                                                 if [ $? = 0 ];then
                                                        Velocidade_leitura

                                                        else
                                                                exit
                                                fi                 

                                        else
                                                rm $velozec.txt
                                                
                                                
                                                dialog --title 'Arquivo apagado com sucesso' --msgbox 'Até outro momento' 7 40 
                                                
                                                
                                                exit
                        fi       

                else
                        echo "Voce escolheu sair."
                        sleep 1
fi

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

Velocidade_leitura(){
velozlei=$(whiptail --title " Benchmark " --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    dialog --infobox "O nome do seu arquivo é $velozlei.txt " 7 40
    sleep 4
    clear
echo "TESTANDO SEU HD AGUARDE..."
      logsave $velozlei.txt dd bs=16K count=102400 iflag=direct if=arquivo_teste of=/dev/null
                
                #desta forma com whiptail ele le o
         whiptail --title 'Resultado Benchmark' --textbox /home/killian/projeto_script/$velozlei.txt 40 80
         rm arquivo_teste
                dialog --yesno "Deseja manter o arquivo $velozlei.txt " 7 40
                
                        if [ $? = 0 ];then
                        clear
                                        echo "aquivo salvo na pasta: "
                                        pwd 
                                        else
                                                rm $velozlei.txt
                                                
                                                
                                                dialog --title 'Arquivo apagado com sucesso' --msgbox 'Até outro momento' 7 40 
                                                
                                                
                                                exit
                        fi       

                else
                        echo "Voce escolheu sair."
fi

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

Desempenho_hd(){
desemp=$(whiptail --title " Benchmark " --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    dialog --infobox "O nome do seu arquivo é $desemp.txt " 7 40
    sleep 4
    clear
echo "TESTANDO SEU HD AGUARDE..."
      logsave $desemp.txt sudo hdparm -t /dev/sda
                
                #desta forma com whiptail ele le o
         whiptail --title 'Resultado Benchmark' --textbox /home/killian/projeto_script/$desemp.txt 40 80
    
                dialog --yesno "Deseja manter o arquivo $v.txt " 7 40
                
                        if [ $? = 0 ];then
                        clear
                                        echo "aquivo salvo na pasta: "
                                        pwd 
                                        else
                                                rm $desemp.txt
                                                
                                                
                                                dialog --title 'Arquivo apagado com sucesso' --msgbox 'Até outro momento' 7 40 
                                                
                                                
                                                exit
                        fi       

                else
                        echo "Voce escolheu sair."
fi        

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

#===============================================================teste de rede====================================================

Rede_teste(){
        dialog --yesno 'O equipamento possui o software de teste de Rede?' 7 60

if [ $? = 0 ]; then
  
speedtest1=$(whiptail --title " Teste de rede " --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)

exitstatus=$?
if [ $exitstatus = 0 ]; then
    dialog --infobox "O nome do seu arquivo é $speedtest1.txt " 7 40
    sleep 4
    clear
echo "TESTANDO SUA REDE AGUARDE..."
      logsave $speedtest1.txt ./speedtest-cli
                
                #desta forma com whiptail ele le o
         whiptail --title 'Resultado Teste de rede' --textbox /home/killian/projeto_script/$speedtest1.txt 40 80
    
                dialog --yesno "Deseja manter o arquivo $speedtest1.txt " 7 40
                
                        if [ $? = 0 ];then
                        clear
                                        echo "aquivo salvo na pasta: "
                                        pwd 
                                        else
                                                rm $speedtest1.txt
                                                
                                                
                                                dialog --title 'Arquivo apagado com sucesso' --msgbox 'Até outro momento' 7 40 
                                                
                                                
                                                exit
                        fi       

                else
                        echo "Voce escolheu sair."
fi        
        
                else
                        dialog --yesno 'Deseja instalar o software de Teste de rede? ' 7 40
                        if [ $? = 0 ];then
                                sudo apt-get install python3
                                wget -O speedtest-cli https://raw.githubusercontent.com/sivel/speedtest-cli/master/speedtest.py
                                chmod +x speedtest-cli

                                dialog --title 'Baixando software' 8 40 
                                dialog --infobox 'Software instalado com sucesso' 3 40
                                sleep 5
                                Rede_teste
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi                        
fi

dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

#===========================================================\\=============================================================================
                                                #UTILITÁRIOS

Utilitarios_menu(){
menuuti=$(
      dialog --stdout               \
             --title 'Menu de escolha'  \
             --menu ' MANUAIS ' \
            0 0 0                   \
            1 'Backup' \
            2 'Limpeza' \
            3 'Scans' \
            4 ''
            0 'Sair'                )

    # Usuario apertou CANCELAR ou ESC, então vamos sair...
    [ $? -ne 0 ] && break

    # De acordo com a opção escolhida, dispara função
    case "$opchd" in
         1) Backup_tipo ;;
         2) Limpeza_geral ;;
         3) Scann ;;
         4) seilas ;;
         0) break ;;
    esac
        
dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi          
}

Backup_tipo(){
dialog --title 'Backup preparação' --yesno 'Você possui o app de backup automatico(cron)?'
        if [$? = 0 ];then
                apt install cron
                        else 
                                backupopc=$(dialog --stdout --title 'Escolha um tipo de backup' \
                                --menu 'Backup tipo' 0 0 0 \
                                1 'Backup automatico' \
                                2 'Backup .tar' \
                                0 'Sair')

                                # Usuario apertou CANCELAR ou ESC, então vamos sair...
                                [ $? -ne 0 ] && break

                                 # De acordo com a opção escolhida, dispara função
                                 case "$backupopc" in 
                                1) Backup_automatico ;;
                                2) Backup_targz ;;
                                0) exit ;;
                                  esac

        fi                        
    
}

Backup_automatico(){
dialog --title 'Backup automatico' --msgbox 'Informe as horas e datas do backup' --infobox 'Para não informar tempo insira *'
       
txtmin=$(dialog --title 'Ecolha a quantidade de minutos para seu backup' --inputbox "Informe os minutos" 10 60 3>&1 1>&2 2>&3 )
txthrs=$(dialog --title 'Ecolha a quantidade de horas para seu backup' --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)
txtdia=$(dialog --title 'Ecolha a quantidade de dias para seu backup' --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)
txtmes=$(dialog --title 'Ecolha a quantidade de meses para seu backup' --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)
txtano=$(dialog --title 'Ecolha a quantidade de anos para seu backup' --inputbox "Qual o nome do arquivo" 10 60 3>&1 1>&2 2>&3)
wayfolder=$(dialog --title 'Caminho da pasta para backup' --inputbox "Informe o caminho da pasta" 10 60 3>&1 1>&2 2>&3)

$txtmin $txthrs $txtdia $txtmes $txtano sudo /home/data_backup.sh >$wayfolder 2>&1

 
}

Backup_targz(){
cd /home
sudo tar -cvpzf /home/backup.tar.gz /home/data
timestamp="$(data +'%b-%d-%y')"
sudo tar -cvpzf /home/backup-${timestamp}.tar.gz /home/data
}

Limpeza_menu(){
limpezamen=$(
      dialog --stdout               \
             --title 'Menu de escolha'  \
             --menu ' MANUAIS ' \
            0 0 0                   \
            1 'Backup' \
            2 'Limpeza' \
            3 'Scans' \
            0 'Sair'                )

    # Usuario apertou CANCELAR ou ESC, então vamos sair...
    [ $? -ne 0 ] && break

    # De acordo com a opção escolhida, dispara função
    case "$opchd" in
         1) Limpeza_autoremove ;;
         2) Limpeza_clean ;;
         3) limpeza_autoclean ;;
         4) Limpeza_geral ;;
         0) break ;;
    esac
        
dialog --yesno 'Deseja voltar ao menu principal? ' 7 40
                        if [ $? = 0 ];then
                                Menu
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi    
}

Limpeza_autoremove(){
dialog --title 'Bem vindo a remoção automatica' --msgbox 'vamos remover bibliotecas que não estão sendo mais usadas'
        apt autoremove > limpeza.txt
                dialog --title 'Limpando' --msgbox 'Aguarde o processo terminar'
        cat limpeza.txt
                dialog --yesno 'Deseja remover este arquivo mostrado? ' 7 40
                        if [ $? = 0 ];then
                                rm limpeza.txt
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi    
}

Limpeza_clean(){
dialog --title 'Bem vindo a limpeza' --msgbox 'A opção clean vai além do autoclean — limpando e removendo todos os arquivos .deb (pacotes) contidos nos diretórios — exceto o lock file:'
        apt clean > limpeza.txt
                dialog --title 'Limpando' --msgbox 'Aguarde o processo terminar'
        cat limpeza.txt
                dialog --yesno 'Deseja remover este arquivo mostrado? ' 7 40
                        if [ $? = 0 ];then
                                rm limpeza.txt
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi    
}

limpeza_autoclean(){
dialog --title 'Bem vindo a limpeza' --msgbox 'Agora vamos limpar o seu repositório local — removendo os arquivos de pacotes (.deb) que não podem mais ser baixados (versões antigas…) e são completamente inúteis e obsoletos.'
        apt autoclean > limpeza.txt
        
                dialog --title 'Limpando' --msgbox 'Aguarde o processo terminar'
        cat limpeza.txt
                dialog --yesno 'Deseja remover este arquivo mostrado? ' 7 40
                        if [ $? = 0 ];then
                                rm limpeza.txt
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi
}

Limpeza_geral(){
dialog --title 'Bem vindo a limpeza geral' --msgbox 'vamos remover bibliotecas que não estão sendo mais usadas, remover arquivos .deb antigos e atuais'
        apt autoremove > limpeza.txt
        apt clean > limpeza.txt
        apt autoclean > limpeza.txt
                dialog --title 'Limpando' --msgbox 'Aguarde o processo terminar'
        cat limpeza.txt
                dialog --yesno 'Deseja remover este arquivo mostrado? ' 7 40
                        if [ $? = 0 ];then
                                rm limpeza.txt
                                        else
                                                dialog --msgbox 'Volte em outro momento' 7 40
                        fi
}

Scann_menu(){
 sudo apt install openvas
 sudo apt install nmap
 
}


#==========================================\\==========================================================

Sair() {
        exit
}
Menu