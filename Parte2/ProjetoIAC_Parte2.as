;;;;; CABECALHO ;;;;;

SP_INI          EQU     8000h ; stack pointer, 8000h por convencao
INT_MASK        EQU     FFFAh ; porto para a interrupt mask
INT_MASK_VALUE  EQU     1000000000001001b ; temporizador, botao 0 e botao up

TIMER_COUNTER   EQU     FFF6h ; portos IO para o timer
TIMER_CONTROL   EQU     FFF7h

TIMER_DELTA     EQU     1 ; periodo do game tick, 1 = 100ms
TIMER_ENABLE    EQU     1 ; valor para ser escrito para TIMER_CONTROL

START_7SD_1     EQU     FFF0h ; 7 segment display divido em 2 devido a forma
DIM_7SD_1       EQU     4 ; como esta numerado
START_7SD_2     EQU     FFEEh
DIM_7SD_2       EQU     2

TERM_COLOR      EQU     FFFBh ; portos IO para o terminal
TERM_CURSOR     EQU     FFFCh
TERM_STATUS     EQU     FFFDh
TERM_WRITE      EQU     FFFEh
TERM_READ       EQU     FFFFh

TERM_CLEAR      EQU     FFFFh ; valor para ser escrito para TERM_CURSOR

DIMENSAO        EQU     80 ; numero de posicoes do vetor
ALTURA          EQU     4 ; altura dos cactos
CHAR_CACTO      EQU     '#' ; caractere usado para representar cactos

DELTA_LINHAS    EQU     0100h ; diferenca entre linhas
COR_AREA_JOGO   EQU     ff00h ; preto no branco

ALTURA_MIN      EQU     1 ; minima altura de salto
ALTURA_MAX      EQU     7 ; maxima altura de salto
TECLA_SALTO     EQU     24 ; seta para cima

SOLO            EQU     2000h ; linha do solo
LINHA_TITULO    EQU     1600h ; em que linha escrever o titulo
LINHA_SUBTITULO EQU     1700h ; em que linha escrever o subtitulo

LINHA_INI       EQU     1f00h ; linha inicial
LINHA_DINO_INI  EQU     1f05h ; linha inicial do dinossauro
ALTURA_DINO_INI EQU     1 ; altura inicial do dinossauro

                ORIG    4000h
                
terreno         TAB     DIMENSAO ; terreno de jogo


                ORIG    5000h

x               WORD    5 ; valor inicial = semente geracactos
timerPending    WORD    0 ; interrupcoes do temporizador por processar
gameRunning     WORD    0 ; variavel de estado do jogo
pontuacao       WORD    0 ; variavel da pontuacao

alturaLinha     WORD    0000h ; variavel da altura da linha
linha           WORD    LINHA_INI ; variavel do endereco da linha

linhaDino       WORD    LINHA_DINO_INI ; endereco da linha do dinossauro
alturaDino      WORD    ALTURA_DINO_INI ; variavel da altura do dinossauro
saltoDino       WORD    0 ; variavel de controlo do salto
direcaoDino     WORD    1 ; 0 = descer, 1 = subir 

welcomeText     STR     'DINO GAME', 0 ; mensagens de informacao
gameOverText    STR     'GAME OVER', 0
helpText        STR     'Press [0] to start a new game!', 0


;;;;; INSTRUCOES DE CONTROLO ;;;;;

                ORIG    0000h
                
MAIN:           MVI     R6, SP_INI ; incializacao do stackpointer
                MVI     R1, INT_MASK ; inicializacao da mascara de interrupcoes
                MVI     R2, INT_MASK_VALUE
                STOR    M[R1], R2
                ENI     ; ativar as interrupcoes
                
                MVI     R1, TERM_COLOR ; definir a cor do jogo no terminal
                MVI     R2, COR_AREA_JOGO
                STOR    M[R1], R2
                
                MVI     R1, TERM_CURSOR ; posicao inical do cursor
                MVI     R2, SOLO
                STOR    M[R1], R2
                
                MVI     R3, DIMENSAO
                SHL     R3 ; duas camadas de solo
                MVI     R1, TERM_WRITE
                MVI     R2, '▓'
                
