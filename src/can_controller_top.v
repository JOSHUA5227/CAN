module can_controller_top #(
    parameter CAN_CLK_FREQ = 100_000_000,
    parameter CAN_BIT_RATE = 1_000_000,
    parameter FIFO_DEPTH   = 8
)(
    input wire        pclk,
    input wire        p_rst_n,

    input wire        can_clk,
    input wire        can_rst_n,

    input wire [11:0] PADDR,
    input wire        PSEL,
    input wire        PENABLE,
    input wire        PWRITE,
    input wire [31:0] PWDATA,
    input wire [3:0]  PSTRB,

    output wire [31:0] PRDATA,
    output wire        PREADY,
    output wire        PSLVERR,

    input wire        can_rx,
    output wire       can_tx
);


    /* ================================================================
     * RESET SYNCHRONIZERS
     * ================================================================ */

    wire p_rst_sync;
    wire can_rst_sync;

    reset_sync u_pclk_reset_sync (
        .clk    (pclk),
        .arst_n (p_rst_n),
        .srst_n (p_rst_sync)
    );

    reset_sync u_canclk_reset_sync (
        .clk    (can_clk),
        .arst_n (can_rst_n),
        .srst_n (can_rst_sync)
    );


    /* ================================================================
     * APB REGISTER OUTPUTS
     * ================================================================ */

    wire        can_enable_p;
    wire        loopback_p;
    wire        listen_only_p;

    wire [31:0] brp_p;
    wire [7:0]  prop_seg_p;
    wire [7:0]  phase_seg1_p;
    wire [7:0]  phase_seg2_p;
    wire [3:0]  sjw_p;

    wire [28:0] tx_identifier_p;
    wire        tx_ide_p;
    wire        tx_rtr_p;
    wire [3:0]  tx_dlc_p;
    wire [63:0] tx_data_p;
    wire        tx_request_p;

    wire        rx_pop_p;

    wire [28:0] filter0_id_p;
    wire [28:0] filter0_mask_p;
    wire        filter0_enable_p;
    wire        filter0_ide_p;

    wire [28:0] filter1_id_p;
    wire [28:0] filter1_mask_p;
    wire        filter1_enable_p;
    wire        filter1_ide_p;


    /* ================================================================
     * TX CDC
     * ================================================================ */

    wire        tx_pending_p;

    wire        can_tx_valid;
    wire [28:0] can_tx_id;
    wire        can_tx_ide;
    wire        can_tx_rtr;
    wire [3:0]  can_tx_dlc;
    wire [63:0] can_tx_data;


    /* ================================================================
     * CAN CONTROLLER RX
     * ================================================================ */

    wire [28:0] rx_identifier_can;
    wire        rx_rtr_can;
    wire        rx_ide_can;
    wire [3:0]  rx_dlc_can;
    wire [63:0] rx_data_can;
    wire        rx_frame_valid_can;


    /* ================================================================
     * CAN CONTROLLER STATUS
     * ================================================================ */

    wire        tx_done;
    wire        rx_done;
    wire        line_busy;

    wire [8:0]  tec;
    wire [7:0]  rec;
    wire [1:0]  error_state;

    wire        ack_received;

    wire        arbitration_lost;
    wire        ack_error;
    wire        crc_error;
    wire        stuff_error;
    wire        form_error;
    wire        bit_error;


    /* ================================================================
     * CAN CONTROLLER STATE
     * ================================================================ */

    wire [3:0] can_state;


    /* ================================================================
     * CAN CONTROLLER TIMING / DEBUG
     * ================================================================ */

    wire bit_en;
    wire sample_en;
    wire can_rx_sync;
    wire can_rx_sample;


    /* ================================================================
     * RX FIFO
     * ================================================================ */

    wire [28:0] rx_identifier_p;
    wire        rx_rtr_p;
    wire        rx_ide_p;
    wire [3:0]  rx_dlc_p;
    wire [63:0] rx_data_p;

    wire [7:0]  rx_fifo_count;
    wire        rx_fifo_empty;

    /*
     * CAN-clock-domain FIFO full.
     *
     * Used by the CAN-clock-domain FIFO write/overflow logic.
     */
    wire        rx_fifo_full;

    /*
     * PCLK-domain FIFO full.
     *
     * Generated inside async_fifo from PCLK-domain FIFO state.
     * Used by the APB register block.
     */
    wire        rx_fifo_full_pclk;

    wire        rx_fifo_overflow;


    /* ================================================================
     * ERROR STATUS
     * ================================================================ */

    wire        can_last_error_valid;
    wire [3:0]  can_last_error_type;
    wire        error_event_toggle;

    wire        last_error_valid;
    wire [3:0]  last_error_type;
    wire        error_event;


    /* ================================================================
     * CAN-DOMAIN CONFIGURATION
     * ================================================================ */

    reg         can_enable_sync1;
    reg         can_enable_can;

    reg         loopback_can;
    reg         listen_only_can;

    reg [31:0]  brp_can;
    reg [7:0]   prop_seg_can;
    reg [7:0]   phase_seg1_can;
    reg [7:0]   phase_seg2_can;
    reg [3:0]   sjw_can;

    reg [28:0]  filter0_id_can;
    reg [28:0]  filter0_mask_can;
    reg         filter0_enable_can;
    reg         filter0_ide_can;

    reg [28:0]  filter1_id_can;
    reg [28:0]  filter1_mask_can;
    reg         filter1_enable_can;
    reg         filter1_ide_can;


    /* ================================================================
     * LOOPBACK / LISTEN-ONLY BUS ROUTING
     * ================================================================ */

    wire can_tx_controller;
    wire can_rx_controller;

    assign can_rx_controller =
        loopback_can ?
            ((can_state == 4'd7) ? 1'b0 : can_tx_controller) :
            can_rx;

    assign can_tx =
        listen_only_can ?
            1'b1 :
            can_tx_controller;


    /* ================================================================
     * ERROR LATCH
     * ================================================================ */

    can_error_latch u_error_latch (
        .clk                (can_clk),
        .rst_n              (can_rst_sync),

        .bit_error          (bit_error),
        .stuff_error        (stuff_error),
        .crc_error          (crc_error),
        .form_error         (form_error),
        .ack_error          (ack_error),

        .last_error_valid   (can_last_error_valid),
        .last_error_type    (can_last_error_type),
        .error_event_toggle (error_event_toggle)
    );


    /* ================================================================
     * ERROR STATUS CDC
     * ================================================================ */

    can_error_status_cdc u_error_status_cdc (
        .pclk                 (pclk),
        .p_rst_n              (p_rst_sync),

        .error_event_toggle   (error_event_toggle),
        .can_last_error_valid (can_last_error_valid),
        .can_last_error_type  (can_last_error_type),

        .last_error_valid     (last_error_valid),
        .last_error_type      (last_error_type),
        .error_event          (error_event)
    );


    /* ================================================================
     * APB SLAVE
     * ================================================================ */

    can_apb_slave #(
        .ADDR_WIDTH(12)
    ) u_apb_slave (
        .PCLK       (pclk),
        .PRESETn    (p_rst_sync),

        .PADDR      (PADDR),
        .PSEL       (PSEL),
        .PENABLE    (PENABLE),
        .PWRITE     (PWRITE),
        .PWDATA     (PWDATA),
        .PSTRB      (PSTRB),

        .PRDATA     (PRDATA),
        .PREADY     (PREADY),
        .PSLVERR    (PSLVERR),

        /*
         * CONTROL
         */
        .can_enable (can_enable_p),
        .loopback   (loopback_p),
        .listen_only(listen_only_p),

        /*
         * BIT TIMING
         */
        .brp        (brp_p),
        .prop_seg   (prop_seg_p),
        .phase_seg1 (phase_seg1_p),
        .phase_seg2 (phase_seg2_p),
        .sjw        (sjw_p),

        /*
         * TX
         */
        .tx_identifier(tx_identifier_p),
        .tx_ide        (tx_ide_p),
        .tx_rtr        (tx_rtr_p),
        .tx_dlc        (tx_dlc_p),
        .tx_data       (tx_data_p),
        .tx_request    (tx_request_p),

        /*
         * RX
         */
        .rx_pop        (rx_pop_p),

        /*
         * FILTER 0
         */
        .filter0_id     (filter0_id_p),
        .filter0_mask   (filter0_mask_p),
        .filter0_enable (filter0_enable_p),
        .filter0_ide    (filter0_ide_p),

        /*
         * FILTER 1
         */
        .filter1_id     (filter1_id_p),
        .filter1_mask   (filter1_mask_p),
        .filter1_enable (filter1_enable_p),
        .filter1_ide    (filter1_ide_p),

        /*
         * TX STATUS
         */
        .tx_busy             (line_busy),
        .tx_pending          (tx_pending_p),
        .tx_done             (tx_done),
        .tx_ack_received     (ack_received),
        .tx_arbitration_lost (arbitration_lost),
        .tx_error            (ack_error |
                               crc_error |
                               stuff_error |
                               form_error |
                               bit_error),

        /*
         * RX FIFO STATUS
         *
         * rx_fifo_full_pclk is already in the PCLK domain.
         */
        .rx_available        (!rx_fifo_empty),
        .rx_fifo_full_pclk   (rx_fifo_full_pclk),
        .rx_overflow         (rx_fifo_overflow),
        .fifo_count          (rx_fifo_count),

        /*
         * ERROR STATUS
         */
        .arb_lost            (arbitration_lost),
        .ack_error           (ack_error),
        .crc_error           (crc_error),
        .stuff_error         (stuff_error),
        .form_error          (form_error),
        .bit_error           (bit_error),

        .error_state         (error_state),

        .recovery_active     (1'b0),

        .last_error_valid    (last_error_valid),
        .last_error_type     (last_error_type),

        .tec                  (tec),
        .rec                  (rec),

        /*
         * RX DATA
         */
        .rx_identifier       (rx_identifier_p),
        .rx_ide              (rx_ide_p),
        .rx_rtr              (rx_rtr_p),
        .rx_dlc              (rx_dlc_p),
        .rx_data             (rx_data_p)
    );


    /* ================================================================
     * TX CDC
     * ================================================================ */

    can_tx_cdc u_tx_cdc (
        /*
         * PCLK DOMAIN
         */
        .pclk         (pclk),
        .p_rst_n      (p_rst_sync),

        .p_tx_id      (tx_identifier_p),
        .p_tx_ide     (tx_ide_p),
        .p_tx_rtr     (tx_rtr_p),
        .p_tx_dlc     (tx_dlc_p),
        .p_tx_data    (tx_data_p),
        .p_tx_request (tx_request_p),

        .p_tx_pending (tx_pending_p),

        /*
         * CAN CLOCK DOMAIN
         */
        .can_clk      (can_clk),
        .can_rst_n    (can_rst_sync),

        .can_tx_ready (can_enable_can && !line_busy),

        .can_tx_valid (can_tx_valid),
        .can_tx_id    (can_tx_id),
        .can_tx_ide   (can_tx_ide),
        .can_tx_rtr   (can_tx_rtr),
        .can_tx_dlc   (can_tx_dlc),
        .can_tx_data  (can_tx_data)
    );


    /* ================================================================
     * CONFIGURATION CROSSING
     * ================================================================ */

    always @(posedge can_clk or negedge can_rst_sync)
    begin
        if(!can_rst_sync)
        begin
            can_enable_sync1 <= 1'b0;
            can_enable_can   <= 1'b0;

            loopback_can     <= 1'b0;
            listen_only_can  <= 1'b0;

            brp_can          <= 32'd1;
            prop_seg_can     <= 8'd0;
            phase_seg1_can   <= 8'd0;
            phase_seg2_can   <= 8'd0;
            sjw_can          <= 4'd0;

            filter0_id_can     <= 29'd0;
            filter0_mask_can   <= 29'd0;
            filter0_enable_can <= 1'b0;
            filter0_ide_can    <= 1'b0;

            filter1_id_can     <= 29'd0;
            filter1_mask_can   <= 29'd0;
            filter1_enable_can <= 1'b0;
            filter1_ide_can    <= 1'b0;
        end
        else
        begin
            can_enable_sync1 <= can_enable_p;
            can_enable_can   <= can_enable_sync1;

            if(!can_enable_can)
            begin
                loopback_can    <= loopback_p;
                listen_only_can <= listen_only_p;

                brp_can          <= brp_p;
                prop_seg_can     <= prop_seg_p;
                phase_seg1_can   <= phase_seg1_p;
                phase_seg2_can   <= phase_seg2_p;
                sjw_can          <= sjw_p;

                filter0_id_can     <= filter0_id_p;
                filter0_mask_can   <= filter0_mask_p;
                filter0_enable_can <= filter0_enable_p;
                filter0_ide_can    <= filter0_ide_p;

                filter1_id_can     <= filter1_id_p;
                filter1_mask_can   <= filter1_mask_p;
                filter1_enable_can <= filter1_enable_p;
                filter1_ide_can    <= filter1_ide_p;
            end
        end
    end


    /* ================================================================
     * ACCEPTANCE FILTER
     * ================================================================ */

    wire rx_frame_accepted;

    can_acceptance_filter #(
        .ID_WIDTH(29)
    ) u_acceptance_filter (
        .rx_identifier  (rx_identifier_can),
        .rx_ide         (rx_ide_can),
        .rx_frame_valid (rx_frame_valid_can),

        .filter0_id     (filter0_id_can),
        .filter0_mask   (filter0_mask_can),
        .filter0_ide    (filter0_ide_can),

        .filter1_id     (filter1_id_can),
        .filter1_mask   (filter1_mask_can),
        .filter1_ide    (filter1_ide_can),

        .frame_accepted (rx_frame_accepted)
    );


    /* ================================================================
     * RX FIFO BRIDGE
     * ================================================================ */

    can_rx_fifo_bridge #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_rx_fifo_bridge (
        /*
         * CAN DOMAIN
         */
        .can_clk          (can_clk),
        .can_rst_n        (can_rst_sync),

        .rx_frame_valid   (rx_frame_accepted),
        .rx_identifier    (rx_identifier_can),
        .rx_ide           (rx_ide_can),
        .rx_rtr           (rx_rtr_can),
        .rx_dlc           (rx_dlc_can),
        .rx_data          (rx_data_can),

        .is_transmitting  (u_can_controller.is_transmitting),
        .loopback         (loopback_can),

        /*
         * PCLK DOMAIN
         */
        .pclk             (pclk),
        .p_rst_n          (p_rst_sync),

        .rx_pop           (rx_pop_p),

        .rx_identifier_out(rx_identifier_p),
        .rx_ide_out       (rx_ide_p),
        .rx_rtr_out       (rx_rtr_p),
        .rx_dlc_out       (rx_dlc_p),
        .rx_data_out      (rx_data_p),

        /*
         * FIFO STATUS
         */
        .fifo_count       (rx_fifo_count),
        .fifo_empty       (rx_fifo_empty),
        .fifo_full        (rx_fifo_full),
        .fifo_full_pclk   (rx_fifo_full_pclk),
        .fifo_overflow    (rx_fifo_overflow)
    );


    /* ================================================================
     * CAN CONTROLLER
     * ================================================================ */

    can_controller #(
        .CAN_CLK_FREQ(CAN_CLK_FREQ),
        .CAN_BIT_RATE(CAN_BIT_RATE)
    ) u_can_controller (
        /*
         * CLOCK / RESET
         */
        .clk        (can_clk),
        .rst_n      (can_rst_sync),

        /*
         * CAN BUS
         */
        .can_rx     (can_rx_controller),
        .can_tx     (can_tx_controller),

        /*
         * BIT TIMING
         */
        .brp        (brp_can),
        .prop_seg   (prop_seg_can),
        .phase_seg1 (phase_seg1_can),
        .phase_seg2 (phase_seg2_can),
        .sjw        (sjw_can),

        /*
         * TX
         */
        .tx_valid      (can_tx_valid && can_enable_can),
        .tx_ide        (can_tx_ide),
        .tx_identifier (can_tx_id),
        .tx_dlc        (can_tx_dlc),
        .tx_data       (can_tx_data),
        .tx_rtr        (can_tx_rtr),

        /*
         * RX
         */
        .rx_identifier  (rx_identifier_can),
        .rx_rtr         (rx_rtr_can),
        .rx_ide         (rx_ide_can),
        .rx_dlc         (rx_dlc_can),
        .rx_data        (rx_data_can),
        .rx_frame_valid (rx_frame_valid_can),

        /*
         * STATUS
         */
        .tx_done        (tx_done),
        .rx_done        (rx_done),
        .line_busy      (line_busy),

        .tec            (tec),
        .rec            (rec),
        .error_state    (error_state),

        .ack_received   (ack_received),

        .arbitration_lost(arbitration_lost),
        .ack_error      (ack_error),
        .crc_error      (crc_error),
        .stuff_error    (stuff_error),
        .form_error     (form_error),
        .bit_error      (bit_error),

        /*
         * CURRENT FRAME STATE
         */
        .can_state      (can_state)
    );

endmodule
