`timescale 1ns/1ps

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

    /*
     * ================================================================
     * RESET SYNCHRONIZERS
     * ================================================================
     */

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


    /*
     * ================================================================
     * APB REGISTER OUTPUTS - PCLK DOMAIN
     * ================================================================
     */

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


    /*
     * ================================================================
     * CONFIGURATION UPDATE SCHEDULER
     * ================================================================
     *
     * APB configuration registers are updated first.
     *
     * config_dirty_p records that a configuration register was written.
     *
     * On the following PCLK cycle, config_update_p requests
     * can_config_cdc to capture the complete, already-updated
     * configuration snapshot.
     *
     * The CDC module holds the snapshot stable until the CAN domain
     * acknowledges it.
     */

    reg  config_dirty_p;
    reg  config_update_p;
    wire config_pending_p;

    wire config_write_p;

    assign config_write_p =
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
        begin
            config_dirty_p  <= 1'b0;
            config_update_p <= 1'b0;
        end
        else
        begin
            config_update_p <= 1'b0;

            if(config_write_p)
                config_dirty_p <= 1'b1;

            if(config_dirty_p && !config_pending_p)
            begin
                config_update_p <= 1'b1;
                config_dirty_p  <= 1'b0;
            end
        end
    end


    /*
     * ================================================================
     * CAN-DOMAIN CONFIGURATION
     * ================================================================
     */

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


    /*
     * ================================================================
     * CONFIGURATION CDC
     * PCLK -> CAN_CLK
     * ================================================================
     */

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

        .p_config_update    (config_update_p),
        .p_config_pending   (config_pending_p),

        .can_clk            (can_clk),
        .can_rst_n          (can_rst_sync),

        .can_enable         (can_enable_can),
        .loopback           (loopback_can),
        .listen_only        (listen_only_can),

        .can_brp            (brp_can),
        .can_prop_seg       (prop_seg_can),
        .can_phase_seg1    (phase_seg1_can),
        .can_phase_seg2    (phase_seg2_can),
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


    /*
     * ================================================================
     * CAN CONTROLLER STATUS - CAN DOMAIN
     * ================================================================
     */

    wire        tx_done_can;
    wire        rx_done_can;
    wire        line_busy_can;
    wire        is_transmitting_can;

    wire [8:0]  tec_can;
    wire [7:0]  rec_can;
    wire [1:0]  error_state_can;

    wire        ack_received_can;
    wire        arbitration_lost_can;

    wire        ack_error_can;
    wire        crc_error_can;
    wire        stuff_error_can;
    wire        form_error_can;
    wire        bit_error_can;

    wire        recovery_active_can;

    wire [3:0]  can_state;


    /*
     * ================================================================
     * TX CDC
     * PCLK -> CAN_CLK
     * ================================================================
     */

    wire        tx_pending_p;

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

        .can_tx_ready (can_enable_can && !line_busy_can),

        .can_tx_valid (can_tx_valid),
        .can_tx_id    (can_tx_id),
        .can_tx_ide   (can_tx_ide),
        .can_tx_rtr   (can_tx_rtr),
        .can_tx_dlc   (can_tx_dlc),
        .can_tx_data  (can_tx_data)
    );


    /*
     * ================================================================
     * CAN RX SIGNALS
     * ================================================================
     */

    wire [28:0] rx_identifier_can;
    wire        rx_rtr_can;
    wire        rx_ide_can;
    wire [3:0]  rx_dlc_can;
    wire [63:0] rx_data_can;
    wire        rx_frame_valid_can;


    /*
     * ================================================================
     * CAN BUS ROUTING
     * ================================================================
     */

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


    /*
     * ================================================================
     * CAN CONTROLLER
     * ================================================================
     */

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

        .tx_done        (tx_done_can),
        .rx_done        (rx_done_can),
        .line_busy      (line_busy_can),
        .is_transmitting(is_transmitting_can),

        .tec            (tec_can),
        .rec            (rec_can),
        .error_state    (error_state_can),
        .ack_received   (ack_received_can),

        .arbitration_lost(arbitration_lost_can),
        .ack_error      (ack_error_can),
        .crc_error      (crc_error_can),
        .stuff_error    (stuff_error_can),
        .form_error     (form_error_can),
        .bit_error      (bit_error_can),

        .recovery_active(recovery_active_can),

        .can_state      (can_state)
    );


    /*
     * ================================================================
     * ERROR EVENT LATCH
     * CAN_CLK DOMAIN
     * ================================================================
     */

    wire        can_last_error_valid;
    wire [3:0]  can_last_error_type;
    wire        error_event_toggle;

    can_error_latch u_error_latch (
        .clk                 (can_clk),
        .rst_n               (can_rst_sync),

        .arbitration_lost    (arbitration_lost_can),
        .bit_error           (bit_error_can),
        .stuff_error         (stuff_error_can),
        .crc_error           (crc_error_can),
        .form_error          (form_error_can),
        .ack_error           (ack_error_can),

        .last_error_valid    (can_last_error_valid),
        .last_error_type     (can_last_error_type),
        .error_event_toggle  (error_event_toggle)
    );


    /*
     * ================================================================
     * CAN -> PCLK STATUS CDC
     * ================================================================
     */

    wire        line_busy_p;
    wire        is_transmitting_p;
    wire        tx_done_p;
    wire        ack_received_p;
    wire        arbitration_lost_p;

    wire [1:0]  error_state_p;
    wire [8:0]  tec_p;
    wire [7:0]  rec_p;
    wire        recovery_active_p;

    wire        last_error_valid;
    wire [3:0]  last_error_type;
    wire        error_event;

    wire        bit_error_p;
    wire        stuff_error_p;
    wire        crc_error_p;
    wire        form_error_p;
    wire        ack_error_p;

    can_error_status_cdc u_error_status_cdc (
        .pclk                 (pclk),
        .p_rst_n              (p_rst_sync),

        .can_clk              (can_clk),
        .can_rst_n            (can_rst_sync),

        .error_event_toggle   (error_event_toggle),
        .can_last_error_valid (can_last_error_valid),
        .can_last_error_type  (can_last_error_type),

        .can_line_busy        (line_busy_can),
        .can_is_transmitting  (is_transmitting_can),
        .can_tx_done          (tx_done_can),
        .can_ack_received     (ack_received_can),
        .can_arbitration_lost (arbitration_lost_can),

        .can_error_state      (error_state_can),
        .can_tec              (tec_can),
        .can_rec              (rec_can),
        .can_recovery_active  (recovery_active_can),

        .line_busy            (line_busy_p),
        .is_transmitting      (is_transmitting_p),

        .tx_done              (tx_done_p),
        .ack_received         (ack_received_p),
        .arbitration_lost     (arbitration_lost_p),

        .error_state          (error_state_p),
        .tec                  (tec_p),
        .rec                  (rec_p),
        .recovery_active      (recovery_active_p),

        .last_error_valid     (last_error_valid),
        .last_error_type      (last_error_type),

        .error_event          (error_event),

        .bit_error            (bit_error_p),
        .stuff_error          (stuff_error_p),
        .crc_error            (crc_error_p),
        .form_error           (form_error_p),
        .ack_error            (ack_error_p)
    );


    /*
     * ================================================================
     * RX FIFO CDC
     * CAN_CLK -> PCLK
     * ================================================================
     */

    wire [28:0] rx_identifier_p;
    wire        rx_rtr_p;
    wire        rx_ide_p;
    wire [3:0]  rx_dlc_p;
    wire [63:0] rx_data_p;

    wire [7:0]  rx_fifo_count;
    wire        rx_fifo_empty;
    wire        rx_fifo_full;
    wire        rx_fifo_full_pclk;
    wire        rx_fifo_overflow;

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

        .is_transmitting   (is_transmitting_can),
        .loopback          (loopback_can),

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
        .fifo_full_pclk    (rx_fifo_full_pclk),
        .fifo_overflow     (rx_fifo_overflow)
    );


    /*
     * ================================================================
     * ACCEPTANCE FILTER
     * CAN_CLK DOMAIN
     * ================================================================
     */

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


    /*
     * ================================================================
     * APB SLAVE
     * PCLK DOMAIN
     * ================================================================
     */

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

        .tx_busy             (line_busy_p),
        .tx_pending          (tx_pending_p),
        .tx_done             (tx_done_p),
        .tx_ack_received     (ack_received_p),
        .tx_arbitration_lost (arbitration_lost_p),

        .tx_error            (ack_error_p |
                              crc_error_p |
                              stuff_error_p |
                              form_error_p |
                              bit_error_p),

        .rx_available        (!rx_fifo_empty),
        .rx_fifo_full_pclk        (rx_fifo_full_pclk),
        .rx_overflow         (rx_fifo_overflow),
        .fifo_count          (rx_fifo_count),

        .arb_lost            (arbitration_lost_p),
        .ack_error           (ack_error_p),
        .crc_error           (crc_error_p),
        .stuff_error         (stuff_error_p),
        .form_error          (form_error_p),
        .bit_error           (bit_error_p),

        .error_state         (error_state_p),
        .recovery_active     (recovery_active_p),

        .last_error_valid    (last_error_valid),
        .last_error_type     (last_error_type),

        .tec                 (tec_p),
        .rec                 (rec_p),

        .rx_identifier       (rx_identifier_p),
        .rx_ide              (rx_ide_p),
        .rx_rtr              (rx_rtr_p),
        .rx_dlc              (rx_dlc_p),
        .rx_data             (rx_data_p)
    );

endmodule