.solo:          STOR    M[R1], R2 ; escrita no terminal do solo
                DEC     R3
                BR.NZ   .solo
                
                MVI     R1, terreno
                MVI     R2, DIMENSAO
                JAL     escrevejogo ; escrever cores para toda a area de jogo
                
                MVI     R1, pontuacao ; inicializacao de variaveis
                STOR    M[R1], R0
                MVI     R1, alturaLinha
                STOR    M[R1], R0
                MVI     R1, linha
                MVI     R2, LINHA_INI
                STOR    M[R1], R2
                MVI     R1, linhaDino
                MVI     R2, LINHA_DINO_INI
                STOR    M[R1], R2
                MVI     R1, alturaDino
                MVI     R2, ALTURA_DINO_INI
                STOR    M[R1], R2
                MVI     R1, saltoDino
                STOR    M[R1], R0
                MVI     R1, direcaoDino
                MVI     R2, 1
                STOR    M[R1], R2
                
                MOV     R3, R0 ; welcome screen ja esta escrito?
                MVI     R4, gameRunning
                
.awaitStart:    LOAD    R1, M[R4] ; aguardar ate o jogo ser iniciado
                CMP     R1, R0 ; deteta o comeco do jogo
                BR.NZ   .start
                
                CMP     R3, R0 ; evitar redundancia se welcome screen ja estiver
                BR.NZ   .awaitStart
                
                MVI     R1, welcomeText ; escreve welcome screen
                MVI     R2, LINHA_TITULO
                JAL     escrevecentrado
                
                MVI     R1, helpText
                MVI     R2, LINHA_SUBTITULO
                JAL     escrevecentrado
                
                MVI     R3, 1 ; sinalizar welcome screen ja foi escrito
                BR      .awaitStart

.start:         MVI     R1, TIMER_COUNTER ; velocidade do temporizador
                MVI     R2, TIMER_DELTA
                STOR    M[R1], R2
                
                MVI     R5, timerPending ; reset count de timer events pendentes
                STOR    M[R5], R0
                
                MVI     R1, TIMER_CONTROL ; ativacao do temporizador
                MVI     R2, TIMER_ENABLE
                STOR    M[R1], R2
                
.loop:          LOAD    R1, M[R5]
                CMP     R1, R0
                JAL.P   processtick ; processar timer events se pendentes > 0
                BR      .loop


;;;;; FUNCOES DE JOGO ;;;;;

processtick:    DEC     R6 ; guardar R7 na pilha para poder chamar funcoes aux
                STOR    M[R6], R7

                MVI     R2, timerPending
                DSI     ; interrupcoes desligadas para proteger codigo sensivel
                LOAD    R1, M[R2]
                DEC     R1 ; decrementar numero de interrupcoes por tratar
                STOR    M[R2], R1
                ENI     ; reativar interrupcoes
                
                MVI     R1, terreno ; passar endereco inicial do vetor
                MVI     R2, DIMENSAO ; passar dimensao do vetor
                JAL     atualizajogo ; atualizar terreno e gerar cacto
                
                MVI     R1, terreno ; passar endereco inicial do vetor
                MVI     R2, DIMENSAO ; passar dimensao do vetor
                JAL     escrevejogo ; escreve o terreno do jogo no terminal
                
                JAL     dinossauro ; escreve o dinossauro; deteta colisao, salta
                
                MVI     R2, pontuacao ; atualizar a pontuacao
                LOAD    R1, M[R2]
                INC     R1
                STOR    M[R2], R1
                JAL     update7SD ; escreve pontuacao no display de 7 segmentos
                
                LOAD    R7, M[R6]
                INC     R6
                
                JMP     R7 ; devolver o controlo da execucao


atualizajogo:   DEC     R6 ; PUSH R4 (preservar)
                STOR    M[R6], R4
                DEC     R6 ; PUSH R7 (permitir chamada de geracacto)
                STOR    M[R6], R7
                
                DEC     R2 ; dimensao - 1, o ultimo nao e alterado no loop
                
