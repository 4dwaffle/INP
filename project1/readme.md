# Processor with a simple instruction set
VHDL implementation of a processor, which can run a program written in Brainfuck.

| Command  | Code | Meaning                                                       | C Equivalent    |
| -------- | ---- | ------------------------------------------------------------- | --------------- |
| >        | 0x3E | increment pointer value                                       | ptr += 1;       |
| <        | 0x3C | decrement pointer value                                       | ptr -= 1;       |
| +        | 0x2B | increment current cell value                                  | *ptr += 1;      |
| -        | 0x2D | decrement current cell value                                  | *ptr -= 1;      |
| .        | 0x7E | print value of current cell                                   | putchar(*ptr)   |
| ,        | 0x2E | load value and save it to the current cell                    | *ptr= getchar() |
| @        | 0x2C | separator of code and data, ends the execution of the program | return;         |
