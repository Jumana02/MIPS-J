# 32-bit Five-Stage Pipeline MIPS Design and Implementation

**Prepared by:** Jumana  
**Language:** Verilog / SystemVerilog  
**Simulation Tool:** EDA Playground – Icarus Verilog 12.0  

---

## 1. Intro

### 1.1 Short Description

This project is a design and simulation of a 32-bit five-stage pipelined MIPS processor written in Verilog/SystemVerilog.

The processor is based on the normal MIPS pipeline stages:

```text
Instruction Fetch → Instruction Decode → Execute → Memory → Write Back
```

The design also handles the main pipeline problems, especially data hazards. A forwarding unit is used to pass results from later pipeline stages back to the Execute stage when needed. A hazard detection unit is also included to stop the pipeline for one cycle in the load-use case, where forwarding alone is not enough.

The project was written in a simple and direct way so that the datapath, control signals, memory operations, forwarding, stalls, branch handling, and jump handling can be followed clearly during simulation.

---

### 1.2 Attached Files

The project contains two main simulation files:

```text
design.sv
testbench.sv
```

The `design.sv` file contains the processor design and all required modules. For the EDA Playground version, the modules are placed in one file to make the project easier to run without extra include files.

The `testbench.sv` file contains the testbench. It loads the demo program into instruction memory, runs the processor, checks the final register and memory values, and prints the final simulation result.

The simulation also generates:

```text
dump.vcd
```

This file can be opened in EPWave to view the waveform signals.

---

### 1.3 Implementation Workflow

The work started by building the basic datapath blocks needed for a MIPS processor, such as the ALU, register file, control unit, instruction memory, and data memory.

After that, the design was arranged into the five pipeline stages. Pipeline registers were added between the stages so that each instruction can pass its required data and control signals to the next stage on every clock cycle.

Then the hazard handling logic was added. The forwarding unit was used to solve most data dependency cases, while the hazard detection unit was used for load-use hazards. Branch and jump behavior were also added so that the PC can move to the correct target address and flush wrong instructions when needed.

Finally, a self-checking testbench was written to verify the processor using a small program that includes arithmetic, memory, branch, jump, and hazard cases.

---

### 1.4 Process Phases

The project was completed in several main phases.

**Phase One: Basic Datapath Blocks**

In this phase, the main hardware blocks were prepared:

- ALU
- ALU control
- Control unit
- Register file
- Instruction memory
- Data memory
- Immediate extension logic
- Write-back selection logic
- Program counter logic

The ALU, ALU control, control unit, register file, instruction memory, and data memory were implemented as main hardware blocks. The immediate extension logic, write-back selection logic, and PC selection logic were implemented inside the main pipeline module.

**Phase Two: Pipeline Structure**

In this phase, the five-stage pipeline structure was added. The pipeline registers were used to separate the stages:

- IF/ID
- ID/EX
- EX/MEM
- MEM/WB

These registers allow different instructions to be active in different stages at the same time.

**Phase Three: Hazard Handling**

In this phase, the forwarding unit and hazard detection unit were added.

The forwarding unit reduces unnecessary stalls by sending data directly from the EX/MEM or MEM/WB stage back to the Execute stage. This is used when an instruction needs a result that has not been written back to the register file yet.

The hazard detection unit handles load-use hazards by freezing the PC and IF/ID register and inserting a bubble into the pipeline.

**Phase Four: Branch, Jump, and Testing**

In the last phase, branch and jump control were checked, and the testbench was completed.

For branch and jump instructions, the PC is updated to the correct target address. Wrongly fetched instructions are flushed so they do not affect the final processor state.

The testbench verifies the final register and memory values and reports whether the simulation passed or failed.

---

## 2. Design

### 2.1 Main Modules

The design contains the following main modules:

```text
mips_pipeline
alu
alu_control
control_unit
reg_file
instr_mem
data_mem
forwarding_unit
hazard_detection_unit
```

The `mips_pipeline` module connects all parts of the processor together. It contains the pipeline registers, PC logic, immediate extension logic, write-back selection logic, and the main datapath connections between the five stages.

---

### 2.2 Module Description

**ALU**

The ALU performs the arithmetic and logic operations required by the supported instructions. The operations include addition, subtraction, AND, OR, and set-on-less-than.

