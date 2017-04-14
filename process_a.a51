$NOMOD51
#include <Reg517a.inc>

NAME processA
PUBLIC processA
EXTRN DATA (processAddress, statusFlag, repCount, serialIsBusy)
EXTRN NUMBER (stopProcessFlag)

; define a relocatable segment of the memory class CODE for the processA
processASegment SEGMENT CODE
	; switch to the created relocatable segment
	RSEG processASegment

processA:
	; print number of loops to UART
	CALL printRepCountToUART

	; convert the char '1' to integer 1 and write to R7
	MOV A, repCount
	SUBB A, #'0'
	MOV R7, A

	CALL printLettersToUART
	CALL removeProcessA



printRepCountToUART:
	; loop until serial port is free
	CALL waitForSerialAndBlock

	; print the repeat time number to UART
	MOV A, repCount
	MOV S0BUF, A									
	
	; loop until output of a character is finished
	CALL waitForLetterIsSent
RET



; loop for printing of letters to UART
printLettersToUART:	
	; reset watchdog timer
	SETB WDT
	SETB SWDT

	; print the characters "abcde"
	CALL printABCDEToUART
	
	; decrease R7 by 1, print letters until R7 = 0	
	DJNZ R7, printLettersToUART
	
	; set stop-flag for the processA	
	CALL removeProcessA
RET


; prints the characters 'abcde' to UART
printABCDEToUART:
	; write to R1 ascii value of the character 'a' (#97d)
	MOV R1, #'A' 
	
	; loop while R1 < 'F'
	loopAtoE:
		CALL waitForSerialAndBlock
		MOV S0BUF, R1
		
		; loop until output of a character is finished
		CALL waitForLetterIsSent		
		
		; increase R1 (letter) by 1
		INC R1

		; if R1 == #102d ('F') - stop, else - loop further
		CJNE R1, #'F', loopAtoE
RET



; wait for serial is free and block it after that
waitForSerialAndBlock:
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
	; reset TI0 (Serial port transmitter interrupt flag) for the next output
	ANL A, #11111101b
	MOV S0CON, A
RET


removeProcessA:
	; stop processA
	MOV DPTR, #processA
	MOV processAddress + 0, DPL
	MOV processAddress + 1, DPH
	MOV statusFlag, #stopProcessFlag
	
	; loop until processor time of processA is over
	endlessLoop:
		NOP
		NOP
	JMP endlessLoop
RET

END