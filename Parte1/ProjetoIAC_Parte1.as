; Projeto de Introducao a Arquitetura de Computadores 2020/21
; PARTE 1
; Joao Antunes 99257
; Rafael Oliveira 99311

DIMENSAO        EQU     80 ; numero de posicoes do vetor
ALTURA          EQU     4 ; altura dos cactos

                ORIG    4000h
                
terreno         TAB     DIMENSAO ; terreno de jogo

                ORIG    5000h

x               WORD    5 ; valor inicial = semente

                ORIG    0000h
                
                MVI     R6, 8000h ; inicializacao stack pointer
                
loop:           MVI     R1, terreno ; passar endereco inicial do vetor
                MVI     R2, DIMENSAO ; passar dimensao do vetor
                JAL     atualizajogo ; invocar atualizajogo
                BR      loop ; loop infinito

Fim:            BR      Fim


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
                BR.NZ   loop ; repetir se faltarem iteracoes (pelo contador)
                
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
                