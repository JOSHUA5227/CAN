//==============================================================
// tb_can_stuffer.v
//
// Self-checking testbench for can_stuffer. Uses a small software
// reference model (compute_reference) to predict the correct
// stuffed sequence for an arbitrary input bit pattern, then drives
// the DUT with the same pattern -- re-presenting the same source
// bit whenever stuff_insert fires, per the "stuffed cycles don't
// advance the field position" protocol -- and compares bit-for-bit.
//==============================================================

`timescale 1ns/1ps

module tb_can_stuffer;

    localparam MAXLEN = 64;

    reg clk = 0, rst_n, bit_en;
    reg tx_bit, stuff_en;
    wire tx_bit_stuffed, stuff_insert;

    can_stuffer dut (
        .clk(clk), .rst_n(rst_n), .bit_en(bit_en),
        .tx_bit(tx_bit), .stuff_en(stuff_en),
        .tx_bit_stuffed(tx_bit_stuffed), .stuff_insert(stuff_insert)
    );

    always #5 clk = ~clk;

    integer pass_count = 0;
    integer fail_count = 0;

    task check(input cond, input [300*8-1:0] msg);
        begin
            if (cond) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0s", msg);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0s", msg);
            end
        end
    endtask

    task pulse_bit_en;
        begin
            @(negedge clk);
            bit_en = 1'b1;
            @(negedge clk);
            bit_en = 1'b0;
        end
    endtask

    task reset_dut;
        begin
            rst_n = 0;
            bit_en = 0;
            tx_bit = 0;
            stuff_en = 0;
            repeat (2) @(posedge clk);
            rst_n = 1;
            @(negedge clk);
        end
    endtask

    // -----------------------------------------------------------
    // Software reference model: given a source bit stream, predict
    // the correctly-stuffed output stream (standard CAN rule: after
    // 5 identical consecutive bits IN THE TRANSMITTED stream, insert
    // a complementary bit, which itself starts a new run).
    // -----------------------------------------------------------
    task compute_reference(
        input  [0:MAXLEN-1] src,
        input  integer      src_len,
        input               stuff_en_val,
        output [0:MAXLEN-1] out_stream,
        output integer      out_len
    );
        integer i, idx;
        reg     run_val;
        integer run_len;
        begin
            if (!stuff_en_val) begin
                // no stuffing at all -- pure passthrough
                for (i = 0; i < src_len; i = i + 1)
                    out_stream[i] = src[i];
                out_len = src_len;
            end else begin
                idx = 0;
                run_len = 0;
                run_val = 1'bx;
                for (i = 0; i < src_len; i = i + 1) begin
                    out_stream[idx] = src[i];
                    idx = idx + 1;

                    if (run_len == 0 || src[i] != run_val) begin
                        run_val = src[i];
                        run_len = 1;
                    end else begin
                        run_len = run_len + 1;
                    end

                    if (run_len == 5) begin
                        out_stream[idx] = ~src[i];
                        idx = idx + 1;
                        run_val = ~src[i];
                        run_len = 1;
                    end
                end
                out_len = idx;
            end
        end
    endtask

    // -----------------------------------------------------------
    // Drive the DUT with a source stream (stuff_en held constant),
    // re-presenting the same source bit on any cycle stuff_insert
    // fired, and record the actual output sequence.
    // -----------------------------------------------------------
    integer stuff_events;
    task drive_dut(
        input  [0:MAXLEN-1] src,
        input  integer      src_len,
        input               stuff_en_val,
        output [0:MAXLEN-1] dut_out,
        output integer      dut_len
    );
        integer i, o;
        begin
            reset_dut;
            stuff_en = stuff_en_val;
            i = 0; o = 0; stuff_events = 0;
            while (i < src_len) begin
                tx_bit = src[i];
                pulse_bit_en;
                dut_out[o] = tx_bit_stuffed;
                o = o + 1;
                if (stuff_insert)
                    stuff_events = stuff_events + 1;
                else
                    i = i + 1;
            end

            // A stuff insertion can become PENDING on the very last
            // real bit but not actually be emitted until one more
            // bit-time later -- check for that trailing case.
            tx_bit = src[src_len-1]; // ignored by the DUT if a stuff fires
            pulse_bit_en;
            if (stuff_insert) begin
                dut_out[o] = tx_bit_stuffed;
                o = o + 1;
                stuff_events = stuff_events + 1;
            end

            dut_len = o;
        end
    endtask

    // -----------------------------------------------------------
    // Run one test: compute reference, drive DUT, compare
    // -----------------------------------------------------------
    reg [0:MAXLEN-1] ref_out, dut_out;
    integer ref_len, dut_len;
    integer k;
    reg match;

    task run_test(
        input [0:MAXLEN-1]   src,
        input integer        src_len,
        input                stuff_en_val,
        input [200*8-1:0]    name
    );
        begin
            compute_reference(src, src_len, stuff_en_val, ref_out, ref_len);
            drive_dut(src, src_len, stuff_en_val, dut_out, dut_len);

            check(dut_len == ref_len,
                  {name, ": output length matches reference"});

            match = 1'b1;
            for (k = 0; k < ref_len; k = k + 1)
                if (dut_out[k] !== ref_out[k])
                    match = 1'b0;
            check(match, {name, ": bit-for-bit sequence matches reference"});

            check(stuff_events == (ref_len - src_len),
                  {name, ": number of stuff_insert pulses matches expected insertions"});

            if (!match || dut_len != ref_len) begin
                $write("      expected: ");
                for (k = 0; k < ref_len; k = k + 1) $write("%b", ref_out[k]);
                $write("\n      actual:   ");
                for (k = 0; k < dut_len; k = k + 1) $write("%b", dut_out[k]);
                $write("\n");
            end
        end
    endtask

    // -----------------------------------------------------------
    // Test vectors
    // -----------------------------------------------------------
    reg [0:MAXLEN-1] pattern;

    initial begin
        $display("\n=== can_stuffer self-checking testbench ===\n");

        // T1: the worked example -- 0000011111 -> 000001111101
        pattern = 0; pattern[0:9] = 10'b0000011111;
        run_test(pattern, 10, 1'b1, "T1 (0000011111, single+double stuff)");

        // T2: exactly 6 zeros -- one stuff right at the boundary,
        // followed by one more real bit
        pattern = 0; pattern[0:5] = 6'b000001;
        run_test(pattern, 6, 1'b1, "T2 (000001, stuff right at boundary)");

        // T3: long run of ones -- multiple consecutive stuff events
        pattern = 0; pattern[0:11] = 12'b111111111111;
        run_test(pattern, 12, 1'b1, "T3 (twelve 1s, multiple stuffs)");

        // T4: alternating bits -- run never reaches 5, zero stuffing
        pattern = 0; pattern[0:9] = 10'b0101010101;
        run_test(pattern, 10, 1'b1, "T4 (alternating, no stuffing needed)");

        // T5: same 6-zero run as T2, but stuff_en=0 -- must pass
        // through untouched, verifying the stuff_en=0 fix
        pattern = 0; pattern[0:5] = 6'b000000;
        run_test(pattern, 6, 1'b0, "T5 (stuff_en=0, pure passthrough, no insertion)");

        // T6: exactly 5 identical bits, nothing after -- stuff bit
        // must still be inserted right at the end
        pattern = 0; pattern[0:4] = 5'b11111;
        run_test(pattern, 5, 1'b1, "T6 (exactly 5 bits, stuff at the tail)");

        // T7: long run of zeros -- multiple stuffs, opposite polarity from T3
        pattern = 0; pattern[0:9] = 10'b0000000000;
        run_test(pattern, 10, 1'b1, "T7 (ten 0s, multiple stuffs, opposite polarity)");

        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("============================================\n");
        $finish;
    end

    initial begin
        #100000;
        $display("[TIMEOUT] simulation hung");
        $finish;
    end

endmodule