.loop:          INC     R1 ; carregar da memoria valor do n+1
                LOAD    R4, M[R1]
                
                DEC     R1 ; carregar na memoria valor do n+1 para n
                STOR    M[R1], R4
                
                INC     R1 ; aumentar n para proxima iteracao
                DEC     R2 ; decrementar contador de iteracoes restantes
                BR.NZ   .loop ; repetir se faltarem iteracoes (pelo contador)
                
                MOV     R4, R1 ; guardar R1 em R4 pois R1 alterado por geracacto
                MVI     R1, ALTURA ; passar altura como argumento
                JAL     geracacto ; invocacao geracacto
                STOR    M[R4], R3 ; carregar na memoria valor retornado
                
                LOAD    R7, M[R6] ; POP R7 (para poder retornar)
                INC     R6
                LOAD    R4, M[R6] ; POP R4 (preservar)
                INC     R6
                
                JMP     R7 ; transferir o controlo de volta


geracacto:      DEC     R6 ; PUSH R4 (preservar)
                STOR    M[R6], R4
                DEC     R6 ; PUSH R5 (preservar)
                STOR    M[R6], R5
                
                MVI     R4, x ; endereco de x
                LOAD    R2, M[R4] ; R2 = x = seed (inicialmente)
                
                MVI     R4, 1
                AND     R5, R2, R4 ; bit = x AND 1
                SHR     R2 ; x >> 1
                
                CMP     R5, R0
                BR.Z    .skipIf ; saltar se bit == 0
                MVI     R4, b400h
                XOR     R2, R2, R4 ; x XOR b400h
                
.skipIf:        MVI     R4, x ; endereco de x
                STOR    M[R4], R2 ; atualizar valor de x
                
                MOV     R3, R0 ; preparar para devolver 0
                MVI     R4, 62258
                CMP     R2, R4
                BR.C    .end ; devolver 0 se x < 62258 (aprox. 95% chance)
                
                DEC     R1 ; altura - 1
                AND     R3, R2, R1 ; x AND (altura - 1)
                INC     R3 ; devolver (x AND (altura  1)) + 1
                
.end:           LOAD    R5, M[R6] ; POP R5 (preservar)
                INC     R6
                LOAD    R4, M[R6] ; POP R4 (preservar)
                INC     R6
                
                JMP     R7 ; transferir o controlo de volta


escrevejogo:    DEC     R6 ; preservar valores de R4 e R5
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R2 ; recebe dimensao vetor como 2o argumento
                DEC     R6
                STOR    M[R6], R1 ; recebe vetor terreno como 1o argumento
                
                MVI     R1, linha
                MVI     R2, SOLO
                MVI     R3, DELTA_LINHAS
                SUB     R2, R2, R3 ; linha acima do solo
                STOR    M[R1], R2
                MVI     R1, alturaLinha
                STOR    M[R1], R0 
                
.linha:         LOAD    R4, M[R6] ; carregar argumentos
                INC     R6
                LOAD    R5, M[R6] ; ciclo, corre para cada linha
                DEC     R6 ; preparar para proxima vez
                
                MVI     R1, TERM_CURSOR ; reposiciona o cursor
                MVI     R2, linha
                LOAD    R2, M[R2]
                STOR    M[R1], R2   
                
.col:           MVI     R1, TERM_WRITE ; ciclo, corre para cada coluna na linha
                LOAD    R3, M[R4]
                CMP     R3, R0
                BR.Z    .semCacto ; se valor em memoria == 0, nao tem cacto
                
                MVI     R2, alturaLinha
                LOAD    R2, M[R2]
                CMP     R3, R2
                BR.NP   .semCacto ; se o cacto for mais baixo que a linha
                
                MVI     R3, CHAR_CACTO
                BR      .comCacto
                
.semCacto:      MVI     R3, ' ' ; quando nao houver cacto, apaga so a posicao
                
