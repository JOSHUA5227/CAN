//==============================================================
// tb_can_bit_timing_engine.v
//
// Self-checking testbench. Checks are built around DIRECT
// inspection of dut.tq_count / dut.phase*_current at the moment
// each pulse fires, rather than clock-counting between pulses --
// sample_en is a registered output and bit_en is combinational,
// so they have different inherent latency relative to the same
// underlying tq_count condition; comparing pulse-to-pulse timing
// directly is not a reliable measurement technique here.
//==============================================================

`timescale 1ns/1ps

module tb_can_bit_timing_engine;

    reg clk = 0, rst_n, can_rx_sync;
    reg [3:0] state;
    reg [31:0] brp;
    reg [7:0] prop_seg, phase_seg1, phase_seg2;
    reg [3:0] sjw;
    wire sample_en, bit_en;

    localparam ST_IDLE = 4'd0;
    localparam ST_ARB  = 4'd2;

    bit_timing_engine dut (
        .clk(clk), .rst_n(rst_n), .can_rx_sync(can_rx_sync), .state(state),
        .brp(brp), .prop_seg(prop_seg), .phase_seg1(phase_seg1),
        .phase_seg2(phase_seg2), .sjw(sjw),
        .sample_en(sample_en), .bit_en(bit_en)
    );

    always #5 clk = ~clk;

    integer pass = 0, fail = 0;
    task check(input cond, input [300*8-1:0] msg);
        begin
            if (cond) begin pass = pass + 1; $display("[PASS] %0s", msg); end
            else begin fail = fail + 1; $display("[FAIL] %0s", msg); end
        end
    endtask

    // brp=2 (2 clk/tq), prop=2, ph1=3, ph2=2 -> tq_per_bit=8
    // sample_point=6 (sample fires when tq_count reaches 5)
    // bit_en fires when tq_count reaches 7
    task cfg_default;
        begin brp=32'd2; prop_seg=8'd2; phase_seg1=8'd3; phase_seg2=8'd2; sjw=4'd2; end
    endtask

    task set_rx(input v);
        begin @(negedge clk); can_rx_sync = v; end
    endtask

    task reset_dut;
        begin
            rst_n = 0; can_rx_sync = 1; state = ST_ARB;
            repeat(2) @(posedge clk);
            rst_n = 1; @(posedge clk);
        end
    endtask

    // bte_state can only reach RUN via a genuine hard sync first --
    // resync can never be exercised without this happening once.
    // The hard sync itself is a synchronization event (sets sync_done),
    // so a resync attempted in that SAME bit would correctly be
    // blocked -- advance through one full bit_en first to reach a
    // fresh bit where sync_done has been cleared again.
    task do_hard_sync;
        begin
            state = ST_IDLE;
            set_rx(0);
            @(posedge clk); // hard sync lands
            set_rx(1);
            @(negedge clk);
            state = ST_ARB;
            while (!bit_en) @(posedge clk); // clear sync_done for a fresh bit
            @(posedge clk);
        end
    endtask

    reg [31:0] tq_at_sample, tq_at_biten;

    initial begin
        $display("\n=== can_bit_timing_engine testbench ===\n");
        cfg_default;
        reset_dut;

        // -----------------------------------------------------
        // TEST 1: nominal free-run (no edges) -- verify sample_en
        // and bit_en fire at exactly the right tq_count values
        // -----------------------------------------------------
        while (!bit_en) @(posedge clk);
        @(posedge clk);

        while (!sample_en) @(posedge clk);
        // sample_en is registered: it fires the cycle AFTER the tq_en
        // pulse where tq_count==sample_point-1, so tq_count has
        // already advanced by 1 by the time we observe it high
        check(dut.tq_count == dut.sample_point,
              "T1a: sample_en fires exactly one tq after the sample point (registered)");

        while (!bit_en) @(posedge clk);
        check(dut.tq_count == dut.effective_tq_per_bit - 1,
              "T1b: bit_en fires exactly at tq_count == effective_tq_per_bit-1");

        // full bit period, measured directly via a second bit_en
        @(posedge clk);
        while (!bit_en) @(posedge clk);
        check(dut.tq_count == dut.effective_tq_per_bit - 1,
              "T1c: second bit_en also lands at the same tq_count (period is stable)");

        // -----------------------------------------------------
        // TEST 2: hard sync gating -- only fires when state==IDLE,
        // and now resets promptly (fixed latency vs prior version)
        // -----------------------------------------------------
        reset_dut;
        state = ST_ARB;
        set_rx(0); // falling edge, but NOT idle
        repeat(3) @(posedge clk);
        check(dut.tq_count != 32'd0,
              "T2a: falling edge while NOT idle does not force tq_count to 0");
        set_rx(1);

        state = ST_IDLE;
        while (dut.tq_count != 32'd3) @(posedge clk); // wait for a known, specific point
        set_rx(0);
        @(posedge clk); @(posedge clk); // one extra cycle of registration latency
        check(dut.tq_count == 32'd0,
              "T2b: hard sync while IDLE resets tq_count on the very next edge");
        set_rx(1);
        state = ST_ARB;

        // -----------------------------------------------------
        // TEST 3: resync -- edge arrives EARLY (before sample point)
        // -----------------------------------------------------
        reset_dut;
        do_hard_sync;
        while (dut.tq_count != 32'd2) @(posedge clk); // before sample_point=6
        set_rx(0);
        @(posedge clk); @(posedge clk); // one extra cycle of registration latency
        check(dut.phase1_current == (phase_seg1 + 2),
              "T3: early edge extends phase1_current by min(phase_error,sjw)");
        check(dut.phase2_current == phase_seg2,
              "T3b: phase2_current unchanged on early-edge resync");
        set_rx(1);

        while (!bit_en) @(posedge clk);
        @(posedge clk);
        check(dut.phase1_current == phase_seg1,
              "T3c: phase1_current reverts to nominal once the (extended) bit ends");

        // -----------------------------------------------------
        // TEST 4: resync -- edge arrives LATE (after sample point)
        // -----------------------------------------------------
        reset_dut;
        do_hard_sync;
        while (dut.tq_count != 32'd7) @(posedge clk); // past sample_point=6
        set_rx(0);
        @(posedge clk); @(posedge clk); // one extra cycle of registration latency
        check(dut.phase2_current == (phase_seg2 - 1),
              "T4: late edge shortens phase2_current by min(phase_error,sjw) -- phase_error here is 1, not sjw");
        check(dut.phase1_current == phase_seg1,
              "T4b: phase1_current unchanged on late-edge resync");
        set_rx(1);

        // -----------------------------------------------------
        // TEST 5: edge lands EXACTLY at the sample point -- explicit
        // zero-adjustment branch (was an implicit hold in the prior
        // version; now explicit)
        // -----------------------------------------------------
        reset_dut;
        do_hard_sync;
        while (dut.tq_count != dut.sample_point) @(posedge clk); // exactly at sample point
        set_rx(0);
        @(posedge clk);
        check((dut.phase1_current == phase_seg1) && (dut.phase2_current == phase_seg2),
              "T5: edge exactly at sample point makes no adjustment");
        set_rx(1);

        // -----------------------------------------------------
        // TEST 6: only one resync per bit (sync_done gating)
        // -----------------------------------------------------
        reset_dut;
        do_hard_sync;
        while (dut.tq_count != 32'd2) @(posedge clk);
        set_rx(0); @(posedge clk); set_rx(1); @(posedge clk);
        check(dut.sync_done == 1'b1, "T6a: sync_done set after first edge in this bit");

        while (dut.tq_count != 32'd4) @(posedge clk);
        set_rx(0); @(posedge clk); set_rx(1); @(posedge clk);
        check(dut.phase1_current == (phase_seg1 + 2),
              "T6b: second edge in same bit does not cause a further adjustment");

        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed", pass, fail);
        $display("============================================\n");
        $finish;
    end

    initial begin #200000; $display("[TIMEOUT] simulation hung"); $finish; end

endmodule
