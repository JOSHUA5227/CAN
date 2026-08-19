//==============================================================
// tb_can_frame_controller.v
//
// Self-checking testbench for can_frame_controller (control path
// only). Drives bit_error / ack_received / crc_error / stuff_error /
// form_error / can_rx_sync directly as abstracted stimulus -- this
// DUT is control-path only, so no real CRC/stuffing datapath is
// modeled here, matching the DUT's own scope.
//
// bit_en is stubbed as a simple free-running divider (per the
// "decouple frame assembly from bit timing" approach) -- swap for
// the real bit-timing engine later without touching this testbench.
//==============================================================

`timescale 1ns/1ps

module tb_can_frame_controller;

    // -----------------------------------------------------------
    // DUT signals
    // -----------------------------------------------------------
    reg         clk, rst_n, bit_en;
    reg         can_rx_sync;
    reg         tx_request, rtr, ide;
    reg  [3:0]  dlc;
    reg         rx_rtr, rx_ide;
    reg  [3:0]  rx_dlc;
    reg         bit_error, ack_received, stuff_insert;
    reg         crc_error, stuff_error, form_error;

    wire        ack_drive, is_transmitting;
    wire [3:0]  field_sel;
    wire [5:0]  bit_cnt;
    wire [2:0]  byte_idx;
    wire        crc_en, stuff_en, error_detected;
    wire        tx_done, tx_busy;

    // Mirror the DUT's own state encoding for readable checks
    localparam IDLE=4'd0, SOF=4'd1, ARBITRATION=4'd2, CONTROL=4'd3,
               DATA=4'd4, CRC=4'd5, CRC_DELIM=4'd6, ACK=4'd7,
               ACK_DELIM=4'd8, EOF=4'd9, INTERMISSION=4'd10,
               ERROR_FLAG=4'd11, WAIT_RECESSIVE=4'd12,
               ERROR_DELIM=4'd13, RX_ONLY=4'd14;

    can_frame_controller dut (
        .clk(clk), .rst_n(rst_n), .bit_en(bit_en),
        .can_rx_sync(can_rx_sync),
        .tx_request(tx_request), .rtr(rtr), .ide(ide), .dlc(dlc),
        .rx_rtr(rx_rtr), .rx_dlc(rx_dlc), .rx_ide(rx_ide),
        .bit_error(bit_error), .ack_received(ack_received),
        .stuff_insert(stuff_insert),
        .crc_error(crc_error), .stuff_error(stuff_error), .form_error(form_error),
        .ack_drive(ack_drive), .is_transmitting(is_transmitting),
        .field_sel(field_sel), .bit_cnt(bit_cnt), .byte_idx(byte_idx),
        .crc_en(crc_en), .stuff_en(stuff_en),
        .error_detected(error_detected),
        .tx_done(tx_done), .tx_busy(tx_busy)
    );

    // -----------------------------------------------------------
    // Clock
    // -----------------------------------------------------------
    initial clk = 0;
    always #5 clk = ~clk;   // 10ns period

    // -----------------------------------------------------------
    // bit_en: testbench-driven single-cycle pulses. Set at negedge
    // (full setup margin before the DUT's capturing posedge), held
    // through that posedge, cleared at the following negedge.
    // -----------------------------------------------------------
    task pulse_bit_en;
        begin
            @(negedge clk);
            bit_en = 1'b1;
            @(negedge clk);
            bit_en = 1'b0;
        end
    endtask

    // -----------------------------------------------------------
    // Bookkeeping
    // -----------------------------------------------------------
    integer pass_count = 0;
    integer fail_count = 0;

    task check(input cond, input [200*8-1:0] msg);
        begin
            if (cond) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0t : %0s", $time, msg);
            end else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0t : %0s (field_sel=%0d bit_cnt=%0d)", $time, msg, field_sel, bit_cnt);
            end
        end
    endtask

    // Assert N clean bit_en pulses in a row, holding whatever
    // stimulus is currently set
    task step_bits(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                pulse_bit_en;
        end
    endtask

    task reset_dut;
        begin
            rst_n = 0;
            bit_en = 0;
            tx_request = 0; rtr = 0; ide = 0; dlc = 4'd0;
            rx_rtr = 0; rx_ide = 0; rx_dlc = 4'd0;
            bit_error = 0; ack_received = 0; stuff_insert = 0;
            crc_error = 0; stuff_error = 0; form_error = 0;
            can_rx_sync = 1'b1; // idle bus
            repeat (4) @(posedge clk);
            rst_n = 1;
            @(negedge clk);
        end
    endtask

    // -----------------------------------------------------------
    // TEST 1: clean standard data frame, 3 bytes, we win arbitration
    // -----------------------------------------------------------
    task test1_standard_data_frame;
        begin
            $display("\n--- TEST 1: standard data frame, 3 bytes ---");
            reset_dut;
            tx_request = 1; rtr = 0; ide = 0; dlc = 4'd3;
            step_bits(1);
            check(field_sel == SOF, "T1: entered SOF");

            step_bits(1);
            check(field_sel == ARBITRATION, "T1: entered ARBITRATION");

            // win all 13 phase-1 bits cleanly (standard -> no phase 2)
            step_bits(13);
            check(field_sel == CONTROL, "T1: ARBITRATION(std) -> CONTROL after 13 bits");

            step_bits(5); // CTRL_LEN_STD
            check(field_sel == DATA, "T1: CONTROL(std,5 bits) -> DATA");

            step_bits(24); // 3 bytes * 8
            check(field_sel == CRC, "T1: DATA(3 bytes) -> CRC");

            step_bits(15);
            check(field_sel == CRC_DELIM, "T1: CRC(15 bits) -> CRC_DELIM");

            step_bits(1);
            check(field_sel == ACK, "T1: CRC_DELIM -> ACK");

            ack_received = 1; // receiver acknowledges
            step_bits(1);
            check(field_sel == ACK_DELIM, "T1: ACK -> ACK_DELIM");
            check(error_detected == 1'b0, "T1: no ACK error when acknowledged");

            step_bits(1);
            check(field_sel == EOF, "T1: ACK_DELIM -> EOF");

            step_bits(6); // 6 of EOF's 7 bits
            check(tx_done == 1'b0, "T1: tx_done not yet asserted mid-EOF");
            step_bits(1); // last EOF bit
            check(tx_done == 1'b1, "T1: tx_done asserted on last EOF bit");
            check(field_sel == INTERMISSION, "T1: EOF -> INTERMISSION");

            step_bits(3);
            check(field_sel == IDLE, "T1: INTERMISSION(3 bits) -> IDLE");
            check(is_transmitting == 1'b0, "T1: is_transmitting cleared back in IDLE");
        end
    endtask

    // -----------------------------------------------------------
    // TEST 2: remote frame -- DATA must be skipped
    // -----------------------------------------------------------
    task test2_remote_frame_skips_data;
        begin
            $display("\n--- TEST 2: remote frame skips DATA ---");
            reset_dut;
            tx_request = 1; rtr = 1; ide = 0; dlc = 4'd5; // DLC nonzero but RTR=1
            step_bits(2 + 13);          // SOF + ARBITRATION
            check(field_sel == CONTROL, "T2: reached CONTROL");
            step_bits(5);
            check(field_sel == CRC, "T2: CONTROL -> CRC directly, DATA skipped (RTR=1)");
        end
    endtask

    // -----------------------------------------------------------
    // TEST 3: data frame with DLC=0 -- DATA must also be skipped
    // -----------------------------------------------------------
    task test3_dlc_zero_skips_data;
        begin
            $display("\n--- TEST 3: DLC=0 skips DATA ---");
            reset_dut;
            tx_request = 1; rtr = 0; ide = 0; dlc = 4'd0;
            step_bits(2 + 13);
            check(field_sel == CONTROL, "T3: reached CONTROL");
            step_bits(5);
            check(field_sel == CRC, "T3: CONTROL -> CRC directly, DATA skipped (DLC=0)");
        end
    endtask

    // -----------------------------------------------------------
    // TEST 4: extended frame -- verify phase-2 arbitration extension
    // -----------------------------------------------------------
    task test4_extended_frame_phase2;
        begin
            $display("\n--- TEST 4: extended frame, phase-2 arbitration ---");
            reset_dut;
            tx_request = 1; rtr = 0; ide = 1; dlc = 4'd2;
            step_bits(1);
            check(field_sel == SOF, "T4: entered SOF");
            step_bits(1);
            check(field_sel == ARBITRATION, "T4: entered ARBITRATION");

            step_bits(13); // phase 1 -- IDE resolves extended here
            check(field_sel == ARBITRATION, "T4: still ARBITRATION after phase-1 (extended detected)");
            check(bit_cnt == 6'd19, "T4: bit_cnt reloaded to 19 for phase 2");

            step_bits(19); // phase 2
            check(field_sel == CONTROL, "T4: ARBITRATION -> CONTROL after full 32 bits");

            step_bits(6); // CTRL_LEN_EXT
            check(field_sel == DATA, "T4: CONTROL(ext,6 bits) -> DATA");
        end
    endtask

    // -----------------------------------------------------------
    // TEST 5: lose arbitration mid-frame
    // -----------------------------------------------------------
    task test5_arbitration_loss;
        begin
            $display("\n--- TEST 5: arbitration loss -> RX_ONLY ---");
            reset_dut;
            tx_request = 1; rtr = 0; ide = 0; dlc = 4'd1;
            step_bits(2); // SOF + first ARBITRATION bit
            step_bits(3); // a few more clean bits

            bit_error = 1; // we sent recessive, bus is dominant -- lost
            step_bits(1);
            check(field_sel == RX_ONLY, "T5: ARBITRATION -> RX_ONLY on bit_error");
            check(is_transmitting == 1'b0, "T5: is_transmitting cleared on loss");
            check(error_detected == 1'b0, "T5: arbitration loss is NOT an error");

            bit_error = 0; // stop mismatching, finish out the field as listener
        end
    endtask

    // -----------------------------------------------------------
    // TEST 6: missing ACK -> ack_error_occured -> error path
    // -----------------------------------------------------------
    task test6_missing_ack;
        begin
            $display("\n--- TEST 6: missing ACK triggers error path ---");
            reset_dut;
            tx_request = 1; rtr = 0; ide = 0; dlc = 4'd0;
            step_bits(2 + 13 + 5); // SOF+ARB(std)+CONTROL
            check(field_sel == CRC, "T6: reached CRC (DLC=0)");
            step_bits(15 + 1);     // CRC + CRC_DELIM
            check(field_sel == ACK, "T6: reached ACK");

            ack_received = 0; // nobody acknowledged
            step_bits(1);
            check(field_sel == ERROR_FLAG, "T6: missing ACK -> ERROR_FLAG");

            step_bits(6); // ERR_FLAG_LEN
            check(field_sel == WAIT_RECESSIVE, "T6: ERROR_FLAG -> WAIT_RECESSIVE");

            can_rx_sync = 1'b1; // bus goes quiet
            step_bits(1);
            check(field_sel == ERROR_DELIM, "T6: WAIT_RECESSIVE -> ERROR_DELIM once bus recessive");

            step_bits(7);
            check(field_sel == INTERMISSION, "T6: ERROR_DELIM -> INTERMISSION");
        end
    endtask

    // -----------------------------------------------------------
    // TEST 7: crc_error preempts immediately, from any state
    // -----------------------------------------------------------
    task test7_crc_error_preempts;
        begin
            $display("\n--- TEST 7: crc_error preempts mid-DATA ---");
            reset_dut;
            tx_request = 1; rtr = 0; ide = 0; dlc = 4'd4;
            step_bits(2 + 13 + 5 + 10); // into the middle of DATA somewhere
            check(field_sel == DATA, "T7: currently in DATA");

            crc_error = 1;
            step_bits(1);
            check(field_sel == ERROR_FLAG, "T7: crc_error preempts DATA -> ERROR_FLAG immediately");
            check(error_detected == 1'b1, "T7: error_detected asserted for crc_error");
            crc_error = 0;
        end
    endtask

    // -----------------------------------------------------------
    // TEST 8: pure listener (never had tx_request) drives ACK, never TX
    // -----------------------------------------------------------
    task test8_pure_listener;
        begin
            $display("\n--- TEST 8: pure listener frame ---");
            reset_dut;
            tx_request = 0; // never wanted to send
            can_rx_sync = 1'b0; // detect someone else's dominant SOF
            step_bits(1);
            check(field_sel == SOF, "T8: entered SOF as listener");
            step_bits(1);
            check(is_transmitting == 1'b0, "T8: is_transmitting stayed 0 (never requested TX)");
            check(field_sel == ARBITRATION, "T8: entered ARBITRATION as listener");

            rx_rtr = 0; rx_dlc = 4'd1; rx_ide = 0;
            step_bits(13);
            check(field_sel == CONTROL, "T8: listener ARBITRATION(std) -> CONTROL");

            step_bits(5);
            check(field_sel == DATA, "T8: listener CONTROL -> DATA (rx_dlc=1)");

            step_bits(8);
            check(field_sel == CRC, "T8: listener DATA(1 byte) -> CRC");

            step_bits(15 + 1);
            check(field_sel == ACK, "T8: listener reached ACK");
            check(ack_drive == 1'b1, "T8: listener drives ACK dominant (crc was clean)");
        end
    endtask

    // -----------------------------------------------------------
    // Run all tests
    // -----------------------------------------------------------
    initial begin
        test1_standard_data_frame;
        test2_remote_frame_skips_data;
        test3_dlc_zero_skips_data;
        test4_extended_frame_phase2;
        test5_arbitration_loss;
        test6_missing_ack;
        test7_crc_error_preempts;
        test8_pure_listener;

        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed", pass_count, fail_count);
        $display("============================================\n");
        $finish;
    end

    // Safety timeout in case any state hangs
    initial begin
        #200000;
        $display("[TIMEOUT] Simulation did not finish in time -- likely a hung state");
        $finish;
    end

endmodule

