`timescale 1ns/1ps

module tb_mips_pipeline;
    reg clk;
    reg reset;
    wire [31:0] pc_debug;
    wire [31:0] instr_debug;
    wire [31:0] alu_result_debug;
    wire [31:0] wb_data_debug;

    integer errors;

    mips_pipeline dut(
        .clk(clk),
        .reset(reset),
        .pc_debug(pc_debug),
        .instr_debug(instr_debug),
        .alu_result_debug(alu_result_debug),
        .wb_data_debug(wb_data_debug)
    );

    always #5 clk = ~clk;

    function [31:0] R;
        input [4:0] rs;
        input [4:0] rt;
        input [4:0] rd;
        input [4:0] shamt;
        input [5:0] funct;
        begin
            R = {6'h00, rs, rt, rd, shamt, funct};
        end
    endfunction

    function [31:0] I;
        input [5:0] opcode;
        input [4:0] rs;
        input [4:0] rt;
        input [15:0] imm;
        begin
            I = {opcode, rs, rt, imm};
        end
    endfunction

    function [31:0] J;
        input [5:0] opcode;
        input [25:0] target;
        begin
            J = {opcode, target};
        end
    endfunction

    task check_reg;
        input [4:0] reg_index;
        input [31:0] expected;
        begin
            if (dut.rf.regs[reg_index] !== expected) begin
                $display("ERROR: R%0d expected %0d (0x%08h), got %0d (0x%08h)",
                         reg_index, expected, expected, dut.rf.regs[reg_index], dut.rf.regs[reg_index]);
                errors = errors + 1;
            end else begin
                $display("OK:    R%0d = %0d (0x%08h)", reg_index, expected, expected);
            end
        end
    endtask

    task check_mem;
        input [7:0] word_index;
        input [31:0] expected;
        begin
            if (dut.dmem.mem[word_index] !== expected) begin
                $display("ERROR: MEM[%0d] expected %0d (0x%08h), got %0d (0x%08h)",
                         word_index, expected, expected, dut.dmem.mem[word_index], dut.dmem.mem[word_index]);
                errors = errors + 1;
            end else begin
                $display("OK:    MEM[%0d] = %0d (0x%08h)", word_index, expected, expected);
            end
        end
    endtask

    initial begin
        $dumpfile("dump.vcd");
        $dumpvars(0, tb_mips_pipeline);

        clk = 1'b0;
        reset = 1'b1;
        errors = 0;

        // Demo program:
        // Tests EX/MEM forwarding, MEM/WB forwarding, load-use stall,
        // store forwarding, taken branch flush, not-taken branch, and jump flush.
        dut.imem.mem[0]  = I(6'h08, 5'd0,  5'd1,  16'd5);   // addi $1,$0,5
        dut.imem.mem[1]  = I(6'h08, 5'd0,  5'd2,  16'd10);  // addi $2,$0,10
        dut.imem.mem[2]  = R(5'd1,  5'd2,  5'd3,  5'd0, 6'h20); // add $3,$1,$2 = 15
        dut.imem.mem[3]  = I(6'h2B, 5'd0,  5'd3,  16'd0);   // sw $3,0($0)
        dut.imem.mem[4]  = I(6'h23, 5'd0,  5'd4,  16'd0);   // lw $4,0($0) = 15
        dut.imem.mem[5]  = R(5'd4,  5'd3,  5'd5,  5'd0, 6'h20); // add $5,$4,$3 = 30
        dut.imem.mem[6]  = I(6'h04, 5'd5,  5'd3,  16'd1);   // beq $5,$3,+1 (not taken)
        dut.imem.mem[7]  = R(5'd5,  5'd1,  5'd6,  5'd0, 6'h22); // sub $6,$5,$1 = 25
        dut.imem.mem[8]  = I(6'h04, 5'd6,  5'd6,  16'd1);   // beq $6,$6,+1 (taken)
        dut.imem.mem[9]  = I(6'h08, 5'd0,  5'd7,  16'd99);  // flushed, should remain 0
        dut.imem.mem[10] = I(6'h08, 5'd0,  5'd8,  16'd1);   // addi $8,$0,1
        dut.imem.mem[11] = J(6'h02, 26'd13);                // jump to instruction 13
        dut.imem.mem[12] = I(6'h08, 5'd0,  5'd9,  16'd77);  // flushed, should remain 0
        dut.imem.mem[13] = I(6'h0D, 5'd8,  5'd10, 16'd2);   // ori $10,$8,2 = 3
        dut.imem.mem[14] = I(6'h0C, 5'd10, 5'd11, 16'd1);   // andi $11,$10,1 = 1
        dut.imem.mem[15] = R(5'd10, 5'd11, 5'd12, 5'd0, 6'h20); // add $12,$10,$11 = 4

        #12 reset = 1'b0;

        repeat (60) @(posedge clk);
        #1;

        $display("\n--- Final register/memory checks ---");
        check_reg(5'd1,  32'd5);
        check_reg(5'd2,  32'd10);
        check_reg(5'd3,  32'd15);
        check_reg(5'd4,  32'd15);
        check_reg(5'd5,  32'd30);
        check_reg(5'd6,  32'd25);
        check_reg(5'd7,  32'd0);
        check_reg(5'd8,  32'd1);
        check_reg(5'd9,  32'd0);
        check_reg(5'd10, 32'd3);
        check_reg(5'd11, 32'd1);
        check_reg(5'd12, 32'd4);
        check_mem(8'd0, 32'd15);

        if (errors == 0)
            $display("\nTEST PASSED: pipeline forwarding, stall, branch, and jump behavior are correct for the demo program.");
        else
            $display("\nTEST FAILED: %0d error(s) found.", errors);

        $finish;
    end
endmodule
