`timescale 1ns/1ps

module tb_can_controller;

    reg can_clk;
    reg rst_n_a;
    reg rst_n_b;

    wire can_rx_a;
    wire can_rx_b;

    wire can_tx_a;
    wire can_tx_b;
    wire can_bus;

    reg [31:0] brp_a;
    reg [7:0] prop_seg_a;
    reg [7:0] phase_seg1_a;
    reg [7:0] phase_seg2_a;
    reg [3:0] sjw_a;

    reg [31:0] brp_b;
    reg [7:0] prop_seg_b;
    reg [7:0] phase_seg1_b;
    reg [7:0] phase_seg2_b;
    reg [3:0] sjw_b;

    reg tx_valid_a;
    reg tx_ide_a;
    reg [28:0] tx_identifier_a;
    reg [3:0] tx_dlc_a;
    reg [63:0] tx_data_a;
    reg tx_rtr_a;

    reg tx_valid_b;
    reg tx_ide_b;
    reg [28:0] tx_identifier_b;
    reg [3:0] tx_dlc_b;
    reg [63:0] tx_data_b;
    reg tx_rtr_b;

    wire [28:0] rx_identifier_a;
    wire rx_rtr_a;
    wire rx_ide_a;
    wire [3:0] rx_dlc_a;
    wire [63:0] rx_data_a;
    wire rx_frame_valid_a;

    wire [28:0] rx_identifier_b;
    wire rx_rtr_b;
    wire rx_ide_b;
    wire [3:0] rx_dlc_b;
    wire [63:0] rx_data_b;
    wire rx_frame_valid_b;

    wire tx_done_a;
    wire rx_done_a;
    wire line_busy_a;
    wire [8:0] tec_a;
    wire [7:0] rec_a;
    wire [1:0] error_state_a;
    wire ack_received_a;
    wire arbitration_lost_a;
    wire ack_error_a;
    wire crc_error_a;
    wire stuff_error_a;
    wire form_error_a;
    wire bit_error_a;
    wire [3:0] can_state_a;
    wire [3:0] can_state_b;

    wire tx_done_b;
    wire rx_done_b;
    wire line_busy_b;
    wire [8:0] tec_b;
    wire [7:0] rec_b;
    wire [1:0] error_state_b;
    wire ack_received_b;
    wire arbitration_lost_b;
    wire ack_error_b;
    wire crc_error_b;
    wire stuff_error_b;
    wire form_error_b;
    wire bit_error_b;

    integer pass_count;
    integer fail_count;
    integer timeout;

    reg tx_done_seen_a;
    reg ack_seen_a;
    reg rx_seen_b;

    reg [28:0] rx_id_saved_b;
    reg [3:0] rx_dlc_saved_b;
    reg [63:0] rx_data_saved_b;
    reg rx_ide_saved_b;
    reg rx_rtr_saved_b;

    assign can_bus = can_tx_a & can_tx_b;

    assign can_rx_a = can_bus;
    assign can_rx_b = can_bus;

    /* ============================================================
     * NODE A
     * ============================================================ */

    can_controller #(
        .CAN_CLK_FREQ(10_000_000),
        .CAN_BIT_RATE(1_000_000)
    ) node_a (
        .clk(can_clk),
        .rst_n(rst_n_a),
        .can_rx(can_rx_a),
        .can_tx(can_tx_a),
        .brp(brp_a),
        .prop_seg(prop_seg_a),
        .phase_seg1(phase_seg1_a),
        .phase_seg2(phase_seg2_a),
        .sjw(sjw_a),
        .tx_valid(tx_valid_a),
        .tx_ide(tx_ide_a),
        .tx_identifier(tx_identifier_a),
        .tx_dlc(tx_dlc_a),
        .tx_data(tx_data_a),
        .tx_rtr(tx_rtr_a),
        .rx_identifier(rx_identifier_a),
        .rx_rtr(rx_rtr_a),
        .rx_ide(rx_ide_a),
        .rx_dlc(rx_dlc_a),
        .rx_data(rx_data_a),
        .rx_frame_valid(rx_frame_valid_a),
        .tx_done(tx_done_a),
        .rx_done(rx_done_a),
        .line_busy(line_busy_a),
        .tec(tec_a),
        .rec(rec_a),
        .error_state(error_state_a),
        .ack_received(ack_received_a),
        .arbitration_lost(arbitration_lost_a),
        .ack_error(ack_error_a),
        .crc_error(crc_error_a),
        .stuff_error(stuff_error_a),
        .form_error(form_error_a),
        .bit_error(bit_error_a),
        .can_state(can_state_a)
    );

    /* ============================================================
     * NODE B
     * ============================================================ */

    can_controller #(
        .CAN_CLK_FREQ(10_000_000),
        .CAN_BIT_RATE(1_000_000)
    ) node_b (
        .clk(can_clk),
        .rst_n(rst_n_b),
        .can_rx(can_rx_b),
        .can_tx(can_tx_b),
        .brp(brp_b),
        .prop_seg(prop_seg_b),
        .phase_seg1(phase_seg1_b),
        .phase_seg2(phase_seg2_b),
        .sjw(sjw_b),
        .tx_valid(tx_valid_b),
        .tx_ide(tx_ide_b),
        .tx_identifier(tx_identifier_b),
        .tx_dlc(tx_dlc_b),
        .tx_data(tx_data_b),
        .tx_rtr(tx_rtr_b),
        .rx_identifier(rx_identifier_b),
        .rx_rtr(rx_rtr_b),
        .rx_ide(rx_ide_b),
        .rx_dlc(rx_dlc_b),
        .rx_data(rx_data_b),
        .rx_frame_valid(rx_frame_valid_b),
        .tx_done(tx_done_b),
        .rx_done(rx_done_b),
        .line_busy(line_busy_b),
        .tec(tec_b),
        .rec(rec_b),
        .error_state(error_state_b),
        .ack_received(ack_received_b),
        .arbitration_lost(arbitration_lost_b),
        .ack_error(ack_error_b),
        .crc_error(crc_error_b),
        .stuff_error(stuff_error_b),
        .form_error(form_error_b),
        .bit_error(bit_error_b),
        .can_state(can_state_b)
    );

    /* ============================================================
     * CAN CLOCK
     * 10 MHz
     * ============================================================ */

    initial begin
        can_clk = 1'b0;
        forever #50 can_clk = ~can_clk;
    end

    /* ============================================================
     * EVENT CAPTURE
     * ============================================================ */

    always @(posedge can_clk) begin
        if(rst_n_a) begin
            if(tx_done_a) begin
                tx_done_seen_a <= 1'b1;
                $display("NODE A TX_DONE at %0t", $time);
            end

            if(ack_received_a) begin
                ack_seen_a <= 1'b1;
                $display("NODE A ACK_RECEIVED at %0t", $time);
            end
        end
    end

    always @(posedge can_clk) begin
        if(rst_n_b) begin
            if(rx_frame_valid_b || rx_done_b) begin
                rx_seen_b <= 1'b1;
                rx_id_saved_b <= rx_identifier_b;
                rx_dlc_saved_b <= rx_dlc_b;
                rx_data_saved_b <= rx_data_b;
                rx_ide_saved_b <= rx_ide_b;
                rx_rtr_saved_b <= rx_rtr_b;
                $display("NODE B RX_FRAME at %0t ID=%h DLC=%d DATA=%h", $time, rx_identifier_b, rx_dlc_b, rx_data_b);
            end
        end
    end

    /* ============================================================
     * MAIN TEST
     * ============================================================ */

    initial begin

        pass_count = 0;
        fail_count = 0;
        timeout = 0;

        tx_done_seen_a = 1'b0;
        ack_seen_a = 1'b0;
        rx_seen_b = 1'b0;

        rx_id_saved_b = 29'd0;
        rx_dlc_saved_b = 4'd0;
        rx_data_saved_b = 64'd0;
        rx_ide_saved_b = 1'b0;
        rx_rtr_saved_b = 1'b0;

        rst_n_a = 1'b0;
        rst_n_b = 1'b0;

        brp_a = 32'd1;
        prop_seg_a = 8'd5;
        phase_seg1_a = 8'd2;
        phase_seg2_a = 8'd2;
        sjw_a = 4'd1;

        brp_b = 32'd1;
        prop_seg_b = 8'd5;
        phase_seg1_b = 8'd2;
        phase_seg2_b = 8'd2;
        sjw_b = 4'd1;

        tx_valid_a = 1'b0;
        tx_ide_a = 1'b0;
        tx_identifier_a = 29'd0;
        tx_dlc_a = 4'd0;
        tx_data_a = 64'd0;
        tx_rtr_a = 1'b0;

        tx_valid_b = 1'b0;
        tx_ide_b = 1'b0;
        tx_identifier_b = 29'd0;
        tx_dlc_b = 4'd0;
        tx_data_b = 64'd0;
        tx_rtr_b = 1'b0;

        /* ========================================================
         * RESET
         * ======================================================== */

        #500;

        rst_n_a = 1'b1;
        rst_n_b = 1'b1;

        repeat(20) @(posedge can_clk);

        $display("==============================================");
        $display("DIRECT CAN CORE 2-NODE TEST");
        $display("==============================================");
        $display("CAN_CLK = 10 MHz");
        $display("BRP     = 1");
        $display("SYNC    = 1 TQ");
        $display("PROP    = 5 TQ");
        $display("PHASE1  = 2 TQ");
        $display("PHASE2  = 2 TQ");
        $display("TOTAL   = 10 TQ");
        $display("BITRATE = 1 Mbps");
        $display("ID      = 00000155");
        $display("DLC     = 4");
        $display("DATA    = A5A5A5A5");
        $display("==============================================");

        /* ========================================================
         * LOAD NODE A FRAME
         * ======================================================== */

        @(posedge can_clk);

        tx_identifier_a <= 29'h0000155;
        tx_ide_a <= 1'b0;
        tx_rtr_a <= 1'b0;
        tx_dlc_a <= 4'd4;
        tx_data_a <= 64'h00000000A5A5A5A5;

        @(posedge can_clk);

        /* ========================================================
         * ISSUE TX REQUEST
         * ======================================================== */

        tx_valid_a <= 1'b1;

        @(posedge can_clk);

        tx_valid_a <= 1'b0;

        $display("TX REQUEST ISSUED at %0t", $time);

        /* ========================================================
         * WAIT FOR TRANSMISSION TO START
         * ======================================================== */

        timeout = 0;

        while((timeout < 1000) && !line_busy_a) begin
            @(posedge can_clk);
            timeout = timeout + 1;
        end

        if(line_busy_a) begin
            pass_count = pass_count + 1;
            $display("PASS: Node A transmission started");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Node A transmission never started");
        end

        /* ========================================================
         * WAIT FOR COMPLETE FRAME
         * ======================================================== */

        timeout = 0;

        while((timeout < 10000) && !tx_done_seen_a && !rx_seen_b) begin
            @(posedge can_clk);
            timeout = timeout + 1;
        end

        repeat(100) @(posedge can_clk);

        /* ========================================================
         * NODE A STATUS
         * ======================================================== */

        $display("==============================================");
        $display("NODE A FINAL STATUS");
        $display("==============================================");
        $display("TX_DONE          = %b", tx_done_seen_a);
        $display("ACK_RECEIVED     = %b", ack_seen_a);
        $display("LINE_BUSY        = %b", line_busy_a);
        $display("ARBITRATION_LOST = %b", arbitration_lost_a);
        $display("ACK_ERROR        = %b", ack_error_a);
        $display("BIT_ERROR        = %b", bit_error_a);
        $display("STUFF_ERROR      = %b", stuff_error_a);
        $display("CRC_ERROR        = %b", crc_error_a);
        $display("FORM_ERROR       = %b", form_error_a);
        $display("TEC              = %d", tec_a);
        $display("REC              = %d", rec_a);
        $display("ERROR_STATE      = %d", error_state_a);
        $display("CAN_STATE        = %d", can_state_a);

        if(tx_done_seen_a) begin
            pass_count = pass_count + 1;
            $display("PASS: TX_DONE occurred");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: TX_DONE did not occur");
        end

        if(ack_seen_a) begin
            pass_count = pass_count + 1;
            $display("PASS: ACK_RECEIVED occurred");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: ACK_RECEIVED did not occur");
        end

        if(!arbitration_lost_a) begin
            pass_count = pass_count + 1;
            $display("PASS: No arbitration loss");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Arbitration loss detected");
        end

        if(!ack_error_a && !bit_error_a && !stuff_error_a && !crc_error_a && !form_error_a) begin
            pass_count = pass_count + 1;
            $display("PASS: No CAN errors");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: CAN error detected");
        end

        /* ========================================================
         * NODE B STATUS
         * ======================================================== */

        $display("==============================================");
        $display("NODE B FINAL RX STATUS");
        $display("==============================================");
        $display("RX_FRAME_VALID   = %b", rx_seen_b);
        $display("RX_ID            = %h", rx_id_saved_b);
        $display("RX_IDE           = %b", rx_ide_saved_b);
        $display("RX_RTR           = %b", rx_rtr_saved_b);
        $display("RX_DLC           = %d", rx_dlc_saved_b);
        $display("RX_DATA          = %h", rx_data_saved_b);
        $display("RX_DONE          = %b", rx_done_b);
        $display("CRC_ERROR        = %b", crc_error_b);
        $display("STUFF_ERROR      = %b", stuff_error_b);
        $display("BIT_ERROR        = %b", bit_error_b);
        $display("FORM_ERROR       = %b", form_error_b);
        $display("ACK_ERROR        = %b", ack_error_b);

        if(rx_seen_b) begin
            pass_count = pass_count + 1;
            $display("PASS: Node B received a frame");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Node B did not receive a frame");
        end

        if(rx_id_saved_b == 29'h0000155) begin
            pass_count = pass_count + 1;
            $display("PASS: RX ID correct");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RX ID incorrect");
        end

        if(rx_dlc_saved_b == 4'd4) begin
            pass_count = pass_count + 1;
            $display("PASS: RX DLC correct");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RX DLC incorrect");
        end

        if(rx_data_saved_b == 64'h00000000A5A5A5A5) begin
            pass_count = pass_count + 1;
            $display("PASS: RX DATA correct");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RX DATA incorrect");
        end

        if(rx_ide_saved_b == 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: RX IDE correct");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RX IDE incorrect");
        end

        if(rx_rtr_saved_b == 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: RX RTR correct");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RX RTR incorrect");
        end

        /* ========================================================
         * FINAL RESULTS
         * ======================================================== */

        $display("==============================================");
        $display("FINAL RESULTS");
        $display("==============================================");
        $display("PASS COUNT = %d", pass_count);
        $display("FAIL COUNT = %d", fail_count);

        if(fail_count == 0)
            $display("TEST RESULT: PASS");
        else
            $display("TEST RESULT: FAIL");

        $display("==============================================");

        $finish;

    end

endmodule
