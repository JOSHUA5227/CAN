`timescale 1ns/1ps

module can_controller_self_checking_tb;

    localparam CAN_CLK_FREQ = 100_000_000;
    localparam CAN_BIT_RATE = 1_000_000;

    reg clk;
    reg rst_n;

    wand can_bus;

    reg [31:0] brp_a;
    reg [7:0]  prop_seg_a;
    reg [7:0]  phase_seg1_a;
    reg [7:0]  phase_seg2_a;
    reg [3:0]  sjw_a;

    reg [31:0] brp_b;
    reg [7:0]  prop_seg_b;
    reg [7:0]  phase_seg1_b;
    reg [7:0]  phase_seg2_b;
    reg [3:0]  sjw_b;

    reg        tx_valid_a;
    reg        tx_ide_a;
    reg [28:0] tx_identifier_a;
    reg [3:0]  tx_dlc_a;
    reg [63:0] tx_data_a;
    reg        tx_rtr_a;

    reg        tx_valid_b;
    reg        tx_ide_b;
    reg [28:0] tx_identifier_b;
    reg [3:0]  tx_dlc_b;
    reg [63:0] tx_data_b;
    reg        tx_rtr_b;

    wire can_tx_a;
    wire can_tx_b;

    wire [28:0] rx_identifier_a;
    wire        rx_ide_a;
    wire        rx_rtr_a;
    wire [3:0]  rx_dlc_a;
    wire [63:0] rx_data_a;
    wire        rx_frame_valid_a;

    wire [28:0] rx_identifier_b;
    wire        rx_ide_b;
    wire        rx_rtr_b;
    wire [3:0]  rx_dlc_b;
    wire [63:0] rx_data_b;
    wire        rx_frame_valid_b;

    wire tx_done_a;
    wire tx_done_b;
    wire rx_done_a;
    wire rx_done_b;

    wire line_busy_a;
    wire line_busy_b;

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
    wire bit_en_a;
    wire sample_en_a;
    wire can_rx_sync_a;
    wire can_rx_sample_a;

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

    wire [3:0] can_state_b;
    wire bit_en_b;
    wire sample_en_b;
    wire can_rx_sync_b;
    wire can_rx_sample_b;

    integer pass_count;
    integer fail_count;

    integer tx_done_count_a;
    integer tx_done_count_b;

    integer rx_done_count_a;
    integer rx_done_count_b;

    integer rx_valid_count_a;
    integer rx_valid_count_b;

    integer ack_count_a;
    integer ack_count_b;

    integer arbitration_lost_count_a;
    integer arbitration_lost_count_b;

    integer error_count_a;
    integer error_count_b;

    integer test_number;

    assign can_bus = can_tx_a;
    assign can_bus = can_tx_b;

    can_controller #(
        .CAN_CLK_FREQ(CAN_CLK_FREQ),
        .CAN_BIT_RATE(CAN_BIT_RATE)
    ) dut_a (
        .clk(clk),
        .rst_n(rst_n),
        .can_rx(can_bus),
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
        .rx_ide(rx_ide_a),
        .rx_rtr(rx_rtr_a),
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

    can_controller #(
        .CAN_CLK_FREQ(CAN_CLK_FREQ),
        .CAN_BIT_RATE(CAN_BIT_RATE)
    ) dut_b (
        .clk(clk),
        .rst_n(rst_n),
        .can_rx(can_bus),
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
        .rx_ide(rx_ide_b),
        .rx_rtr(rx_rtr_b),
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

    always #5 clk = ~clk;

    always @(posedge clk)
    begin
        if (!rst_n)
        begin
            tx_done_count_a          = 0;
            tx_done_count_b          = 0;
            rx_done_count_a          = 0;
            rx_done_count_b          = 0;
            rx_valid_count_a         = 0;
            rx_valid_count_b         = 0;
            ack_count_a              = 0;
            ack_count_b              = 0;
            arbitration_lost_count_a = 0;
            arbitration_lost_count_b = 0;
            error_count_a            = 0;
            error_count_b            = 0;
        end
        else
        begin
            if (tx_done_a)
                tx_done_count_a = tx_done_count_a + 1;

            if (tx_done_b)
                tx_done_count_b = tx_done_count_b + 1;

            if (rx_done_a)
                rx_done_count_a = rx_done_count_a + 1;

            if (rx_done_b)
                rx_done_count_b = rx_done_count_b + 1;

            if (rx_frame_valid_a)
                rx_valid_count_a = rx_valid_count_a + 1;

            if (rx_frame_valid_b)
                rx_valid_count_b = rx_valid_count_b + 1;

            if (ack_received_a)
                ack_count_a = ack_count_a + 1;

            if (ack_received_b)
                ack_count_b = ack_count_b + 1;

            if (arbitration_lost_a)
                arbitration_lost_count_a =
                    arbitration_lost_count_a + 1;

            if (arbitration_lost_b)
                arbitration_lost_count_b =
                    arbitration_lost_count_b + 1;

            if (ack_error_a ||
                crc_error_a ||
                stuff_error_a ||
                form_error_a ||
                bit_error_a)
                error_count_a = error_count_a + 1;

            if (ack_error_b ||
                crc_error_b ||
                stuff_error_b ||
                form_error_b ||
                bit_error_b)
                error_count_b = error_count_b + 1;
        end
    end

    task configure;
        begin
            brp_a        = 32'd1;
            prop_seg_a   = 8'd5;
            phase_seg1_a = 8'd2;
            phase_seg2_a = 8'd2;
            sjw_a        = 4'd1;

            brp_b        = 32'd1;
            prop_seg_b   = 8'd5;
            phase_seg1_b = 8'd2;
            phase_seg2_b = 8'd2;
            sjw_b        = 4'd1;
        end
    endtask

    task clear_tx;
        begin
            tx_valid_a      = 1'b0;
            tx_ide_a        = 1'b0;
            tx_identifier_a = 29'd0;
            tx_dlc_a        = 4'd0;
            tx_data_a       = 64'd0;
            tx_rtr_a        = 1'b0;

            tx_valid_b      = 1'b0;
            tx_ide_b        = 1'b0;
            tx_identifier_b = 29'd0;
            tx_dlc_b        = 4'd0;
            tx_data_b       = 64'd0;
            tx_rtr_b        = 1'b0;
        end
    endtask

    task reset_dut;
        begin
            rst_n = 1'b0;
            clear_tx;

            repeat (10) @(posedge clk);

            rst_n = 1'b1;

            repeat (10) @(posedge clk);
        end
    endtask

    task start_a;
        input        ide_value;
        input [28:0] identifier_value;
        input [3:0]  dlc_value;
        input [63:0] data_value;
        input        rtr_value;

        begin
            @(negedge clk);

            tx_ide_a        = ide_value;
            tx_identifier_a = identifier_value;
            tx_dlc_a        = dlc_value;
            tx_data_a       = data_value;
            tx_rtr_a        = rtr_value;
            tx_valid_a      = 1'b1;

            @(negedge clk);

            tx_valid_a = 1'b0;
        end
    endtask

    task start_b;
        input        ide_value;
        input [28:0] identifier_value;
        input [3:0]  dlc_value;
        input [63:0] data_value;
        input        rtr_value;

        begin
            @(negedge clk);

            tx_ide_b        = ide_value;
            tx_identifier_b = identifier_value;
            tx_dlc_b        = dlc_value;
            tx_data_b       = data_value;
            tx_rtr_b        = rtr_value;
            tx_valid_b      = 1'b1;

            @(negedge clk);

            tx_valid_b = 1'b0;
        end
    endtask

    task start_both;
        input        ide_value_a;
        input [28:0] identifier_value_a;
        input [3:0]  dlc_value_a;
        input [63:0] data_value_a;
        input        rtr_value_a;

        input        ide_value_b;
        input [28:0] identifier_value_b;
        input [3:0]  dlc_value_b;
        input [63:0] data_value_b;
        input        rtr_value_b;

        begin
            @(negedge clk);

            tx_ide_a        = ide_value_a;
            tx_identifier_a = identifier_value_a;
            tx_dlc_a        = dlc_value_a;
            tx_data_a       = data_value_a;
            tx_rtr_a        = rtr_value_a;
            tx_valid_a      = 1'b1;

            tx_ide_b        = ide_value_b;
            tx_identifier_b = identifier_value_b;
            tx_dlc_b        = dlc_value_b;
            tx_data_b       = data_value_b;
            tx_rtr_b        = rtr_value_b;
            tx_valid_b      = 1'b1;

            @(negedge clk);

            tx_valid_a = 1'b0;
            tx_valid_b = 1'b0;
        end
    endtask

    task check64;
        input [127:0] name;
        input [63:0] expected;
        input [63:0] actual;

        begin
            if (actual === expected)
            begin
                pass_count = pass_count + 1;
                $display("PASS: %s", name);
            end
            else
            begin
                fail_count = fail_count + 1;
                $display("FAIL: %s", name);
                $display("      Expected = %h", expected);
                $display("      Actual   = %h", actual);
            end
        end
    endtask

    task checkbit;
        input [127:0] name;
        input expected;
        input actual;

        begin
            if (actual === expected)
            begin
                pass_count = pass_count + 1;
                $display("PASS: %s", name);
            end
            else
            begin
                fail_count = fail_count + 1;
                $display("FAIL: %s", name);
                $display("      Expected = %b", expected);
                $display("      Actual   = %b", actual);
            end
        end
    endtask

    task check_event;
        input [127:0] name;
        input integer expected;
        input integer actual;

        begin
            if (actual == expected)
            begin
                pass_count = pass_count + 1;
                $display("PASS: %s", name);
            end
            else
            begin
                fail_count = fail_count + 1;
                $display("FAIL: %s", name);
                $display("      Expected = %0d", expected);
                $display("      Actual   = %0d", actual);
            end
        end
    endtask

    task print_test;
        input [127:0] name;

        begin
            test_number = test_number + 1;

            $display("");
            $display("------------------------------------------------------------");
            $display("TEST %0d: %s", test_number, name);
            $display("------------------------------------------------------------");
        end
    endtask

    task test_standard_basic;
        integer tx_start;
        integer rx_start;

        begin
            print_test("STANDARD BASIC DATA FRAME");

            reset_dut;

            tx_start = tx_done_count_a;
            rx_start = rx_valid_count_b;

            start_a(
                1'b0,
                29'h00000123,
                4'd8,
                64'hA1B2C3D455667788,
                1'b0
            );

            #500000;

            check64(
                "Standard RX ID",
                64'h0000000000000123,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Standard RX IDE",
                1'b0,
                rx_ide_b
            );

            checkbit(
                "Standard RX RTR",
                1'b0,
                rx_rtr_b
            );

            check64(
                "Standard RX DLC",
                64'd8,
                {60'd0,rx_dlc_b}
            );

            check64(
                "Standard RX DATA",
                64'hA1B2C3D455667788,
                rx_data_b
            );

            check_event(
                "Standard RX frame event",
                rx_start + 1,
                rx_valid_count_b
            );

            check_event(
                "Standard TX done",
                tx_start + 1,
                tx_done_count_a
            );
        end
    endtask

    task test_extended_basic;
        integer tx_start;
        integer rx_start;

        begin
            print_test("EXTENDED BASIC DATA FRAME");

            reset_dut;

            tx_start = tx_done_count_a;
            rx_start = rx_valid_count_b;

            start_a(
                1'b1,
                29'h12345678,
                4'd8,
                64'h1122334455667788,
                1'b0
            );

            #500000;

            check64(
                "Extended RX ID",
                64'h0000000012345678,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Extended RX IDE",
                1'b1,
                rx_ide_b
            );

            checkbit(
                "Extended RX RTR",
                1'b0,
                rx_rtr_b
            );

            check64(
                "Extended RX DLC",
                64'd8,
                {60'd0,rx_dlc_b}
            );

            check64(
                "Extended RX DATA",
                64'h1122334455667788,
                rx_data_b
            );

            check_event(
                "Extended RX frame event",
                rx_start + 1,
                rx_valid_count_b
            );

            check_event(
                "Extended TX done",
                tx_start + 1,
                tx_done_count_a
            );
        end
    endtask

    task test_dlc;
        input [3:0] dlc_value;
        input [63:0] data_value;

        begin
            reset_dut;

            start_a(
                1'b0,
                29'h00000255,
                dlc_value,
                data_value,
                1'b0
            );

            #500000;

            check64(
                "DLC RX",
                {60'd0,dlc_value},
                {60'd0,rx_dlc_b}
            );

            if (dlc_value != 0)
            begin
                case (dlc_value)

                    4'd1:
                        check64(
                            "DLC1 data",
                            64'h00000000000000A5,
                            rx_data_b
                        );

                    4'd2:
                        check64(
                            "DLC2 data",
                            64'h000000000000A5B6,
                            rx_data_b
                        );

                    4'd4:
                        check64(
                            "DLC4 data",
                            64'h00000000A5B6C7D8,
                            rx_data_b
                        );

                    4'd8:
                        check64(
                            "DLC8 data",
                            64'h1122334455667788,
                            rx_data_b
                        );

                    default:
                        check64(
                            "DLC data",
                            data_value,
                            rx_data_b
                        );

                endcase
            end
        end
    endtask

    task test_standard_rtr;
        begin
            print_test("STANDARD REMOTE FRAME");

            reset_dut;

            start_a(
                1'b0,
                29'h00000321,
                4'd4,
                64'd0,
                1'b1
            );

            #500000;

            check64(
                "Standard RTR ID",
                64'h0000000000000321,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Standard RTR IDE",
                1'b0,
                rx_ide_b
            );

            checkbit(
                "Standard RTR",
                1'b1,
                rx_rtr_b
            );

            check64(
                "Standard RTR DLC",
                64'd4,
                {60'd0,rx_dlc_b}
            );
        end
    endtask

    task test_extended_rtr;
        begin
            print_test("EXTENDED REMOTE FRAME");

            reset_dut;

            start_a(
                1'b1,
                29'h048C1234,
                4'd4,
                64'd0,
                1'b1
            );

            #500000;

            check64(
                "Extended RTR ID",
                64'h00000000048C1234,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Extended RTR IDE",
                1'b1,
                rx_ide_b
            );

            checkbit(
                "Extended RTR",
                1'b1,
                rx_rtr_b
            );

            check64(
                "Extended RTR DLC",
                64'd4,
                {60'd0,rx_dlc_b}
            );
        end
    endtask

    task test_standard_id_boundaries;
        begin
            print_test("STANDARD ID MINIMUM");

            reset_dut;

            start_a(
                1'b0,
                29'h00000000,
                4'd1,
                64'h00000000000000AA,
                1'b0
            );

            #500000;

            check64(
                "Standard minimum ID",
                64'd0,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Standard minimum IDE",
                1'b0,
                rx_ide_b
            );

            check64(
                "Standard minimum data",
                64'h00000000000000AA,
                rx_data_b
            );

            print_test("STANDARD ID MAXIMUM");

            reset_dut;

            start_a(
                1'b0,
                29'h000007FF,
                4'd1,
                64'h0000000000000055,
                1'b0
            );

            #500000;

            check64(
                "Standard maximum ID",
                64'h00000000000007FF,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Standard maximum IDE",
                1'b0,
                rx_ide_b
            );

            check64(
                "Standard maximum data",
                64'h0000000000000055,
                rx_data_b
            );
        end
    endtask

    task test_extended_id_boundaries;
        begin
            print_test("EXTENDED ID MINIMUM");

            reset_dut;

            start_a(
                1'b1,
                29'h00000000,
                4'd1,
                64'h0000000000000011,
                1'b0
            );

            #500000;

            check64(
                "Extended minimum ID",
                64'd0,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Extended minimum IDE",
                1'b1,
                rx_ide_b
            );

            check64(
                "Extended minimum data",
                64'h0000000000000011,
                rx_data_b
            );

            print_test("EXTENDED ID MAXIMUM");

            reset_dut;

            start_a(
                1'b1,
                29'h1FFFFFFF,
                4'd1,
                64'h0000000000000022,
                1'b0
            );

            #500000;

            check64(
                "Extended maximum ID",
                64'h000000001FFFFFFF,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Extended maximum IDE",
                1'b1,
                rx_ide_b
            );

            check64(
                "Extended maximum data",
                64'h0000000000000022,
                rx_data_b
            );
        end
    endtask

    task test_standard_stuffing;
        begin
            print_test("STANDARD STUFFING STRESS");

            reset_dut;

            start_a(
                1'b0,
                29'h000001FF,
                4'd8,
                64'h00000000FFFFFFFF,
                1'b0
            );

            #500000;

            check64(
                "Standard stuffing ID",
                64'h00000000000001FF,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Standard stuffing IDE",
                1'b0,
                rx_ide_b
            );

            check64(
                "Standard stuffing data",
                64'h00000000FFFFFFFF,
                rx_data_b
            );

            check64(
                "Standard stuffing DLC",
                64'd8,
                {60'd0,rx_dlc_b}
            );

            check_event(
                "Standard stuffing error count B",
                0,
                error_count_b
            );
        end
    endtask

    task test_extended_stuffing;
        begin
            print_test("EXTENDED STUFFING STRESS");

            reset_dut;

            start_a(
                1'b1,
                29'h1FFFC000,
                4'd8,
                64'hFFFFFFFF00000000,
                1'b0
            );

            #500000;

            check64(
                "Extended stuffing ID",
                64'h000000001FFFC000,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Extended stuffing IDE",
                1'b1,
                rx_ide_b
            );

            check64(
                "Extended stuffing data",
                64'hFFFFFFFF00000000,
                rx_data_b
            );

            check_event(
                "Extended stuffing error count B",
                0,
                error_count_b
            );
        end
    endtask

    task test_reverse_direction;
        begin
            print_test("REVERSE DIRECTION");

            reset_dut;

            start_b(
                1'b0,
                29'h00000456,
                4'd8,
                64'hCAFEBABE12345678,
                1'b0
            );

            #500000;

            check64(
                "Reverse RX ID",
                64'h0000000000000456,
                {35'd0,rx_identifier_a}
            );

            checkbit(
                "Reverse RX IDE",
                1'b0,
                rx_ide_a
            );

            checkbit(
                "Reverse RX RTR",
                1'b0,
                rx_rtr_a
            );

            check64(
                "Reverse RX DLC",
                64'd8,
                {60'd0,rx_dlc_a}
            );

            check64(
                "Reverse RX data",
                64'hCAFEBABE12345678,
                rx_data_a
            );
        end
    endtask

    task test_standard_arbitration;
        integer arb_start_a;

        begin
            print_test("STANDARD vs STANDARD ARBITRATION");

            reset_dut;

            arb_start_a = arbitration_lost_count_a;

            start_both(
                1'b0,
                29'h00000300,
                4'd8,
                64'hAAAAAAAAAAAAAAAA,
                1'b0,

                1'b0,
                29'h00000100,
                4'd8,
                64'hBBBBBBBBBBBBBBBB,
                1'b0
            );

            #500000;

            check64(
                "Standard arbitration winner ID A",
                64'h0000000000000100,
                {35'd0,rx_identifier_a}
            );

            checkbit(
                "Standard arbitration RX IDE A",
                1'b0,
                rx_ide_a
            );

            check64(
                "Standard arbitration winner data A",
                64'hBBBBBBBBBBBBBBBB,
                rx_data_a
            );

            check64(
                "Standard arbitration winner ID B",
                64'h0000000000000100,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Standard arbitration RX IDE B",
                1'b0,
                rx_ide_b
            );

            check64(
                "Standard arbitration winner data B",
                64'hBBBBBBBBBBBBBBBB,
                rx_data_b
            );

            check_event(
                "Standard arbitration loss A",
                arb_start_a + 1,
                arbitration_lost_count_a
            );
        end
    endtask

    task test_extended_arbitration;
        integer arb_start_b;

        begin
            print_test("EXTENDED vs EXTENDED ARBITRATION");

            reset_dut;

            arb_start_b = arbitration_lost_count_b;

            start_both(
                1'b1,
                29'h048C0000,
                4'd8,
                64'hAAAAAAAAAAAAAAAA,
                1'b0,

                1'b1,
                29'h06AF0000,
                4'd8,
                64'hBBBBBBBBBBBBBBBB,
                1'b0
            );

            #500000;

            check64(
                "Extended arbitration winner ID A",
                64'h00000000048C0000,
                {35'd0,rx_identifier_a}
            );

            checkbit(
                "Extended arbitration IDE A",
                1'b1,
                rx_ide_a
            );

            check64(
                "Extended arbitration winner data A",
                64'hAAAAAAAAAAAAAAAA,
                rx_data_a
            );

            check64(
                "Extended arbitration winner ID B",
                64'h00000000048C0000,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "Extended arbitration IDE B",
                1'b1,
                rx_ide_b
            );

            check64(
                "Extended arbitration winner data B",
                64'hAAAAAAAAAAAAAAAA,
                rx_data_b
            );

            check_event(
                "Extended arbitration loss B",
                arb_start_b + 1,
                arbitration_lost_count_b
            );
        end
    endtask

    task test_same_base_std_ext;
        integer arb_start_b;

        begin
            print_test("SAME 11-BIT ID STANDARD vs EXTENDED");

            reset_dut;

            arb_start_b = arbitration_lost_count_b;

            start_both(
                1'b0,
                29'h00000123,
                4'd8,
                64'hAAAAAAAA55555555,
                1'b0,

                1'b1,
                29'h048C0000,
                4'd8,
                64'hBBBBBBBB66666666,
                1'b0
            );

            #500000;

            check64(
                "STD/EXT arbitration ID A",
                64'h0000000000000123,
                {35'd0,rx_identifier_a}
            );

            checkbit(
                "STD/EXT winner is standard A",
                1'b0,
                rx_ide_a
            );

            check64(
                "STD/EXT winner data A",
                64'hAAAAAAAA55555555,
                rx_data_a
            );

            check64(
                "STD/EXT arbitration ID B",
                64'h0000000000000123,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "STD/EXT loser receives standard B",
                1'b0,
                rx_ide_b
            );

            check64(
                "STD/EXT winner data B",
                64'hAAAAAAAA55555555,
                rx_data_b
            );

            check_event(
                "STD/EXT extended node arbitration loss",
                arb_start_b + 1,
                arbitration_lost_count_b
            );
        end
    endtask

    task test_same_base_std_ext_nonzero;
        integer arb_start_b;

        begin
            print_test("SAME 11-BIT ID STD vs EXT WITH NONZERO EXTENSION");

            reset_dut;

            arb_start_b = arbitration_lost_count_b;

            start_both(
                1'b0,
                29'h00000123,
                4'd8,
                64'h13579BDF2468ACE0,
                1'b0,

                1'b1,
                29'h048C1234,
                4'd8,
                64'hDEADBEEFCAFEBABE,
                1'b0
            );

            #500000;

            check64(
                "STD/EXT nonzero ID result A",
                64'h0000000000000123,
                {35'd0,rx_identifier_a}
            );

            checkbit(
                "STD/EXT nonzero winner is standard",
                1'b0,
                rx_ide_a
            );

            check64(
                "STD/EXT nonzero winner data A",
                64'h13579BDF2468ACE0,
                rx_data_a
            );

            check64(
                "STD/EXT nonzero ID result B",
                64'h0000000000000123,
                {35'd0,rx_identifier_b}
            );

            checkbit(
                "STD/EXT nonzero loser sees standard",
                1'b0,
                rx_ide_b
            );

            check64(
                "STD/EXT nonzero winner data B",
                64'h13579BDF2468ACE0,
                rx_data_b
            );

            check_event(
                "STD/EXT nonzero arbitration loss B",
                arb_start_b + 1,
                arbitration_lost_count_b
            );
        end
    endtask

    task test_back_to_back;
        integer rx_start;
        integer tx_start;

        begin
            print_test("BACK-TO-BACK STANDARD FRAMES");

            reset_dut;

            rx_start = rx_valid_count_b;
            tx_start = tx_done_count_a;

            start_a(
                1'b0,
                29'h00000111,
                4'd8,
                64'h1111111122222222,
                1'b0
            );

            #500000;

            repeat (20) @(posedge clk);

            start_a(
                1'b0,
                29'h00000222,
                4'd8,
                64'h3333333344444444,
                1'b0
            );

            #500000;

            repeat (20) @(posedge clk);

            check_event(
                "Back-to-back RX frame count",
                rx_start + 2,
                rx_valid_count_b
            );

            check_event(
                "Back-to-back TX done count",
                tx_start + 2,
                tx_done_count_a
            );

            check64(
                "Back-to-back final ID",
                64'h0000000000000222,
                {35'd0,rx_identifier_b}
            );

            check64(
                "Back-to-back final data",
                64'h3333333344444444,
                rx_data_b
            );
        end
    endtask

    initial
    begin
        clk = 1'b0;
        rst_n = 1'b0;

        pass_count = 0;
        fail_count = 0;
        test_number = 0;

        tx_done_count_a = 0;
        tx_done_count_b = 0;
        rx_done_count_a = 0;
        rx_done_count_b = 0;
        rx_valid_count_a = 0;
        rx_valid_count_b = 0;
        ack_count_a = 0;
        ack_count_b = 0;
        arbitration_lost_count_a = 0;
        arbitration_lost_count_b = 0;
        error_count_a = 0;
        error_count_b = 0;

        configure;
        clear_tx;

        $display("");
        $display("============================================================");
        $display(" CAN 2.0B CAN_CONTROLLER SELF-CHECKING TESTBENCH");
        $display("============================================================");
        $display("");
        $display("Clock       = 100 MHz");
        $display("CAN bitrate = 1 Mbps");
        $display("BRP         = 1");
        $display("PROP_SEG    = 5");
        $display("PHASE_SEG1  = 2");
        $display("PHASE_SEG2  = 2");
        $display("SJW         = 1");
        $display("");
        $display("No APB");
        $display("No FIFO");
        $display("No CDC");
        $display("No acceptance filter");
        $display("Direct CAN controller node-to-node testing");
        $display("============================================================");

        test_standard_basic;

        test_extended_basic;

        print_test("DLC 0");

        reset_dut;

        start_a(
            1'b0,
            29'h00000255,
            4'd0,
            64'd0,
            1'b0
        );

        #500000;

        check64(
            "DLC0",
            64'd0,
            {60'd0,rx_dlc_b}
        );

        print_test("DLC 1");

        test_dlc(
            4'd1,
            64'h00000000000000A5
        );

        print_test("DLC 2");

        test_dlc(
            4'd2,
            64'h000000000000A5B6
        );

        print_test("DLC 4");

        test_dlc(
            4'd4,
            64'h00000000A5B6C7D8
        );

        print_test("DLC 8");

        test_dlc(
            4'd8,
            64'h1122334455667788
        );

        test_standard_rtr;

        test_extended_rtr;

        test_standard_id_boundaries;

        test_extended_id_boundaries;

        test_standard_stuffing;

        test_extended_stuffing;

        test_reverse_direction;

        test_standard_arbitration;

        test_extended_arbitration;

        test_same_base_std_ext;

        test_same_base_std_ext_nonzero;

        test_back_to_back;

        $display("");
        $display("============================================================");
        $display(" FINAL TEST SUMMARY");
        $display("============================================================");
        $display("Tests executed = %0d", test_number);
        $display("Checks passed  = %0d", pass_count);
        $display("Checks failed  = %0d", fail_count);
        $display("");
        $display("Event counters:");
        $display("  TX done A             = %0d", tx_done_count_a);
        $display("  TX done B             = %0d", tx_done_count_b);
        $display("  RX valid A            = %0d", rx_valid_count_a);
        $display("  RX valid B            = %0d", rx_valid_count_b);
        $display("  ACK A                 = %0d", ack_count_a);
        $display("  ACK B                 = %0d", ack_count_b);
        $display("  Arbitration loss A    = %0d", arbitration_lost_count_a);
        $display("  Arbitration loss B    = %0d", arbitration_lost_count_b);
        $display("  Error events A        = %0d", error_count_a);
        $display("  Error events B        = %0d", error_count_b);

        $display("");
        $display("============================================================");

        if (fail_count == 0)
            $display("RESULT: PASS");
        else
            $display("RESULT: FAIL");

        $display("============================================================");

        $finish;
    end

endmodule
