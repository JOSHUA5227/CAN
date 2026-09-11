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
    output wire        can_tx
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
     * CONFIGURATION UPDATE REQUEST
     * ================================================================ */

    reg config_update_pending;

    wire config_write;

    assign config_write =
        PSEL &&
        PENABLE &&
        PWRITE &&
        PREADY &&
        !PSLVERR &&
        (
            (PADDR == 12'h004) ||
            (PADDR == 12'h010) ||
            (PADDR == 12'h014) ||
            (PADDR == 12'h018) ||
            (PADDR == 12'h04C) ||
            (PADDR == 12'h050) ||
            (PADDR == 12'h054) ||
            (PADDR == 12'h058) ||
            (PADDR == 12'h05C) ||
            (PADDR == 12'h060)
        );

    always @(posedge pclk or negedge p_rst_sync)
    begin
        if(!p_rst_sync)
            config_update_pending <= 1'b0;
        else
            config_update_pending <= config_write;
    end


    /* ================================================================
     * CAN-DOMAIN CONFIGURATION
     * ================================================================ */

    wire        can_enable_can;
    wire        loopback_can;
    wire        listen_only_can;

    wire [31:0] brp_can;
    wire [7:0]  prop_seg_can;
    wire [7:0]  phase_seg1_can;
    wire [7:0]  phase_seg2_can;
    wire [3:0]  sjw_can;

    wire [28:0] filter0_id_can;
    wire [28:0] filter0_mask_can;
    wire        filter0_enable_can;
    wire        filter0_ide_can;

    wire [28:0] filter1_id_can;
    wire [28:0] filter1_mask_can;
    wire        filter1_enable_can;
    wire        filter1_ide_can;

    wire        config_pending_can;


    /* ================================================================
     * CONFIGURATION CDC
     *
     * Configuration is transferred from pclk to can_clk using the
     * dedicated configuration CDC block.
     * ================================================================ */

    can_config_cdc u_config_cdc (
        .pclk               (pclk),
        .p_rst_n            (p_rst_sync),

        .p_can_enable       (can_enable_p),
        .p_loopback         (loopback_p),
        .p_listen_only      (listen_only_p),

        .p_brp              (brp_p),
        .p_prop_seg         (prop_seg_p),
        .p_phase_seg1       (phase_seg1_p),
        .p_phase_seg2       (phase_seg2_p),
        .p_sjw              (sjw_p),

        .p_filter0_id       (filter0_id_p),
        .p_filter0_mask     (filter0_mask_p),
        .p_filter0_enable   (filter0_enable_p),
        .p_filter0_ide      (filter0_ide_p),

        .p_filter1_id       (filter1_id_p),
        .p_filter1_mask     (filter1_mask_p),
        .p_filter1_enable   (filter1_enable_p),
        .p_filter1_ide      (filter1_ide_p),

        .p_config_update    (config_update_pending),
        .p_config_pending   (config_pending_can),

        .can_clk            (can_clk),
        .can_rst_n          (can_rst_sync),

        .can_enable         (can_enable_can),
        .loopback           (loopback_can),
        .listen_only        (listen_only_can),

        .can_brp            (brp_can),
        .can_prop_seg       (prop_seg_can),
        .can_phase_seg1     (phase_seg1_can),
        .can_phase_seg2     (phase_seg2_can),
        .can_sjw            (sjw_can),

        .can_filter0_id     (filter0_id_can),
        .can_filter0_mask   (filter0_mask_can),
        .can_filter0_enable (filter0_enable_can),
        .can_filter0_ide    (filter0_ide_can),

        .can_filter1_id     (filter1_id_can),
        .can_filter1_mask   (filter1_mask_can),
        .can_filter1_enable (filter1_enable_can),
        .can_filter1_ide    (filter1_ide_can)
    );


    /* ================================================================
     * TX CDC
     * ================================================================ */

    wire        tx_pending_p;

    wire        line_busy;
    wire        can_tx_valid;
    wire [28:0] can_tx_id;
    wire        can_tx_ide;
    wire        can_tx_rtr;
    wire [3:0]  can_tx_dlc;
    wire [63:0] can_tx_data;

    can_tx_cdc u_tx_cdc (
        .pclk         (pclk),
        .p_rst_n      (p_rst_sync),

        .p_tx_id      (tx_identifier_p),
        .p_tx_ide     (tx_ide_p),
        .p_tx_rtr     (tx_rtr_p),
        .p_tx_dlc     (tx_dlc_p),
        .p_tx_data    (tx_data_p),
        .p_tx_request (tx_request_p),

        .p_tx_pending (tx_pending_p),

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
     * CAN CONTROLLER STATUS
     * ================================================================ */

    wire        tx_done;
    wire        rx_done;
    wire        is_transmitting;

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
     * CAN CONTROLLER STATE / TIMING
     * ================================================================ */

    wire [3:0] can_state;

    wire bit_en;
    wire sample_en;
    wire can_rx_sync;
    wire can_rx_sample;


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
     * ERROR STATUS CDC
     * ================================================================ */

    wire can_last_error_valid;
    wire [3:0] can_last_error_type;
    wire error_event_toggle;

    wire last_error_valid;
    wire [3:0] last_error_type;
    wire error_event;

    wire arbitration_lost_p;
    wire bit_error_p;
    wire stuff_error_p;
    wire crc_error_p;
    wire form_error_p;
    wire ack_error_p;

    can_error_latch u_error_latch (
        .clk                 (can_clk),
        .rst_n               (can_rst_sync),

        .bit_error           (bit_error),
        .stuff_error         (stuff_error),
        .crc_error           (crc_error),
        .form_error          (form_error),
        .ack_error           (ack_error),
        .arbitration_lost    (arbitration_lost),

        .last_error_valid    (can_last_error_valid),
        .last_error_type     (can_last_error_type),
        .error_event_toggle  (error_event_toggle)
    );


    can_error_status_cdc u_error_status_cdc (
        .pclk                 (pclk),
        .p_rst_n              (p_rst_sync),

        .error_event_toggle   (error_event_toggle),
        .can_last_error_valid (can_last_error_valid),
        .can_last_error_type  (can_last_error_type),

        .last_error_valid     (last_error_valid),
        .last_error_type      (last_error_type),
        .error_event          (error_event),

        .arbitration_lost     (arbitration_lost_p),
        .bit_error            (bit_error_p),
        .stuff_error          (stuff_error_p),
        .crc_error            (crc_error_p),
        .form_error           (form_error_p),
        .ack_error            (ack_error_p)
    );


    /* ================================================================
     * RX FIFO
     * ================================================================ */

    wire [28:0] rx_identifier_p;
    wire        rx_rtr_p;
    wire        rx_ide_p;
    wire [3:0]  rx_dlc_p;
    wire [63:0] rx_data_p;

    wire [7:0] rx_fifo_count;
    wire       rx_fifo_empty;
    wire       rx_fifo_full;
    wire       rx_fifo_overflow;
    wire rx_frame_accepted;

    can_rx_fifo_bridge #(
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_rx_fifo_bridge (
        .can_clk           (can_clk),
        .can_rst_n         (can_rst_sync),

        .rx_frame_valid    (rx_frame_accepted),
        .rx_identifier     (rx_identifier_can),
        .rx_ide            (rx_ide_can),
        .rx_rtr            (rx_rtr_can),
        .rx_dlc            (rx_dlc_can),
        .rx_data           (rx_data_can),

        .pclk              (pclk),
        .p_rst_n           (p_rst_sync),

        .rx_pop            (rx_pop_p),

        .rx_identifier_out (rx_identifier_p),
        .rx_ide_out        (rx_ide_p),
        .rx_rtr_out        (rx_rtr_p),
        .rx_dlc_out        (rx_dlc_p),
        .rx_data_out       (rx_data_p),

        .fifo_count        (rx_fifo_count),
        .fifo_empty        (rx_fifo_empty),
        .fifo_full         (rx_fifo_full),
        .fifo_overflow     (rx_fifo_overflow),

        .is_transmitting   (is_transmitting),
        .loopback          (loopback_can)
    );


    /* ================================================================
     * ACCEPTANCE FILTER
     * ================================================================ */


    can_acceptance_filter #(
        .ID_WIDTH(29)
    ) u_acceptance_filter (
        .rx_identifier  (rx_identifier_can),
        .rx_ide         (rx_ide_can),
        .rx_frame_valid (rx_frame_valid_can),

        .filter0_id     (filter0_id_can),
        .filter0_mask   (filter0_mask_can),
        .filter0_enable (filter0_enable_can),
        .filter0_ide    (filter0_ide_can),

        .filter1_id     (filter1_id_can),
        .filter1_mask   (filter1_mask_can),
        .filter1_enable (filter1_enable_can),
        .filter1_ide    (filter1_ide_can),

        .frame_accepted (rx_frame_accepted)
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

        .can_enable (can_enable_p),
        .loopback   (loopback_p),
        .listen_only(listen_only_p),

        .brp        (brp_p),
        .prop_seg   (prop_seg_p),
        .phase_seg1 (phase_seg1_p),
        .phase_seg2 (phase_seg2_p),
        .sjw        (sjw_p),

        .tx_identifier(tx_identifier_p),
        .tx_ide        (tx_ide_p),
        .tx_rtr        (tx_rtr_p),
        .tx_dlc        (tx_dlc_p),
        .tx_data       (tx_data_p),
        .tx_request    (tx_request_p),

        .rx_pop        (rx_pop_p),

        .filter0_id     (filter0_id_p),
        .filter0_mask   (filter0_mask_p),
        .filter0_enable (filter0_enable_p),
        .filter0_ide    (filter0_ide_p),

        .filter1_id     (filter1_id_p),
        .filter1_mask   (filter1_mask_p),
        .filter1_enable (filter1_enable_p),
        .filter1_ide    (filter1_ide_p),

        .tx_busy             (line_busy),
        .tx_pending          (tx_pending_p),
        .tx_done             (tx_done),
        .tx_ack_received     (ack_received),
        .tx_arbitration_lost (arbitration_lost),
        .tx_error            (ack_error_p |
                               crc_error_p |
                               stuff_error_p |
                               form_error_p |
                               bit_error_p),

        .rx_available        (!rx_fifo_empty),
        .rx_fifo_full        (rx_fifo_full),
        .rx_overflow         (rx_fifo_overflow),
        .fifo_count          (rx_fifo_count),

        .arb_lost            (arbitration_lost_p),
        .ack_error           (ack_error_p),
        .crc_error           (crc_error_p),
        .stuff_error         (stuff_error_p),
        .form_error          (form_error_p),
        .bit_error           (bit_error_p),

        .error_state         (error_state),

        .recovery_active     (1'b0),

        .last_error_valid    (last_error_valid),
        .last_error_type     (last_error_type),

        .tec                 (tec),
        .rec                 (rec),

        .rx_identifier       (rx_identifier_p),
        .rx_ide              (rx_ide_p),
        .rx_rtr              (rx_rtr_p),
        .rx_dlc              (rx_dlc_p),
        .rx_data             (rx_data_p)
    );


    /* ================================================================
     * CAN CONTROLLER
     * ================================================================ */
    can_controller #(
        .CAN_CLK_FREQ(CAN_CLK_FREQ),
        .CAN_BIT_RATE(CAN_BIT_RATE)
    ) u_can_controller (
        .clk        (can_clk),
        .rst_n      (can_rst_sync),

        .can_rx     (can_rx_controller),
        .can_tx     (can_tx_controller),

        .brp        (brp_can),
        .prop_seg   (prop_seg_can),
        .phase_seg1 (phase_seg1_can),
        .phase_seg2 (phase_seg2_can),
        .sjw        (sjw_can),

        .tx_valid      (can_tx_valid && can_enable_can),
        .tx_ide        (can_tx_ide),
        .tx_identifier (can_tx_id),
        .tx_dlc        (can_tx_dlc),
        .tx_data       (can_tx_data),
        .tx_rtr        (can_tx_rtr),

        .rx_identifier  (rx_identifier_can),
        .rx_rtr         (rx_rtr_can),
        .rx_ide         (rx_ide_can),
        .rx_dlc         (rx_dlc_can),
        .rx_data        (rx_data_can),
        .rx_frame_valid (rx_frame_valid_can),

        .tx_done        (tx_done),
        .rx_done        (),
        .line_busy      (line_busy),
        .is_transmitting(is_transmitting),

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

        .can_state      (can_state)
    );

endmodule
