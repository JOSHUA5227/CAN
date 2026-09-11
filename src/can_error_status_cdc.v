module can_error_status_cdc (
    input wire        pclk,
    input wire        p_rst_n,
    input wire        can_clk,
    input wire        can_rst_n,

    input wire        error_event_toggle,
    input wire        can_last_error_valid,
    input wire [3:0]  can_last_error_type,

    input wire        can_line_busy,
    input wire        can_is_transmitting,
    input wire        can_tx_done,
    input wire        can_ack_received,
    input wire        can_arbitration_lost,
    input wire        can_recovery_active,

    input wire [1:0]  can_error_state,
    input wire [8:0]  can_tec,
    input wire [7:0]  can_rec,

    output reg        line_busy,
    output reg        is_transmitting,
    output reg        tx_done,
    output reg        ack_received,
    output reg        arbitration_lost,
    output reg        recovery_active,

    output reg [1:0]  error_state,
    output reg [8:0]  tec,
    output reg [7:0]  rec,

    output reg        last_error_valid,
    output reg [3:0]  last_error_type,
    output reg        error_event,

    output reg        bit_error,
    output reg        stuff_error,
    output reg        crc_error,
    output reg        form_error,
    output reg        ack_error
);

    /*
     * ================================================================
     * CAN_CLK DOMAIN
     * ================================================================
     */

    reg can_last_error_valid_hold;
    reg [3:0] can_last_error_type_hold;

    reg error_event_toggle_seen_can;

    reg status_toggle_can;

    reg [1:0] can_error_state_snapshot;
    reg [8:0] can_tec_snapshot;
    reg [7:0] can_rec_snapshot;

    reg tx_done_toggle_can;
    reg ack_toggle_can;
    reg arb_toggle_can;

    reg can_tx_done_seen;
    reg can_ack_received_seen;
    reg can_arbitration_lost_seen;


    /*
     * Error event and status snapshot generation.
     *
     * error_event_toggle is an event indicator in the CAN clock
     * domain. When it changes, capture the associated error/status
     * information into stable CAN-domain registers and toggle
     * status_toggle_can.
     */

    always @(posedge can_clk or negedge can_rst_n)
    begin
        if(!can_rst_n)
        begin
            can_last_error_valid_hold <= 1'b0;
            can_last_error_type_hold  <= 4'd0;

            error_event_toggle_seen_can <= 1'b0;

            status_toggle_can <= 1'b0;

            can_error_state_snapshot <= 2'd0;
            can_tec_snapshot         <= 9'd0;
            can_rec_snapshot         <= 8'd0;

            tx_done_toggle_can <= 1'b0;
            ack_toggle_can     <= 1'b0;
            arb_toggle_can     <= 1'b0;

            can_tx_done_seen          <= 1'b0;
            can_ack_received_seen     <= 1'b0;
            can_arbitration_lost_seen <= 1'b0;
        end
        else
        begin
            /*
             * Capture latest error information whenever valid.
             */
            if(can_last_error_valid)
            begin
                can_last_error_valid_hold <= 1'b1;
                can_last_error_type_hold  <= can_last_error_type;
            end

            /*
             * Detect TX done event.
             */
            if(can_tx_done && !can_tx_done_seen)
                tx_done_toggle_can <= ~tx_done_toggle_can;

            /*
             * Detect ACK received event.
             */
            if(can_ack_received && !can_ack_received_seen)
                ack_toggle_can <= ~ack_toggle_can;

            /*
             * Detect arbitration lost event.
             */
            if(can_arbitration_lost && !can_arbitration_lost_seen)
                arb_toggle_can <= ~arb_toggle_can;

            /*
             * Remember current event levels.
             */
            can_tx_done_seen          <= can_tx_done;
            can_ack_received_seen     <= can_ack_received;
            can_arbitration_lost_seen <= can_arbitration_lost;

            /*
             * Detect a new error event.
             *
             * This is the correct comparison:
             *
             * current toggle != previous toggle
             *
             * Do not compare an event toggle against a valid level.
             */
            if(error_event_toggle != error_event_toggle_seen_can)
            begin
                error_event_toggle_seen_can <= error_event_toggle;

                /*
                 * Snapshot all CAN-domain status associated with
                 * this event.
                 */
                can_error_state_snapshot <= can_error_state;
                can_tec_snapshot         <= can_tec;
                can_rec_snapshot         <= can_rec;

                /*
                 * Indicate that the status snapshot is ready.
                 */
                status_toggle_can <= ~status_toggle_can;
            end

            /*
             * TX done, ACK, or arbitration events can also require
             * a fresh error/status snapshot.
             */
            if((can_tx_done && !can_tx_done_seen) ||
               (can_ack_received && !can_ack_received_seen) ||
               (can_arbitration_lost && !can_arbitration_lost_seen))
            begin
                can_error_state_snapshot <= can_error_state;
                can_tec_snapshot         <= can_tec;
                can_rec_snapshot         <= can_rec;

                status_toggle_can <= ~status_toggle_can;
            end
        end
    end


    /*
     * ================================================================
     * CAN_CLK -> PCLK LEVEL SYNCHRONIZERS
     * ================================================================
     *
     * These are persistent status levels, not event pulses.
     */

    reg line_busy_sync1;
    reg line_busy_sync2;

    reg is_transmitting_sync1;
    reg is_transmitting_sync2;

    reg recovery_active_sync1;
    reg recovery_active_sync2;


    /*
     * ================================================================
     * CAN_CLK -> PCLK EVENT SYNCHRONIZERS
     * ================================================================
     */

    reg error_event_toggle_sync1;
    reg error_event_toggle_sync2;
    reg error_event_toggle_seen;

    reg status_toggle_sync1;
    reg status_toggle_sync2;
    reg status_toggle_seen;

    reg tx_done_toggle_sync1;
    reg tx_done_toggle_sync2;
    reg tx_done_toggle_seen;

    reg ack_toggle_sync1;
    reg ack_toggle_sync2;
    reg ack_toggle_seen;

    reg arb_toggle_sync1;
    reg arb_toggle_sync2;
    reg arb_toggle_seen;


    /*
     * ================================================================
     * PCLK DOMAIN
     * ================================================================
     */

    always @(posedge pclk or negedge p_rst_n)
    begin
        if(!p_rst_n)
        begin
            /*
             * Level synchronizers.
             */
            line_busy_sync1       <= 1'b0;
            line_busy_sync2       <= 1'b0;

            is_transmitting_sync1 <= 1'b0;
            is_transmitting_sync2 <= 1'b0;

            recovery_active_sync1 <= 1'b0;
            recovery_active_sync2 <= 1'b0;

            /*
             * Event synchronizers.
             */
            error_event_toggle_sync1 <= 1'b0;
            error_event_toggle_sync2 <= 1'b0;
            error_event_toggle_seen   <= 1'b0;

            status_toggle_sync1 <= 1'b0;
            status_toggle_sync2 <= 1'b0;
            status_toggle_seen  <= 1'b0;

            tx_done_toggle_sync1 <= 1'b0;
            tx_done_toggle_sync2 <= 1'b0;
            tx_done_toggle_seen  <= 1'b0;

            ack_toggle_sync1 <= 1'b0;
            ack_toggle_sync2 <= 1'b0;
            ack_toggle_seen  <= 1'b0;

            arb_toggle_sync1 <= 1'b0;
            arb_toggle_sync2 <= 1'b0;
            arb_toggle_seen  <= 1'b0;

            /*
             * Outputs.
             */
            line_busy        <= 1'b0;
            is_transmitting  <= 1'b0;

            tx_done          <= 1'b0;
            ack_received     <= 1'b0;
            arbitration_lost <= 1'b0;

            recovery_active  <= 1'b0;

            error_state <= 2'd0;
            tec         <= 9'd0;
            rec         <= 8'd0;

            last_error_valid <= 1'b0;
            last_error_type  <= 4'd0;
            error_event      <= 1'b0;

            bit_error   <= 1'b0;
            stuff_error <= 1'b0;
            crc_error   <= 1'b0;
            form_error  <= 1'b0;
            ack_error   <= 1'b0;
        end
        else
        begin
            /*
             * --------------------------------------------------------
             * Synchronize persistent CAN-domain levels.
             * --------------------------------------------------------
             */

            line_busy_sync1 <= can_line_busy;
            line_busy_sync2 <= line_busy_sync1;

            is_transmitting_sync1 <= can_is_transmitting;
            is_transmitting_sync2 <= is_transmitting_sync1;

            recovery_active_sync1 <= can_recovery_active;
            recovery_active_sync2 <= recovery_active_sync1;

            /*
             * --------------------------------------------------------
             * Synchronize event toggles.
             * --------------------------------------------------------
             */

            error_event_toggle_sync1 <= error_event_toggle;
            error_event_toggle_sync2 <= error_event_toggle_sync1;

            status_toggle_sync1 <= status_toggle_can;
            status_toggle_sync2 <= status_toggle_sync1;

            tx_done_toggle_sync1 <= tx_done_toggle_can;
            tx_done_toggle_sync2 <= tx_done_toggle_sync1;

            ack_toggle_sync1 <= ack_toggle_can;
            ack_toggle_sync2 <= ack_toggle_sync1;

            arb_toggle_sync1 <= arb_toggle_can;
            arb_toggle_sync2 <= arb_toggle_sync1;

            /*
             * --------------------------------------------------------
             * Publish synchronized level signals.
             * --------------------------------------------------------
             */

            line_busy       <= line_busy_sync2;
            is_transmitting <= is_transmitting_sync2;
            recovery_active <= recovery_active_sync2;

            /*
             * --------------------------------------------------------
             * Event outputs are one PCLK cycle pulses.
             * --------------------------------------------------------
             */

            tx_done          <= 1'b0;
            ack_received     <= 1'b0;
            arbitration_lost <= 1'b0;
            error_event      <= 1'b0;

            /*
             * --------------------------------------------------------
             * TX DONE event.
             * --------------------------------------------------------
             */

            if(tx_done_toggle_sync2 != tx_done_toggle_seen)
            begin
                tx_done_toggle_seen <= tx_done_toggle_sync2;
                tx_done <= 1'b1;
            end

            /*
             * --------------------------------------------------------
             * ACK RECEIVED event.
             * --------------------------------------------------------
             */

            if(ack_toggle_sync2 != ack_toggle_seen)
            begin
                ack_toggle_seen <= ack_toggle_sync2;
                ack_received <= 1'b1;
            end

            /*
             * --------------------------------------------------------
             * ARBITRATION LOST event.
             * --------------------------------------------------------
             */

            if(arb_toggle_sync2 != arb_toggle_seen)
            begin
                arb_toggle_seen <= arb_toggle_sync2;
                arbitration_lost <= 1'b1;
            end

            /*
             * --------------------------------------------------------
             * Status snapshot event.
             * --------------------------------------------------------
             *
             * The snapshot registers are written in CAN_CLK and are
             * held stable until the next status event. The toggle is
             * synchronized before the PCLK domain consumes them.
             */

            if(status_toggle_sync2 != status_toggle_seen)
            begin
                status_toggle_seen <= status_toggle_sync2;

                error_state <= can_error_state_snapshot;
                tec         <= can_tec_snapshot;
                rec         <= can_rec_snapshot;
            end

            /*
             * --------------------------------------------------------
             * Error event.
             * --------------------------------------------------------
             */

            if(error_event_toggle_sync2 != error_event_toggle_seen)
            begin
                error_event_toggle_seen <= error_event_toggle_sync2;

                last_error_valid <= can_last_error_valid_hold;
                last_error_type  <= can_last_error_type_hold;

                error_event <= 1'b1;

                /*
                 * Decode the captured error type.
                 */
                case(can_last_error_type_hold)

                    4'd1:
                    begin
                        bit_error   <= 1'b1;
                        stuff_error <= 1'b0;
                        crc_error   <= 1'b0;
                        form_error  <= 1'b0;
                        ack_error   <= 1'b0;
                    end

                    4'd2:
                    begin
                        bit_error   <= 1'b0;
                        stuff_error <= 1'b1;
                        crc_error   <= 1'b0;
                        form_error  <= 1'b0;
                        ack_error   <= 1'b0;
                    end

                    4'd3:
                    begin
                        bit_error   <= 1'b0;
                        stuff_error <= 1'b0;
                        crc_error   <= 1'b1;
                        form_error  <= 1'b0;
                        ack_error   <= 1'b0;
                    end

                    4'd4:
                    begin
                        bit_error   <= 1'b0;
                        stuff_error <= 1'b0;
                        crc_error   <= 1'b0;
                        form_error  <= 1'b1;
                        ack_error   <= 1'b0;
                    end

                    4'd5:
                    begin
                        bit_error   <= 1'b0;
                        stuff_error <= 1'b0;
                        crc_error   <= 1'b0;
                        form_error  <= 1'b0;
                        ack_error   <= 1'b1;
                    end

                    default:
                    begin
                        bit_error   <= 1'b0;
                        stuff_error <= 1'b0;
                        crc_error   <= 1'b0;
                        form_error  <= 1'b0;
                        ack_error   <= 1'b0;
                    end

                endcase
            end
            else
            begin
                /*
                 * Error indicators are event pulses, not persistent
                 * levels.
                 */
                bit_error   <= 1'b0;
                stuff_error <= 1'b0;
                crc_error   <= 1'b0;
                form_error  <= 1'b0;
                ack_error   <= 1'b0;
            end
        end
    end

endmodule
