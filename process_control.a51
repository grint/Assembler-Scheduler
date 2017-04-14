$NOMOD51
#include <Reg517a.inc>

NAME processControl

EXTRN CODE (processA, processB)
EXTRN DATA (processAddress, statusFlag, repCount)
EXTRN NUMBER (newProcessFlag, stopProcessFlag)
PUBLIC processControl

; define a relocable segment of the memory class CODE for the processBControl
processControlSegment SEGMENT CODE
	; switch to the created relocable segment
	RSEG processControlSegment

processControl:
	; reset watchdog timer
	SETB WDT
	SETB SWDT
	
	; wait for input on UART
	waitForInput:
	JNB RI0, waitForInput
	
	; read input and call the serial handler
	MOV R7, S0BUF
	CALL readSerial
	


; start or delete processes according to a received charachter
readSerial:
	checkLetterB:
	CJNE R7, #'b', checkLetterC
		; start processB
		MOV DPTR, #processB
		MOV processAddress + 1, DPH
		MOV processAddress + 0, DPL
		MOV statusFlag, #newProcessFlag
		JMP noValidProcess
	
	checkLetterC:
	CJNE R7, #'c', checkNumbers
		; delete processB
		MOV DPTR, #processB
		MOV processAddress + 1, DPH
		MOV processAddress + 0, DPL
		MOV statusFlag, #stopProcessFlag	
		JMP noValidProcess
	
	checkNumbers:
		; check input on R7 and set parameters accordingly
		MOV A, R7
		; clear CY (carry)
		CLR C
		; if less than '1' - jump to noValidProcess
		SUBB A, #'1'
		JC noValidProcess
		; if greater than '9' - jump to noValidProcess
		SUBB A, #0x09
		; jump if the carry flag is not set
		JNC noValidProcess
			; start processA
			MOV repCount, R7
			MOV DPTR, #processA
			MOV processAddress + 1, DPH
			MOV processAddress + 0, DPL
			MOV statusFlag, #newProcessFlag
	
	noValidProcess:
		; reset R7
		MOV R7, #0x0
		; reset receiver interrupt flag
		CLR RI0
		; wait further
		JMP processControl

END