**ALU Control**

The ALU control unit chooses the exact ALU operation using the `ALUOp` signal and the function field for R-type instructions.

**Control Unit**

The control unit reads the opcode and generates the control signals used by the datapath, such as `RegWrite`, `MemRead`, `MemWrite`, `ALUSrc`, `MemtoReg`, `Branch`, and `Jump`.

**Register File**

The register file contains 32 registers. It has two read ports and one write port. Register zero always stays equal to zero. The design also includes same-cycle write/read behavior so that write-back values can be seen correctly when needed.

**Instruction Memory**

The instruction memory stores the test program. In this project, the testbench loads the instructions directly into memory before the simulation starts.

**Data Memory**

The data memory is used by `lw` and `sw` instructions. Store instructions write data to memory, and load instructions read data from memory.

**Forwarding Unit**

The forwarding unit checks the destination registers in later pipeline stages and compares them with the source registers in the Execute stage. If a match is found, the correct value is forwarded to the ALU input.

**Hazard Detection Unit**

The hazard detection unit checks for load-use hazards. If the current instruction depends on a value being loaded from memory by the previous instruction, the unit inserts a one-cycle stall.

**Pipeline Registers**

The pipeline registers store the values and control signals between stages. They are needed so that the processor can execute instructions in a pipelined way.

The pipeline registers used in this design are:

```text
IF/ID
ID/EX
EX/MEM
MEM/WB
```

---

### 2.3 Pipeline Stages

The processor is divided into five stages.

**Instruction Fetch (IF)**

This stage uses the PC to fetch the next instruction from instruction memory. It also calculates the next sequential address, `PC + 4`.

**Instruction Decode (ID)**

This stage decodes the instruction, reads register values, extends the immediate field, and generates the control signals.

**Execute (EX)**

This stage performs the ALU operation, applies forwarding when needed, calculates branch targets, and selects the destination register.

**Memory (MEM)**

This stage handles data memory read and write operations for load and store instructions.

**Write Back (WB)**

This stage writes the final value back to the register file. The value can come from the ALU result or from data memory.

---

### 2.4 Hazard and Control Handling

The design handles the main hazards that appear in a pipelined processor.

For normal data hazards, forwarding is used. The forwarding unit can select data from the EX/MEM stage or the MEM/WB stage and send it directly to the ALU input.

The forwarding signals are:

```text
ForwardA
ForwardB
```

Their values are:

```text
00 = use the normal register value
01 = forward from MEM/WB stage
10 = forward from EX/MEM stage
```

For load-use hazards, the pipeline is stalled for one cycle. This is done by freezing the PC and IF/ID register and inserting a bubble into ID/EX.

The stall signals are:

```text
PCWrite
IF_ID_Write
ControlZero
```

When a stall happens:

```text
PCWrite = 0
IF_ID_Write = 0
ControlZero = 1
```

For branches and jumps, the PC is updated to the correct target address. Wrongly fetched instructions are flushed so that they do not change the processor state.

---

## 3. Testing and Testbench

### 3.1 Testbench Description

The testbench is written in `testbench.sv`. It creates the clock and reset signals, loads the instruction memory, runs the processor, and checks the output.

The testbench does not only show waveforms. It also checks the final values automatically. If any value is wrong, it prints an error message. If all values are correct, it prints that the test passed.

---

### 3.2 Test Program

The test program was chosen to check different parts of the pipeline.

It tests:

- Arithmetic instructions
- Logical instructions
- Store and load instructions
- EX/MEM forwarding
- MEM/WB forwarding
- Load-use stall
- Not-taken branch
- Taken branch
- Jump flush
- Write-back result

The expected final values are:

```text
R1  = 5
R2  = 10
R3  = 15
R4  = 15
R5  = 30
R6  = 25
R7  = 0
R8  = 1
R9  = 0
R10 = 3
R11 = 1
R12 = 4
MEM[0] = 15
```

Registers `R7` and `R9` should stay zero because their instructions are flushed by the branch and jump behavior.

---

### 3.3 Simulation Result

The project was simulated using EDA Playground with Icarus Verilog 12.0.

The used settings are:

```text
Language: SystemVerilog / Verilog
Simulator: Icarus Verilog 12.0
Compile option: -Wall -g2012
Top module: tb_mips_pipeline
```

