;-------------------------------------------------------------------------------
;	
;   Esame di Architetture e Programmazione di Sistemi Digitali/Sistemi Elettronici 
;   Autori Vivien Owabor e Mario Rossetti
;   Corso Ingegneria Elettronica / Ingegneria Elettronica e delle Tecnologie Digitali
;   Università Politecnica delle Marche, Ancona 
;	
;   Data consegna progetto 26/11/2024 
;   
;   Traccia 56: 
;   Si realizzi un firmware che riceva dal computer tramite porta seriale (USART) una
;   parola, come sequenza di codici ASCII dei singoli caratteri. La parola è terminata da
;   un punto ed è di lunghezza massima fissata a priori. Dopo aver ricevuto la parola, il
;   programma deve convertire tutti i caratteri in minuscolo (solo quelli nel range 'A'..'Z')
;   e reinviarla sulla porta seriale (USART).	
; 		
;-------------------------------------------------------------------------------		      
			     			      
PROCESSOR 16F887	;direttiva che definisce il tipo di processore
#include <xc.inc>	;file che contiene le definizioni dei simboli (nomi registri, nomi bit dei registri, ecc).
#include "macro.inc"	;definizione di macro utili

;CONFIGURATION BITS
    CONFIG "FOSC = INTRC_NOCLKOUT"	;configura l'oscillatore del microcontrollore per utilizzare il clock interno (INTRC)
					//il segnale di clock non viene inviato all'esterno (NOCLKOUT)
    CONFIG "CP = OFF"			;PFM (Program Flash Memory) and Data EEPROM code protection disabled
        				//disabilita la protezione del codice memorizzato nel microcontrollore
					//il codice può essere letto esternamente
    CONFIG "CPD = OFF"			;Data memory code protection is disabled
        				//disabilita la protezione del codice nella memoria dati EEPROM
					//la memoria può essere letta o scritta esternamente
    CONFIG "WDTE = OFF"			;disabilita il Watchdog Timer
    CONFIG "BOREN = OFF"		;disabilita il Brown-out Reset
    CONFIG "PWRTE = OFF"		;disabilita il Power-up Timer
    CONFIG "LVP = OFF"			;Low voltage programming disabled 
					//disabilita la Low Voltage Programming, altrimenti il pin RB3 (porta B) 
					//non può essere utilizzato come I/O generico.
					//(_LVP_ON -> RB3/PGM come PGM pin cioè per ICSP = In-Circuit Serial Programming)
    CONFIG "DEBUG = OFF"		;Background debugger disabled
    					//disabilita la modalità di debug del microcontrollore
;CONFIG2
    CONFIG "BOR4V = BOR21V"	;Brown-out Reset Selection bit (Configura la soglia del Brown-out Reset a 2,1 V)
    CONFIG "WRT = OFF"		;disabilita la protezione in scrittura della memoria Flash
	   
;Variabili in RAM (shared RAM)
    PSECT udata_shr 
 
tmp:
    DS 1    ;variabile temporanea per calcoli intermedi

;------------------------------INIZIO PROGRAMMA---------------------------------
;Reset vector
    PSECT resetVec,class=CODE,delta=2
    
resetVec:
    PAGESEL start
    GOTO start
    
;------------------------------CICLO PRINCIPALE---------------------------------
PSECT MainCode,global,class=CODE,delta=2    ;codice rilocabile
    
start: 
    PAGESEL INIT
    CALL INIT	    ;inizializzazione hardware
    PAGESEL BUFF
    CALL BUFF	    ;inizializzazione del buffer
    CLRF BUF_START  ;pulizia dell'inizio del buffer
	
    ;va a capo
    PAGESEL STAMPA_CAPO
    CALL STAMPA_CAPO
	
    ;stampa "SCRIVI" all'avvio
    PAGESEL STAMPA_SCRIVI
    CALL STAMPA_SCRIVI
    		
RX:	
    ;ATTESA DEI DATI: inizio ricezione dei caratteri
    BANKSEL PIR1		    ;il registro PIR1 contiene i flag bits delle interruzioni periferiche
    BTFSS PIR1,PIR1_RCIF_POSITION   ;BTFSS è un bit test che controlla se è stato ricevuto un carattere
    GOTO RX			    ;se RCIF=1, salta il GOTO e va in RIC, altrimenti continua ad aspettare
	
