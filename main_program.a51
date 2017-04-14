$NOMOD51
#include <Reg517a.inc>

EXTRN CODE (processA, processB, processControl)
PUBLIC processAddress, statusFlag, stacks
PUBLIC stopProcess, startNewProcess ; helper functions
PUBLIC newProcessFlag, stopProcessFlag, noProcessFlag ; flags
PUBLIC repCount, secondLength, serialIsBusy, isTimer0Ovf ; helper constants
PUBLIC currentProcess

; define status flags values
noProcessFlag EQU 0
newProcessFlag EQU 1
stopProcessFlag EQU 2


; define a relocatable segment of the memory class DATA for the program
programData SEGMENT DATA
	; switch to programData segment
	RSEG programData
		
	; Program Counter (Instruction Pointer)
	processIPTable: DS 8
	
	; -------X | -------X | -------X | -------X
	; processA | processB | processB2 | processControl
	activeFlags: DS 4
	isProcessA EQU activeFlags
	isProcessB EQU activeFlags + 1
	isProcessB2 EQU activeFlags + 2
	isProcessControl EQU activeFlags + 3
	;isProcessB3 EQU activeFlags + 4
	
	; to tell the scheduler which process has to be started or stopped
	processAddress: DS 2
	processAddressL EQU processAddress
	processAddressH EQU processAddress + 1		

	; to tell the scheduler if the process, stored in processAddress,
	; has to be started or stopped.
	; Possible options: newProcessFlag, stopProcessFlag, noProcessFlag
	statusFlag: DS 1

	; pointer to the current process
	currentProcess: DS 1
		
	; to save process priorities in array
	priorities: DS 4

	; to save processes StackPointers in array
	stacks: DS 4
	
	; array of initial StackPointers
	stackStartAddr: DS 4
	
	; to store the number, which point how many times to repeat "ABCDE"
	repCount: DS 1

	; for the magic number - to make the second length ~1 sec
	secondLength: DS 1

	; to check if sending to UART is done
	serialIsBusy: DS 1
		
	isTimer0Ovf: DS 1
		
	; 20 Byte for each process	
	processData: DS 80


; define the absolute segments for the timer interrupts
CSEG AT 1Bh
JMP	scheduler

CSEG AT 0Bh
JMP	timer0Overflow

; define an absolute segment
; program execution always starts on reset at location 0000
CSEG AT 0
; jump to the start of the program 
JMP	start


; define a relocatable segment of the memory class CODE for the program
programCode SEGMENT CODE
	; switch to the created relocatable segment
	RSEG programCode


start:
	; reset watchdog timer
	SETB WDT
	SETB SWDT	
	
	; set SP to the new stack for the program
	MOV SP, #processData
	CALL init

	; initialize Stack Pointer
	MOV A, #stacks
	ADD A, currentProcess
	MOV R0, A
	mov SP, @R0

	; endless loop to make the scheduler work forever
	endlessStartLoop:
		NOP
		NOP
		; reset watchdog timer
		SETB WDT
		SETB SWDT
	JMP endlessStartLoop



