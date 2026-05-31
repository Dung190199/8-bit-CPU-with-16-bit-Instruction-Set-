`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 31.05.2026 15:44:56
// Design Name: 
// Module Name: tb_CPU_full_2
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////

module tb_CPU_full_2 ();

    localparam integer CLK_PERIOD    = 10;
    localparam integer PIPE_DEPTH    = 9;
    localparam integer SETTLE_CYCLES = 3;

    reg        clk;
    reg        reset;
    reg        cpu_en;
    wire [7:0] databus;
    wire [7:0] result_out;
    wire       check_instruction_register;
    wire       check_instruction_decoder;
    wire       check_data_register;
    wire       check_alu;
    wire       check_mul;

    CPU dut (
        .clk                        (clk),
        .reset                      (reset),
        .cpu_en                     (cpu_en),
        .databus                    (databus),
        .result_out                 (result_out),
        .check_instruction_register (check_instruction_register),
        .check_instruction_decoder  (check_instruction_decoder),
        .check_data_register        (check_data_register),
        .check_alu                  (check_alu),
        .check_mul                  (check_mul)
    );

    initial clk = 1'b0;
    always  #(CLK_PERIOD/2) clk = ~clk;

    integer pass_count, fail_count, tc_num;

    initial begin
        $dumpfile("tb_CPU_full_2.vcd");
        $dumpvars(0, tb_CPU_full_2);
    end

    // =========================================================================
    // [v2] SCOREBOARD - independent of directed-test pass/fail counters
    // =========================================================================
    // Golden sequence: result_out expected value after each write-back.
    // Index 0-7 matches ROM[0]-ROM[7] write-back order.
    // HLT (index 7) has no write-back → scoreboard skips it.
    // =========================================================================
    localparam integer GOLD_LEN = 7; // MOV ADD SUB ABS NOT AND NEG (HLT no WB)
    reg [7:0] gold_seq [0:6];
    integer   scb_ptr;           // next expected index into gold_seq
    integer   scb_fail_count;    // separate counter - never touches fail_count
    reg [7:0] scb_prev;          // last seen result_out in scoreboard

    initial begin
        gold_seq[0] = 8'h3C; // MOV R0,60
        gold_seq[1] = 8'h82; // ADD R0,70
        gold_seq[2] = 8'hCE; // SUB R0,180
        gold_seq[3] = 8'h32; // ABS R0
        gold_seq[4] = 8'hCD; // NOT R0
        gold_seq[5] = 8'h0D; // AND R0,0x0F
        gold_seq[6] = 8'hF3; // NEG R0
        scb_ptr        = 0;
        scb_fail_count = 0;
        scb_prev       = 8'hXX;
    end

    // Scoreboard monitor: fires whenever result_out changes while out of reset.
    // Compares against next entry in gold_seq.
    // Resets its own pointer when it detects result_out returns to 0x00
    // (indicating a DUT reset happened).
    always @(posedge clk) begin
        if (reset && (result_out !== scb_prev) && (result_out !== 8'hXX)) begin
            if (result_out === 8'h00) begin
                // DUT reset detected - restart sequence pointer
                scb_ptr  = 0;
                scb_prev = result_out;
            end else begin
                if (scb_ptr < GOLD_LEN) begin
                    if (result_out === gold_seq[scb_ptr]) begin
                        $display("[SCB PASS] write-back #%0d: got=0x%02X  exp=0x%02X",
                                 scb_ptr, result_out, gold_seq[scb_ptr]);
                    end else begin
                        $display("[SCB FAIL] write-back #%0d: got=0x%02X  exp=0x%02X  ***UNEXPECTED***",
                                 scb_ptr, result_out, gold_seq[scb_ptr]);
                        scb_fail_count = scb_fail_count + 1;
                    end
                    scb_ptr = scb_ptr + 1;
                    if (scb_ptr >= GOLD_LEN) scb_ptr = 0; // wrap for repeated runs
                end
                scb_prev = result_out;
            end
        end
    end

    // =========================================================================
    // [v2] FUNCTIONAL COVERAGE MODEL - event-based bins (Verilog compatible)
    // =========================================================================
    // cov_opcode[0:7]       : has opcode N been executed and result written?
    // cov_reset_phase[0:8]  : has reset been asserted during pipeline phase N?
    //                         index = phase number (1-based: 1..8 meaningful)
    // cov_gate_tested       : has cpu_en=0 been tested while ROM is mid-fetch?
    // =========================================================================
    integer cov_opcode      [0:7]; // hit count per opcode
    integer cov_reset_phase [0:8]; // hit count per phase-at-reset
    integer cov_gate_tested;       // cpu_en gate test hit count

    // [v3] write-back phase coverage: which master_phase was active when
    // Enable_Write_Data went HIGH? Must only ever be 8 or 9.
    integer cov_wb_phase    [0:9]; // index = master_phase (0..9), 8&9 expected

    // [v3] pipeline monitor: previous master_phase for edge detection
    reg [3:0] pipe_mon_prev_phase;

    integer cov_i;
    initial begin
        for (cov_i = 0; cov_i <= 7; cov_i = cov_i + 1)
            cov_opcode[cov_i] = 0;
        for (cov_i = 0; cov_i <= 8; cov_i = cov_i + 1)
            cov_reset_phase[cov_i] = 0;
        for (cov_i = 0; cov_i <= 9; cov_i = cov_i + 1)
            cov_wb_phase[cov_i] = 0;
        cov_gate_tested    = 0;
        pipe_mon_prev_phase = 4'd0;
    end

    // Track opcode execution: sample Opcode_register at Enable_ALU rising edge
    // (CLK7 - the cycle ALU actually computes). This is the "executed" event.
    reg prev_enable_alu;
    initial prev_enable_alu = 1'b0;

    always @(posedge clk) begin
        if (reset) begin
            if (!prev_enable_alu && dut.Enable_ALU) begin
                // Rising edge of Enable_ALU = ALU starting to compute
                // Opcode_out (FS input to ALU) is valid at this point
                cov_opcode[dut.u_alu.FS] = cov_opcode[dut.u_alu.FS] + 1;
            end
            prev_enable_alu <= dut.Enable_ALU;
        end else begin
            prev_enable_alu <= 1'b0;
        end
    end

    // =========================================================================
    // [v3] PIPELINE PHASE MONITOR (PIPE_MON)
    // =========================================================================
    // Fires on every master_phase transition (rising edge of a new phase).
    // Prints: time | master_phase | cpu_en | active enable signals.
    // Pure observation - no pass/fail counter touch.
    // Helps debug timing when a TC fails: see exactly which phase was active
    // at the moment of failure in the waveform log.
    // =========================================================================
    always @(posedge clk) begin
        if (reset) begin
            // Log every new phase (transition = phase changed from previous)
            if (dut.u_rom.clock !== pipe_mon_prev_phase &&
                dut.u_rom.clock !== 4'd0) begin
                $display("[PIPE] t=%8t | phase=%0d | cpu_en=%b | ALU=%b WrEn=%b RdA=%b RdB=%b | PC=%0d",
                    $time,
                    dut.u_rom.clock,
                    cpu_en,
                    dut.Enable_ALU,
                    dut.Enable_Write_Data,
                    dut.Enable_Read_Data_A,
                    dut.Enable_Read_Data_B,
                    dut.u_rom.instruction_counter);
            end
            pipe_mon_prev_phase <= dut.u_rom.clock;
        end else begin
            pipe_mon_prev_phase <= 4'd0;
        end
    end

    // =========================================================================
    // [v3] ASSERTION A7 - Write-back window protocol check
    // =========================================================================
    // Enable_Write_Data must ONLY be asserted during master_phase 8 or 9.
    // Any write-back at phase 1-7 is a decoder bug - data not yet computed.
    // Any write-back at phase 0 (idle) is a spurious enable - state-machine bug.
    // =========================================================================
    always @(posedge clk) begin
        if (reset && dut.Enable_Write_Data) begin
            // Record which phase the write-back occurred (for coverage)
            if (dut.u_rom.clock <= 9)
                cov_wb_phase[dut.u_rom.clock] = cov_wb_phase[dut.u_rom.clock] + 1;

            // Assert: must be phase 8 or 9
            if (dut.u_rom.clock != 4'd8 && dut.u_rom.clock != 4'd9) begin
                $display("[ASSERT FAIL A7] t=%0t Enable_Write_Data HIGH at phase=%0d (must be 8 or 9)",
                         $time, dut.u_rom.clock);
                fail_count = fail_count + 1;
            end
        end
    end

    // Task: sample coverage - called inside TC12 after each random reset
    task sample_reset_phase_cov;
        input integer phase_num; // 1-based phase when reset was asserted
        begin
            if (phase_num >= 1 && phase_num <= 8)
                cov_reset_phase[phase_num] = cov_reset_phase[phase_num] + 1;
        end
    endtask

    // Task: print coverage report - called at end of simulation
    task print_coverage;
        integer i;
        integer opcode_hits, phase_hits;
        reg [63:0] opcode_names [0:7]; // display only, not synthesizable
        begin
            opcode_hits = 0;
            phase_hits  = 0;

            $display("\n================================================================");
            $display("  [v2] FUNCTIONAL COVERAGE REPORT");
            $display("================================================================");

            $display("\n  -- Opcode Execution Coverage --");
            $display("  %-6s  %-8s  %-6s  %s", "OP[2:0]", "Mnemonic", "Hits", "Status");
            $display("  %-6s  %-8s  %-6s  %s", "------", "--------", "----", "------");
            begin : cov_op_blk
                reg [23:0] mnemonics [0:7];
                mnemonics[0] = "MOV";
                mnemonics[1] = "ADD";
                mnemonics[2] = "SUB";
                mnemonics[3] = "ABS";
                mnemonics[4] = "NOT";
                mnemonics[5] = "AND";
                mnemonics[6] = "NEG";
                mnemonics[7] = "HLT";
                for (i = 0; i <= 7; i = i + 1) begin
                    $display("  3'b%3b   %-8s  %-6d  %s",
                             i[2:0], mnemonics[i], cov_opcode[i],
                             cov_opcode[i] > 0 ? "HIT" : "MISS <<");
                    if (cov_opcode[i] > 0) opcode_hits = opcode_hits + 1;
                end
            end
            $display("  Opcode coverage: %0d/8 bins hit (%0d%%)",
                     opcode_hits, opcode_hits * 100 / 8);

            $display("\n  -- Reset-Phase Coverage (mid-instruction reset) --");
            $display("  %-8s  %-6s  %s", "Phase", "Hits", "Status");
            $display("  %-8s  %-6s  %s", "-----", "----", "------");
            for (i = 1; i <= 8; i = i + 1) begin
                $display("  CLK%-5d  %-6d  %s",
                         i, cov_reset_phase[i],
                         cov_reset_phase[i] > 0 ? "HIT" : "MISS <<");
                if (cov_reset_phase[i] > 0) phase_hits = phase_hits + 1;
            end
            $display("  Reset-phase coverage: %0d/8 bins hit (%0d%%)",
                     phase_hits, phase_hits * 100 / 8);

            $display("\n  -- cpu_en Gate Coverage --");
            $display("  cpu_en gate test hit count: %0d  %s",
                     cov_gate_tested,
                     cov_gate_tested > 0 ? "[HIT]" : "[MISS] <<");

            $display("\n  -- [v3] Write-back Phase Coverage --");
            $display("  (Enable_Write_Data must only fire at phase 8 or 9)");
            $display("  %-8s  %-6s  %s", "Phase", "Hits", "Status");
            $display("  %-8s  %-6s  %s", "-----", "----", "------");
            begin : cov_wb_blk
                integer wb_i;
                for (wb_i = 0; wb_i <= 9; wb_i = wb_i + 1) begin
                    if (cov_wb_phase[wb_i] > 0) begin
                        $display("  phase%-4d  %-6d  %s",
                                 wb_i, cov_wb_phase[wb_i],
                                 (wb_i == 8 || wb_i == 9) ? "[OK]" : "[ILLEGAL] <<");
                    end
                end
                if (cov_wb_phase[8] == 0 && cov_wb_phase[9] == 0)
                    $display("  WARNING: no write-back observed at phase 8 or 9 <<");
                else
                    $display("  Write-back window (ph8+ph9 total hits): %0d",
                             cov_wb_phase[8] + cov_wb_phase[9]);
            end

            $display("\n  -- Scoreboard Summary --");
            $display("  SCB fail count (independent): %0d  %s",
                     scb_fail_count,
                     scb_fail_count == 0 ? "[CLEAN]" : "[FAILURES DETECTED] <<");
            $display("================================================================");
        end
    endtask

    // =========================================================================
    // [v2] ASSERTION A6 - HLT write-back guard (concurrent, runs whole sim)
    // =========================================================================
    // When ROM is replaying HLT (instruction_counter == 7, opcode = 3'b111),
    // Enable_Write_Data must NEVER be asserted.
    // We read instruction_counter directly from ROM via hierarchical reference.
    // =========================================================================
    always @(posedge clk) begin
        if (reset &&
            (dut.u_rom.instruction_counter === 3'd7) &&
            dut.Enable_Write_Data) begin
            $display("[ASSERT FAIL A6] t=%0t HLT phase: Enable_Write_Data=1 (illegal write-back)",
                     $time);
            fail_count = fail_count + 1;
        end
    end

    // ── Golden values ─────────────────────────────────────────────────────────
    localparam [7:0]
        GOLD_MOV = 8'h3C,
        GOLD_ADD = 8'h82,
        GOLD_SUB = 8'hCE,
        GOLD_ABS = 8'h32,
        GOLD_NOT = 8'hCD,
        GOLD_AND = 8'h0D,
        GOLD_NEG = 8'hF3,
        GOLD_HLT = 8'hF3;

    // ── Tasks ─────────────────────────────────────────────────────────────────
    task apply_reset;
        input integer n_cycles;
        begin
            cpu_en = 1'b0;
            reset  = 1'b0;
            repeat (n_cycles) @(posedge clk);
            #1; reset = 1'b1;
            @(posedge clk); #1;
        end
    endtask

    task run_n_gated_cycles;
        input integer n;
        begin
            cpu_en = 1'b1;
            repeat (n) @(posedge clk);
            #1; cpu_en = 1'b0;
        end
    endtask

    task run_one_instruction;
        begin
            run_n_gated_cycles(PIPE_DEPTH);
            repeat (SETTLE_CYCLES) @(posedge clk);
            #2;
        end
    endtask

    task check_result;
        input [511:0] label;
        input [7:0]   expected;
        input [7:0]   actual;
        begin
            if (actual === expected) begin
                $display("[PASS] TC%-2d  %-48s  exp=0x%02X(%4d)  got=0x%02X(%4d)",
                         tc_num, label,
                         expected, $signed(expected),
                         actual,   $signed(actual));
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] TC%-2d  %-48s  exp=0x%02X(%4d)  got=0x%02X(%4d)  ***MISMATCH***",
                         tc_num, label,
                         expected, $signed(expected),
                         actual,   $signed(actual));
                fail_count = fail_count + 1;
            end
            tc_num = tc_num + 1;
        end
    endtask

    task check_signal;
        input [511:0] label;
        input         expected;
        input         actual;
        begin
            if (actual === expected) begin
                $display("[PASS] TC%-2d  %-48s  exp=%b  got=%b",
                         tc_num, label, expected, actual);
                pass_count = pass_count + 1;
            end else begin
                $display("[FAIL] TC%-2d  %-48s  exp=%b  got=%b  ***MISMATCH***",
                         tc_num, label, expected, actual);
                fail_count = fail_count + 1;
            end
            tc_num = tc_num + 1;
        end
    endtask

    // ── Monitor ───────────────────────────────────────────────────────────────
    reg [7:0] prev_result;
    initial   prev_result = 8'hXX;

    always @(posedge clk) begin
        if (reset && (result_out !== prev_result)) begin
            $display("[MON] t=%8t | cpu_en=%b | databus=0x%02X | result_out=0x%02X(%4d) | %s",
                     $time, cpu_en, databus,
                     result_out, $signed(result_out),
                     cpu_en ? "write-back in gated window"
                            : "write-back in settle window");
            prev_result = result_out;
        end
    end

    // ── Concurrent assertions ─────────────────────────────────────────────────
    // A1: result_out no X/Z while out of reset
    always @(posedge clk) begin
        if (reset && ^result_out === 1'bx) begin
            $display("[ASSERT FAIL] t=%0t result_out contains X/Z", $time);
            fail_count = fail_count + 1;
        end
    end

    // A2: databus no X/Z while out of reset
    always @(posedge clk) begin
        if (reset && ^databus === 1'bx) begin
            $display("[ASSERT FAIL] t=%0t databus contains X/Z", $time);
            fail_count = fail_count + 1;
        end
    end

    // A3: Enable_ALU and Enable_Write_Data must not overlap
    //     (ALU computes CLK7; write-back starts CLK8 - no overlap by design)
    always @(posedge clk) begin
        if (reset && dut.Enable_ALU && dut.Enable_Write_Data) begin
            $display("[ASSERT FAIL] t=%0t Enable_ALU and Enable_Write_Data both HIGH", $time);
            fail_count = fail_count + 1;
        end
    end

    // A4: check_mul must always be 1 (combinational mux - always valid)
    always @(posedge clk) begin
        if (reset && !check_mul) begin
            $display("[ASSERT FAIL] t=%0t check_mul went LOW (mux always valid)", $time);
            fail_count = fail_count + 1;
        end
    end

    // A5: check_data_register X/Z
    always @(posedge clk) begin
        if(reset && (check_data_register === 1'bx || check_data_register === 1'bz)) begin
            $display("[ASSERT FAIL] t=%0t check_data_register is X/Z ", $time);
            fail_count = fail_count + 1;
        end
    end

    // =========================================================================
    // MAIN TEST SEQUENCE
    // =========================================================================
    initial begin
        pass_count = 0; fail_count = 0; tc_num = 1;
        reset = 1'b0; cpu_en = 1'b0;

        $display("================================================================");
        $display("  tb_CPU_full - Vivado 2024.2");
        $display("  docx 6.2 fixes: YEL4/5/6, ORG7/8 verified");
        $display("  CLK=%0dns  PIPE=%0d  SETTLE=%0d",
                  CLK_PERIOD, PIPE_DEPTH, SETTLE_CYCLES);
        $display("================================================================");

        // ─────────────────────────────────────────────────────────────────────
        // TC01 - Reset assertion
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC01: Reset assertion ---");
        reset = 1'b0; cpu_en = 1'b0;
        repeat (6) @(posedge clk); #2;
        check_result("result_out=0x00 during RESET",  8'h00, result_out);
        check_result("databus   =0x00 during RESET",  8'h00, databus);

        // ─────────────────────────────────────────────────────────────────────
        // TC02 - Full 8-instruction golden trace
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC02: Full golden trace (all 8 instructions) ---");
        apply_reset(4);
        run_one_instruction();
        check_result("ROM[0] MOV R0,60    → 0x3C( 60)", GOLD_MOV, result_out);
        run_one_instruction();
        check_result("ROM[1] ADD R0,70    → 0x82(130)", GOLD_ADD, result_out);
        run_one_instruction();
        check_result("ROM[2] SUB R0,180   → 0xCE(-50)", GOLD_SUB, result_out);
        run_one_instruction();
        check_result("ROM[3] ABS R0       → 0x32( 50)", GOLD_ABS, result_out);
        run_one_instruction();
        check_result("ROM[4] NOT R0       → 0xCD(205)", GOLD_NOT, result_out);
        run_one_instruction();
        check_result("ROM[5] AND R0,0x0F  → 0x0D( 13)", GOLD_AND, result_out);
        run_one_instruction();
        check_result("ROM[6] NEG R0       → 0xF3(-13)", GOLD_NEG, result_out);
        run_one_instruction();
        check_result("ROM[7] HLT          → 0xF3(noWB)", GOLD_HLT, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC03 - NOT standalone
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC03: NOT standalone ---");
        apply_reset(4);
        run_one_instruction(); run_one_instruction();
        run_one_instruction(); run_one_instruction();
        run_one_instruction(); // NOT
        check_result("NOT: ~0x32 = 0xCD", GOLD_NOT, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC04 - AND nibble mask
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC04: AND nibble mask ---");
        apply_reset(4);
        repeat(5) run_one_instruction();
        run_one_instruction(); // AND
        check_result("AND: 0xCD & 0x0F = 0x0D", GOLD_AND, result_out);
        begin : tc04_nibble
            reg [7:0] upper;
            upper = result_out & 8'hF0;
            check_result("AND: upper nibble = 0x00", 8'h00, upper);
        end

        // ─────────────────────────────────────────────────────────────────────
        // TC05 - NEG 2's complement property
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC05: NEG 2s complement ---");
        apply_reset(4);
        repeat(6) run_one_instruction();
        run_one_instruction(); // NEG
        check_result("NEG: ~0x0D+1 = 0xF3", GOLD_NEG, result_out);
        begin : tc05_prop
            reg [7:0] sum;
            sum = 8'h0D + result_out;
            check_result("NEG: 0x0D + NEG(0x0D) = 0x00", 8'h00, sum);
        end

        // ─────────────────────────────────────────────────────────────────────
        // TC06 - HLT no write-back
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC06: HLT no write-back ---");
        apply_reset(4);
        repeat(7) run_one_instruction();
        run_one_instruction(); // HLT
        check_result("HLT: R0 unchanged = 0xF3", GOLD_HLT, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC07 - YEL4 fix: HLT freezes PC, running more cycles keeps R0=0xF3
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC07: YEL4 - HLT freezes PC (no advance) ---");
        apply_reset(4);
        repeat(8) run_one_instruction(); // run to HLT, R0=0xF3
        check_result("After HLT: R0=0xF3", GOLD_HLT, result_out);

        // Run 2 more instruction slots - with freeze, PC stays on HLT
        // result_out must remain 0xF3 (HLT keeps replaying, no write-back)
        run_one_instruction();
        check_result("1 cycle after HLT: R0 still 0xF3 (PC frozen)", GOLD_HLT, result_out);
        run_one_instruction();
        check_result("2 cycles after HLT: R0 still 0xF3 (PC frozen)", GOLD_HLT, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC07b - Reset clears frozen PC, restarts from ROM[0]
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC07b: Reset after HLT restarts from MOV ---");
        apply_reset(4);          // reset clears instruction_counter to 0
        run_one_instruction();   // first instruction after reset = ROM[0] = MOV
        check_result("Post-HLT reset: ROM[0] MOV = 0x3C", GOLD_MOV, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC08 - cpu_en gate
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC08: cpu_en gate ---");
        apply_reset(4);
        cpu_en = 1'b0;
        repeat (40) @(posedge clk); #2;
        check_result("40cy cpu_en=0: result_out=0x00", 8'h00, result_out);
        check_result("40cy cpu_en=0: databus   =0x00", 8'h00, databus);
        cov_gate_tested = cov_gate_tested + 1; // [v2] mark gate coverage hit

        // ─────────────────────────────────────────────────────────────────────
        // TC09 - Mid-execution reset
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC09: Mid-execution reset ---");
        apply_reset(4);
        repeat(4) run_one_instruction();  // reach ABS, R0=0x32
        run_n_gated_cycles(4);            // 4 cycles into NOT
        reset  = 1'b0;
        @(posedge clk); #1; @(posedge clk); #1;
        reset  = 1'b1;
        cpu_en = 1'b0;
        repeat (3) @(posedge clk); #2;
        check_result("Mid-NOT reset: R0=0x00", 8'h00, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC10 - check_* signals (ORG8 fix)
        // ─────────────────────────────────────────────────────────────────────
//        $display("\n--- TC10: ORG8 - check_* real status ---");
//        apply_reset(4); #2;
//        // check_mul: combinational mux, always 1
//        check_signal("check_mul = 1 (comb mux always valid)", 1'b1, check_mul);
//        // check_data_register: register file always ready = 1
//        check_signal("check_data_register = 1 (RF always valid)", 1'b1, check_data_register);
//        // check_instruction_register: 0 before first instruction loaded
//        // (reg_loaded starts 0 after reset, set to 1 after CLK3 of first instr)
//        check_signal("check_IR = 0 before first instr loaded", 1'b0, check_instruction_register);
//        // Run first instruction → IR gets loaded at CLK3
//        run_one_instruction();
//        check_signal("check_IR = 1 after first instr loaded", 1'b1, check_instruction_register);
//        // check_alu: HIGH only during Enable_cal (CLK7 phase)
//        // Between instructions it is 0
//        check_signal("check_alu = 0 between instructions", 1'b0, check_alu);
         
         $display("\n--- TC10: ORG8 - check_* real status ---");
        apply_reset(4); #2;
        // check_mul: combinational mux, always 1
        check_signal("check_mul = 1 (comb mux always valid)", 1'b1, check_mul);
        // check_data_register: 0 after reset (written flag cleared - correct after fix)
        check_signal("check_data_register = 0 after reset", 1'b0, check_data_register);
        // check_instruction_register: 0 before first instruction loaded
        // (reg_loaded starts 0 after reset, set to 1 after CLK3 of first instr)
        check_signal("check_IR = 0 before first instr loaded", 1'b0, check_instruction_register);
        // Run first instruction → IR gets loaded at CLK3, RF gets written at CLK8
        run_one_instruction();
        check_signal("check_IR = 1 after first instr loaded", 1'b1, check_instruction_register);
        // check_data_register: 1 after first write-back (MOV R0,60)
        check_signal("check_data_register = 1 after first write", 1'b1, check_data_register);
        // check_alu: HIGH only during Enable_cal (CLK7 phase)
        // Between instructions it is 0
        check_signal("check_alu = 0 between instructions", 1'b0, check_alu);

        // ─────────────────────────────────────────────────────────────────────
        // TC11 - Timing stress: 3 loops, verify R0 consistent
        // (without PC wrap since HLT now freezes - test needs reset between loops)
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC11: Timing stress - 3 independent runs ---");

        apply_reset(4);
        repeat(8) run_one_instruction();
        check_result("Run1 [7]=HLT: R0=0xF3", GOLD_HLT, result_out);

        apply_reset(4);
        repeat(8) run_one_instruction();
        check_result("Run2 [7]=HLT: R0=0xF3", GOLD_HLT, result_out);

        apply_reset(4);
        run_one_instruction(); run_one_instruction();
        run_one_instruction(); run_one_instruction();
        check_result("Run3 [3]=ABS: R0=0x32", GOLD_ABS, result_out);

        // ─────────────────────────────────────────────────────────────────────
        // TC12 [v2] - Constrained-random reset phase sweep
        // ─────────────────────────────────────────────────────────────────────
        // Goal: cover all 8 pipeline phases (CLK1-CLK8) with a mid-instruction
        //       reset. After each random reset, R0 must return to 0x00.
        //       Uses $random with fixed seed for reproducibility.
        //       N_RAND_RUNS = 16 gives statistically good phase coverage.
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC12 [v2]: Constrained-random reset phase sweep ---");
        begin : tc12_rand
            integer rand_run;
            integer rand_phase;  // phase to assert reset (1-8)
            integer n_rand_runs;
            reg [7:0] tc12_label;

            n_rand_runs = 16;

            // Seed $random for reproducibility - same seed = same sequence
            // Change seed to explore different phase combinations
            begin : seed_block
                integer dummy;
                dummy = $random(32'd42); // seed = 42
            end

            for (rand_run = 0; rand_run < n_rand_runs; rand_run = rand_run + 1)
            begin : rand_loop

                // Pick a random phase 1-8 (constrained: never 9 = normal CLK9)
                rand_phase = ($random % 8) + 1; // range [1,8]

                // Run 2 full instructions first (reach stable state R0=0x82)
                apply_reset(4);
                run_one_instruction(); // MOV → R0=0x3C
                run_one_instruction(); // ADD → R0=0x82

                // Now start 3rd instruction (SUB), interrupt at rand_phase
                cpu_en = 1'b1;
                repeat (rand_phase) @(posedge clk); // advance rand_phase cycles
                #1;

                // Assert reset mid-instruction
                reset  = 1'b0;
                cpu_en = 1'b0;
                @(posedge clk); #1;
                @(posedge clk); #1;
                reset  = 1'b1;

                // Settle
                repeat (SETTLE_CYCLES) @(posedge clk); #2;

                // Check: after reset, R0 must be 0x00 regardless of phase
                check_result("TC12: mid-instr reset → R0=0x00", 8'h00, result_out);

                // Record coverage
                sample_reset_phase_cov(rand_phase);

                $display("[TC12]   run=%0d  reset_at_phase=%0d  result=0x%02X %s",
                         rand_run, rand_phase, result_out,
                         result_out === 8'h00 ? "(clean)" : "(DIRTY - partial WB?)");
            end // rand_loop
        end // tc12_rand

        // ─────────────────────────────────────────────────────────────────────
        // TC13 [v3] - Directed reset-phase coverage closer
        // ─────────────────────────────────────────────────────────────────────
        // Problem TC12 has: with seed=42, $random may not hit every phase.
        // TC13 explicitly iterates phases 1-8 one by one, guaranteeing
        // cov_reset_phase[1:8] are ALL hit = 8/8 bins = 100% coverage.
        //
        // Same structure as TC12 inner loop, but phase is deterministic.
        // After each directed reset: R0 must be 0x00 (same pass criterion).
        // ─────────────────────────────────────────────────────────────────────
        $display("\n--- TC13 [v3]: Directed phase coverage closer (phase 1-8) ---");
        begin : tc13_directed
            integer dir_phase;

            for (dir_phase = 1; dir_phase <= 8; dir_phase = dir_phase + 1)
            begin : dir_loop

                // Reach stable state: run MOV + ADD (R0=0x82)
                apply_reset(4);
                run_one_instruction(); // MOV → R0=0x3C
                run_one_instruction(); // ADD → R0=0x82

                // Enter 3rd instruction (SUB), advance exactly dir_phase gated cycles
                cpu_en = 1'b1;
                repeat (dir_phase) @(posedge clk);
                #1;

                // Assert reset at this exact phase
                reset  = 1'b0;
                cpu_en = 1'b0;
                @(posedge clk); #1;
                @(posedge clk); #1;
                reset  = 1'b1;

                // Settle
                repeat (SETTLE_CYCLES) @(posedge clk); #2;

                // Check
                check_result("TC13: directed phase reset → R0=0x00", 8'h00, result_out);

                // Mark coverage bin (guaranteed hit for this phase)
                sample_reset_phase_cov(dir_phase);

                $display("[TC13]   phase=%0d  result=0x%02X  %s",
                         dir_phase, result_out,
                         result_out === 8'h00 ? "(clean)" : "(DIRTY - partial WB?)");
            end // dir_loop
        end // tc13_directed


        $display("\n================================================================");
        $display("  SUMMARY");
        $display("  Total  : %0d", pass_count + fail_count);
        $display("  PASS   : %0d", pass_count);
        $display("  FAIL   : %0d", fail_count);
        if (fail_count == 0)
            $display("  STATUS : ALL TESTS PASSED");
        else
            $display("  STATUS : %0d FAILED", fail_count);
        $display("================================================================");
        $display("  YEL4 - HLT freezes PC                      : TC07");
        $display("  YEL5 - Data_in_SRC/DEST rename             : compile-time");
        $display("  YEL6 - Single master_phase bus              : compile-time");
        $display("  ORG7 - instruction_*.v names               : compile-time");
        $display("  ORG8 - check_* real status                  : TC10");
        $display("  [v2] Random reset sweep                     : TC12");
        $display("  [v2] HLT write-back guard                   : A6");
        $display("  [v3] Pipeline phase monitor                 : PIPE_MON");
        $display("  [v3] Write-back window assertion            : A7");
        $display("  [v3] Directed phase coverage closer         : TC13");
        $display("  [v3] Write-back phase coverage bins         : cov_wb_phase");
        $display("================================================================");

        // [v2] Print functional coverage report last
        print_coverage;

        $finish;
    end

    initial begin
        #10_000_000;
        $display("[TIMEOUT] 10ms exceeded");
        $finish;
    end

endmodule