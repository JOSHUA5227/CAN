`timescale 1ns/1ps

module error_controller(
    input wire clk,
    input wire rst_n,
    input wire bit_en,
    input wire [3:0] state,
    input wire is_transmitting,
    input wire can_rx_sync,

    input wire bit_error,
    input wire bit_error_occured,
    input wire tx_bit,
    input wire [5:0] bit_cnt,
    input wire arb_phase,
    input wire active_ide,

    input wire ack_error,
    input wire form_error,
    input wire stuff_error,
    input wire crc_error,

    input wire tx_done,
    input wire rx_done,

    output reg [8:0] tec,
    output reg [7:0] rec,
    output wire [1:0] error_state,
    output reg error_flag_active,
    output wire error_flag_request,
    output wire recovery_active
);

    localparam IDLE = 4'd0;
    localparam SOF = 4'd1;
    localparam ARBITRATION = 4'd2;
    localparam CONTROL = 4'd3;
    localparam DATA = 4'd4;
    localparam CRC = 4'd5;
    localparam CRC_DELIM = 4'd6;
    localparam ACK = 4'd7;
    localparam ACK_DELIM = 4'd8;
    localparam EOF = 4'd9;
    localparam INTERMISSION = 4'd10;
    localparam ERROR_FLAG = 4'd11;
    localparam WAIT_RECESSIVE = 4'd12;
    localparam ERROR_DELIM = 4'd13;
    localparam RX_ONLY = 4'd14;

    localparam ERROR_ACTIVE = 2'd0;
    localparam ERROR_PASSIVE = 2'd1;
    localparam BUS_OFF = 2'd2;

    reg [1:0] present_state;
    reg [1:0] next_state;

    reg error_flag_active_reg;

    reg [3:0] recovery_bit_count;
    reg [6:0] recovery_sequence_count;

    reg [4:0] dominant_count;

    reg error_flag_sent;
    reg error_flag_error_seen;

    reg [8:0] tec_next;
    reg [7:0] rec_next;

    wire error_event;
    wire bus_off_recovery;
    wire error_flag_start;

    wire transmitter_error;
    wire receiver_error;

    wire ack_error_exception;
    wire arbitration_stuff_exception;
    wire stuff_before_rtr;

    wire first_dominant_after_flag;
    wire dominant_error_plus8;

    wire recovery_bit_count_is_ten;
    wire recovery_sequence_count_is_127;

    wire tec_at_504;
    wire tec_nonzero;

    wire rec_at_248;
    wire rec_nonzero;

    wire tec_passive_limit;
    wire rec_passive_limit;

    wire successful_tx;
    wire successful_rx;

    wire receiver_error_exception;

    assign error_state = present_state;

    assign recovery_active = (present_state == BUS_OFF);

    assign error_event =
           bit_error_occured ||
           ack_error ||
           form_error ||
           stuff_error ||
           crc_error;

    assign error_flag_request =
           error_event &&
           (present_state != BUS_OFF) &&
           (state != ERROR_FLAG) &&
           (state != WAIT_RECESSIVE);

    assign error_flag_start =
           bit_en &&
           error_flag_request;

    assign transmitter_error =
           error_event &&
           is_transmitting;

    assign receiver_error =
           error_event &&
           !is_transmitting;

    assign ack_error_exception =
           ack_error &&
           is_transmitting &&
           (present_state == ERROR_PASSIVE) &&
           (state == ACK);

    assign stuff_before_rtr =
           (!arb_phase && active_ide) ||
           (!arb_phase && !active_ide && (bit_cnt > 6'd2)) ||
           (arb_phase && (bit_cnt > 6'd1));

    assign arbitration_stuff_exception =
           stuff_error &&
           is_transmitting &&
           (state == ARBITRATION) &&
           stuff_before_rtr &&
           (tx_bit == 1'b1) &&
           (bit_error == 1'b1);

    assign first_dominant_after_flag =
           bit_en &&
           error_flag_sent &&
           !error_flag_error_seen &&
           !can_rx_sync;

    assign dominant_error_plus8 =
           bit_en &&
           !can_rx_sync &&
           (
               (
                   error_flag_active_reg &&
                   (
                       (dominant_count == 5'd13) ||
                       (
                           (dominant_count > 5'd13) &&
                           (dominant_count[2:0] == 3'd5)
                       )
                   )
               ) ||
               (
                   !error_flag_active_reg &&
                   (
                       (dominant_count == 5'd7) ||
                       (
                           (dominant_count > 5'd7) &&
                           (dominant_count[2:0] == 3'd7)
                       )
                   )
               )
           );

    /*
 *      * Explicit comparison wires.
 *           */
    assign recovery_bit_count_is_ten =
           (recovery_bit_count == 4'd10);

    assign recovery_sequence_count_is_127 =
           (recovery_sequence_count == 7'd127);

    assign tec_at_504 =
           (tec >= 9'd504);

    assign tec_nonzero =
           (tec != 9'd0);

    assign rec_at_248 =
           (rec >= 8'd248);

    assign rec_nonzero =
           (rec != 8'd0);

    assign tec_passive_limit =
           (tec >= 9'd128);

    assign rec_passive_limit =
           (rec >= 8'd128);

    assign successful_tx =
           tx_done;

    assign successful_rx =
           rx_done;

    assign receiver_error_exception =
           bit_error_occured &&
           (state == ERROR_FLAG) &&
           error_flag_active_reg;

    assign bus_off_recovery =
           (present_state == BUS_OFF) &&
           bit_en &&
           recovery_bit_count_is_ten &&
           recovery_sequence_count_is_127;


    /*
 *      * =========================================================
 *           * ERROR STATE REGISTER
 *                * =========================================================
 *                     */

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
            present_state <= ERROR_ACTIVE;
        else
            present_state <= next_state;
    end


    /*
 *      * =========================================================
 *           * ERROR STATE TRANSITIONS
 *                * =========================================================
 *                     */

    always @(*)
    begin
        next_state = present_state;

        case (present_state)

            ERROR_ACTIVE:
            begin
                if (tec >= 9'd256)
                    next_state = BUS_OFF;
                else if (tec_passive_limit || rec_passive_limit)
                    next_state = ERROR_PASSIVE;
                else
                    next_state = ERROR_ACTIVE;
            end

            ERROR_PASSIVE:
            begin
                if (tec >= 9'd256)
                    next_state = BUS_OFF;
                else if ((tec <= 8'd127) && (rec <= 8'd127))
                    next_state = ERROR_ACTIVE;
                else
                    next_state = ERROR_PASSIVE;
            end

            BUS_OFF:
            begin
                if (bus_off_recovery)
                    next_state = ERROR_ACTIVE;
                else
                    next_state = BUS_OFF;
            end

            default:
                next_state = ERROR_ACTIVE;

        endcase
    end


    /*
 *      * =========================================================
 *           * ERROR FLAG TYPE
 *                * =========================================================
 *                     */

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
            error_flag_active_reg <= 1'b1;
        else if (error_flag_start)
            error_flag_active_reg <= (present_state == ERROR_ACTIVE);
    end


    always @(*)
    begin
        error_flag_active = error_flag_active_reg;
    end


    /*
 *      * =========================================================
 *           * ERROR FLAG TRACKING
 *                * =========================================================
 *                     */

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            error_flag_sent      <= 1'b0;
            error_flag_error_seen <= 1'b0;
        end
        else if ((state != ERROR_FLAG) &&
                 (state != WAIT_RECESSIVE))
        begin
            error_flag_sent       <= 1'b0;
            error_flag_error_seen <= 1'b0;
        end
        else if (bit_en)
        begin
            if (state == ERROR_FLAG)
                error_flag_sent <= 1'b1;

            if (error_event)
                error_flag_error_seen <= 1'b1;
        end
    end


    /*
 *      * =========================================================
 *           * DOMINANT ERROR FLAG COUNTING
 *                * =========================================================
 *                     */

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
            dominant_count <= 5'd0;
        else if ((state != ERROR_FLAG) &&
                 (state != WAIT_RECESSIVE))
            dominant_count <= 5'd0;
        else if (bit_en)
        begin
            if (can_rx_sync)
                dominant_count <= 5'd0;
            else if (dominant_count != 5'd31)
                dominant_count <= dominant_count + 5'd1;
        end
    end


    /*
 *      * =========================================================
 *           * BUS-OFF RECOVERY
 *                *
 *                     * 128 sequences of 11 consecutive recessive bits.
 *                          * =========================================================
 *                               */

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            recovery_bit_count      <= 4'd0;
            recovery_sequence_count <= 7'd0;
        end
        else if (present_state == BUS_OFF)
        begin
            if (bit_en)
            begin
                if (can_rx_sync)
                begin
                    if (recovery_bit_count_is_ten)
                    begin
                        recovery_bit_count <= 4'd0;

                        if (!recovery_sequence_count_is_127)
                            recovery_sequence_count <=
                                recovery_sequence_count + 7'd1;
                    end
                    else
                    begin
                        recovery_bit_count <=
                            recovery_bit_count + 4'd1;
                    end
                end
                else
                begin
                    recovery_bit_count <= 4'd0;
                end
            end
        end
        else
        begin
            recovery_bit_count      <= 4'd0;
            recovery_sequence_count <= 7'd0;
        end
    end


    /*
 *      * =========================================================
 *           * TEC / REC NEXT-STATE LOGIC
 *                * =========================================================
 *                     *
 *                          * All calculations are performed here.
 *                               *
 *                                    * TEC and REC themselves are assigned
 *                                    only once in the
 *                                         * sequential block below.
 *                                              * =========================================================
 *                                                   */

    always @(*)
    begin
        tec_next = tec;
        rec_next = rec;

        /*
 *          * -----------------------------------------------------
 *                   * BUS-OFF RECOVERY COMPLETE
 *                            * -----------------------------------------------------
 *                                     */

        if (bus_off_recovery)
        begin
            tec_next = 9'd0;
            rec_next = 8'd0;
        end

        /*
 *          * -----------------------------------------------------
 *                   * ERROR OCCURRED
 *                            * -----------------------------------------------------
 *                                     */

        else if (error_event)
        begin

            /*
 *              * -------------------------------------------------
 *                           * TRANSMITTER ERROR
 *                                        * -------------------------------------------------
 *                                                     */

            if (transmitter_error &&
                !ack_error_exception &&
                !arbitration_stuff_exception)
            begin
                if (tec_at_504)
                    tec_next = 9'd511;
                else
                    tec_next = tec + 9'd8;
            end

            /*
 *              * -------------------------------------------------
 *                           * RECEIVER ERROR
 *                                        * -------------------------------------------------
 *                                                     */

            else if (receiver_error &&
                     !receiver_error_exception)
            begin
                if (rec != 8'd255)
                    rec_next = rec + 8'd1;
            end

            /*
 *              * -------------------------------------------------
 *                           * FIRST DOMINANT BIT AFTER ERROR FLAG
 *                                        * -------------------------------------------------
 *                                                     */

            if (first_dominant_after_flag)
            begin
                if (rec_at_248)
                    rec_next = 8'd255;
                else
                    rec_next = rec + 8'd8;
            end

            /*
 *              * -------------------------------------------------
 *                           * DOMINANT ERROR FLAG EXTENSION
 *                                        * -------------------------------------------------
 *                                                     */

            if (dominant_error_plus8)
            begin
                if (is_transmitting)
                begin
                    if (tec_at_504)
                        tec_next = 9'd511;
                    else
                        tec_next = tec + 9'd8;
                end
                else
                begin
                    if (rec_at_248)
                        rec_next = 8'd255;
                    else
                        rec_next = rec + 8'd8;
                end
            end
        end

        /*
 *          * -----------------------------------------------------
 *                   * SUCCESSFUL TRANSMISSION
 *                            * -----------------------------------------------------
 *                                     */

        else if (successful_tx)
        begin
            if (tec_nonzero)
                tec_next = tec - 9'd1;
        end

        /*
 *          * -----------------------------------------------------
 *                   * SUCCESSFUL RECEPTION
 *                            * -----------------------------------------------------
 *                                     */

        else if (successful_rx)
        begin
            if (!rec_nonzero)
                rec_next = 8'd0;
            else if (rec <= 8'd127)
                rec_next = rec - 8'd1;
            else
                rec_next = 8'd127;
        end
    end


    /*
 *      * =========================================================
 *           * TEC / REC REGISTERS
 *                * =========================================================
 *                     *
 *                          * One sequential assignment per register.
 *                               * =========================================================
 *                                    */

    always @(posedge clk or negedge rst_n)
    begin
        if (!rst_n)
        begin
            tec <= 9'd0;
            rec <= 8'd0;
        end
        else if (bit_en)
        begin
            tec <= tec_next;
            rec <= rec_next;
        end
    end

endmodule