; enables interrupts and UARTs, sets timer modes and
; initializes the needed data
init:	
	; enable all interrupts, each interrupt source is individually enabled
	SETB EAL
	; enable Timer1 overflow interrupt 
	SETB ET1
	; enable Timer0 overflow interrupt 
	SETB ET0
	
	configSerial0:
		; SCON = SM0 | SM1 | SM2 | REN | TB8 | RB8 | TI | RI
		;		   0	1	  0		1	  
		; Set Serial0 to Mode 1 (8-bit UART, variable baud rate - mode 1)
		CLR	SM0
		SETB SM1
	
		; enable receiving
		SETB REN0	
		
		; enable programmable baudrate generator
		SETB BD
		
		; set SMOD = 0
		MOV A, PCON			
		CLR	ACC.7					
		MOV	PCON, A	
		
		; set baud rate to 14400
		MOV	S0RELL, #0xE6
		MOV	S0RELH, #0x03

	configTimer:
		; set mode of timer1 and timer0 to Mode 1 - 16-bit (M1=0, M0=1)
		; TMOD = Gate | C/T | M1 | M0 | Gate | C/T | M1 | M0
		MOV	A, #00010001b
		MOV TMOD, A

		; start timer1
		; TCON = TF1 | TR1 | TF0 | TR0 | IE1 | IT1 | IE0 | IT0
		SETB TR1
		
		; init timer 0
		MOV TL0, #0xB0
		MOV TH0, #0x3C
		; start timer 0
		SETB TR0
	
	; initialize statusFlag to 0 - there are no processes yet
	MOV statusFlag, #noProcessFlag
	
	; init repeat times with 0
	MOV repCount, #0x00

	; init secondLength with magic loop number
	MOV secondLength, #40d
	
	MOV isTimer0Ovf, #0x00

	; set that serial port is free
	MOV serialIsBusy, #0

	; init priorities for each process
	MOV priorities + 0, #0xC0 ;processA
	MOV priorities + 1, #0xC0 ;processB
	MOV priorities + 2, #0xC0 ;processB2
	MOV priorities + 3, #0xE0 ;processControl

	; set currentProcess to the process A row
	; the value will be set to the next one (0) by the scheduler
	MOV currentProcess, #3

	; initialize start addresses of the processes and 
	; set all processes to inactive mode
	
	; Process A start address
	MOV DPTR, #processA
	MOV processIPTable , DPL
	MOV processIPTable + 1, DPH
	; Process A is inactive
	MOV isProcessA, #0x00
	
	; Process B start address
	MOV DPTR, #processB
	MOV processIPTable + 2, DPL
	MOV processIPTable + 3, DPH	
	; Process B is inactive
	MOV isProcessB, #0x00

	; Process B2 start address
	MOV DPTR, #processB
	MOV processIPTable + 4, DPL
	MOV processIPTable + 5, DPH
	; Process B2 is inactive
	MOV isProcessB2, #0x00

	; Process Control start address
	MOV DPTR, #processControl
	MOV processIPTable + 6, DPL
	MOV processIPTable + 7, DPH
	; Process Control is inactive
	MOV isProcessControl, #0x00

	; Process B3 start address
	;MOV DPTR, #processB
	;MOV processIPTable + 8, DPL
	;MOV processIPTable + 9, DPH
	; Process B3 is inactive
	;MOV isProcessB3, #0x00

	; init Stack Pointers for each process
	; process A
	MOV A, #processData
	MOV stacks, A
	MOV stackStartAddr, A
	; process B - processData+20
	ADD A, #20
	MOV stacks + 1, A
	MOV stackStartAddr + 1, A
	; Process B2 - processData+40
	ADD A, #20
	MOV stacks + 2, A
	MOV stackStartAddr + 2, A
	; Process Control - processData+60
	ADD A, #20
	MOV stacks + 3, A
	MOV stackStartAddr + 3, A
	; Process B3 - processData+80
	;ADD A, #20
	;MOV stacks + 4, A
	;MOV stackStartAddr + 4, A

	; call ProcessControl
	; set the statusFlag to newProcessFlag 
	; to let processControle be started by the scheduler
	MOV DPTR, #processControl
	MOV processAddress + 0, DPL
	MOV processAddress + 1, DPH
	MOV statusFlag, #newProcessFlag
RET



