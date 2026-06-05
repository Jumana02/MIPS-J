`timescale 1ns/1ps

module alu(
    input  [31:0] a,
    input  [31:0] b,
    input  [3:0]  alu_ctrl,
    output reg [31:0] result,
    output zero
);
    always @(*) begin
        case (alu_ctrl)
            4'b0000: result = a & b;                         // AND
            4'b0001: result = a | b;                         // OR
            4'b0010: result = a + b;                         // ADD
            4'b0110: result = a - b;                         // SUB
            4'b0111: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0; // SLT
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);
endmodule
`timescale 1ns/1ps

module alu_control(
    input  [2:0] alu_op,
    input  [5:0] funct,
    output reg [3:0] alu_ctrl
);
    always @(*) begin
        case (alu_op)
            3'b000: alu_ctrl = 4'b0010; // add: lw, sw, addi
            3'b001: alu_ctrl = 4'b0110; // subtract: beq
            3'b011: alu_ctrl = 4'b0000; // andi
            3'b100: alu_ctrl = 4'b0001; // ori
            3'b010: begin               // R-type
                case (funct)
                    6'h20: alu_ctrl = 4'b0010; // add
                    6'h22: alu_ctrl = 4'b0110; // sub
                    6'h24: alu_ctrl = 4'b0000; // and
                    6'h25: alu_ctrl = 4'b0001; // or
                    6'h2A: alu_ctrl = 4'b0111; // slt
                    default: alu_ctrl = 4'b0010;
                endcase
            end
            default: alu_ctrl = 4'b0010;
        endcase
    end
endmodule
`timescale 1ns/1ps

module control_unit(
    input  [5:0] opcode,
    output reg reg_dst,
    output reg alu_src,
    output reg mem_to_reg,
    output reg reg_write,
    output reg mem_read,
    output reg mem_write,
    output reg branch,
    output reg jump,
    output reg ext_op,
    output reg [2:0] alu_op
);
    localparam OP_RTYPE = 6'h00;
    localparam OP_LW    = 6'h23;
    localparam OP_SW    = 6'h2B;
    localparam OP_BEQ   = 6'h04;
    localparam OP_ADDI  = 6'h08;
    localparam OP_ANDI  = 6'h0C;
    localparam OP_ORI   = 6'h0D;
    localparam OP_J     = 6'h02;

    always @(*) begin
        reg_dst    = 1'b0;
        alu_src    = 1'b0;
        mem_to_reg = 1'b0;
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        ext_op     = 1'b1;   // 1: sign-extend, 0: zero-extend
        alu_op     = 3'b000;

        case (opcode)
            OP_RTYPE: begin
                reg_dst   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 3'b010;
            end
            OP_LW: begin
                alu_src    = 1'b1;
                mem_to_reg = 1'b1;
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                ext_op     = 1'b1;
                alu_op     = 3'b000;
            end
            OP_SW: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                ext_op    = 1'b1;
                alu_op    = 3'b000;
            end
            OP_BEQ: begin
                branch = 1'b1;
                ext_op = 1'b1;
                alu_op = 3'b001;
            end
            OP_ADDI: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                ext_op    = 1'b1;
                alu_op    = 3'b000;
            end
            OP_ANDI: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                ext_op    = 1'b0;
                alu_op    = 3'b011;
            end
            OP_ORI: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                ext_op    = 1'b0;
                alu_op    = 3'b100;
            end
            OP_J: begin
                jump = 1'b1;
            end
            default: begin
                // Unsupported instructions become a safe no-operation.
            end
        endcase
    end
endmodule
`timescale 1ns/1ps