;RICEZIONE CARATTERE
RIC:	
    BANKSEL RCREG   ;EUSART Receive Data Register
    MOVF RCREG,W    ;prendo il dato ricevuto dal registro e lo metto su W
    MOVWF TEMP	    ;salvo il dato da W a TEMP

    ;SALVA IL CARATTERE nel buffer tramite indirizzamento indiretto
    MOVF TEMP,W	    ;copio TEMP in W
    MOVWF INDF	    ;salva il carattere nel buffer tramite FSR
	
    ;visualizzazione parola immessa dall'utente
    BANKSEL TXREG   ;EUSART Transmit Data Register	    
    MOVF INDF,W	    ;prendo il carattere dal buffer e lo metto su W
    MOVWF TXREG	    ;carica il carattere nel registro di trasmissione per stamparlo a schermo

    ;CONTROLLO PUNTO: primo controllo per far partire la conversione prima della lunghezza massima
    ;prendo il carattere dal buffer e lo confronto con '.'
    MOVF INDF,W				;prendo il carattere dal buffer e lo metto su W		
    MOVWF TEMP				;carica il carattere in TEMP
    MOVLW '.'				;metto il carattere '.' in W
    SUBWF TEMP,W			;sottrazione di W da TEMP, il risultato va in W.
					//se W=TEMP='.', Z diventa 1
    BTFSC STATUS,STATUS_Z_POSITION	;BIT-TEST: se Z=0, salta la prossima istruzione e continua la ricezione, 
	                                //altrimenti si va al GOTO CONVERT
    GOTO CONVERT			;sezione in cui avviene la conversione 
	
    INCF FSR,F		;incremento l'FSR per salvare il carattere nel buffer
    DECFSZ LUNG_MAX,F   ;decremento di 1 il valore della lunghezza massima
    GOTO RX		;se LUNG_MAX è diverso da 0, vado a ricevere il prossimo carattere
    GOTO CONTROLLO	;se LUNG_MAX è uguale a 0, vado a controllare il carattere appena immesso

;---------------------- SALVA NEL BUFFER (Indirizzamento indiretto) ------------------------------
CONTROLLO:
    DECF FSR,F	;decremento l'FSR perchè si trova in una posizione successiva all'ultimo carattere
    
    ;CONTROLLO PUNTO: secondo controllo per verificare che l'ultimo carattere immesso sia il punto
    ;prendo il carattere dal buffer e lo confronto con '.'
    MOVF INDF,W				;prendo il carattere dal buffer e lo metto su W			
    MOVWF TEMP				;carica il carattere in TEMP
    MOVLW '.'				;metto il carattere '.' in W
    SUBWF TEMP,W			;sottrazione di W da TEMP, il risultato va in W.
					//se W=TEMP='.', Z diventa 1
    BTFSC STATUS,STATUS_Z_POSITION	;BIT-TEST: se Z=0 si va al GOTO start, altrimenti si va al GOTO CONVERT
    GOTO CONVERT			;sezione in cui avviene la conversione 
    GOTO start
    
CONVERT:
    PAGESEL BUFF
    CALL BUFF	    ;riconfiguro buffer e lung_max
    
CICLO_CONVERT: ;ciclo di conversione di tutti i caratteri tranne il '.'
    
    ;CONTROLLO PUNTO: faccio la conversione fino al carattere prima del punto
    MOVF INDF,W				;prendo il carattere dal buffer e lo metto su W
    MOVWF TEMP				;carica il carattere in TEMP
    MOVLW '.'				;metto il carattere '.' in W
    SUBWF TEMP,W			;sottrazione di W da TEMP, il risultato va in W.
					//se W=TEMP='.', Z diventa 1
    BTFSC STATUS,STATUS_Z_POSITION	;BIT-TEST: se Z=0, salta la prossima istruzione e continua il ciclo di conversione, 
					//altrimenti va al GOTO INIT_TRANS
    GOTO INIT_TRANS			;sezione in cui avviene il ciclo di trasmissione
    
    ;recupera il carattere dal buffer
    MOVF INDF,W				;prendo il carattere dal buffer e lo metto su W
    MOVWF TEMP				;salva il carattere in TEMP
    MOVLW 'Z'				;carica il carattere 'Z' in W
    SUBWF TEMP,W			;sottrazione di 'Z' da TEMP. Se 'Z'<=TEMP, allora C=1
    BTFSS STATUS,STATUS_C_POSITION	;BIT-TEST: se C=1, significa che il carattere è minuscolo e va al GOTO INCREMENTO, 
					//altrimenti si va al GOTO MINUSCOLO
    GOTO MINUSCOLO			;vai alla sezione MINUSCOLO
    GOTO INCREMENTO			;vai alla sezione INCREMENTO

