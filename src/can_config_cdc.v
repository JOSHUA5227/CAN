`timescale 1ns/1ps

/*
 *  * ================================================================
 *   * CAN CONFIGURATION CLOCK-DOMAIN CROSSING
 *    * ================================================================
 *     *
 *      * PCLK -> CAN_CLK
 *       *
 *        * All CAN configuration is transferred as one coherent snapshot:
 *         *
 *          *   CAN_ENABLE
 *           *   LOOPBACK
 *            *   LISTEN_ONLY
 *             *   BRP
 *              *   PROP_SEG
 *               *   PHASE_SEG1
 *                *   PHASE_SEG2
 *                 *   SJW
 *                  *   FILTER0_ID
 *                   *   FILTER0_MASK
 *                    *   FILTER0_ENABLE
 *                     *   FILTER0_IDE
 *                      *   FILTER1_ID
 *                       *   FILTER1_MASK
 *                        *   FILTER1_ENABLE
 *                         *   FILTER1_IDE
 *                          *
 *                           * The payload is captured in the PCLK domain and
 *                           held stable while
 *                            * the request is pending.
 *                             *
 *                              * A request toggle crosses from PCLK to
 *                              CAN_CLK through a 2-FF
 *                               * synchronizer.
 *                                *
 *                                 * The CAN domain captures the complete
 *                                 snapshot when the request
 *                                  * toggle changes.
 *                                   *
 *                                    * An acknowledgement toggle returns from
 *                                    CAN_CLK to PCLK through
 *                                     * another 2-FF synchronizer.
 *                                      *
 *                                       * IMPORTANT:
 *                                        *
 *                                         * The payload buses themselves are
 *                                         NOT individually synchronized.
 *                                          * They are protected by the
 *                                          handshake protocol:
 *                                           *
 *                                            *   1. Capture payload in PCLK
 *                                            domain.
 *                                             *   2. Change request toggle.
 *                                              *   3. Hold payload stable
 *                                              while transaction is pending.
 *                                               *   4. CAN domain detects
 *                                               synchronized request.
 *                                                *   5. CAN domain captures
 *                                                complete payload.
 *                                                 *   6. CAN domain changes
 *                                                 acknowledgement toggle.
 *                                                  *   7. PCLK domain sees
 *                                                  acknowledgement and
 *                                                  releases pending state.
 *                                                   *
 *                                                    * This is appropriate
 *                                                    because configuration
 *                                                    changes are infrequent
 *                                                     * and the payload
 *                                                     remains stable for the
 *                                                     entire CDC transaction.
 *                                                      *
 *                                                       * ================================================================
 *                                                        */

module can_config_cdc (

    /*
 *      * ================================================================
 *           * PCLK DOMAIN
 *                * ================================================================
 *                     */

    input wire        pclk,
    input wire        p_rst_n,

    input wire        p_can_enable,
    input wire        p_loopback,
    input wire        p_listen_only,

    input wire [31:0] p_brp,
    input wire [7:0]  p_prop_seg,
    input wire [7:0]  p_phase_seg1,
    input wire [7:0]  p_phase_seg2,
    input wire [3:0]  p_sjw,

    input wire [28:0] p_filter0_id,
    input wire [28:0] p_filter0_mask,
    input wire        p_filter0_enable,
    input wire        p_filter0_ide,

    input wire [28:0] p_filter1_id,
    input wire [28:0] p_filter1_mask,
    input wire        p_filter1_enable,
    input wire        p_filter1_ide,

    /*
 *      * One PCLK-cycle pulse requesting transfer of the current
 *           * configuration snapshot.
 *                */
    input wire        p_config_update,

    /*
 *      * High while the PCLK-side configuration transaction is
 *           * outstanding.
 *                */
    output reg        p_config_pending,


    /*
 *      * ================================================================
 *           * CAN_CLK DOMAIN
 *                * ================================================================
 *                     */

    input wire        can_clk,
    input wire        can_rst_n,

    output reg        can_enable,
    output reg        loopback,
    output reg        listen_only,

    output reg [31:0] can_brp,
    output reg [7:0]  can_prop_seg,
    output reg [7:0]  can_phase_seg1,
    output reg [7:0]  can_phase_seg2,
    output reg [3:0]  can_sjw,

    output reg [28:0] can_filter0_id,
    output reg [28:0] can_filter0_mask,
    output reg        can_filter0_enable,
    output reg        can_filter0_ide,

    output reg [28:0] can_filter1_id,
    output reg [28:0] can_filter1_mask,
    output reg        can_filter1_enable,
    output reg        can_filter1_ide
);


    /*
 *      * ================================================================
 *           * PCLK DOMAIN
 *                * ================================================================
 *                     */

    /*
 *      * Request toggle.
 *           */
    reg config_req_toggle_p;


    /*
 *      * Stable configuration snapshot.
 *           *
 *                * These registers must not change while p_config_pending is
 *                     * asserted.
 *                          */
    reg        cfg_can_enable_p;
    reg        cfg_loopback_p;
    reg        cfg_listen_only_p;

    reg [31:0] cfg_brp_p;
    reg [7:0]  cfg_prop_seg_p;
    reg [7:0]  cfg_phase_seg1_p;
    reg [7:0]  cfg_phase_seg2_p;
    reg [3:0]  cfg_sjw_p;

    reg [28:0] cfg_filter0_id_p;
    reg [28:0] cfg_filter0_mask_p;
    reg        cfg_filter0_enable_p;
    reg        cfg_filter0_ide_p;

    reg [28:0] cfg_filter1_id_p;
    reg [28:0] cfg_filter1_mask_p;
    reg        cfg_filter1_enable_p;
    reg        cfg_filter1_ide_p;


    /*
 *      * CAN-domain acknowledgement toggle.
 *           */
    reg config_ack_toggle_can;

    /*
 *      * Synchronize acknowledgement back into PCLK.
 *           */
    reg config_ack_sync1_p;
    reg config_ack_sync2_p;


    /*
 *      * Next-state version of p_config_pending.
 *           */
    reg p_config_pending_next;

    /*
 *      * Explicit acknowledgement comparison.
 *           */
    wire config_ack_received_p;

    assign config_ack_received_p =
           p_config_pending &&
           (config_ack_sync2_p == config_req_toggle_p);


    /*
 *      * ================================================================
 *           * PCLK CONFIGURATION HANDSHAKE NEXT-STATE LOGIC
 *                * ================================================================
 *                     */

    always @(*)
    begin
        p_config_pending_next = p_config_pending;

        /*
 *          * CAN side has consumed the current configuration.
 *                   */
        if (config_ack_received_p)
        begin
            p_config_pending_next = 1'b0;
        end

        /*
 *          * Start a new configuration transaction only when there is
 *                   * no previous transaction outstanding.
 *                            */
        else if (p_config_update && !p_config_pending)
        begin
            p_config_pending_next = 1'b1;
        end
    end


    /*
 *      * ================================================================
 *           * PCLK CONFIGURATION HANDSHAKE
 *                * ================================================================
 *                     */

    always @(posedge pclk or negedge p_rst_n)
    begin
        if (!p_rst_n)
        begin
            config_req_toggle_p <= 1'b0;

            cfg_can_enable_p     <= 1'b0;
            cfg_loopback_p       <= 1'b0;
            cfg_listen_only_p    <= 1'b0;

            cfg_brp_p            <= 32'd1;
            cfg_prop_seg_p       <= 8'd0;
            cfg_phase_seg1_p     <= 8'd0;
            cfg_phase_seg2_p     <= 8'd0;
            cfg_sjw_p            <= 4'd0;

            cfg_filter0_id_p     <= 29'd0;
            cfg_filter0_mask_p   <= 29'd0;
            cfg_filter0_enable_p <= 1'b0;
            cfg_filter0_ide_p    <= 1'b0;

            cfg_filter1_id_p     <= 29'd0;
            cfg_filter1_mask_p   <= 29'd0;
            cfg_filter1_enable_p <= 1'b0;
            cfg_filter1_ide_p    <= 1'b0;

            config_ack_sync1_p   <= 1'b0;
            config_ack_sync2_p   <= 1'b0;

            p_config_pending     <= 1'b0;
        end
        else
        begin
            /*
 *              * Synchronize CAN acknowledgement.
 *                           */
            config_ack_sync1_p <= config_ack_toggle_can;
            config_ack_sync2_p <= config_ack_sync1_p;

            /*
 *              * Start a new configuration transaction.
 *                           *
 *                                        * Capture every configuration signal
 *                                        before changing
 *                                                     * the request toggle.
 *                                                                  */
            if (p_config_update && !p_config_pending)
            begin
                cfg_can_enable_p     <= p_can_enable;
                cfg_loopback_p       <= p_loopback;
                cfg_listen_only_p    <= p_listen_only;

                cfg_brp_p            <= p_brp;
                cfg_prop_seg_p       <= p_prop_seg;
                cfg_phase_seg1_p     <= p_phase_seg1;
                cfg_phase_seg2_p     <= p_phase_seg2;
                cfg_sjw_p            <= p_sjw;

                cfg_filter0_id_p     <= p_filter0_id;
                cfg_filter0_mask_p   <= p_filter0_mask;
                cfg_filter0_enable_p <= p_filter0_enable;
                cfg_filter0_ide_p    <= p_filter0_ide;

                cfg_filter1_id_p     <= p_filter1_id;
                cfg_filter1_mask_p   <= p_filter1_mask;
                cfg_filter1_enable_p <= p_filter1_enable;
                cfg_filter1_ide_p    <= p_filter1_ide;

                /*
 *                  * Toggle request only after the entire snapshot
 *                                   * has been captured.
 *                                                    */
                config_req_toggle_p <= ~config_req_toggle_p;
            end

            /*
 *              * Single sequential assignment to p_config_pending.
 *                           */
            p_config_pending <= p_config_pending_next;
        end
    end


    /*
 *      * ================================================================
 *           * CAN_CLK DOMAIN
 *                * ================================================================
 *                     */

    reg config_req_sync1_can;
    reg config_req_sync2_can;
    reg config_req_seen_can;


    /*
 *      * ================================================================
 *           * CAN CONFIGURATION CONSUMPTION
 *                * ================================================================
 *                     */

    always @(posedge can_clk or negedge can_rst_n)
    begin
        if (!can_rst_n)
        begin
            config_req_sync1_can <= 1'b0;
            config_req_sync2_can <= 1'b0;
            config_req_seen_can  <= 1'b0;

            config_ack_toggle_can <= 1'b0;

            can_enable           <= 1'b0;
            loopback             <= 1'b0;
            listen_only          <= 1'b0;

            can_brp              <= 32'd1;
            can_prop_seg         <= 8'd0;
            can_phase_seg1       <= 8'd0;
            can_phase_seg2       <= 8'd0;
            can_sjw              <= 4'd0;

            can_filter0_id       <= 29'd0;
            can_filter0_mask     <= 29'd0;
            can_filter0_enable   <= 1'b0;
            can_filter0_ide      <= 1'b0;

            can_filter1_id       <= 29'd0;
            can_filter1_mask     <= 29'd0;
            can_filter1_enable   <= 1'b0;
            can_filter1_ide      <= 1'b0;
        end
        else
        begin
            /*
 *              * Synchronize request toggle from PCLK.
 *                           */
            config_req_sync1_can <= config_req_toggle_p;
            config_req_sync2_can <= config_req_sync1_can;

            /*
 *              * New configuration snapshot detected.
 *                           */
            if (config_req_sync2_can != config_req_seen_can)
            begin
                /*
 *                  * Capture the complete configuration snapshot.
 *                                   */
                can_enable          <= cfg_can_enable_p;
                loopback            <= cfg_loopback_p;
                listen_only         <= cfg_listen_only_p;

                can_brp             <= cfg_brp_p;
                can_prop_seg        <= cfg_prop_seg_p;
                can_phase_seg1      <= cfg_phase_seg1_p;
                can_phase_seg2      <= cfg_phase_seg2_p;
                can_sjw             <= cfg_sjw_p;

                can_filter0_id      <= cfg_filter0_id_p;
                can_filter0_mask    <= cfg_filter0_mask_p;
                can_filter0_enable  <= cfg_filter0_enable_p;
                can_filter0_ide     <= cfg_filter0_ide_p;

                can_filter1_id      <= cfg_filter1_id_p;
                can_filter1_mask    <= cfg_filter1_mask_p;
                can_filter1_enable  <= cfg_filter1_enable_p;
                can_filter1_ide     <= cfg_filter1_ide_p;

                /*
 *                  * Mark request consumed.
 *                                   */
                config_req_seen_can <= config_req_sync2_can;

                /*
 *                  * Acknowledge the consumed configuration.
 *                                   */
                config_ack_toggle_can <= config_req_sync2_can;
            end
        end
    end

endmodule