.comCacto:      STOR    M[R1], R3 ; escrita do cacto
                INC     R4 ; avancar para a proxima coluna
                DEC     R5 ; numero de vezes restantes a executar o loop
                BR.NZ   .col
                
                MVI     R1, linha ; mudanca de linha (para cima)
                LOAD    R2, M[R1]
                MVI     R3, DELTA_LINHAS
                SUB     R2, R2, R3
                STOR    M[R1], R2

                MVI     R1, alturaLinha
                LOAD    R2, M[R1]
                INC     R2
                STOR    M[R1], R2
                MVI     R1, ALTURA_MAX ; atualizar 2*ALTURA_MAX de forma a 
                SHL     R1 ; garantir uma area de jogo limpa
                CMP     R1, R2
                BR.NZ   .linha
                
                INC     R6 ; compensar os argumentos estarem na pilha
                INC     R6
                LOAD    R5, M[R6] ; reposicao de valores de R4 e R5
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7 ; retorno do controlo


dinossauro:     DEC     R6 ; preservar valores de R4, R5 e R7
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R1, TERM_STATUS ; verif se a seta do teclado foi premida
                LOAD    R1, M[R1] 
                CMP     R1, R0
                JAL.NZ  verifsalto
                
                MVI     R1, saltoDino ; detecao da variavel do salto
                LOAD    R1, M[R1]
                CMP     R1, R0
                BR.Z    .naoSalta
                
                MVI     R1, direcaoDino ; detecao da direcao do salto
                LOAD    R1, M[R1]
                CMP     R1, R0 ; 0 = descer
                BR.Z    .descer
                
.subir:         MVI     R1, linhaDino ; salto do dinossauro a subir 
                LOAD    R2, M[R1]
                MVI     R3, DELTA_LINHAS
                SUB     R2, R2, R3
                STOR    M[R1], R2
                
                MVI     R1, alturaDino ; sobe uma linha por intervalo de tempo
                LOAD    R2, M[R1]
                INC     R2
                STOR    M[R1], R2
                
                MVI     R1, ALTURA_MAX
                MOV     R3, R0 ; 0 = descer
                CMP     R2, R1
                BR.Z    .inverteDirecao
                
                INC     R3 ; 1 = subir
.inverteDirecao:MVI     R1, direcaoDino ; uma vez atingida a altura max comecar
                STOR    M[R1], R3 ; a descer
                BR      .naoSalta
                
.descer:        MVI     R1, linhaDino ; salto do dinossauro a descer
                LOAD    R2, M[R1]
                MVI     R3, DELTA_LINHAS
                ADD     R2, R2, R3
                STOR    M[R1], R2
                
                MVI     R1, alturaDino ; desce uma linha por intervalo de tempo
                LOAD    R2, M[R1]
                DEC     R2
                STOR    M[R1], R2
                
                MVI     R1, ALTURA_MIN ; verifica a chegada a altura minima
                CMP     R1, R2
                BR.N    .naoSalta
                
                MVI     R1, direcaoDino ; repoe a direcao do salto para o prox
                MVI     R2, 1 ; 1 = subir
                STOR    M[R1], R2
                
                MVI     R1, saltoDino ; termina o salto
                STOR    M[R1], R0 
                
.naoSalta:      MVI     R4, terreno
                MVI     R1, LINHA_INI
                MVI     R2, LINHA_DINO_INI
                SUB     R1, R2, R1 ; calcular offset de colunas
                ADD     R4, R4, R1
                LOAD    R4, M[R4] ; obter possivel cacto na coluna do dino
                
                MVI     R1, linhaDino
                JAL     escrevedino ; mesmo que depois seja detetada colisao,
                        ; e necessario para que o dino fique visivel
                
                MVI     R1, alturaDino
                LOAD    R1, M[R1] ; compara a altura do dino a altura do cacto
                CMP     R4, R1 ; para detetar colisoes
                BR.N    .naoColisao

.colisao:       MVI     R1, gameOverText ; escreve no terminal msgs informativas
                MVI     R2, LINHA_TITULO
                JAL     escrevecentrado
                
                MVI     R1, helpText
                MVI     R2, LINHA_SUBTITULO
                JAL     escrevecentrado
                
                MVI     R1, gameRunning ; termina o jogo
                STOR    M[R1], R0
                