INCREMENTO: ;se il carattere è minuscolo, non lo devo convertire e quindi passo alla valutazione del prossimo carattere
    INCF FSR,F		;incrementa il puntatore FSR
    DECFSZ LUNG_MAX,F   ;decremento di 1 il valore della lunghezza massima
    GOTO CICLO_CONVERT  ;se LUNG_MAX è diverso da 0, continuo la conversione
    GOTO INIT_TRANS     ;se LUNG_MAX=0, inizia la trasmissione
     
MINUSCOLO:
    ;CONVERSIONE DA MAIUSCOLO A MINUSCOLO (aggiunge 0x20)
    MOVLW 0x20		;aggiunge 0x20 per convertire da maiuscolo a minuscolo
    ADDWF INDF,F	;aggiorna il carattere nel buffer
    GOTO INCREMENTO	;vai a incrementare l'FSR e poi, a seconda di LUNG_MAX, si sceglie come proseguire

;---------------------- ROUTINE DI TRASMISSIONE --------------------------------
INIT_TRANS: ;inizializzazione della trasmissione
    ;stampa "CONVERSIONE:" all'avvio della trasmissione
    PAGESEL STAMPA_CAPO
    CALL STAMPA_CAPO	    ;sezione che manda a capo
    PAGESEL STAMPA_CONV
    CALL STAMPA_CONV	    ;sezione che stampa "CONVERSIONE:"
    PAGESEL BUFF
    CALL BUFF		    ;riconfigurazione buffer e lung_max
    
TRANS: ;trasmissione
    BANKSEL PIR1		    ;il registro PIR1 contiene i flag bits delle interruzioni periferiche
    BTFSS PIR1,PIR1_TXIF_POSITION   ;aspetta finché il registro di trasmissione non è pronto
    GOTO TRANS			    ;se TXIF=1, salta l'istruzione successiva, altrimenti continua ad aspettare
      
    BANKSEL TXREG   ;EUSART Transmit Data Register
    MOVF INDF,W	    ;prendo il carattere dal buffer e lo metto su W
    MOVWF TXREG	    ;carica il carattere nel registro di trasmissione
    
    ;CONTROLLO PUNTO: Terzo controllo per trasmettere i caratteri fino al punto
    ;prendo il carattere dal buffer e lo confronto con '.'
    MOVF INDF,W				;prendo il carattere dal buffer e lo metto su W
    MOVWF TEMP				;salva il carattere in TEMP
    MOVLW '.'				;;carica il carattere '.' in W
    SUBWF TEMP,W			;sottrazione di W da TEMP, il risultato va in W.
					//se W=TEMP='.', Z diventa 1
    BTFSC STATUS,STATUS_Z_POSITION	;BIT-TEST: se Z=0, l'istruzione successiva viene saltata e 
					//quindi continua il ciclo di trasmissione, altrimenti si va al GOTO start
    GOTO start

    INCF FSR,F		;incremento per trasmettere il carattere successivo
    DECFSZ LUNG_MAX,F	;decremento di 1 il valore della lunghezza massima
    GOTO TRANS		;se LUNG_MAX è diverso da 0, continuo la trasmissione
    GOTO start		;se LUNG_MAX=0, ritorno allo start
    