The final output of the testbench is:

```text
TEST PASSED: pipeline forwarding, stall, branch, and jump behavior are correct for the demo program.
```

This means the processor executed the test program correctly and the final register and memory values matched the expected results.

---

### 3.4 Waveform

The waveform can be viewed using EPWave after running the simulation.

Useful signals to check are:

```text
clk
reset
pc_debug
instr_debug
alu_result_debug
wb_data_debug
errors
ForwardA
ForwardB
PCWrite
IF_ID_Write
ControlZero
PCSrc
JumpD
```

At the beginning, `reset` starts high, so the processor is cleared. After `reset` goes low, the processor starts execution.

The `pc_debug` signal shows the Program Counter. It increases by 4 each instruction:

```text
0 → 4 → 8 → C → 10 → 14 → 18 → 1C → 20
```

This happens because each MIPS instruction is 32 bits, which equals 4 bytes.

The `instr_debug` signal shows the instruction currently being fetched or decoded.

The `alu_result_debug` signal shows the result produced by the ALU in the Execute stage.

The `wb_data_debug` signal shows the value written back to the register file. These values appear later than the ALU result because write-back is the last pipeline stage.

The `errors` signal stays `0`, which means the testbench did not detect any wrong result.

---

### 3.5 Waveform Case Examples

**Case 1: Forwarding Case**

This case happens with these instructions:

```text
addi $1, $0, 5
addi $2, $0, 10
add  $3, $1, $2
```

The instruction `add $3, $1, $2` depends on the two previous instructions because it needs the values of `$1` and `$2`.

However, these values may not be written back to the register file yet. Instead of waiting, the forwarding unit sends the values directly to the ALU.

In the waveform, this can be seen when `ForwardA` and `ForwardB` change from `0` to non-zero values. This means forwarding is active.

The ALU result becomes:

```text
0000000F
```

`0F` in hexadecimal equals 15 in decimal.

So:

```text
$3 = $1 + $2 = 5 + 10 = 15
```

This proves that the forwarding unit works correctly.

---

**Case 2: Load-Use Hazard / Stall Case**

This case happens with these instructions:

```text
lw  $4, 0($0)
add $5, $4, $3
```

The `lw` instruction loads a value into `$4`. The next instruction immediately uses `$4`, so this causes a load-use hazard.

The loaded value is not ready right away, so the hazard detection unit stalls the pipeline for one cycle.

In the waveform, the stall can be seen when:

```text
PCWrite = 0
IF_ID_Write = 0
ControlZero = 1
```

This means the PC and IF/ID pipeline register are paused for one cycle.

After the stall, the processor continues execution. The ALU result becomes:

```text
0000001E
```

`1E` in hexadecimal equals 30 in decimal.

So:

```text
$5 = $4 + $3 = 15 + 15 = 30
```

This proves that the load-use hazard was detected and handled correctly.

---

**Case 3: Branch Taken and Flush Case**

This case happens with these instructions:

```text
beq  $6, $6, +1
addi $7, $0, 99
```

Since `$6` equals `$6`, the branch condition is true. Therefore, the branch is taken.

When the branch is taken, the next instruction is flushed from the pipeline. This means:

```text
addi $7, $0, 99
```

does not execute.

In the final result, register `$7` remains 0. This proves that the branch flush worked correctly.

In the waveform, this case is related to `PCSrc = 1`, which means the branch was taken.

---

**Case 4: Jump Flush Case**

This case happens with these instructions:

```text
j    13
addi $9, $0, 77
```

The jump instruction changes the PC to the target instruction. Because of this, the instruction after the jump is flushed.

So:

```text
addi $9, $0, 77
```

does not execute.

In the final result, register `$9` remains 0. This proves that the jump flush worked correctly.

In the waveform, this is related to `JumpD = 1`.

---

## 4. Conclusion

This project implements and tests a 32-bit five-stage pipelined MIPS processor in Verilog/SystemVerilog.

The design includes the main datapath blocks, pipeline registers, control unit, ALU, register file, instruction and data memories, forwarding unit, hazard detection unit, branch handling, jump handling, and a self-checking testbench.

The simulation result confirms that the processor runs the demo program correctly and handles the tested pipeline cases successfully.