.awaitRestart:  LOAD    R2, M[R1] ; espera o inicio do jogo
                CMP     R2, R0
                BR.Z    .awaitRestart
                
                MVI     R1, terreno
                MVI     R2, DIMENSAO
                JAL     limpa ; limpa o terminal e a pontuacao
                
                JMP     MAIN ; recomeca o jogo do inicio
                
.naoColisao:    LOAD    R7, M[R6] ; repoe valores de R4, R5 e R7
                INC     R6
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7


verifsalto:     MVI     R1, TERM_READ ; verif seta do teclado
                LOAD    R1, M[R1]
                MVI     R2, TECLA_SALTO
                CMP     R1, R2 ; ultima tecla == tecla desejada?
                JMP.NZ  R7
                
                MVI     R1, saltoDino ; ativa o salto do dinossauro
                MVI     R2, 1
                STOR    M[R1], R2
				JMP     R7


limpa:          STOR    M[R1], R0 ; recebe terreno, DIMENSAO como args
                INC     R1
                DEC     R2
                BR.NZ   limpa

                MVI     R1, TERM_CURSOR ; limpa o terminal por completo
                MVI     R2, TERM_CLEAR
                STOR    M[R1], R2

                MVI     R1, pontuacao ; reset da pontuacao 
                STOR    M[R1], R0
                
                JMP     R7


escrevedino:    DEC     R6 ; preservar R4 e R5
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                
                MVI     R1, TERM_CURSOR
                MVI     R2, TERM_WRITE
                
                MVI     R3, linhaDino ; posicionamento do cursor
                LOAD    R3, M[R3]
                STOR    M[R1], R3
                
                MVI     R4, 'ε' ; escrita da parte de baixo do dinossauro
                STOR    M[R2], R4
                
                MVI     R4, DELTA_LINHAS
                SUB     R3, R3, R4 ; sobe uma linha
                STOR    M[R1], R3
                
                MVI     R4, '&' ; escrita da parte de cima do dinossauro
                STOR    M[R2], R4

                LOAD    R5, M[R6] ; repor valores de R4 e R5
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                 
                JMP     R7


;;;;; FUNCOES AUXILIARES ;;;;;

update7SD:      DEC     R6 ; recebe um arg para por no 7SD em decimal
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5 ; preservar valores de R4 e R5
                
                MVI     R5, 0 ; = second loop (7SD divido em 2 partes)
                
                MVI     R2, START_7SD_1
                MVI     R3, DIM_7SD_1
                
.loop:          DEC     R6 ; presevar registos para permitir a chamada de auxs
                STOR    M[R6], R2
                DEC     R6
                STOR    M[R6], R3
                DEC     R6
                STOR    M[R6], R7
                
                MVI     R2, 10d
                JAL     divint ; divisao inteira n por 10
                MOV     R1, R3 ; atualizar n = n // 10
                LOAD    R4, M[R6]
                INC     R6
                
                LOAD    R7, M[R6]
                INC     R6
                LOAD    R3, M[R6]
                INC     R6
                LOAD    R2, M[R6]
                INC     R6
                STOR    M[R2], R4 ; escrever n % 10 como digito do 7SD
                INC     R2
                DEC     R3
                BR.NZ   .loop
                
                CMP     R5, R0
                BR.NZ   .done ; se o ciclo ja correu 2 vezes (2 partes do 7SD)
                
                INC     R5
                MVI     R2, START_7SD_2
                MVI     R3, DIM_7SD_2
                BR      .loop
                
.done:          LOAD    R5, M[R6] ; repoe valores de R4 e R5
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                JMP     R7 ; transferir controlo de volta


divint:         MOV     R3, R0 ; divisao inteira n // m
.loop:          CMP     R1, R0
                BR.N    .end
                SUB     R1, R1, R2
                INC     R3
                BR      .loop
                
