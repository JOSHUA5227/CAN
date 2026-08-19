`timescale 1ns/1ps

module tb_can_frame_controller;

    reg         clk;
    reg         rst_n;
    reg         bit_en;

    reg         can_rx_sync;
    reg         sof_detected;

    reg         tx_request;
    reg         rtr;
    reg         ide;
    reg  [3:0]  dlc;

    reg         bit_error;
    reg         error_event;
    reg         stuff_insert;
    reg         rx_bit_valid;

    reg         rx_rtr;
    reg         rx_ide;
    reg  [3:0]  rx_dlc;

    wire        ack_drive;
    wire        arb_phase;
    wire        is_transmitting;

    wire [3:0]  field_sel;
    wire [5:0]  bit_cnt;
    wire [2:0]  byte_idx;

    wire        crc_en;
    wire        stuff_en;

    wire        bit_error_occured;
    wire        tx_done;
    wire        rx_done;
    wire        line_busy;

    localparam IDLE           = 4'd0;
    localparam SOF            = 4'd1;
    localparam ARBITRATION    = 4'd2;
    localparam CONTROL        = 4'd3;
    localparam DATA           = 4'd4;
    localparam CRC            = 4'd5;
    localparam CRC_DELIM      = 4'd6;
    localparam ACK            = 4'd7;
    localparam ACK_DELIM      = 4'd8;
    localparam EOF            = 4'd9;
    localparam INTERMISSION   = 4'd10;
    localparam ERROR_FLAG     = 4'd11;
    localparam WAIT_RECESSIVE = 4'd12;
    localparam ERROR_DELIM    = 4'd13;
    localparam RX_ONLY        = 4'd14;

    can_frame_controller dut (
        .clk(clk),
        .rst_n(rst_n),
        .bit_en(bit_en),

        .can_rx_sync(can_rx_sync),
        .sof_detected(sof_detected),

        .tx_request(tx_request),
        .rtr(rtr),
        .ide(ide),
        .dlc(dlc),

        .bit_error(bit_error),
        .error_event(error_event),
        .stuff_insert(stuff_insert),
        .rx_bit_valid(rx_bit_valid),

        .rx_rtr(rx_rtr),
        .rx_dlc(rx_dlc),
        .rx_ide(rx_ide),

        .ack_drive(ack_drive),
        .arb_phase(arb_phase),
        .is_transmitting(is_transmitting),

        .field_sel(field_sel),
        .bit_cnt(bit_cnt),
        .byte_idx(byte_idx),

        .crc_en(crc_en),
        .stuff_en(stuff_en),

        .bit_error_occured(bit_error_occured),
        .tx_done(tx_done),
        .rx_done(rx_done),
        .line_busy(line_busy)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    task pulse_bit_en;
        begin
            @(negedge clk);
            bit_en = 1'b1;

            @(negedge clk);
            bit_en = 1'b0;
        end
    endtask

    task step_bits(input integer n);
        integer i;
        begin
            for (i = 0; i < n; i = i + 1)
                pulse_bit_en;
        end
    endtask

    integer pass_count = 0;
    integer fail_count = 0;

    task check(input cond, input [200*8-1:0] msg);
        begin
            if (cond) begin
                pass_count = pass_count + 1;
                $display("[PASS] %0t : %0s", $time, msg);
            end
            else begin
                fail_count = fail_count + 1;
                $display("[FAIL] %0t : %0s (state=%0d bit_cnt=%0d)",
                         $time, msg, field_sel, bit_cnt);
            end
        end
    endtask

    task reset_dut;
        begin
            rst_n = 0;
            bit_en = 0;

            can_rx_sync = 1'b1;
            sof_detected = 1'b0;

            tx_request = 1'b0;
            rtr = 1'b0;
            ide = 1'b0;
            dlc = 4'd0;

            bit_error = 1'b0;
            error_event = 1'b0;
            stuff_insert = 1'b0;
            rx_bit_valid = 1'b1;

            rx_rtr = 1'b0;
            rx_ide = 1'b0;
            rx_dlc = 4'd0;

            repeat (4) @(posedge clk);

            rst_n = 1'b1;

            @(negedge clk);
        end
    endtask


    task test1_standard_data_frame;
        begin
            $display("\n--- TEST 1: standard data frame, 3 bytes ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b0;
            ide = 1'b0;
            dlc = 4'd3;

            step_bits(1);
            check(field_sel == SOF,
                  "T1: entered SOF");

            step_bits(1);
            check(field_sel == ARBITRATION,
                  "T1: entered ARBITRATION");

            step_bits(13);
            check(field_sel == CONTROL,
                  "T1: ARBITRATION(std) -> CONTROL");

            step_bits(5);
            check(field_sel == DATA,
                  "T1: CONTROL(std) -> DATA");

            step_bits(24);
            check(field_sel == CRC,
                  "T1: DATA(3 bytes) -> CRC");

            step_bits(15);
            check(field_sel == CRC_DELIM,
                  "T1: CRC -> CRC_DELIM");

            step_bits(1);
            check(field_sel == ACK,
                  "T1: CRC_DELIM -> ACK");

            step_bits(1);
            check(field_sel == ACK_DELIM,
                  "T1: ACK -> ACK_DELIM");

            step_bits(1);
            check(field_sel == EOF,
                  "T1: ACK_DELIM -> EOF");

            step_bits(6);
            check(tx_done == 1'b0,
                  "T1: tx_done not asserted mid-EOF");

            step_bits(1);
            check(tx_done == 1'b1,
                  "T1: tx_done asserted on last EOF bit");

            check(field_sel == INTERMISSION,
                  "T1: EOF -> INTERMISSION");

            step_bits(3);

            check(field_sel == IDLE,
                  "T1: INTERMISSION -> IDLE");

            check(is_transmitting == 1'b0,
                  "T1: is_transmitting cleared");
        end
    endtask


    task test2_remote_frame;
        begin
            $display("\n--- TEST 2: remote frame skips DATA ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b1;
            ide = 1'b0;
            dlc = 4'd5;

            step_bits(2 + 13);

            check(field_sel == CONTROL,
                  "T2: reached CONTROL");

            step_bits(5);

            check(field_sel == CRC,
                  "T2: RTR frame skips DATA");
        end
    endtask


    task test3_dlc_zero;
        begin
            $display("\n--- TEST 3: DLC=0 skips DATA ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b0;
            ide = 1'b0;
            dlc = 4'd0;

            step_bits(2 + 13);

            check(field_sel == CONTROL,
                  "T3: reached CONTROL");

            step_bits(5);

            check(field_sel == CRC,
                  "T3: DLC=0 skips DATA");
        end
    endtask


    task test4_extended_frame;
        begin
            $display("\n--- TEST 4: extended frame ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b0;
            ide = 1'b1;
            dlc = 4'd2;

            step_bits(1);

            check(field_sel == SOF,
                  "T4: entered SOF");

            step_bits(1);

            check(field_sel == ARBITRATION,
                  "T4: entered ARBITRATION");

            step_bits(13);

            check(field_sel == ARBITRATION,
                  "T4: still ARBITRATION after phase 1");

            check(arb_phase == 1'b1,
                  "T4: arb_phase indicates extended frame");

            check(bit_cnt == 6'd19,
                  "T4: bit_cnt loaded with 19");

            step_bits(19);

            check(field_sel == CONTROL,
                  "T4: phase 2 -> CONTROL");

            step_bits(6);

            check(field_sel == DATA,
                  "T4: extended CONTROL -> DATA");
        end
    endtask


    task test5_arbitration_loss;
        begin
            $display("\n--- TEST 5: arbitration loss -> RX_ONLY ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b0;
            ide = 1'b0;
            dlc = 4'd1;

            step_bits(2);

            step_bits(3);
            bit_error = 1'b1;

            @(negedge clk);
            check(bit_error_occured == 1'b1,
                  "T5: bit_error_occured asserted");

            bit_en = 1'b1;

            @(negedge clk);
            bit_en = 1'b0;

            check(field_sel == RX_ONLY,
                  "T5: ARBITRATION -> RX_ONLY");

            check(is_transmitting == 1'b0,
                  "T5: is_transmitting cleared");

            bit_error = 1'b0;
        end
    endtask


    task test6_error_event;
        begin
            $display("\n--- TEST 6: error_event -> ERROR_FLAG ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b0;
            ide = 1'b0;
            dlc = 4'd0;

            step_bits(2 + 13 + 5);

            check(field_sel == CRC,
                  "T6: reached CRC");

            step_bits(5);

            error_event = 1'b1;

            step_bits(1);

            check(field_sel == ERROR_FLAG,
                  "T6: error_event -> ERROR_FLAG");

            error_event = 1'b0;

            step_bits(6);

            check(field_sel == WAIT_RECESSIVE,
                  "T6: ERROR_FLAG -> WAIT_RECESSIVE");

            can_rx_sync = 1'b1;

            step_bits(1);

            check(field_sel == ERROR_DELIM,
                  "T6: WAIT_RECESSIVE -> ERROR_DELIM");

            step_bits(7);

            check(field_sel == INTERMISSION,
                  "T6: ERROR_DELIM -> INTERMISSION");
        end
    endtask


    task test7_error_preemption;
        begin
            $display("\n--- TEST 7: error_event preempts DATA ---");

            reset_dut;

            tx_request = 1'b1;
            rtr = 1'b0;
            ide = 1'b0;
            dlc = 4'd4;

            step_bits(2 + 13 + 5 + 10);

            check(field_sel == DATA,
                  "T7: currently in DATA");

            error_event = 1'b1;

            step_bits(1);

            check(field_sel == ERROR_FLAG,
                  "T7: error_event preempts DATA");

            error_event = 1'b0;
        end
    endtask


    task test8_pure_listener;
        begin
            $display("\n--- TEST 8: pure listener ---");

            reset_dut;

            tx_request = 1'b0;

            sof_detected = 1'b1;
            can_rx_sync = 1'b0;

            step_bits(1);

            check(field_sel == SOF,
                  "T8: listener entered SOF");

            sof_detected = 1'b0;

            step_bits(1);

            check(is_transmitting == 1'b0,
                  "T8: listener is_transmitting=0");

            check(field_sel == ARBITRATION,
                  "T8: listener entered ARBITRATION");

            rx_rtr = 1'b0;
            rx_dlc = 4'd1;
            rx_ide = 1'b0;

            rx_bit_valid = 1'b1;

            step_bits(13);

            check(field_sel == CONTROL,
                  "T8: listener ARBITRATION -> CONTROL");

            step_bits(5);

            check(field_sel == DATA,
                  "T8: listener CONTROL -> DATA");

            step_bits(8);

            check(field_sel == CRC,
                  "T8: listener DATA -> CRC");

            step_bits(15 + 1);

            check(field_sel == ACK,
                  "T8: listener reached ACK");

            check(ack_drive == 1'b1,
                  "T8: listener drives ACK");
        end
    endtask
task test9_basic_rx_frame;
    begin
        $display("\n--- TEST 9: basic RX frame ---");

        reset_dut;

        tx_request   = 1'b0;
        sof_detected = 1'b1;
        rx_bit_valid = 1'b1;

        rx_ide = 1'b0;
        rx_rtr = 1'b0;
        rx_dlc = 4'd1;

        can_rx_sync = 1'b0;

        step_bits(1);

        sof_detected = 1'b0;

        check(field_sel == SOF,
              "T9: RX entered SOF");

        step_bits(1);

        check(field_sel == ARBITRATION,
              "T9: RX entered ARBITRATION");

        check(is_transmitting == 1'b0,
              "T9: RX is_transmitting=0");

        step_bits(13);

        check(field_sel == CONTROL,
              "T9: RX ARBITRATION -> CONTROL");

        step_bits(5);

        check(field_sel == DATA,
              "T9: RX CONTROL -> DATA");

        step_bits(8);

        check(field_sel == CRC,
              "T9: RX DATA -> CRC");

        step_bits(15);

        check(field_sel == CRC_DELIM,
              "T9: RX CRC -> CRC_DELIM");

        step_bits(1);

        check(field_sel == ACK,
              "T9: RX CRC_DELIM -> ACK");

        check(ack_drive == 1'b1,
              "T9: RX drives dominant ACK");

        step_bits(1);

        check(field_sel == ACK_DELIM,
              "T9: RX ACK -> ACK_DELIM");

        check(ack_drive == 1'b0,
              "T9: ACK drive released");

        step_bits(1);

        check(field_sel == EOF,
              "T9: RX ACK_DELIM -> EOF");

        // First 6 EOF bits
        step_bits(6);

        // The 7th and final EOF bit is the bit_en cycle
        // that generates rx_done and moves to INTERMISSION.
        @(negedge clk);
        bit_en = 1'b1;

        #1;

        check(rx_done == 1'b0,
              "T9: rx_done before final EOF clock edge");

        @(posedge clk);

        #1;

        check(rx_done == 1'b1,
              "T9: rx_done asserted on last EOF bit");

        check(field_sel == INTERMISSION,
              "T9: RX EOF -> INTERMISSION");

        @(negedge clk);
        bit_en = 1'b0;

        // Complete the remaining 3 intermission bits.
        step_bits(3);

        check(field_sel == IDLE,
              "T9: RX INTERMISSION -> IDLE");

        check(is_transmitting == 1'b0,
              "T9: RX remains receiver");
    end
endtask

    initial begin
        $dumpfile("can_frame_controller.vcd");
        $dumpvars(0, tb_can_frame_controller);

        test1_standard_data_frame;
        test2_remote_frame;
        test3_dlc_zero;
        test4_extended_frame;
        test5_arbitration_loss;
        test6_error_event;
        test7_error_preemption;
        test8_pure_listener;
        test9_basic_rx_frame;

        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed",
                 pass_count, fail_count);
        $display("============================================\n");

        $finish;
    end


    initial begin
        #200000;

        $display("[TIMEOUT] Simulation did not finish");

        $finish;
    end

endmodule
