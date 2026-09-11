`timescale 1ns/1ps

module tb_can_controller_top;

    reg pclk;
    reg can_clk;

    reg p_rst_n_a;
    reg can_rst_n_a;
    reg p_rst_n_b;
    reg can_rst_n_b;

    reg [11:0] PADDR_A;
    reg PSEL_A;
    reg PENABLE_A;
    reg PWRITE_A;
    reg [31:0] PWDATA_A;
    reg [3:0] PSTRB_A;

    wire [31:0] PRDATA_A;
    wire PREADY_A;
    wire PSLVERR_A;

    reg [11:0] PADDR_B;
    reg PSEL_B;
    reg PENABLE_B;
    reg PWRITE_B;
    reg [31:0] PWDATA_B;
    reg [3:0] PSTRB_B;

    wire [31:0] PRDATA_B;
    wire PREADY_B;
    wire PSLVERR_B;

    wire can_tx_a;
    wire can_tx_b;
    wire can_rx_a;
    wire can_rx_b;
    wire can_bus;

    integer pass_count;
    integer fail_count;
    integer timeout;

    reg [31:0] tx_status_a;
    reg [31:0] rx_status_b;
    reg [31:0] rx_id_b;
    reg [31:0] rx_ctrl_b;
    reg [31:0] rx_data_lo_b;
    reg [31:0] rx_data_hi_b;

    assign can_bus = can_tx_a & can_tx_b;

    assign can_rx_a = can_bus;
    assign can_rx_b = can_bus;

    /* ============================================================
     * NODE A
     * ============================================================ */

    can_controller_top #(
        .CAN_CLK_FREQ(10_000_000),
        .CAN_BIT_RATE(1_000_000),
        .FIFO_DEPTH(8)
    ) dut_a (
        .pclk(pclk),
        .p_rst_n(p_rst_n_a),
        .can_clk(can_clk),
        .can_rst_n(can_rst_n_a),
        .PADDR(PADDR_A),
        .PSEL(PSEL_A),
        .PENABLE(PENABLE_A),
        .PWRITE(PWRITE_A),
        .PWDATA(PWDATA_A),
        .PSTRB(PSTRB_A),
        .PRDATA(PRDATA_A),
        .PREADY(PREADY_A),
        .PSLVERR(PSLVERR_A),
        .can_rx(can_rx_a),
        .can_tx(can_tx_a)
    );

    /* ============================================================
     * NODE B
     * ============================================================ */

    can_controller_top #(
        .CAN_CLK_FREQ(10_000_000),
        .CAN_BIT_RATE(1_000_000),
        .FIFO_DEPTH(8)
    ) dut_b (
        .pclk(pclk),
        .p_rst_n(p_rst_n_b),
        .can_clk(can_clk),
        .can_rst_n(can_rst_n_b),
        .PADDR(PADDR_B),
        .PSEL(PSEL_B),
        .PENABLE(PENABLE_B),
        .PWRITE(PWRITE_B),
        .PWDATA(PWDATA_B),
        .PSTRB(PSTRB_B),
        .PRDATA(PRDATA_B),
        .PREADY(PREADY_B),
        .PSLVERR(PSLVERR_B),
        .can_rx(can_rx_b),
        .can_tx(can_tx_b)
    );

    /* ============================================================
     * CLOCKS
     * PCLK    = 100 MHz
     * CAN_CLK = 10 MHz
     * ============================================================ */

    initial begin
        pclk = 1'b0;
        forever #5 pclk = ~pclk;
    end

    initial begin
        can_clk = 1'b0;
        forever #50 can_clk = ~can_clk;
    end

    /* ============================================================
     * APB WRITE NODE A
     * ============================================================ */

    task apb_write_a;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge pclk);
            PADDR_A   <= addr;
            PWDATA_A  <= data;
            PWRITE_A  <= 1'b1;
            PSTRB_A   <= 4'hF;
            PSEL_A    <= 1'b1;
            PENABLE_A <= 1'b0;

            @(posedge pclk);
            PENABLE_A <= 1'b1;

            @(posedge pclk);
            PSEL_A    <= 1'b0;
            PENABLE_A <= 1'b0;
            PWRITE_A  <= 1'b0;
            PADDR_A   <= 12'd0;
            PWDATA_A  <= 32'd0;
            PSTRB_A   <= 4'd0;
        end
    endtask

    /* ============================================================
     * APB WRITE NODE B
     * ============================================================ */

    task apb_write_b;
        input [11:0] addr;
        input [31:0] data;
        begin
            @(posedge pclk);
            PADDR_B   <= addr;
            PWDATA_B  <= data;
            PWRITE_B  <= 1'b1;
            PSTRB_B   <= 4'hF;
            PSEL_B    <= 1'b1;
            PENABLE_B <= 1'b0;

            @(posedge pclk);
            PENABLE_B <= 1'b1;

            @(posedge pclk);
            PSEL_B    <= 1'b0;
            PENABLE_B <= 1'b0;
            PWRITE_B  <= 1'b0;
            PADDR_B   <= 12'd0;
            PWDATA_B  <= 32'd0;
            PSTRB_B   <= 4'd0;
        end
    endtask

    /* ============================================================
     * APB READ NODE A
     * ============================================================ */

    task apb_read_a;
        input [11:0] addr;
        output [31:0] data;
        begin
            @(posedge pclk);
            PADDR_A   <= addr;
            PWRITE_A  <= 1'b0;
            PSTRB_A   <= 4'h0;
            PSEL_A    <= 1'b1;
            PENABLE_A <= 1'b0;

            @(posedge pclk);
            PENABLE_A <= 1'b1;

            @(posedge pclk);
            #1;
            data = PRDATA_A;

            PSEL_A    <= 1'b0;
            PENABLE_A <= 1'b0;
            PADDR_A   <= 12'd0;
        end
    endtask

    /* ============================================================
     * APB READ NODE B
     * ============================================================ */

    task apb_read_b;
        input [11:0] addr;
        output [31:0] data;
        begin
            @(posedge pclk);
            PADDR_B   <= addr;
            PWRITE_B  <= 1'b0;
            PSTRB_B   <= 4'h0;
            PSEL_B    <= 1'b1;
            PENABLE_B <= 1'b0;

            @(posedge pclk);
            PENABLE_B <= 1'b1;

            @(posedge pclk);
            #1;
            data = PRDATA_B;

            PSEL_B    <= 1'b0;
            PENABLE_B <= 1'b0;
            PADDR_B   <= 12'd0;
        end
    endtask

    /* ============================================================
     * CAN DOMAIN BIT TIMING MONITOR
     * ============================================================ */

    always @(posedge can_clk) begin
        if(can_rst_n_a) begin
            if(dut_a.u_can_controller.bit_en)
                $display("NODE A BIT_EN time=%0t state=%d bit_cnt=%d", $time, dut_a.u_can_controller.field_sel, dut_a.u_can_controller.bit_cnt);
        end
    end

    always @(posedge can_clk) begin
        if(can_rst_n_b) begin
            if(dut_b.u_can_controller.bit_en)
                $display("NODE B BIT_EN time=%0t state=%d bit_cnt=%d", $time, dut_b.u_can_controller.field_sel, dut_b.u_can_controller.bit_cnt);
        end
    end

    /* ============================================================
     * CAN DOMAIN EVENT MONITOR
     * ============================================================ */

    always @(posedge can_clk) begin
        if(can_rst_n_a) begin
            if(dut_a.u_can_controller.tx_done)
                $display("CAN EVENT: NODE A TX_DONE at %0t", $time);

            if(dut_a.u_can_controller.ack_received)
                $display("CAN EVENT: NODE A ACK_RECEIVED at %0t", $time);

            if(dut_a.u_can_controller.arbitration_lost)
                $display("CAN EVENT: NODE A ARBITRATION_LOST at %0t", $time);
        end
    end

    /* ============================================================
     * MAIN TEST
     * ============================================================ */

    initial begin

        pass_count = 0;
        fail_count = 0;
        timeout = 0;

        PADDR_A = 12'd0;
        PSEL_A = 1'b0;
        PENABLE_A = 1'b0;
        PWRITE_A = 1'b0;
        PWDATA_A = 32'd0;
        PSTRB_A = 4'd0;

        PADDR_B = 12'd0;
        PSEL_B = 1'b0;
        PENABLE_B = 1'b0;
        PWRITE_B = 1'b0;
        PWDATA_B = 32'd0;
        PSTRB_B = 4'd0;

        p_rst_n_a = 1'b0;
        can_rst_n_a = 1'b0;
        p_rst_n_b = 1'b0;
        can_rst_n_b = 1'b0;

        /* ========================================================
         * RESET
         * ======================================================== */

        #200;

        p_rst_n_a = 1'b1;
        can_rst_n_a = 1'b1;
        p_rst_n_b = 1'b1;
        can_rst_n_b = 1'b1;

        #500;

        $display("==============================================");
        $display("SIMPLE 2-NODE CAN 2.0B TEST");
        $display("==============================================");
        $display("PCLK    = 100 MHz");
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
         * NODE A BIT TIMING
         * ======================================================== */

        apb_write_a(12'h010, 32'd1);
        apb_write_a(12'h014, 32'h00020205);
        apb_write_a(12'h018, 32'd1);

        /* ========================================================
         * NODE B BIT TIMING
         * ======================================================== */

        apb_write_b(12'h010, 32'd1);
        apb_write_b(12'h014, 32'h00020205);
        apb_write_b(12'h018, 32'd1);

        /* ========================================================
         * NODE B ACCEPTANCE FILTER
         * ======================================================== */

        apb_write_b(12'h04C, 32'h00000155);
        apb_write_b(12'h050, 32'h000007FF);
        apb_write_b(12'h054, 32'h00000001);

        /* ========================================================
         * ENABLE BOTH NODES
         * ======================================================== */

        apb_write_a(12'h004, 32'h00000001);
        apb_write_b(12'h004, 32'h00000001);

        #5000;

        /* ========================================================
         * LOAD NODE A TX FRAME
         * ======================================================== */

        apb_write_a(12'h01C, 32'h00000155);
        apb_write_a(12'h020, 32'h00000010);
        apb_write_a(12'h024, 32'hA5A5A5A5);
        apb_write_a(12'h028, 32'h00000000);

        /* ========================================================
         * BEFORE TX COMMAND
         * ======================================================== */

        $display("==============================================");
        $display("BEFORE TX COMMAND");
        $display("==============================================");
        $display("TX_PENDING       = %b", dut_a.u_can_controller.tx_pending);
        $display("IS_TRANSMITTING  = %b", dut_a.u_can_controller.is_transmitting);
        $display("LINE_BUSY        = %b", dut_a.u_can_controller.line_busy);
        $display("BIT_EN           = %b", dut_a.u_can_controller.bit_en);
        $display("ERROR_STATE      = %b", dut_a.u_can_controller.error_state);

        /* ========================================================
         * START TRANSMISSION
         * ======================================================== */

        $display("==============================================");
        $display("START TX at %0t", $time);
        $display("==============================================");

        apb_write_a(12'h02C, 32'h00000001);

        /* ========================================================
         * WAIT FOR CAN DOMAIN TO START
         * ======================================================== */

        timeout = 0;

        while((timeout < 1000) && !dut_a.u_can_controller.is_transmitting) begin
            @(posedge can_clk);
            timeout = timeout + 1;
        end

        if(dut_a.u_can_controller.is_transmitting) begin
            pass_count = pass_count + 1;
            $display("PASS: Node A started CAN transmission");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Node A never started transmission");
        end

        /* ========================================================
         * WAIT FOR COMPLETE FRAME AND FIFO UPDATE
         * ======================================================== */

        timeout = 0;

        while((timeout < 10000) && !dut_b.rx_fifo_count) begin
            @(posedge can_clk);
            timeout = timeout + 1;
        end

        #10000;

        /* ========================================================
         * APB TX STATUS
         * ======================================================== */

        apb_read_a(12'h030, tx_status_a);

        $display("==============================================");
        $display("NODE A TX STATUS");
        $display("==============================================");
        $display("TX_STATUS    = %h", tx_status_a);
        $display("TX_PENDING   = %b", tx_status_a[0]);
        $display("TX_BUSY      = %b", tx_status_a[1]);
        $display("TX_DONE      = %b", tx_status_a[2]);
        $display("ACK_RECEIVED = %b", tx_status_a[3]);
        $display("ARB_LOST     = %b", tx_status_a[4]);
        $display("TX_ERROR     = %b", tx_status_a[5]);

        if(tx_status_a[1] == 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: TX_BUSY cleared");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: TX_BUSY still asserted");
        end

        if(tx_status_a[2] == 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: TX_DONE received");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: TX_DONE missing");
        end

        if(tx_status_a[3] == 1'b1) begin
            pass_count = pass_count + 1;
            $display("PASS: ACK_RECEIVED received");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: ACK_RECEIVED missing");
        end

        if(tx_status_a[4] == 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: No arbitration loss");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: Arbitration loss detected");
        end

        if(tx_status_a[5] == 1'b0) begin
            pass_count = pass_count + 1;
            $display("PASS: No TX error");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: TX error detected");
        end

        /* ========================================================
         * NODE B RX STATUS
         * ======================================================== */

        apb_read_b(12'h034, rx_status_b);

        $display("==============================================");
        $display("NODE B RX STATUS");
        $display("==============================================");
        $display("RX_STATUS  = %h", rx_status_b);
        $display("FIFO_COUNT = %d", rx_status_b[7:0]);
        $display("FIFO_EMPTY = %b", rx_status_b[8]);
        $display("FIFO_FULL  = %b", rx_status_b[9]);
        $display("OVERFLOW   = %b", rx_status_b[10]);

        if(rx_status_b[7:0] != 8'd0) begin
            pass_count = pass_count + 1;
            $display("PASS: RX FIFO contains a frame");
        end
        else begin
            fail_count = fail_count + 1;
            $display("FAIL: RX FIFO empty");
        end

        /* ========================================================
         * NODE B RX DATA
         * ======================================================== */

        if(rx_status_b[7:0] != 8'd0) begin

            apb_read_b(12'h038, rx_id_b);
            apb_read_b(12'h03C, rx_ctrl_b);
            apb_read_b(12'h040, rx_data_lo_b);
            apb_read_b(12'h044, rx_data_hi_b);

            $display("==============================================");
            $display("NODE B RECEIVED FRAME");
            $display("==============================================");
            $display("RX_ID      = %h", rx_id_b);
            $display("RX_CTRL    = %h", rx_ctrl_b);
            $display("RX_DATA_LO = %h", rx_data_lo_b);
            $display("RX_DATA_HI = %h", rx_data_hi_b);

            if(rx_id_b == 32'h00000155) begin
                pass_count = pass_count + 1;
                $display("PASS: RX ID correct");
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: RX ID incorrect");
            end

            if(rx_ctrl_b == 32'h00000010) begin
                pass_count = pass_count + 1;
                $display("PASS: RX CTRL correct");
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: RX CTRL incorrect");
            end

            if(rx_data_lo_b == 32'hA5A5A5A5) begin
                pass_count = pass_count + 1;
                $display("PASS: RX DATA correct");
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: RX DATA incorrect");
            end

            if(rx_data_hi_b == 32'h00000000) begin
                pass_count = pass_count + 1;
                $display("PASS: RX DATA HIGH correct");
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: RX DATA HIGH incorrect");
            end

        end

        /* ========================================================
         * NODE A INTERNAL STATUS
         * ======================================================== */

        $display("==============================================");
        $display("NODE A INTERNAL STATUS");
        $display("==============================================");
        $display("IS_TRANSMITTING  = %b", dut_a.u_can_controller.is_transmitting);
        $display("LINE_BUSY        = %b", dut_a.u_can_controller.line_busy);
        $display("TX_PENDING       = %b", dut_a.u_can_controller.tx_pending);
        $display("ACK_RECEIVED     = %b", dut_a.u_can_controller.ack_received);
        $display("ARBITRATION_LOST = %b", dut_a.u_can_controller.arbitration_lost);
        $display("ACK_ERROR        = %b", dut_a.u_can_controller.ack_error);
        $display("BIT_ERROR        = %b", dut_a.u_can_controller.bit_error);
        $display("STUFF_ERROR      = %b", dut_a.u_can_controller.stuff_error);
        $display("FORM_ERROR       = %b", dut_a.u_can_controller.form_error);

        /* ========================================================
         * NODE B INTERNAL STATUS
         * ======================================================== */

        $display("==============================================");
        $display("NODE B INTERNAL STATUS");
        $display("==============================================");
        $display("RX_IDENTIFIER    = %h", dut_b.u_can_controller.rx_identifier);
        $display("RX_IDE           = %b", dut_b.u_can_controller.rx_ide);
        $display("RX_RTR           = %b", dut_b.u_can_controller.rx_rtr);
        $display("RX_DLC           = %d", dut_b.u_can_controller.rx_dlc);
        $display("RX_DATA          = %h", dut_b.u_can_controller.rx_data);
        $display("CRC_ERROR        = %b", dut_b.u_can_controller.rx_crc_error);
        $display("STUFF_ERROR      = %b", dut_b.u_can_controller.stuff_error);
        $display("BIT_ERROR        = %b", dut_b.u_can_controller.bit_error);
        $display("FORM_ERROR       = %b", dut_b.u_can_controller.form_error);
        $display("ACK_ERROR        = %b", dut_b.u_can_controller.ack_error);

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