.end:           DEC     R3
                ADD     R1, R1, R2 ; compensar subtracao a mais causada pelo 0
                DEC     R6
                STOR    M[R6], R1 ; devolve divisao (R3) e resto (pela pilha)
                
                JMP     R7 ; transferir controlo de volta
                

escrevecentrado:DEC     R6 ; recebe a cadeia de caracteres e a linha
                STOR    M[R6], R4
                DEC     R6
                STOR    M[R6], R5
                DEC     R6
                STOR    M[R6], R7 ; preservar para permitir invocacao de auxs
                
                MOV     R4, R1
                MOV     R5, R2
                JAL     strlen ; obter (em R3) o tamanho da cadeia de caracteres
                
                MVI     R1, DIMENSAO ; calcular primeira posicao
                SUB     R1, R1, R3
                SHRA    R1
                OR      R1, R5, R1 ; juntar coluna e linha
                
                MVI     R2, TERM_CURSOR
                STOR    M[R2], R1
                
                MVI     R1, TERM_WRITE
.loop:          LOAD    R2, M[R4]
                CMP     R2, R0
                BR.Z    .endLoop
                STOR    M[R1], R2
                INC     R4
                BR      .loop
                
.endLoop:       LOAD    R7, M[R6] ; repor registos
                INC     R6
                LOAD    R5, M[R6]
                INC     R6
                LOAD    R4, M[R6]
                INC     R6
                
                JMP     R7 ; retornar o controlo


strlen:         MOV     R3, R0 ; calcular o tamanho de uma cadeia de caracteres
.loop:          LOAD    R2, M[R1]
                CMP     R2, R0
                JMP.Z   R7
                INC     R3
                INC     R1
                BR      .loop
                
                
;;;;; CODIGO DE INTERRUPCOES ;;;;;
                
timerinterrupt: DEC     R6 ; funcao auxiliar de interrupcoes do temporizador
                STOR    M[R6], R1 ; excecionalmente, e necessario preservar R1-6
                DEC     R6
                STOR    M[R6], R2
                
                MVI     R1, TIMER_CONTROL ; reativar temporizador
                MVI     R2, TIMER_ENABLE
                STOR    M[R1], R2
                
                MVI     R2, timerPending
                DSI     ; desligar interrupcoes para proteger codigo sensivel
                LOAD    R1, M[R2]
                INC     R1 ; incrementar numero de interrupcoes pendentes
                STOR    M[R2], R1
                ENI     ; reativar interrupcoes

                LOAD    R2, M[R6] ; repor R1 e R2
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                
                JMP     R7 ; devolver o controlo
                
                
                ORIG    7F00h ; handle button 0 interruption
                DEC     R6
                STOR    M[R6], R1 ; interrupcoes tem que presevar R1-R7
                DEC     R6
                STOR    M[R6], R2
                
                MVI     R1, gameRunning ; variavel de controlo do jogo
                MVI     R2, 1
                STOR    M[R1], R2 ; comecar o jogo
                
                LOAD    R2, M[R6] ; repor registos
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                
                RTI     ; terminar interrupcao
                
                
                ORIG    7F30h ; handle button up interruption
                DEC     R6
                STOR    M[R6], R1 ; interrupcoes tem que preservar R1-R7
                DEC     R6
                STOR    M[R6], R2
                
                MVI     R1, saltoDino ; variavel de controlo do salto do dino
                MVI     R2, 1
                STOR    M[R1], R2 ; ativar o salto
                
                LOAD    R2, M[R6] ; repor registos
                INC     R6
                LOAD    R1, M[R6]
                INC     R6
                
                RTI     ; terminar interrupcao
                
                
                ORIG    7FF0h ; handle timer interruption
                DEC     R6
                STOR    M[R6], R7
                
                ; !!! Numero limitado de instrucoes aqui portanto
                ; !!! a funcao timerinterrupt TEM OBRIGATORIAMENTE de
                ; !!! preservar todos os registos (exceto R7)
                JAL     timerinterrupt
                
                LOAD    R7, M[R6]
                INC     R6
                
                RTI     ; terminar interrupcao