module reg_file(
    input clk,
    input reset,
    input reg_write,
    input [4:0] read_reg1,
    input [4:0] read_reg2,
    input [4:0] write_reg,
    input [31:0] write_data,
    output [31:0] read_data1,
    output [31:0] read_data2
);
    reg [31:0] regs [0:31];
    integer i;

    // Asynchronous reads with same-cycle write bypass.
    // This models the common MIPS behavior where WB writes are visible to ID reads
    // in the same cycle. It also fixes cases where an instruction immediately after
    // a jump reads a register being written back in that cycle.
    assign read_data1 = (read_reg1 == 5'd0) ? 32'd0 :
                        (reg_write && (write_reg != 5'd0) && (write_reg == read_reg1)) ? write_data :
                        regs[read_reg1];

    assign read_data2 = (read_reg2 == 5'd0) ? 32'd0 :
                        (reg_write && (write_reg != 5'd0) && (write_reg == read_reg2)) ? write_data :
                        regs[read_reg2];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else begin
            if (reg_write && (write_reg != 5'd0))
                regs[write_reg] <= write_data;
            regs[0] <= 32'd0;
        end
    end
endmodule
`timescale 1ns/1ps

module instr_mem(
    input [31:0] addr,
    output [31:0] instr
);
    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'h00000000;
    end

    // Word-addressed instruction memory. Testbenches may load mem[] hierarchically.
    assign instr = mem[addr[9:2]];
endmodule
`timescale 1ns/1ps

module data_mem(
    input clk,
    input mem_read,
    input mem_write,
    input [31:0] addr,
    input [31:0] write_data,
    output [31:0] read_data
);
    reg [31:0] mem [0:255];
    integer i;

    initial begin
        for (i = 0; i < 256; i = i + 1)
            mem[i] = 32'd0;
    end

    // Word-addressed memory. addr[9:2] selects one of 256 words.
    assign read_data = mem_read ? mem[addr[9:2]] : 32'd0;

    always @(posedge clk) begin
        if (mem_write)
            mem[addr[9:2]] <= write_data;
    end
endmodule
`timescale 1ns/1ps

module forwarding_unit(
    input ex_mem_reg_write,
    input [4:0] ex_mem_rd,
    input mem_wb_reg_write,
    input [4:0] mem_wb_rd,
    input [4:0] id_ex_rs,
    input [4:0] id_ex_rt,
    output reg [1:0] forward_a,
    output reg [1:0] forward_b
);
    always @(*) begin
        forward_a = 2'b00;
        forward_b = 2'b00;

        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rs))
            forward_a = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rs))
            forward_a = 2'b01;

        if (ex_mem_reg_write && (ex_mem_rd != 5'd0) && (ex_mem_rd == id_ex_rt))
            forward_b = 2'b10;
        else if (mem_wb_reg_write && (mem_wb_rd != 5'd0) && (mem_wb_rd == id_ex_rt))
            forward_b = 2'b01;
    end
endmodule
`timescale 1ns/1ps

module hazard_detection_unit(
    input id_ex_mem_read,
    input [4:0] id_ex_rt,
    input [4:0] if_id_rs,
    input [4:0] if_id_rt,
    output reg pc_write,
    output reg if_id_write,
    output reg control_zero
);
    always @(*) begin
        pc_write     = 1'b1;
        if_id_write  = 1'b1;
        control_zero = 1'b0;

        // Load-use hazard: stall PC and IF/ID, insert a bubble into ID/EX.
        if (id_ex_mem_read && ((id_ex_rt == if_id_rs) || (id_ex_rt == if_id_rt))) begin
            pc_write     = 1'b0;
            if_id_write  = 1'b0;
            control_zero = 1'b1;
        end
    end
endmodule
`timescale 1ns/1ps

module mips_pipeline(
    input clk,
    input reset,
    output [31:0] pc_debug,
    output [31:0] instr_debug,
    output [31:0] alu_result_debug,
    output [31:0] wb_data_debug
);
    // -------------------------
    // Global wires/register declarations
    // -------------------------
    reg [31:0] pc;
    wire [31:0] instrF;
    wire [31:0] pc_plus4F;
    wire [31:0] pc_next;

    // IF/ID pipeline register
    reg [31:0] IF_ID_pc_plus4;
    reg [31:0] IF_ID_instr;

    // ID stage wires
    wire [5:0] opcodeD;
    wire [4:0] rsD;
    wire [4:0] rtD;
    wire [4:0] rdD;
    wire [5:0] functD;

    wire RegDstD;
    wire ALUSrcD;
    wire MemtoRegD;
    wire RegWriteD;
    wire MemReadD;
    wire MemWriteD;
    wire BranchD;
    wire JumpD;
    wire ExtOpD;
    wire [2:0] ALUOpD;

    wire [31:0] read_data1D;
    wire [31:0] read_data2D;
    wire [31:0] imm_extD;
    wire [31:0] jump_targetD;
    wire [31:0] wb_write_data;

    wire PCWrite;
    wire IF_ID_Write;
    wire ControlZero;

    // ID/EX pipeline register
    reg ID_EX_RegDst;
    reg ID_EX_ALUSrc;
    reg ID_EX_MemtoReg;
    reg ID_EX_RegWrite;
    reg ID_EX_MemRead;
    reg ID_EX_MemWrite;
    reg ID_EX_Branch;
    reg [2:0] ID_EX_ALUOp;
    reg [31:0] ID_EX_pc_plus4;
    reg [31:0] ID_EX_read_data1;
    reg [31:0] ID_EX_read_data2;
    reg [31:0] ID_EX_imm_ext;
    reg [4:0] ID_EX_rs;
    reg [4:0] ID_EX_rt;
    reg [4:0] ID_EX_rd;
    reg [5:0] ID_EX_funct;

    // EX stage wires
    wire [1:0] ForwardA;
    wire [1:0] ForwardB;
    wire [31:0] forwardA_data;
    wire [31:0] forwardB_data;
    wire [3:0] alu_ctrlE;
    wire [31:0] alu_srcB_E;
    wire [31:0] alu_resultE;
    wire zeroE;
    wire [31:0] branch_targetE;
    wire [4:0] write_regE;
    wire PCSrc;

    // EX/MEM pipeline register
    reg EX_MEM_MemtoReg;
    reg EX_MEM_RegWrite;
    reg EX_MEM_MemRead;
    reg EX_MEM_MemWrite;
    reg [31:0] EX_MEM_alu_result;
    reg [31:0] EX_MEM_write_data;
    reg [4:0] EX_MEM_write_reg;

    // MEM stage wires
    wire [31:0] mem_read_dataM;

    // MEM/WB pipeline register
    reg MEM_WB_MemtoReg;
    reg MEM_WB_RegWrite;
    reg [31:0] MEM_WB_read_data;
    reg [31:0] MEM_WB_alu_result;
    reg [4:0] MEM_WB_write_reg;

    // -------------------------
    // IF stage
    // -------------------------
    instr_mem imem(
        .addr(pc),
        .instr(instrF)
    );

    assign pc_plus4F = pc + 32'd4;

    // -------------------------
    // ID stage
    // -------------------------
    assign opcodeD = IF_ID_instr[31:26];
    assign rsD     = IF_ID_instr[25:21];
    assign rtD     = IF_ID_instr[20:16];
    assign rdD     = IF_ID_instr[15:11];
    assign functD  = IF_ID_instr[5:0];

    control_unit main_control(
        .opcode(opcodeD),
        .reg_dst(RegDstD),
        .alu_src(ALUSrcD),
        .mem_to_reg(MemtoRegD),
        .reg_write(RegWriteD),
        .mem_read(MemReadD),
        .mem_write(MemWriteD),
        .branch(BranchD),
        .jump(JumpD),
        .ext_op(ExtOpD),
        .alu_op(ALUOpD)
    );

    reg_file rf(
        .clk(clk),
        .reset(reset),
        .reg_write(MEM_WB_RegWrite),
        .read_reg1(rsD),
        .read_reg2(rtD),
        .write_reg(MEM_WB_write_reg),
        .write_data(wb_write_data),
        .read_data1(read_data1D),
        .read_data2(read_data2D)
    );

    assign imm_extD = ExtOpD ? {{16{IF_ID_instr[15]}}, IF_ID_instr[15:0]} : {16'd0, IF_ID_instr[15:0]};
    assign jump_targetD = {IF_ID_pc_plus4[31:28], IF_ID_instr[25:0], 2'b00};

    hazard_detection_unit hdu(
        .id_ex_mem_read(ID_EX_MemRead),
        .id_ex_rt(ID_EX_rt),
        .if_id_rs(rsD),
        .if_id_rt(rtD),
        .pc_write(PCWrite),
        .if_id_write(IF_ID_Write),
        .control_zero(ControlZero)
    );

    // -------------------------
    // EX stage
    // -------------------------
    forwarding_unit fu(
        .ex_mem_reg_write(EX_MEM_RegWrite),
        .ex_mem_rd(EX_MEM_write_reg),
        .mem_wb_reg_write(MEM_WB_RegWrite),
        .mem_wb_rd(MEM_WB_write_reg),
        .id_ex_rs(ID_EX_rs),
        .id_ex_rt(ID_EX_rt),
        .forward_a(ForwardA),
        .forward_b(ForwardB)
    );

    assign forwardA_data = (ForwardA == 2'b10) ? EX_MEM_alu_result :
                           (ForwardA == 2'b01) ? wb_write_data :
                                                  ID_EX_read_data1;

    assign forwardB_data = (ForwardB == 2'b10) ? EX_MEM_alu_result :
                           (ForwardB == 2'b01) ? wb_write_data :
                                                  ID_EX_read_data2;

    alu_control alu_control_unit(
        .alu_op(ID_EX_ALUOp),
        .funct(ID_EX_funct),
        .alu_ctrl(alu_ctrlE)
    );

    assign alu_srcB_E = ID_EX_ALUSrc ? ID_EX_imm_ext : forwardB_data;

    alu alu_unit(
        .a(forwardA_data),
        .b(alu_srcB_E),
        .alu_ctrl(alu_ctrlE),
        .result(alu_resultE),
        .zero(zeroE)
    );

    assign branch_targetE = ID_EX_pc_plus4 + (ID_EX_imm_ext << 2);
    assign write_regE = ID_EX_RegDst ? ID_EX_rd : ID_EX_rt;
    assign PCSrc = ID_EX_Branch & zeroE;

    // -------------------------
    // MEM stage
    // -------------------------
    data_mem dmem(
        .clk(clk),
        .mem_read(EX_MEM_MemRead),
        .mem_write(EX_MEM_MemWrite),
        .addr(EX_MEM_alu_result),
        .write_data(EX_MEM_write_data),
        .read_data(mem_read_dataM)
    );

    // -------------------------
    // WB stage
    // -------------------------
    assign wb_write_data = MEM_WB_MemtoReg ? MEM_WB_read_data : MEM_WB_alu_result;

    // PC selection priority: taken branch, then jump, then sequential PC.
    assign pc_next = PCSrc ? branch_targetE :
                     JumpD ? jump_targetD :
                             pc_plus4F;

    // -------------------------
    // Sequential pipeline updates
    // -------------------------
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc <= 32'd0;
        end else if (PCWrite) begin
            pc <= pc_next;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            IF_ID_pc_plus4 <= 32'd0;
            IF_ID_instr    <= 32'h00000000;
        end else if (PCSrc || JumpD) begin
            IF_ID_pc_plus4 <= 32'd0;
            IF_ID_instr    <= 32'h00000000;
        end else if (IF_ID_Write) begin
            IF_ID_pc_plus4 <= pc_plus4F;
            IF_ID_instr    <= instrF;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset || PCSrc || JumpD || ControlZero) begin
            ID_EX_RegDst     <= 1'b0;
            ID_EX_ALUSrc     <= 1'b0;
            ID_EX_MemtoReg   <= 1'b0;
            ID_EX_RegWrite   <= 1'b0;
            ID_EX_MemRead    <= 1'b0;
            ID_EX_MemWrite   <= 1'b0;
            ID_EX_Branch     <= 1'b0;
            ID_EX_ALUOp      <= 3'b000;
            ID_EX_pc_plus4   <= 32'd0;
            ID_EX_read_data1 <= 32'd0;
            ID_EX_read_data2 <= 32'd0;
            ID_EX_imm_ext    <= 32'd0;
            ID_EX_rs         <= 5'd0;
            ID_EX_rt         <= 5'd0;
            ID_EX_rd         <= 5'd0;
            ID_EX_funct      <= 6'd0;
        end else begin
            ID_EX_RegDst     <= RegDstD;
            ID_EX_ALUSrc     <= ALUSrcD;
            ID_EX_MemtoReg   <= MemtoRegD;
            ID_EX_RegWrite   <= RegWriteD;
            ID_EX_MemRead    <= MemReadD;
            ID_EX_MemWrite   <= MemWriteD;
            ID_EX_Branch     <= BranchD;
            ID_EX_ALUOp      <= ALUOpD;
            ID_EX_pc_plus4   <= IF_ID_pc_plus4;
            ID_EX_read_data1 <= read_data1D;
            ID_EX_read_data2 <= read_data2D;
            ID_EX_imm_ext    <= imm_extD;
            ID_EX_rs         <= rsD;
            ID_EX_rt         <= rtD;
            ID_EX_rd         <= rdD;
            ID_EX_funct      <= functD;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            EX_MEM_MemtoReg   <= 1'b0;
            EX_MEM_RegWrite   <= 1'b0;
            EX_MEM_MemRead    <= 1'b0;
            EX_MEM_MemWrite   <= 1'b0;
            EX_MEM_alu_result <= 32'd0;
            EX_MEM_write_data <= 32'd0;
            EX_MEM_write_reg  <= 5'd0;
        end else begin
            EX_MEM_MemtoReg   <= ID_EX_MemtoReg;
            EX_MEM_RegWrite   <= ID_EX_RegWrite;
            EX_MEM_MemRead    <= ID_EX_MemRead;
            EX_MEM_MemWrite   <= ID_EX_MemWrite;
            EX_MEM_alu_result <= alu_resultE;
            EX_MEM_write_data <= forwardB_data;
            EX_MEM_write_reg  <= write_regE;
        end
    end

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            MEM_WB_MemtoReg   <= 1'b0;
            MEM_WB_RegWrite   <= 1'b0;
            MEM_WB_read_data  <= 32'd0;
            MEM_WB_alu_result <= 32'd0;
            MEM_WB_write_reg  <= 5'd0;
        end else begin
            MEM_WB_MemtoReg   <= EX_MEM_MemtoReg;
            MEM_WB_RegWrite   <= EX_MEM_RegWrite;
            MEM_WB_read_data  <= mem_read_dataM;
            MEM_WB_alu_result <= EX_MEM_alu_result;
            MEM_WB_write_reg  <= EX_MEM_write_reg;
        end
    end

    assign pc_debug         = pc;
    assign instr_debug      = IF_ID_instr;
    assign alu_result_debug = alu_resultE;
    assign wb_data_debug    = wb_write_data;
endmodule
