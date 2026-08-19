`timescale 1ns/1ps

module tb_can_bit_timing_engine;

    reg clk = 0;
    reg rst_n;
    reg can_rx_sync;

    reg [3:0] state;

    reg [31:0] brp;
    reg [7:0] prop_seg;
    reg [7:0] phase_seg1;
    reg [7:0] phase_seg2;
    reg [3:0] sjw;

    wire sample_en;
    wire sof_detected;
    wire bit_en;

    localparam ST_IDLE = 4'd0;
    localparam ST_ARB  = 4'd2;

    bit_timing_engine dut (
        .clk(clk),
        .rst_n(rst_n),
        .can_rx_sync(can_rx_sync),
        .state(state),

        .brp(brp),
        .prop_seg(prop_seg),
        .phase_seg1(phase_seg1),
        .phase_seg2(phase_seg2),
        .sjw(sjw),

        .sample_en(sample_en),
        .sof_detected(sof_detected),
        .bit_en(bit_en)
    );

    always #5 clk = ~clk;

    integer pass = 0;
    integer fail = 0;

    task check(input cond, input [300*8-1:0] msg);
        begin
            if (cond) begin
                pass = pass + 1;
                $display("[PASS] %0s", msg);
            end
            else begin
                fail = fail + 1;
                $display("[FAIL] %0s", msg);
            end
        end
    endtask

    task cfg_default;
        begin
            brp        = 32'd2;
            prop_seg   = 8'd2;
            phase_seg1 = 8'd3;
            phase_seg2 = 8'd2;
            sjw        = 4'd2;
        end
    endtask

    task set_rx(input v);
        begin
            @(negedge clk);
            can_rx_sync = v;
        end
    endtask

    task reset_dut;
        begin
            rst_n       = 1'b0;
            can_rx_sync = 1'b1;
            state       = ST_ARB;

            repeat(2) @(posedge clk);

            rst_n = 1'b1;

            @(posedge clk);
        end
    endtask

    task do_hard_sync;
        begin
            state = ST_IDLE;

            set_rx(0);

            @(posedge clk);

            set_rx(1);

            @(negedge clk);
            state = ST_ARB;

            while (!bit_en)
                @(posedge clk);

            @(posedge clk);
        end
    endtask

    initial begin

        $dumpfile("can_bit_timing_engine.vcd");
        $dumpvars(0, tb_can_bit_timing_engine);

        $display("\n=== can_bit_timing_engine testbench ===\n");

        cfg_default;
        reset_dut;

        // -----------------------------------------------------
        // TEST 1: nominal free-run
        // -----------------------------------------------------

        while (!bit_en)
            @(posedge clk);

        @(posedge clk);

        while (!sample_en)
            @(posedge clk);

        check(
            dut.tq_count == dut.sample_point,
            "T1a: sample_en fires exactly one tq after the sample point (registered)"
        );

        while (!bit_en)
            @(posedge clk);

        check(
            dut.tq_count == dut.effective_tq_per_bit - 1,
            "T1b: bit_en fires exactly at tq_count == effective_tq_per_bit-1"
        );

        @(posedge clk);

        while (!bit_en)
            @(posedge clk);

        check(
            dut.tq_count == dut.effective_tq_per_bit - 1,
            "T1c: second bit_en also lands at the same tq_count (period is stable)"
        );

        // -----------------------------------------------------
        // TEST 2: hard sync gating
        // -----------------------------------------------------

        reset_dut;

        state = ST_ARB;

        set_rx(0);

        repeat(3) @(posedge clk);

        check(
            dut.tq_count != 32'd0,
            "T2a: falling edge while NOT idle does not force tq_count to 0"
        );

        set_rx(1);

        state = ST_IDLE;

        while (dut.tq_count != 32'd3)
            @(posedge clk);

        set_rx(0);

        @(posedge clk);
        @(posedge clk);

        check(
            dut.tq_count == 32'd0,
            "T2b: hard sync while IDLE resets tq_count on the very next edge"
        );

        check(
            sof_detected == 1'b1,
            "T2c: sof_detected asserted during HARD_SYNC"
        );

        set_rx(1);

        state = ST_ARB;

        // -----------------------------------------------------
        // TEST 3: early resynchronization
        // -----------------------------------------------------

        reset_dut;

        do_hard_sync;

        while (dut.tq_count != 32'd2)
            @(posedge clk);

        set_rx(0);

        @(posedge clk);
        @(posedge clk);

        check(
            dut.phase1_current == (phase_seg1 + 2),
            "T3: early edge extends phase1_current by min(phase_error,sjw)"
        );

        check(
            dut.phase2_current == phase_seg2,
            "T3b: phase2_current unchanged on early-edge resync"
        );

        set_rx(1);

        while (!bit_en)
            @(posedge clk);

        @(posedge clk);

        check(
            dut.phase1_current == phase_seg1,
            "T3c: phase1_current reverts to nominal once the extended bit ends"
        );

        // -----------------------------------------------------
        // TEST 4: late resynchronization
        // -----------------------------------------------------

        reset_dut;

        do_hard_sync;

        while (dut.tq_count != 32'd7)
            @(posedge clk);

        set_rx(0);

        @(posedge clk);
        @(posedge clk);

        check(
            dut.phase2_current == (phase_seg2 - 1),
            "T4: late edge shortens phase2_current by min(phase_error,sjw)"
        );

        check(
            dut.phase1_current == phase_seg1,
            "T4b: phase1_current unchanged on late-edge resync"
        );

        set_rx(1);

        // -----------------------------------------------------
        // TEST 5: edge exactly at sample point
        // -----------------------------------------------------

        reset_dut;

        do_hard_sync;

        while (dut.tq_count != dut.sample_point)
            @(posedge clk);

        set_rx(0);

        @(posedge clk);

        check(
            (dut.phase1_current == phase_seg1) &&
            (dut.phase2_current == phase_seg2),
            "T5: edge exactly at sample point makes no adjustment"
        );

        set_rx(1);

        // -----------------------------------------------------
        // TEST 6: only one resync per bit
        // -----------------------------------------------------

        reset_dut;

        do_hard_sync;

        while (dut.tq_count != 32'd2)
            @(posedge clk);

        set_rx(0);

        @(posedge clk);

        set_rx(1);

        @(posedge clk);

        check(
            dut.sync_done == 1'b1,
            "T6a: sync_done set after first edge in this bit"
        );

        while (dut.tq_count != 32'd4)
            @(posedge clk);

        set_rx(0);

        @(posedge clk);

        set_rx(1);

        @(posedge clk);

        check(
            dut.phase1_current == (phase_seg1 + 2),
            "T6b: second edge in same bit does not cause a further adjustment"
        );

        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed", pass, fail);
        $display("============================================\n");

        $finish;
    end

    initial begin
        #200000;

        $display("[TIMEOUT] simulation hung");

        $finish;
    end

endmodule
