; Autor reseni: Václav Berný xberny00
; Pocet cyklu k serazeni puvodniho retezce: 2542
; Pocet cyklu razeni sestupne serazeneho retezce: 3208
; Pocet cyklu razeni vzestupne serazeneho retezce: 337
; Pocet cyklu razeni retezce s vasim loginem: 628
; Implementovany radici algoritmus: Bubble sort
; ------------------------------------------------

; DATA SEGMENT
                .data
; login:          .asciiz "vitejte-v-inp-2023"  ; puvodni uvitaci retezec
; login:          .asciiz "vvttpnjiiee3220---"  ; sestupne serazeny retezec
; login:          .asciiz "---0223eeiijnpttvv"  ; vzestupne serazeny retezec
 login:          .asciiz ""             ; SEM DOPLNTE VLASTNI LOGIN
                                                ; A POUZE S TIMTO ODEVZDEJTE

params_sys5:    .space  8   ; misto pro ulozeni adresy pocatku
                            ; retezce pro vypis pomoci syscall 5
                            ; (viz nize - "funkce" print_string)

; CODE SEGMENT
                .text
main:
        lb      r2, login(r1)           ;load first char
        beqz    r2, end                         ;if end of string, jump to end
        daddi   r9, r9, 1
        daddi   r8, r8, 1
        while:
                lb      r2, login(r1)           ;load first char
                lb      r3, login(r9)           ;load second char
                
                daddi   r1, r1, 1               ;i++
                daddi   r9, r9, 1               ;j++

                sltu    r5, r3, r2              ;if r3 >= r2 then r5 = 0
                beqz    r3, check               ;if end of string, jump to check
                daddi   r6, r1, -1
                beqz    r5, while               ;if r5 = 0 then go to next

                sb      r2, login(r1)           ;swap
                sb      r3, login(r6)
                jal     while

        check:
                lb      r2, login(r7)           ;load first char
                lb      r3, login(r8)           ;load second char
                
                daddi   r7, r7, 1               ;i++
                daddi   r8, r8, 1               ;j++

                sltu    r5, r3, r2              ;if r3 >= r2 then r5 = 0
                beqz    r3, end                 ;if end of string, jump to end
                xor     r1, r1, r1              ;null the r1
                beqz    r5, check               ;if r5 = 0 then go to next
                
                daddi   r9, r7, 0
                daddi   r1, r7, -1              ;its sorted till this position
                
                daddi   r8, r0, 1               ;set value of r8 to 1
                xor     r7, r7, r7              ;null the r7
                
                jal     while                   ;not in order, go to another iteration
        
        end:
                daddi   r4, r0, login   ; vozrovy vypis: adresa login: do r4
                jal     print_string    ; vypis pomoci print_string - viz nize
                syscall 0   ; halt

print_string:   ; adresa retezce se ocekava v r4
                sw      r4, params_sys5(r0)
                daddi   r14, r0, params_sys5    ; adr pro syscall 5 musi do r14
                syscall 5   ; systemova procedura - vypis retezce na terminal
                jr      r31 ; return - r31 je urcen na return address

