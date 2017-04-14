$NOMOD51
#include <Reg517a.inc>

NAME processB

EXTRN DATA (secondLength, serialIsBusy, isTimer0Ovf, currentProcess)
PUBLIC processB

; define a relocable segment of the memory class CODE for the processB
processBSegment SEGMENT CODE
	; switch to the created relocable segment
	RSEG processBSegment


processB:
	CALL printPlusToUART
	CALL waitOneSecond
	CALL printMinusToUART
	CALL waitOneSecond
	JMP processB


; write the character '+' to UART
printPlusToUART:
	CALL waitForSeriaAndBlock
	MOV S0BUF, #'+' ;#43d
	CALL waitForLetterIsSent
	MOV A, currentProcess
RET


; write the character '-' to UART
printMinusToUART:
	CALL waitForSeriaAndBlock
	MOV S0BUF, #'-' ;#45d
	CALL waitForLetterIsSent
	MOV A, currentProcess
RET


; wait until serial is free and block it after that
waitForSeriaAndBlock:
	; while serial is busy do nothing
	checkSerialIsBusy:
		MOV A, serialIsBusy
	JB ACC.0, checkSerialIsBusy
	; block serial
	MOV serialIsBusy, #1
RET


; loop until output of a character is finished
waitForLetterIsSent:
	; SCON = SM0 | SM1 | SM2 | REN | TB8 | RB8 | TI | RI
	; we need the 1st bit (TI0) to find out if the data transmittion is finished
	MOV	A, S0CON
	; if the TI0 is not set --> transmittion not finished --> wait (go to loop)
	JNB	ACC.1, waitForLetterIsSent
	; free serial
	MOV serialIsBusy, #0
	; reset TI0 (Serial port transmitter interrupt flag) for the letters
	ANL A, #11111101b
	MOV S0CON, A
RET


; wait for ~1 second - 40 cycles, 0,025 sec each
waitOneSecond:
	MOV R5, secondLength ; #40d
	
	; wait for Timer0 overflow
	timerOverflowLoop:
		MOV A, isTimer0Ovf ; default isTimer0Ovf = 000
		CJNE A, #0, nextTimer0Ovf 
			JMP notTimer0OvfProcessB3 ; start loop again
		; check Process B1 Overflow
		nextTimer0Ovf:
			ANL A, #0x01 ; set isTimer0Ovf = xx1
			CJNE A, currentProcess, notTimer0OvfProcessB
				; current process is 01 (first ProcessB)
				MOV A, isTimer0Ovf
				ANL A, #0xFE ; set isTimer0Ovf = xx0
				MOV isTimer0Ovf, A
				JMP endTimer0OvfProcess ; end overflow for ProcessB1
		; check Process B2 Overflow
		notTimer0OvfProcessB:
			MOV A, isTimer0Ovf
			ANL A, #0x02 ; set isTimer0Ovf = x1x
			JZ notTimer0OvfProcessB2 ; if isTimer0Ovf = 000 - another process is working
			CJNE A, currentProcess, notTimer0OvfProcessB2
				; current process is 02 (second ProcessB)
				MOV A, isTimer0Ovf
				ANL A, #0xFD ; set isTimer0Ovf = x0x
				MOV isTimer0Ovf, A		
				JMP endTimer0OvfProcess ; end overflow for ProcessB2
		; check Process B3 Overflow
		notTimer0OvfProcessB2:
			;MOV A, isTimer0Ovf
			;ANL A, #0x02 
			;JZ notTimer0OvfProcessB3
			;ADD A, #0x01 ; set isTimer0Ovf = 1xx
			;CJNE A, currentProcess, notTimer0OvfProcessB3
				; current process is 03 (third ProcessB)
				;MOV A, isTimer0Ovf
				;ANL A, #0xFB ; set isTimer0Ovf = 0xx
				;MOV isTimer0Ovf, A		
				;JMP endTimer0OvfProcess ; end overflow for ProcessB3
		notTimer0OvfProcessB3:
			JMP timerOverflowLoop
	endTimer0OvfProcess:

	; reset watchdog
	SETB WDT
	SETB SWDT

	; return to a new overflow loop if R5 is not yet = 0
	DJNZ R5, timerOverflowLoop
RET

END