;------------------------------INIZIALIZZAZIONI---------------------------------
INIT: ;inizializzazione dell'hardware
    BUF_START EQU 0x30	;indirizzo di partenza del buffer per la ricezione
    LUNG_MAX EQU 0x70   ;lunghezza max della parola (posizionata lontana dalle prime posizioni 
			//per non incorrere in errori)
    TEMP EQU 0x20	;variabile temporanea per la conversione
    CLRF TEMP		;azzera il contenuto del registro di indirizzo 0x20
    
    ;inizializzazione dei LED utilizzati come verifica durante la progettazione
    BANKSEL TRISD   ;PORTD Tri-State Control bit
    BCF TRISD,0	    ;azzera il bit TRISD0, quindi configura il Pin PORTD come uscita
    BANKSEL PORTD   ;PORTD General Purpose I/O Pin bit
    BCF PORTD,0	    ;azzerra il bit RD0, quindi spegne il LED
    
    ;EUSART
    ;INIZIALIZZAZIONE EUSART per trasmissione
    BANKSEL TXSTA	;EUSART Transmit Status and Control Register	    
    MOVLW 00100100B     ;TXEN=1 (Transmit enabled), SYNC=0 (Asynchronous mode), BRGH=1 (High speed asynchronous mode)
    MOVWF TXSTA         ;imposta il registro TXSTA

    BANKSEL RCSTA	;EUSART Receive Status and Control Register
    MOVLW 10010000B     ;SPEN=1 (porta seriale abilitata), CREN=1 (ricezione abilitata)
    MOVWF RCSTA         ;imposta il registro RCSTA
    
    BANKSEL OSCCON      ;Oscillator Control Register 
    MOVLW 01110001B	;frequenza dell'oscillatore interno impostata a 8MHz
    MOVWF OSCCON        ;scrive il valore in OSCCON
    
    BANKSEL BAUDCTL	;Baud Rate Control Register
    CLRF BAUDCTL	;azzera il registro, allora BRG16=0 (8-bit Baud Rate Generator is used)

    BANKSEL SPBRG   ;insieme al bit BRGH determinano il Baud Rate
    MOVLW 25	    ;muovo il 25 in W
    MOVWF SPBRG	    ;sposto il 25 nel registro SPBRG, così impostando il Baud Rate a 19200
    
    RETURN  ;return from subroutine
    
BUFF: ;INIZIALIZZAZIONE DEL BUFFER
    ;imposto il valore in LUNG_MAX=8
    CLRF LUNG_MAX	;azzera il registro	   
    MOVLW 0x08		;muove l'esadecimale(=8 decimale) in W
    MOVWF LUNG_MAX	;muove l'esadecimale in W
    MOVLW BUF_START     ;carica l'inizio del buffer
    MOVWF FSR           ;FSR punta all'inizio del buffer
    RETURN		;return from subroutine
    
;------------------------------ROUTINE SCRITTURA--------------------------------
STAMPA_CAPO: ;va a capo
    MOVLW 0x0A		    ;muove l'esadecimale(=10 decimale) in W
    CALL INVIA_CARATTERE    ;chiama la sezione che invia il carattere
    RETURN		    ;return from subroutine
    
STAMPA_SCRIVI: ;routine per inviare "SCRIVI"
    MOVLW 'S'		    ;carattere 'S'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'C'		    ;carattere 'C'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'R'		    ;carattere 'R'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'I'		    ;carattere 'I'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'V'		    ;carattere 'V'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'I'		    ;carattere 'I'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW ':'		    ;carattere ':'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 0x0A		    ;va a capo
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    RETURN		    ;return from subroutine

STAMPA_CONV: ;stampa "CONVERSIONE:"
    MOVLW 'C'		    ;carattere 'C'    
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'O'		    ;carattere 'O'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'N'		    ;carattere 'N'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'V'		    ;carattere 'V'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'E'		    ;carattere 'E'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'R'		    ;carattere 'R'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'S'		    ;carattere 'S'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'I'		    ;carattere 'I'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'O'		    ;carattere 'O'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'N'		    ;carattere 'N'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 'E'		    ;carattere 'E'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW ':'		    ;carattere ':'
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    MOVLW 0x0A		    ;va a capo
    CALL INVIA_CARATTERE    ;chiama la subroutine per inviare il carattere
    RETURN		    ;return from subroutine

INVIA_CARATTERE: ;routine per inviare un singolo carattere via USART
    BANKSEL PIR1			;il registro PIR1 contiene i flag bits delle interruzioni periferiche
    BTFSS PIR1, PIR1_TXIF_POSITION	;aspetta finché il registro di trasmissione non è pronto
    GOTO INVIA_CARATTERE		;se TXIF=1, salta questa istruzione e continua la routine, 
					//altrimenti continua ad aspettare
    BANKSEL TXREG   ;EUSART Transmit Data Register	
    MOVWF TXREG	    ;carica il carattere da inviare nel registro TXREG
    RETURN	    ;return from subroutine

;---------------------- TERMINAZIONE DEL PROGRAMMA -------------------
FINE_PROG:
    END resetVec    ;direttiva che segnala all'assemblatore la fine del programma