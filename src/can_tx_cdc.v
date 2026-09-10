`timescale 1ns/1ps

/*
 * CAN TX clock-domain crossing
 *
 * PCLK -> CAN_CLK
 *
 * The APB-side request is converted to a toggle event rather than being
 * synchronized as a one-cycle pulse.  This is required because PCLK and
 * CAN_CLK are asynchronous and a PCLK pulse can otherwise be completely
 * missed by CAN_CLK.
 *
 * Payload/control are captured in the PCLK domain and held stable while
 * the request is pending.  The CAN domain consumes the request only after
 * the toggle has passed through a 2-FF synchronizer.
 *
 * The acknowledgement toggle returns to PCLK and clears p_tx_pending.
 *
 * Interface is intentionally unchanged.
 */
module can_tx_cdc (
    input  wire        pclk,
    input  wire        p_rst_n,

    input  wire [28:0] p_tx_id,
    input  wire        p_tx_ide,
    input  wire        p_tx_rtr,
    input  wire [3:0]  p_tx_dlc,
    input  wire [63:0] p_tx_data,
    input  wire        p_tx_request,

    output reg         p_tx_pending,

    input  wire        can_clk,
    input  wire        can_rst_n,

    input  wire        can_tx_ready,

    output reg         can_tx_valid,
    output reg  [28:0] can_tx_id,
    output reg         can_tx_ide,
    output reg         can_tx_rtr,
    output reg  [3:0]  can_tx_dlc,
    output reg  [63:0] can_tx_data
);

    /*
     * ================================================================
     * PCLK DOMAIN
     * ================================================================
     */

    reg        tx_req_toggle_p;

    reg [28:0] tx_id_hold_p;
    reg        tx_ide_hold_p;
    reg        tx_rtr_hold_p;
    reg [3:0]  tx_dlc_hold_p;
    reg [63:0] tx_data_hold_p;

    /*
     * CAN-domain acknowledgement toggle synchronized back to PCLK.
     */
    reg tx_ack_toggle_can;
    reg tx_ack_sync1_p;
    reg tx_ack_sync2_p;

    always @(posedge pclk or negedge p_rst_n)
    begin
        if(!p_rst_n)
        begin
            tx_req_toggle_p <= 1'b0;

            tx_id_hold_p    <= 29'd0;
            tx_ide_hold_p   <= 1'b0;
            tx_rtr_hold_p   <= 1'b0;
            tx_dlc_hold_p   <= 4'd0;
            tx_data_hold_p  <= 64'd0;

            tx_ack_sync1_p  <= 1'b0;
            tx_ack_sync2_p  <= 1'b0;

            p_tx_pending    <= 1'b0;
        end
        else
        begin
            /*
             * Synchronize CAN acknowledgement.
             */
            tx_ack_sync1_p <= tx_ack_toggle_can;
            tx_ack_sync2_p <= tx_ack_sync1_p;

            /*
             * Acknowledgement means the CAN domain has consumed the
             * current request.
             */
            if(p_tx_pending &&
               (tx_ack_sync2_p == tx_req_toggle_p))
            begin
                p_tx_pending <= 1'b0;
            end

            /*
             * Accept a new APB request only when no previous request
             * is outstanding.
             */
            if(p_tx_request && !p_tx_pending)
            begin
                /*
                 * Capture the complete frame before changing the
                 * request toggle.  The payload then remains stable
                 * until the CAN side acknowledges it.
                 */
                tx_id_hold_p   <= p_tx_id;
                tx_ide_hold_p  <= p_tx_ide;
                tx_rtr_hold_p  <= p_tx_rtr;
                tx_dlc_hold_p  <= p_tx_dlc;
                tx_data_hold_p <= p_tx_data;

                tx_req_toggle_p <= ~tx_req_toggle_p;
                p_tx_pending    <= 1'b1;
            end
        end
    end

    /*
     * ================================================================
     * CAN_CLK DOMAIN
     * ================================================================
     */

    reg tx_req_sync1_can;
    reg tx_req_sync2_can;
    reg tx_req_seen_can;

    /*
     * Acknowledgement is initialized to the same state as the request
     * history.  After reset both are zero.
     */
    always @(posedge can_clk or negedge can_rst_n)
    begin
        if(!can_rst_n)
        begin
            tx_req_sync1_can <= 1'b0;
            tx_req_sync2_can <= 1'b0;
            tx_req_seen_can  <= 1'b0;

            tx_ack_toggle_can <= 1'b0;

            can_tx_valid <= 1'b0;
            can_tx_id    <= 29'd0;
            can_tx_ide   <= 1'b0;
            can_tx_rtr   <= 1'b0;
            can_tx_dlc   <= 4'd0;
            can_tx_data  <= 64'd0;
        end
        else
        begin
            /*
             * Synchronize request toggle into CAN clock domain.
             */
            tx_req_sync1_can <= tx_req_toggle_p;
            tx_req_sync2_can <= tx_req_sync1_can;

            /*
             * can_tx_valid is a one-CAN-clock pulse.
             */
            can_tx_valid <= 1'b0;

            /*
             * A new request is held until the CAN controller is ready.
             *
             * The PCLK-side payload registers are guaranteed stable
             * while p_tx_pending is asserted.
             */
            if((tx_req_sync2_can != tx_req_seen_can) &&
               can_tx_ready)
            begin
                can_tx_id    <= tx_id_hold_p;
                can_tx_ide   <= tx_ide_hold_p;
                can_tx_rtr   <= tx_rtr_hold_p;
                can_tx_dlc   <= tx_dlc_hold_p;
                can_tx_data  <= tx_data_hold_p;

                can_tx_valid <= 1'b1;

                /*
                 * Mark the request consumed and acknowledge it.
                 */
                tx_req_seen_can  <= tx_req_sync2_can;
                tx_ack_toggle_can <= tx_req_sync2_can;
            end
        end
    end

endmodule

