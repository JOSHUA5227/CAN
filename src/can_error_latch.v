module can_error_latch (

    input wire        clk,
    input wire        rst_n,

    /*
     * CAN error/event inputs.
     *
     * IMPORTANT:
     * arbitration_lost is checked BEFORE bit_error because
     * arbitration loss is detected using the bit-error comparison
     * while the controller is in the ARBITRATION state.
     *
     * Therefore arbitration_lost and bit_error may be high
     * simultaneously, but arbitration loss must be reported as
     * a separate event and NOT as a bit error.
     */
    input wire        arbitration_lost,

    input wire        bit_error,
    input wire        stuff_error,
    input wire        crc_error,
    input wire        form_error,
    input wire        ack_error,

    /*
     * Last event information.
     *
     * The existing signal names are retained for compatibility
     * with the rest of the design.
     */
    output reg        last_error_valid,
    output reg [3:0]  last_error_type,

    /*
     * Toggles whenever a new error/event is detected.
     */
    output reg        error_event_toggle
);


/* ================================================================
 * EVENT TYPE DEFINITIONS
 * ================================================================ */

localparam ERROR_NONE    = 4'd0;
localparam ERROR_BIT     = 4'd1;
localparam ERROR_STUFF   = 4'd2;
localparam ERROR_CRC     = 4'd3;
localparam ERROR_FORM    = 4'd4;
localparam ERROR_ACK     = 4'd5;

/*
 * Arbitration loss is deliberately given its own event code.
 *
 * It is NOT a CAN error and must NOT modify TEC/REC.
 */
localparam EVENT_ARB_LOST = 4'd6;


/* ================================================================
 * EVENT LATCH
 * ================================================================ */

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        last_error_valid   <= 1'b0;
        last_error_type    <= ERROR_NONE;
        error_event_toggle <= 1'b0;
    end
    else
    begin

        /*
         * --------------------------------------------------------
         * ARBITRATION LOSS
         * --------------------------------------------------------
         *
         * This MUST have priority over bit_error.
         *
         * The frame controller detects arbitration loss when:
         *
         *     present_state == ARBITRATION
         *     is_transmitting == 1
         *     bit_error == 1
         *
         * Therefore bit_error can also be asserted.
         *
         * Arbitration loss is a normal non-destructive CAN event,
         * not a transmitter error.
         */
        if(arbitration_lost)
        begin
            last_error_valid   <= 1'b1;
            last_error_type    <= EVENT_ARB_LOST;
            error_event_toggle <= ~error_event_toggle;
        end

        /*
         * --------------------------------------------------------
         * BIT ERROR
         * --------------------------------------------------------
         */
        else if(bit_error)
        begin
            last_error_valid   <= 1'b1;
            last_error_type    <= ERROR_BIT;
            error_event_toggle <= ~error_event_toggle;
        end

        /*
         * --------------------------------------------------------
         * STUFF ERROR
         * --------------------------------------------------------
         */
        else if(stuff_error)
        begin
            last_error_valid   <= 1'b1;
            last_error_type    <= ERROR_STUFF;
            error_event_toggle <= ~error_event_toggle;
        end

        /*
         * --------------------------------------------------------
         * CRC ERROR
         * --------------------------------------------------------
         */
        else if(crc_error)
        begin
            last_error_valid   <= 1'b1;
            last_error_type    <= ERROR_CRC;
            error_event_toggle <= ~error_event_toggle;
        end

        /*
         * --------------------------------------------------------
         * FORM ERROR
         * --------------------------------------------------------
         */
        else if(form_error)
        begin
            last_error_valid   <= 1'b1;
            last_error_type    <= ERROR_FORM;
            error_event_toggle <= ~error_event_toggle;
        end

        /*
         * --------------------------------------------------------
         * ACKNOWLEDGEMENT ERROR
         * --------------------------------------------------------
         */
        else if(ack_error)
        begin
            last_error_valid   <= 1'b1;
            last_error_type    <= ERROR_ACK;
            error_event_toggle <= ~error_event_toggle;
        end

    end
end

endmodule