; timer interrupt that determines the current process
; and starts or deletes processes
scheduler:
	SETB WDT
	SETB SWDT

	; clear TF1 (Timer 1 overflow flag)
	CLR TF1

	; save Program Counter (PC, 2 Bytes)
	POP DPH
	POP DPL
	MOV A, #processIPTable
	ADD A, currentProcess 
	ADD A, currentProcess
	MOV R0, A
	MOV @R0, DPL
	INC R0
	MOV @R0, DPH

	; push registers to the stack
	PUSH PSW
	PUSH 0
	PUSH 1
	PUSH 2
	PUSH 3
	PUSH 4
	PUSH 5
	PUSH 6
	PUSH 7
	PUSH ACC
	PUSH B
	PUSH DPH
	PUSH DPL

	; save StackPointer
	MOV A, #stacks 
	; INC R0
	ADD A, currentProcess
	MOV R0, A
	MOV @R0, SP
	
	; iterate until an active process is found
	activeProcessLoop:		
		; reset watchdog timer
		SETB WDT
		SETB SWDT		
		; increment currentProcess, initial value = 3
		MOV A, currentProcess
		INC A
		CJNE A, #4, notFirstProcess
			; reset currentProcess if it already points to the last row 
			MOV A, #0
		notFirstProcess:
			MOV currentProcess, A

		; check status flags
		MOV R0, statusFlag
		; status flag = new
		CJNE R0, #newProcessFlag, notNew
			JMP startNewProcess
		notNew:
		; status flag = delete
		CJNE R0, #stopProcessFlag, notNewNotStop
			JMP stopProcess
		notNewNotStop:
		; reset statusFlag 
		MOV statusFlag, #noProcessFlag
		
		; check active flag
		MOV A, #activeFlags
		ADD A, currentProcess
		MOV R1, A
		CJNE @R1, #0x01, activeProcessLoop 
	
	; set timer according to priority
	MOV TL1, #0x00
	; check if process A
	CJNE R1, #isProcessA, notProcessA
	CLR TR1
	MOV TH1, priorities
	SETB TR1
	notProcessA:
	; check if process B
	CJNE R1, #isProcessB, notProcessB
		CLR TR1
		MOV TH1, priorities + 1
		SETB TR1
	notProcessB:
	; check if process B2
	CJNE R1, #isProcessB, notProcessB2
		CLR TR1
		MOV TH1, priorities + 2
		SETB TR1
	notProcessB2:
	; check if process 4
	CJNE R1, #isProcessControl, notProcessControl
		CLR TR1
		MOV TH1, priorities + 3
		SETB TR1
	notProcessControl:
	;CJNE R1, #isProcessB3, notProcessB3
		;CLR TR1
		;MOV TH1, priorities
		;SETB TR1
	;notProcessB3:

	; restore the SP of the current process 
	loadStackPointer:
		MOV A, currentProcess
		ADD A, #stacks
		MOV R0, A
		MOV SP, @R0
	
	; pop registers from the stack for the current process
	popRegisters:
		POP DPL
		POP DPH
		POP B
		POP ACC
		POP 7
		POP 6
		POP 5
		POP 4
		POP 3
		POP 2
		POP 1
		POP 0
		POP PSW
	
	MOV A, #processIPTable
	ADD A, currentProcess
	ADD A, currentProcess
	MOV R0, A
	MOV DPL, @R0
	PUSH DPL
	INC R0
	MOV DPH, @R0
	PUSH DPH		
RETI


timer0Overflow:
	; init timer - #15536d	
	MOV TL0, #0xB0
	MOV TH0, #0x3C
	
	MOV isTimer0Ovf, #0x07 ; 111

	; reset overflow flag
	CLR TF0
RETI


; called from the scheduler if stopProcessFlag flag is set
stopProcess:
	; reset watchdog timer
	SETB WDT
	SETB SWDT

	; determine the process to delete and set its active flag to 0
	; compare the current process address with the address of the processes
	processAtoStop:
		MOV DPTR, #processA
		MOV A, DPH
		CJNE A, processAddressH, processBtoStop
			MOV A, DPL
			CJNE A, processAddressL, processBtoStop
				MOV isProcessA, #0x00
				JMP endStop
				
	processBtoStop:
		MOV DPTR, #processB
		MOV A,DPH		
		CJNE A, processAddressH, processControlToStop
			MOV A, DPL
			CJNE A, processAddressL, processControlToStop
			
			MOV A, isProcessB
			CJNE A, #0x01, processB2toStop
				; stop process B1
				MOV isProcessB, #0x00
				JMP endStop
			processB2toStop:
				; stop process B2
				MOV isProcessB2, #0x00
				JMP endStop

	processControlToStop:
		MOV DPTR, #processControl
		MOV A, DPH		
		CJNE A, processAddressH, endStop
			MOV A,DPL
			CJNE A, processAddressL, endStop			
				MOV isProcessControl, #0x00
				JMP endStop

	endStop:
		JMP notNewNotStop



