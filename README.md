# Assembler Scheduler

Scheduler program for switching multiple processes for microcontrollers of the 8051-family.

The goal of this project is to write a task management program with the following functions:

- Three processes must be implemented: "Console Process", "Process A" and "Process B".
- Control of the processes should be performed via scheduler.
- The ability to start and stop the processes.
- Each process must have own priority.
- Control of the processes is performed with preemptive multitasking.

**Process A** outputs the entered number (n) followed by the string "ABCDE" repeated n times via the serial interface 0.

**Process B** outputs the characters "+" and "-" alternately every second via the serial interface 0.

**Console process** constantly reads commands (characters) from the serial interface 0 and starts or stops other processes.

------------

**Example input:** x, 1, b, x, 0, c, 2, b, 3, c, b, 4, c

**Output:** 1ABCDE+-2ABCDEABCDE+-3ABCDEABCDEABCDE+-+-+-+-+4ABCDEABCDEABCDEABCDE-+-+-

**Example input:** x, 9, b, x, 8, b, b, 1, c, c, 2

**Output:** 9ABCDEABCDEABCDEABCDEABCDEABCDEABCDEABCDEABCDE+-+-+-+-8ABCDEABCDEABCDE ABCDEABCDEABCDEABCDEABCDE+-+-+-+-+-+-++--1ABCDE++--+-2ABCDEABCDE

------------

### Double call of a process

Double call of a process as long as it is active (e.g., sequence: 'b', 'b') is handled the following way:

By starting of a process B, the following check is performed:
- If no process B is running, start a new process B.
- If a process B is running, the second process B starts.
- If two processes B are running - do nothing.

Thus the program has the possibility to simultaneously start two identical processes B. It is not available for process A, because process A is automatically terminated after performing its task.

### Using of serial interface 0 by several processes

Controlling the access to writing via the serial interface is based on the principle of the semaphore (or rather mutex) using the variable "serialIsBusy", which tells the processes whether the serial interface is free or busy. After the start of the transfer of a sybmol, the variable is set equal to 1, after the end of the transfer, the value is zeroed.

Accordingly, when an interrupt from the scheduler occurs and the Control is gave to another process which also sends something to the serial interface, the first process doesn't lose the transmitted symbol.

### Priorities of the processes

The 4-byte array "priorities" was defined for the priorities, with 1 byte for each process. The priorities determine the CPU time allocated for performing a process, i. e. how often the interrupt is called by timer 1.

After becoming an interrupt from the timer, the scheduler function checks which process should be started. The corresponding priority value from the array "priorities" is written in the register TH1. The larger value is written in TH1 and TL1, the more often the interrupt occurs, i. e. the higher the priority, the smaller the value in the "priorities" array.


------------

More detailed description is available in the "[Dokumentation.pdf](Dokumentation.pdf "Dokumentation.pdf")" (in German).
