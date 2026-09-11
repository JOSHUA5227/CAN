`timescale 1ns/1ps

module tb_can_controller_arbitration;

    parameter CAN_CLK_FREQ = 10_000_000;
    parameter CAN_BIT_RATE = 1_000_000;

    /*
     * ================================================================
     * CLOCK AND RESET
     * ================================================================
     */

    reg clk;
    reg rst_n;


    /*
     * ================================================================
     * CAN BUS
     * ================================================================
     *
     * CAN bus is wired AND:
     *
     * TX = 0 -> dominant
     * TX = 1 -> recessive
     *
     * Therefore:
     *
     * bus = TX_A & TX_B
     *
     * ================================================================
     */

    wire can_bus;
    wire can_tx_a;
    wire can_tx_b;

    assign can_bus = can_tx_a & can_tx_b;


    /*
     * ================================================================
     * COMMON BIT TIMING
     * ================================================================
     *
     * 10 MHz CAN clock
     * 1 MHz CAN bit rate
     *
     * BRP       = 1
     * PROP_SEG  = 5
     * PHASE_SEG1 = 2
     * PHASE_SEG2 = 2
     * SJW       = 1
     *
     * Total = 10 TQ per CAN bit.
     * ================================================================
     */

    reg [31:0] brp;
    reg [7:0]  prop_seg;
    reg [7:0]  phase_seg1;
    reg [7:0]  phase_seg2;
    reg [3:0]  sjw;


    /*
     * ================================================================
     * NODE A TRANSMIT
     *
     * ID = 0x200
     *
     * Expected:
     *
     * NODE A loses arbitration.
     * ================================================================
     */

    reg        tx_valid_a;
    reg        tx_ide_a;
    reg [28:0] tx_identifier_a;
    reg [3:0]  tx_dlc_a;
    reg [63:0] tx_data_a;
    reg        tx_rtr_a;


    /*
     * ================================================================
     * NODE B TRANSMIT
     *
     * ID = 0x100
     *
     * Expected:
     *
     * NODE B wins arbitration.
     * ================================================================
     */

    reg        tx_valid_b;
    reg        tx_ide_b;
    reg [28:0] tx_identifier_b;
    reg [3:0]  tx_dlc_b;
    reg [63:0] tx_data_b;
    reg        tx_rtr_b;


    /*
     * ================================================================
     * NODE A RECEIVE / STATUS
     * ================================================================
     */

    wire [28:0] rx_identifier_a;
    wire        rx_rtr_a;
    wire        rx_ide_a;
    wire [3:0]  rx_dlc_a;
    wire [63:0] rx_data_a;
    wire        rx_frame_valid_a;

    wire        tx_done_a;
    wire        rx_done_a;
    wire        line_busy_a;

    wire [8:0]  tec_a;
    wire [7:0]  rec_a;
    wire [1:0]  error_state_a;

    wire        ack_received_a;

    wire        arbitration_lost_a;
    wire        ack_error_a;
    wire        crc_error_a;
    wire        stuff_error_a;
    wire        form_error_a;
    wire        bit_error_a;

    wire [3:0]  can_state_a;


    /*
     * ================================================================
     * NODE B RECEIVE / STATUS
     * ================================================================
     */

    wire [28:0] rx_identifier_b;
    wire        rx_rtr_b;
    wire        rx_ide_b;
    wire [3:0]  rx_dlc_b;
    wire [63:0] rx_data_b;
    wire        rx_frame_valid_b;

    wire        tx_done_b;
    wire        rx_done_b;
    wire        line_busy_b;

    wire [8:0]  tec_b;
    wire [7:0]  rec_b;
    wire [1:0]  error_state_b;

    wire        ack_received_b;

    wire        arbitration_lost_b;
    wire        ack_error_b;
    wire        crc_error_b;
    wire        stuff_error_b;
    wire        form_error_b;
    wire        bit_error_b;

    wire [3:0]  can_state_b;


    /*
     * ================================================================
     * NODE A DUT
     * ================================================================
     */

    can_controller #(
        .CAN_CLK_FREQ(CAN_CLK_FREQ),
        .CAN_BIT_RATE(CAN_BIT_RATE)
    ) dut_a (
        .clk(clk),
        .rst_n(rst_n),

        .can_rx(can_bus),
        .can_tx(can_tx_a),

        .brp(brp),
        .prop_seg(prop_seg),
        .phase_seg1(phase_seg1),
        .phase_seg2(phase_seg2),
        .sjw(sjw),

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


    /*
     * ================================================================
     * NODE B DUT
     * ================================================================
     */

    can_controller #(
        .CAN_CLK_FREQ(CAN_CLK_FREQ),
        .CAN_BIT_RATE(CAN_BIT_RATE)
    ) dut_b (
        .clk(clk),
        .rst_n(rst_n),

        .can_rx(can_bus),
        .can_tx(can_tx_b),

        .brp(brp),
        .prop_seg(prop_seg),
        .phase_seg1(phase_seg1),
        .phase_seg2(phase_seg2),
        .sjw(sjw),

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


    /*
     * ================================================================
     * CLOCK GENERATION
     * ================================================================
     *
     * 100 ns clock period = 10 MHz.
     * ================================================================
     */

    initial
    begin
        clk = 1'b0;
    end

    always #50 clk = ~clk;


    /*
     * ================================================================
     * TEST VARIABLES
     * ================================================================
     */

    integer pass_count;
    integer fail_count;
    integer timeout_count;

    reg arbitration_seen;
    reg winner_done_seen;
    reg loser_rx_seen;


    /*
     * ================================================================
     * MAIN TEST
     * ================================================================
     */

    initial
    begin

        pass_count = 0;
        fail_count = 0;
        timeout_count = 0;

        arbitration_seen = 1'b0;
        winner_done_seen = 1'b0;
        loser_rx_seen = 1'b0;


        /*
         * ------------------------------------------------------------
         * BIT TIMING
         * ------------------------------------------------------------
         */

        brp = 32'd1;
        prop_seg = 8'd5;
        phase_seg1 = 8'd2;
        phase_seg2 = 8'd2;
        sjw = 4'd1;


        /*
         * ------------------------------------------------------------
         * NODE A MESSAGE
         * ------------------------------------------------------------
         *
         * ID = 0x200
         * DLC = 1
         * DATA = A5
         *
         * This node must lose to 0x100.
         */

        tx_valid_a = 1'b0;
        tx_ide_a = 1'b0;
        tx_identifier_a = 29'h00000200;
        tx_dlc_a = 4'd1;
        tx_data_a = 64'h00000000000000A5;
        tx_rtr_a = 1'b0;


        /*
         * ------------------------------------------------------------
         * NODE B MESSAGE
         * ------------------------------------------------------------
         *
         * ID = 0x100
         * DLC = 1
         * DATA = 5A
         *
         * This node must win arbitration.
         */

        tx_valid_b = 1'b0;
        tx_ide_b = 1'b0;
        tx_identifier_b = 29'h00000100;
        tx_dlc_b = 4'd1;
        tx_data_b = 64'h000000000000005A;
        tx_rtr_b = 1'b0;


        /*
         * ------------------------------------------------------------
         * RESET
         * ------------------------------------------------------------
         */

        rst_n = 1'b0;

        repeat(20)
            @(posedge clk);

        rst_n = 1'b1;

        repeat(20)
            @(posedge clk);


        $display("============================================================");
        $display("CAN 2-NODE ARBITRATION TEST");
        $display("============================================================");
        $display("NODE A ID  = 0x200");
        $display("NODE B ID  = 0x100");
        $display("EXPECTED   = NODE B WINS");
        $display("EXPECTED   = NODE A LOSES");
        $display("BUS        = TX_A & TX_B");
        $display("============================================================");


        /*
         * ------------------------------------------------------------
         * START BOTH TRANSMISSIONS ON THE SAME CLOCK EDGE
         * ------------------------------------------------------------
         */

        @(posedge clk);

        tx_valid_a <= 1'b1;
        tx_valid_b <= 1'b1;

        @(posedge clk);

        tx_valid_a <= 1'b0;
        tx_valid_b <= 1'b0;


        /*
         * ------------------------------------------------------------
         * WAIT FOR ARBITRATION LOSS AND WINNER COMPLETION
         * ------------------------------------------------------------
         */

        while((!arbitration_seen || !winner_done_seen) && (timeout_count < 100000))
        begin

            @(posedge clk);

            timeout_count = timeout_count + 1;


            /*
             * NODE A MUST LOSE
             */

            if(arbitration_lost_a && !arbitration_seen)
            begin
                arbitration_seen = 1'b1;
                pass_count = pass_count + 1;

                $display("PASS: NODE A detected arbitration loss");
            end


            /*
             * NODE B MUST COMPLETE
             */

            if(tx_done_b && !winner_done_seen)
            begin
                winner_done_seen = 1'b1;
                pass_count = pass_count + 1;

                $display("PASS: NODE B completed transmission");
            end


            /*
             * NODE A SHOULD EVENTUALLY RECEIVE NODE B'S FRAME
             */

            if(rx_frame_valid_a && !loser_rx_seen)
            begin
                loser_rx_seen = 1'b1;

                $display("INFO: NODE A received a frame after losing arbitration");
            end

        end


        /*
         * ============================================================
         * FINAL NODE A STATUS
         * ============================================================
         */

        $display("============================================================");
        $display("FINAL NODE A STATUS");
        $display("TX_DONE=%b", tx_done_a);
        $display("RX_FRAME_VALID=%b", rx_frame_valid_a);
        $display("ARBITRATION_LOST=%b", arbitration_lost_a);
        $display("ACK_RECEIVED=%b", ack_received_a);
        $display("LINE_BUSY=%b", line_busy_a);
        $display("TEC=%0d", tec_a);
        $display("REC=%0d", rec_a);
        $display("ERROR_STATE=%0d", error_state_a);
        $display("ACK_ERROR=%b", ack_error_a);
        $display("CRC_ERROR=%b", crc_error_a);
        $display("STUFF_ERROR=%b", stuff_error_a);
        $display("FORM_ERROR=%b", form_error_a);
        $display("BIT_ERROR=%b", bit_error_a);
        $display("RX_ID=%h", rx_identifier_a);
        $display("RX_IDE=%b", rx_ide_a);
        $display("RX_RTR=%b", rx_rtr_a);
        $display("RX_DLC=%0d", rx_dlc_a);
        $display("RX_DATA=%h", rx_data_a);


        /*
         * ============================================================
         * FINAL NODE B STATUS
         * ============================================================
         */

        $display("============================================================");
        $display("FINAL NODE B STATUS");
        $display("TX_DONE=%b", tx_done_b);
        $display("RX_FRAME_VALID=%b", rx_frame_valid_b);
        $display("ARBITRATION_LOST=%b", arbitration_lost_b);
        $display("ACK_RECEIVED=%b", ack_received_b);
        $display("LINE_BUSY=%b", line_busy_b);
        $display("TEC=%0d", tec_b);
        $display("REC=%0d", rec_b);
        $display("ERROR_STATE=%0d", error_state_b);
        $display("ACK_ERROR=%b", ack_error_b);
        $display("CRC_ERROR=%b", crc_error_b);
        $display("STUFF_ERROR=%b", stuff_error_b);
        $display("FORM_ERROR=%b", form_error_b);
        $display("BIT_ERROR=%b", bit_error_b);
        $display("RX_ID=%h", rx_identifier_b);
        $display("RX_IDE=%b", rx_ide_b);
        $display("RX_RTR=%b", rx_rtr_b);
        $display("RX_DLC=%0d", rx_dlc_b);
        $display("RX_DATA=%h", rx_data_b);


        /*
         * ============================================================
         * CHECK 1
         * NODE A LOST ARBITRATION
         * ============================================================
         */

        if(arbitration_lost_a)
        begin
            $display("PASS: NODE A lost arbitration");
        end
        else
        begin
            $display("FAIL: NODE A did not lose arbitration");
            fail_count = fail_count + 1;
        end


        /*
         * ============================================================
         * CHECK 2
         * NODE B DID NOT LOSE
         * ============================================================
         */

        if(!arbitration_lost_b)
        begin
            $display("PASS: NODE B won arbitration");
        end
        else
        begin
            $display("FAIL: NODE B incorrectly lost arbitration");
            fail_count = fail_count + 1;
        end


        /*
         * ============================================================
         * CHECK 3
         * NODE B COMPLETED TRANSMISSION
         * ============================================================
         */

        if(tx_done_b)
        begin
            $display("PASS: NODE B TX_DONE asserted");
        end
        else
        begin
            $display("FAIL: NODE B did not complete transmission");
            fail_count = fail_count + 1;
        end


        /*
         * ============================================================
         * CHECK 4
         * ARBITRATION LOSS IS NOT A CAN ERROR
         * ============================================================
         */

        if(!ack_error_a &&
           !crc_error_a &&
           !stuff_error_a &&
           !form_error_a &&
           !bit_error_a)
        begin
            $display("PASS: NODE A generated no CAN protocol error");
        end
        else
        begin
            $display("FAIL: NODE A generated a CAN error during arbitration");
            fail_count = fail_count + 1;
        end


        /*
         * ============================================================
         * CHECK 5
         * NODE A RECEIVED WINNING FRAME
         * ============================================================
         */

        if(rx_frame_valid_a)
        begin

            if(rx_identifier_a == 29'h00000100)
            begin
                $display("PASS: NODE A received ID 0x100");
            end
            else
            begin
                $display("FAIL: NODE A received incorrect ID");
                fail_count = fail_count + 1;
            end


            if(rx_dlc_a == 4'd1)
            begin
                $display("PASS: NODE A received correct DLC");
            end
            else
            begin
                $display("FAIL: NODE A received incorrect DLC");
                fail_count = fail_count + 1;
            end


            if(rx_data_a == 64'h000000000000005A)
            begin
                $display("PASS: NODE A received correct data");
            end
            else
            begin
                $display("FAIL: NODE A received incorrect data");
                fail_count = fail_count + 1;
            end


            if(rx_ide_a == 1'b0)
            begin
                $display("PASS: NODE A received standard frame");
            end
            else
            begin
                $display("FAIL: NODE A received incorrect IDE");
                fail_count = fail_count + 1;
            end


            if(rx_rtr_a == 1'b0)
            begin
                $display("PASS: NODE A received data frame");
            end
            else
            begin
                $display("FAIL: NODE A received incorrect RTR");
                fail_count = fail_count + 1;
            end

        end
        else
        begin
            $display("FAIL: NODE A did not receive winning frame");
            fail_count = fail_count + 1;
        end


        /*
         * ============================================================
         * CHECK 6
         * NODE B MUST NOT REPORT ARBITRATION LOSS
         * ============================================================
         */

        if(!arbitration_lost_b)
        begin
            $display("PASS: NODE B arbitration_lost remains low");
        end
        else
        begin
            $display("FAIL: NODE B arbitration_lost asserted");
            fail_count = fail_count + 1;
        end


        /*
         * ============================================================
         * CHECK 7
         * TIMEOUT
         * ============================================================
         */

        if(timeout_count >= 100000)
        begin
            $display("FAIL: Test timed out");
            fail_count = fail_count + 1;
        end
        else
        begin
            $display("PASS: Test completed before timeout");
        end


        /*
         * ============================================================
         * FINAL RESULT
         * ============================================================
         */

        $display("============================================================");
        $display("FINAL RESULTS");
        $display("PASS COUNT=%0d", pass_count);
        $display("FAIL COUNT=%0d", fail_count);

        if(fail_count == 0)
        begin
            $display("ARBITRATION TEST PASS");
        end
        else
        begin
            $display("ARBITRATION TEST FAIL");
        end

        $display("============================================================");

        #1000;

        $finish;

    end


    /*
     * ================================================================
     * STATE MONITOR
     *
     * This uses hierarchical access only for DEBUGGING.
     * It does not change the DUT interface.
     *
     * CAN states:
     *
     * 0  IDLE
     * 1  SOF
     * 2  ARBITRATION
     * 3  CONTROL
     * 4  DATA
     * 5  CRC
     * 6  CRC_DELIM
     * 7  ACK
     * 8  ACK_DELIM
     * 9  EOF
     * 10 INTERMISSION
     * 11 ERROR_FLAG
     * 12 WAIT_RECESSIVE
     * 13 ERROR_DELIM
     * 14 RX_ONLY
     * ================================================================
     */

    reg [3:0] last_state_a;
    reg [3:0] last_state_b;

    initial
    begin
        last_state_a = 4'hF;
        last_state_b = 4'hF;
    end


    always @(posedge clk)
    begin

        if(rst_n)
        begin

            if(can_state_a != last_state_a)
            begin
                $display("NODE A STATE %0d -> %0d TX=%b BUS=%b ARB_LOST=%b BUSY=%b", last_state_a, can_state_a, can_tx_a, can_bus, arbitration_lost_a, line_busy_a);
                last_state_a = can_state_a;
            end


            if(can_state_b != last_state_b)
            begin
                $display("NODE B STATE %0d -> %0d TX=%b BUS=%b ARB_LOST=%b BUSY=%b", last_state_b, can_state_b, can_tx_b, can_bus, arbitration_lost_b, line_busy_b);
                last_state_b = can_state_b;
            end

        end

    end


endmodule