; called from the scheduler if newProcessFlag flag is set
startNewProcess:
	; reset watchdog timer
	SETB WDT
	SETB SWDT
	
	; determine the process to start and set its active flag to 1
	processAtoStart:
		; compare the current process address with the address of processA
		MOV DPTR, #processA	
		MOV A,DPH
		CJNE A, processAddressH, processBtoStart
			; still chance that it's processA
			MOV A, DPL
			CJNE A, processAddressL, processBtoStart	
				; yes, it's process A to start, set PC
				MOV processIPTable, DPL
				MOV processIPTable+1, DPH
				; move stack pointer to the begin of the stack
				MOV SP, stackStartAddr
				; push startadress of the process on the stack
				PUSH PSW
				PUSH 0
				PUSH 1
				PUSH 2
				PUSH 3
				PUSH 4
				PUSH 5
				PUSH 6
				PUSH 7
				PUSH ACC
				PUSH B
				PUSH DPH
				PUSH DPL
				; store the changed stackpointer 
				; and set the active flag of the process to 1
				MOV stacks, SP
				MOV isProcessA, #0x01
				MOV currentProcess, #0x00
				
				JMP endStart
				
	processBtoStart:
		; compare the current process address with the address of processB
		MOV DPTR, #processB
		MOV A, DPH
		CJNE A, processAddressH, processControlToStart
			; still chance that it's processB
			MOV A, DPL
			CJNE A, processAddressL, processControlToStart							
				; yes, it's process B to start
				; check if processB is runnig already
				MOV A, isProcessB
				CJNE A, #0x01, processBNotRunning
					; processB is runnig, start a new one
					; check if process4 is runnig
					checkIfProcessB2Runnig:
						MOV A, isProcessB2
						;CJNE A, #0x00, checkIfProcessB3Runnig
						CJNE A, #0x00, endCheckProcessB
							; process B2 (index 2) is free to use
							MOV processIPTable+4, DPL
							MOV processIPTable+5, DPH			
							MOV SP, stackStartAddr + 2
							; push startadress of the process on the stack
							;CALL pushRegistersProcess4
							PUSH PSW
							PUSH 0
							PUSH 1
							PUSH 2
							PUSH 3
							PUSH 4
							PUSH 5
							PUSH 6
							PUSH 7
							PUSH ACC
							PUSH B
							PUSH DPH
							PUSH DPL
							; store the changed stackpointer
							; and set the active flag of the process to 1				
							MOV stacks + 2, SP
							MOV isProcessB2, #0x01
							MOV currentProcess, #0x02
							JMP endCheckProcessB
					
					;checkIfProcessB3Runnig:
						;MOV A, isProcessB3
						;CJNE A, #0x00, endCheckProcessB
							; process B3 (index 4) is free to use
							;MOV processIPTable+8, DPL
							;MOV processIPTable+9, DPH			
							;MOV SP, stackStartAddr + 4
							; push startadress of the process on the stack
							; store the changed stackpointer
							; and set the active flag of the process to 1				
							;MOV stacks + 4, SP
							;MOV isProcess5, #0x01
							;MOV currentProcess, #0x04
							;JMP endCheckProcessB

				processBNotRunning:
					; processB not runnig, start it, set PC
					MOV processIPTable+2, DPL
					MOV processIPTable+3, DPH			
					MOV SP, stackStartAddr + 1
					; push startadress of the process on the stack
					PUSH PSW
					PUSH 0
					PUSH 1
					PUSH 2
					PUSH 3
					PUSH 4
					PUSH 5
					PUSH 6
					PUSH 7
					PUSH ACC
					PUSH B
					PUSH DPH
					PUSH DPL
					; store the changed stackpointer
					; and set the active flag of the process to 1				
					MOV stacks + 1, SP
					MOV isProcessB, #0x01
					MOV currentProcess, #0x01
					JMP endCheckProcessB
				
				endCheckProcessB:
					JMP endStart
					
	processControlToStart:
		MOV DPTR, #processControl
		MOV A,DPH
		CJNE A, processAddressH, endStart
			; still chance that it's processControl		
			MOV A,DPL
			CJNE A, processAddressL, endStart
				; yes, it's process Control to start			
				MOV processIPTable+6, DPL
				MOV processIPTable+7, DPH			
				MOV SP, stackStartAddr + 3
				; push startadress of the process on the stack				
				PUSH PSW
				PUSH 0
				PUSH 1
				PUSH 2
				PUSH 3
				PUSH 4
				PUSH 5
				PUSH 6
				PUSH 7
				PUSH ACC
				PUSH B
				PUSH DPH
				PUSH DPL
				; store the changed stackpointer
				; and set the active flag of the process to 1				
				MOV stacks + 3, SP
				MOV isProcessControl, #0x01 
				MOV currentProcess, #0x03
				JMP endStart
	endStart:
		JMP notNewNotStop

END