module can_error_status_cdc (

    /* ========================================================
     * PCLK DOMAIN
     * ======================================================== */

    input wire        pclk,
    input wire        p_rst_n,

    /*
     * Event toggle generated in the CAN clock domain.
     */
    input wire        error_event_toggle,

    /*
     * Event information held in the CAN clock domain.
     */
    input wire        can_last_error_valid,
    input wire [3:0]  can_last_error_type,

    /*
     * PCLK-domain event status.
     */
    output reg        last_error_valid,
    output reg [3:0]  last_error_type,

    /*
     * One PCLK-cycle pulse for a new event.
     */
    output reg        error_event,

    /*
     * PCLK-domain sticky arbitration-loss status.
     */
    output reg        arbitration_lost,

    /*
     * PCLK-domain sticky error status.
     */
    output reg        bit_error,
    output reg        stuff_error,
    output reg        crc_error,
    output reg        form_error,
    output reg        ack_error
);


/* ================================================================
 * EVENT TYPE DEFINITIONS
 * ================================================================ */

localparam EVENT_BIT      = 4'd1;
localparam EVENT_STUFF    = 4'd2;
localparam EVENT_CRC      = 4'd3;
localparam EVENT_FORM     = 4'd4;
localparam EVENT_ACK      = 4'd5;
localparam EVENT_ARB_LOST = 4'd6;


/* ================================================================
 * EVENT TOGGLE SYNCHRONIZER
 * ================================================================ */

reg error_toggle_sync1;
reg error_toggle_sync2;
reg error_toggle_seen;


/* ================================================================
 * PCLK DOMAIN
 * ================================================================ */

always @(posedge pclk or negedge p_rst_n)
begin
    if(!p_rst_n)
    begin
        error_toggle_sync1 <= 1'b0;
        error_toggle_sync2 <= 1'b0;
        error_toggle_seen  <= 1'b0;

        last_error_valid   <= 1'b0;
        last_error_type    <= 4'd0;

        error_event        <= 1'b0;

        arbitration_lost   <= 1'b0;

        bit_error          <= 1'b0;
        stuff_error        <= 1'b0;
        crc_error          <= 1'b0;
        form_error         <= 1'b0;
        ack_error          <= 1'b0;
    end
    else
    begin

        /*
         * --------------------------------------------------------
         * Synchronize the event toggle.
         * --------------------------------------------------------
         */
        error_toggle_sync1 <= error_event_toggle;
        error_toggle_sync2 <= error_toggle_sync1;


        /*
         * error_event is a one-cycle PCLK pulse.
         */
        error_event <= 1'b0;


        /*
         * --------------------------------------------------------
         * Detect a new CAN-domain event.
         * --------------------------------------------------------
         */
        if(error_toggle_sync2 != error_toggle_seen)
        begin
            /*
             * Mark event as consumed.
             */
            error_toggle_seen <= error_toggle_sync2;

            /*
             * Generate one PCLK-cycle event pulse.
             */
            error_event <= 1'b1;

            /*
             * Capture event information.
             */
            last_error_valid <= can_last_error_valid;
            last_error_type  <= can_last_error_type;


            /*
             * ----------------------------------------------------
             * BIT ERROR
             * ----------------------------------------------------
             */
            if(can_last_error_type == EVENT_BIT)
            begin
                bit_error <= 1'b1;
            end


            /*
             * ----------------------------------------------------
             * STUFF ERROR
             * ----------------------------------------------------
             */
            if(can_last_error_type == EVENT_STUFF)
            begin
                stuff_error <= 1'b1;
            end


            /*
             * ----------------------------------------------------
             * CRC ERROR
             * ----------------------------------------------------
             */
            if(can_last_error_type == EVENT_CRC)
            begin
                crc_error <= 1'b1;
            end


            /*
             * ----------------------------------------------------
             * FORM ERROR
             * ----------------------------------------------------
             */
            if(can_last_error_type == EVENT_FORM)
            begin
                form_error <= 1'b1;
            end


            /*
             * ----------------------------------------------------
             * ACK ERROR
             * ----------------------------------------------------
             */
            if(can_last_error_type == EVENT_ACK)
            begin
                ack_error <= 1'b1;
            end


            /*
             * ----------------------------------------------------
             * ARBITRATION LOSS
             * ----------------------------------------------------
             *
             * Arbitration loss is not a CAN error.
             *
             * It is retained as a separate sticky status event.
             */
            if(can_last_error_type == EVENT_ARB_LOST)
            begin
                arbitration_lost <= 1'b1;
            end

        end

    end
end

endmodule
