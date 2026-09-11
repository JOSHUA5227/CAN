module can_frame_controller(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_en,

    input  wire        can_rx_sync,
    input  wire        sof_detected,

    input  wire        tx_request,
    input  wire        rtr,
    input  wire        ide,
    input  wire [3:0]  dlc,

    input  wire        bit_error,
    input  wire        error_event,
    input  wire        error_flag_request,
    input  wire        stuff_insert,
    input  wire        rx_bit_valid,

    input  wire        rx_rtr,
    input  wire [3:0]  rx_dlc,
    input  wire [1:0]  error_state,

    output reg         ack_drive,
    output reg         arb_phase,
    output reg         is_transmitting,

    output wire [3:0]  field_sel,
    output reg  [5:0]  bit_cnt,
    output reg  [2:0]  byte_idx,

    output reg         crc_en,
    output reg         stuff_en,

    output wire        bit_error_occured,
    output wire        arbitration_lost,
    output reg         active_ide,

    output reg         tx_done,
    output reg         rx_done,
    output reg         line_busy
);


/* =============================================================
 * STATES
 * ============================================================= */

localparam IDLE           = 4'd0;
localparam SOF            = 4'd1;
localparam ARBITRATION    = 4'd2;
localparam CONTROL        = 4'd3;
localparam DATA           = 4'd4;
localparam CRC            = 4'd5;
localparam CRC_DELIM      = 4'd6;
localparam ACK            = 4'd7;
localparam ACK_DELIM      = 4'd8;
localparam EOF            = 4'd9;
localparam INTERMISSION   = 4'd10;
localparam ERROR_FLAG     = 4'd11;
localparam WAIT_RECESSIVE = 4'd12;
localparam ERROR_DELIM    = 4'd13;
localparam RX_ONLY        = 4'd14;

/*
 * CAN 2.0B:
 *
 * Error-passive transmitter must send eight recessive bits
 * after INTERMISSION before recognizing the bus as idle.
 */
localparam SUSPEND_TRANSMISSION = 4'd15;

localparam ERROR_ACTIVE  = 2'd0;
localparam ERROR_PASSIVE = 2'd1;
localparam BUS_OFF       = 2'd2;


/* =============================================================
 * FRAME LENGTHS
 * ============================================================= */

localparam ARB_PHASE1_LEN = 6'd13;
localparam ARB_PHASE2_LEN = 6'd19;

localparam CTRL_LEN_STD = 6'd5;
localparam CTRL_LEN_EXT = 6'd6;

localparam CRC_LEN          = 6'd15;
localparam EOF_LEN          = 6'd7;
localparam INTERMISSION_LEN = 6'd3;
localparam ERROR_FLAG_LEN   = 6'd6;
localparam ERROR_DELIM_LEN  = 6'd8;
localparam SUSPEND_LEN      = 6'd8;


/* =============================================================
 * STATE REGISTERS
 * ============================================================= */

reg [3:0] present_state;
reg [3:0] next_state;

reg [5:0] next_bit_cnt;
reg [2:0] next_byte_idx;

reg       next_arb_phase;
reg       next_is_transmitting;
reg       next_active_ide;


/* =============================================================
 * SUSPEND TRANSMISSION CONTROL
 * ============================================================= */

reg suspend_required;


/* =============================================================
 * FIELD OUTPUT
 * ============================================================= */

assign field_sel = present_state;


/* =============================================================
 * ARBITRATION LOSS
 * ============================================================= */

/*
 * Losing arbitration is NOT an error.
 *
 * If we transmitted recessive but observed dominant during
 * arbitration, we stop transmitting and become a receiver.
 */

wire arbitration_loss;

assign arbitration_loss =
    (present_state == ARBITRATION) &&
    is_transmitting &&
    bit_error;

/*
 * Export arbitration loss for the top-level status path.
 *
 * This is a pulse corresponding to the arbitration-loss
 * detection condition.
 */

assign arbitration_lost = arbitration_loss;


/* =============================================================
 * TRANSMITTER BIT ERROR
 * ============================================================= */

/*
 * Arbitration loss must not be reported as a transmitter error.
 */

assign bit_error_occured =
    (present_state != ARBITRATION) &&
    is_transmitting &&
    bit_error;


/* =============================================================
 * STATE REGISTER
 * ============================================================= */

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        present_state <= IDLE;
    else if (bit_en)
        present_state <= next_state;
end


/* =============================================================
 * REGISTERED OUTPUT / CONTROL LOGIC
 * ============================================================= */

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        bit_cnt          <= 6'd0;
        byte_idx         <= 3'd0;
        arb_phase        <= 1'b0;
        is_transmitting  <= 1'b0;
        active_ide       <= 1'b0;

        ack_drive        <= 1'b0;

        crc_en           <= 1'b0;
        stuff_en         <= 1'b0;

        tx_done          <= 1'b0;
        rx_done          <= 1'b0;
        line_busy        <= 1'b0;

        suspend_required <= 1'b0;
    end
    else
    begin
        /*
         * Completion signals are pulses.
         */
        tx_done <= 1'b0;
        rx_done <= 1'b0;


        /* =====================================================
         * ACK DRIVE
         * ===================================================== */

        ack_drive <= 1'b0;

        /*
         * A receiver drives dominant during ACK.
         *
         * Error-passive receivers still acknowledge frames.
         * Bus-off nodes do not drive the bus.
         */
        if ((present_state == ACK) &&
            !is_transmitting &&
            (error_state != BUS_OFF))
        begin
            ack_drive <= 1'b1;
        end


        /* =====================================================
         * BIT STUFFING ENABLE
         * ===================================================== */

        case (present_state)

            SOF,
            ARBITRATION,
            CONTROL,
            DATA,
            CRC,
            RX_ONLY:
                stuff_en <= 1'b1;

            default:
                stuff_en <= 1'b0;

        endcase


        /* =====================================================
         * CRC ENABLE
         * ===================================================== */

        case (present_state)

            SOF,
            ARBITRATION,
            CONTROL,
            DATA:
                crc_en <= 1'b1;

            CRC:
                crc_en <= !is_transmitting;

            default:
                crc_en <= 1'b0;

        endcase


        /* =====================================================
         * BIT-BOUNDARY STATE UPDATES
         * ===================================================== */

        if (bit_en)
        begin
            bit_cnt         <= next_bit_cnt;
            byte_idx        <= next_byte_idx;
            arb_phase       <= next_arb_phase;
            is_transmitting <= next_is_transmitting;
            active_ide      <= next_active_ide;
        end


        /* =====================================================
         * LINE BUSY
         * ===================================================== */

        /*
         * Suspend transmission is still part of the current
         * frame's interframe handling, therefore line_busy
         * remains asserted until IDLE.
         */
        line_busy <= (present_state != IDLE);


        /* =====================================================
         * FRAME COMPLETION
         * ===================================================== */

        /*
         * Completion occurs on the final EOF bit.
         */
        if (bit_en &&
            (present_state == EOF) &&
            (bit_cnt == 6'd1))
        begin
            if (is_transmitting)
                tx_done <= 1'b1;
            else
                rx_done <= 1'b1;
        end


        /* =====================================================
         * SUSPEND TRANSMISSION FLAG
         * ===================================================== */

        /*
         * If this node was the transmitter and was
         * error-passive when the frame completed, it must
         * perform the eight-bit Suspend Transmission field
         * after the three-bit INTERMISSION.
         */
        if (bit_en &&
            (present_state == EOF) &&
            (bit_cnt == 6'd1) &&
            is_transmitting &&
            (error_state == ERROR_PASSIVE))
        begin
            suspend_required <= 1'b1;
        end

        /*
         * Another node has started transmitting during suspend.
         * We are now a receiver, so the suspend requirement is
         * no longer applicable.
         */
        else if (bit_en &&
                 (present_state == SUSPEND_TRANSMISSION) &&
                 (can_rx_sync == 1'b0))
        begin
            suspend_required <= 1'b0;
        end

        /*
         * Eight suspend bits have completed.
         */
        else if (bit_en &&
                 (present_state == SUSPEND_TRANSMISSION) &&
                 (bit_cnt == 6'd1))
        begin
            suspend_required <= 1'b0;
        end

        /*
         * Normal return to IDLE also clears the flag.
         */
        else if (bit_en &&
                 (present_state == IDLE))
        begin
            suspend_required <= 1'b0;
        end

    end
end


/* =============================================================
 * NEXT-STATE / COUNTER LOGIC
 * ============================================================= */

always @*
begin

    /*
     * Default: hold everything.
     */
    next_state           = present_state;
    next_bit_cnt         = bit_cnt;
    next_byte_idx        = byte_idx;
    next_arb_phase       = arb_phase;
    next_is_transmitting = is_transmitting;
    next_active_ide      = active_ide;


    /* =========================================================
     * GLOBAL ERROR HANDLING
     * ========================================================= */

    /*
     * Error processing has priority over normal frame
     * progression.
     *
     * Suspend transmission is deliberately not allowed to
     * continue if a new error is detected.
     */
    if ((error_flag_request || error_event) &&
        (error_state != BUS_OFF) &&
        (present_state != ERROR_FLAG) &&
        (present_state != WAIT_RECESSIVE) &&
        (present_state != ERROR_DELIM))
    begin
        next_state           = ERROR_FLAG;
        next_bit_cnt         = ERROR_FLAG_LEN;
        next_byte_idx        = 3'd0;
        next_arb_phase       = 1'b0;
        next_is_transmitting = 1'b0;
        next_active_ide      = 1'b0;
    end

    else
    begin

        case (present_state)


            /* =================================================
             * IDLE
             * ================================================= */

            IDLE:
            begin
                next_bit_cnt         = 6'd0;
                next_byte_idx        = 3'd0;
                next_arb_phase       = 1'b0;
                next_is_transmitting = 1'b0;
                next_active_ide      = 1'b0;

                /*
                 * Received SOF has priority because arbitration
                 * may already have started on the bus.
                 */
                if (sof_detected ||
                    (can_rx_sync == 1'b0))
                begin
                    next_state           = ARBITRATION;
                    next_bit_cnt         = ARB_PHASE1_LEN;
                    next_is_transmitting = 1'b0;
                end

                else if (tx_request &&
                         (error_state != BUS_OFF))
                begin
                    next_state           = SOF;
                    next_bit_cnt         = 6'd1;
                    next_is_transmitting = 1'b1;
                    next_active_ide      = ide;
                end
            end


            /* =================================================
             * SOF
             * ================================================= */

            SOF:
            begin
                if (bit_en)
                begin
                    next_state     = ARBITRATION;
                    next_bit_cnt   = ARB_PHASE1_LEN;
                    next_arb_phase = 1'b0;

                    if (is_transmitting)
                        next_active_ide = ide;
                    else
                        next_active_ide = 1'b0;
                end
            end


            /* =================================================
             * ARBITRATION
             * ================================================= */

            ARBITRATION:
            begin

                /*
                 * Arbitration loss is normal CAN operation.
                 *
                 * Stop transmitting and continue receiving.
                 *
                 * IMPORTANT:
                 * The current arbitration bit has already been
                 * consumed when bit_error detects the loss.
                 * Therefore decrement bit_cnt here so that the
                 * receiver remains aligned with the winner.
                 */
  if (arbitration_loss)
  begin
      next_is_transmitting = 1'b0;
      next_state = RX_ONLY;

      if (bit_cnt > 6'd1)
          next_bit_cnt = bit_cnt - 6'd1;
      else
          next_bit_cnt = 6'd1;
  end
                /*
                 * Receiver physical stuff bit:
                 * do not consume a logical arbitration bit.
                 */
                else if (!is_transmitting &&
                         !rx_bit_valid)
                begin
                    next_state   = ARBITRATION;
                    next_bit_cnt = bit_cnt;
                end

                /*
                 * TX physical stuff bit:
                 * do not consume a logical arbitration bit.
                 */
                else if (is_transmitting &&
                         stuff_insert)
                begin
                    next_state   = ARBITRATION;
                    next_bit_cnt = bit_cnt;
                end

                else if (bit_en)
                begin

                    if (!arb_phase)
                    begin
                        /*
                         * Phase 0:
                         *
                         * 13 -> 3 : Identifier
                         * 2      : RTR/SRR
                         * 1      : IDE
                         */

                        if (bit_cnt > 6'd1)
                        begin
                            next_bit_cnt = bit_cnt - 6'd1;
                        end

                        else
                        begin

                            if (is_transmitting)
                            begin
                                next_active_ide = ide;

                                if (ide)
                                begin
                                    next_arb_phase = 1'b1;
                                    next_bit_cnt   = ARB_PHASE2_LEN;
                                end
                                else
                                begin
                                    next_arb_phase = 1'b0;
                                    next_state     = CONTROL;
                                    next_bit_cnt   = CTRL_LEN_STD;
                                end
                            end

                            else
                            begin
                                /*
                                 * Current bus sample is IDE.
                                 */
                                next_active_ide = can_rx_sync;

                                if (can_rx_sync)
                                begin
                                    next_arb_phase = 1'b1;
                                    next_bit_cnt   = ARB_PHASE2_LEN;
                                end
                                else
                                begin
                                    next_arb_phase = 1'b0;
                                    next_state     = CONTROL;
                                    next_bit_cnt   = CTRL_LEN_STD;
                                end
                            end

                        end
                    end

                    else
                    begin
                        /*
                         * Extended arbitration:
                         *
                         * 19 -> 2 : extended identifier
                         * 1      : RTR
                         */

                        if (bit_cnt > 6'd1)
                        begin
                            next_bit_cnt = bit_cnt - 6'd1;
                        end

                        else
                        begin
                            next_state      = CONTROL;
                            next_bit_cnt    = CTRL_LEN_EXT;
                            next_arb_phase  = 1'b0;
                            next_active_ide = 1'b1;
                        end
                    end

                end
            end


            /* =================================================
             * CONTROL
             * ================================================= */

            CONTROL:
            begin

                /*
                 * RX physical stuff bit.
                 */
                if (!is_transmitting &&
                    !rx_bit_valid)
                begin
                    next_state   = CONTROL;
                    next_bit_cnt = bit_cnt;
                end

                /*
                 * TX inserted stuff bit.
                 */
                else if (is_transmitting &&
                         stuff_insert)
                begin
                    next_state   = CONTROL;
                    next_bit_cnt = bit_cnt;
                end

                else if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin

                        if (is_transmitting)
                        begin

                            /*
                             * Remote frame or DLC=0:
                             * no DATA field.
                             */
                            if (rtr ||
                                (dlc == 4'd0))
                            begin
                                next_state   = CRC;
                                next_bit_cnt = CRC_LEN;
                            end

                            else
                            begin
                                next_state    = DATA;
                                next_bit_cnt  = 6'd8;
                                next_byte_idx = 3'd0;
                            end
                        end

                        else
                        begin

                            /*
                             * rx_dlc[0] is updated on this same
                             * clock edge by the RX datapath.
                             *
                             * Therefore use the current sampled
                             * bus bit for DLC[0].
                             */
                            if (rx_rtr ||
                                ({rx_dlc[3:1],
                                  can_rx_sync} == 4'd0))
                            begin
                                next_state   = CRC;
                                next_bit_cnt = CRC_LEN;
                            end

                            else
                            begin
                                next_state    = DATA;
                                next_bit_cnt  = 6'd8;
                                next_byte_idx = 3'd0;
                            end
                        end

                    end
                end
            end


            /* =================================================
             * DATA
             * ================================================= */

            DATA:
            begin

                /*
                 * RX physical stuff bit.
                 */
                if (!is_transmitting &&
                    !rx_bit_valid)
                begin
                    next_state   = DATA;
                    next_bit_cnt = bit_cnt;
                end

                /*
                 * TX physical stuff bit.
                 */
                else if (is_transmitting &&
                         stuff_insert)
                begin
                    next_state   = DATA;
                    next_bit_cnt = bit_cnt;
                end

                else if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin

                        if (is_transmitting)
                        begin

                            if ((byte_idx + 3'd1) >= dlc)
                            begin
                                next_state   = CRC;
                                next_bit_cnt = CRC_LEN;
                            end

                            else
                            begin
                                next_state    = DATA;
                                next_bit_cnt  = 6'd8;
                                next_byte_idx = byte_idx + 3'd1;
                            end
                        end

                        else
                        begin

                            if ((byte_idx + 3'd1) >= rx_dlc)
                            begin
                                next_state   = CRC;
                                next_bit_cnt = CRC_LEN;
                            end

                            else
                            begin
                                next_state    = DATA;
                                next_bit_cnt  = 6'd8;
                                next_byte_idx = byte_idx + 3'd1;
                            end
                        end

                    end
                end
            end


            /* =================================================
             * CRC
             * ================================================= */

            CRC:
            begin

                /*
                 * CRC field is stuffed.
                 *
                 * A physical stuff bit does not consume one
                 * of the 15 logical CRC bits.
                 */
                if (!is_transmitting &&
                    !rx_bit_valid)
                begin
                    next_state   = CRC;
                    next_bit_cnt = bit_cnt;
                end

                else if (is_transmitting &&
                         stuff_insert)
                begin
                    next_state   = CRC;
                    next_bit_cnt = bit_cnt;
                end

                else if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin
                        next_state   = CRC_DELIM;
                        next_bit_cnt = 6'd1;
                    end
                end
            end


            /* =================================================
             * CRC DELIMITER
             * ================================================= */

            CRC_DELIM:
            begin
                if (bit_en)
                begin
                    next_state   = ACK;
                    next_bit_cnt = 6'd1;
                end
            end


            /* =================================================
             * ACK
             * ================================================= */

            ACK:
            begin
                if (bit_en)
                begin
                    next_state   = ACK_DELIM;
                    next_bit_cnt = 6'd1;
                end
            end


            /* =================================================
             * ACK DELIMITER
             * ================================================= */

            ACK_DELIM:
            begin
                if (bit_en)
                begin
                    next_state   = EOF;
                    next_bit_cnt = EOF_LEN;
                end
            end


            /* =================================================
             * EOF
             * ================================================= */

            EOF:
            begin

                /*
                 * EOF is seven recessive bits.
                 */
                if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin
                        /*
                         * Always enter the normal three-bit
                         * INTERMISSION first.
                         *
                         * If this was an error-passive TX,
                         * suspend_required was latched above.
                         */
                        next_state   = INTERMISSION;
                        next_bit_cnt = INTERMISSION_LEN;
                    end
                end
            end


            /* =================================================
             * INTERMISSION
             * ================================================= */

            INTERMISSION:
            begin

                /*
                 * Three recessive bits.
                 */
                if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin

                        /*
                         * ERROR-PASSIVE TRANSMITTER:
                         *
                         * After INTERMISSION, send eight
                         * additional recessive bits.
                         */
                        if (suspend_required)
                        begin
                            next_state   = SUSPEND_TRANSMISSION;
                            next_bit_cnt = SUSPEND_LEN;
                        end

                        else
                        begin
                            next_state           = IDLE;
                            next_bit_cnt         = 6'd0;
                            next_byte_idx        = 3'd0;
                            next_arb_phase       = 1'b0;
                            next_is_transmitting = 1'b0;
                            next_active_ide      = 1'b0;
                        end

                    end
                end
            end


            /* =================================================
             * SUSPEND TRANSMISSION
             * ================================================= */

            SUSPEND_TRANSMISSION:
            begin

                /*
                 * During Suspend Transmission this node must
                 * transmit only recessive bits.
                 *
                 * is_transmitting is forced low, which also
                 * means the existing top-level TX datapath will
                 * release the CAN bus.
                 */
                next_is_transmitting = 1'b0;
                next_active_ide      = 1'b0;
                next_arb_phase       = 1'b0;

                /*
                 * If another station starts transmitting during
                 * Suspend Transmission, its dominant SOF means
                 * that this node becomes the receiver.
                 */
                if (can_rx_sync == 1'b0)
                begin
                    next_state   = ARBITRATION;
                    next_bit_cnt = ARB_PHASE1_LEN;
                end

                else if (bit_en)
                begin

                    /*
                     * Continue counting the eight recessive
                     * suspend bits.
                     */
                    if (bit_cnt > 6'd1)
                    begin
                        next_state   = SUSPEND_TRANSMISSION;
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin
                        /*
                         * Eight suspend bits complete.
                         * The bus may now be recognized as idle.
                         */
                        next_state           = IDLE;
                        next_bit_cnt         = 6'd0;
                        next_byte_idx        = 3'd0;
                        next_arb_phase       = 1'b0;
                        next_is_transmitting = 1'b0;
                        next_active_ide      = 1'b0;
                    end
                end
            end


            /* =================================================
             * ERROR FLAG
             * ================================================= */

            ERROR_FLAG:
            begin

                /*
                 * Six dominant bits.
                 */
                if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin
                        next_state   = WAIT_RECESSIVE;
                        next_bit_cnt = 6'd1;
                    end
                end
            end


            /* =================================================
             * WAIT RECESSIVE
             * ================================================= */

            WAIT_RECESSIVE:
            begin

                /*
                 * Remain here while the bus is dominant.
                 */
                if (can_rx_sync == 1'b0)
                begin
                    next_state   = WAIT_RECESSIVE;
                    next_bit_cnt = 6'd1;
                end

                else if (bit_en)
                begin
                    next_state   = ERROR_DELIM;
                    next_bit_cnt = ERROR_DELIM_LEN;
                end
            end


            /* =================================================
             * ERROR DELIMITER
             * ================================================= */

            ERROR_DELIM:
            begin

                /*
                 * Eight recessive bits.
                 */
                if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin
                        next_state   = INTERMISSION;
                        next_bit_cnt = INTERMISSION_LEN;
                    end
                end
            end


            /* =================================================
             * RX ONLY
             * ================================================= */

            RX_ONLY:
            begin

                /*
                 * Arbitration loser remains a receiver.
                 */
                next_is_transmitting = 1'b0;

                /*
                 * RX physical stuff bit.
                 */
                if (!rx_bit_valid)
                begin
                    next_state   = RX_ONLY;
                    next_bit_cnt = bit_cnt;
                end

                else if (bit_en)
                begin

                    if (!arb_phase)
                    begin

                        /*
                         * Phase 0.
                         */
                        if (bit_cnt > 6'd1)
                        begin
                            next_bit_cnt = bit_cnt - 6'd1;
                        end

                        else
                        begin

                            /*
                             * Current sampled bus value is IDE.
                             */
                            next_active_ide = can_rx_sync;

                            if (can_rx_sync)
                            begin
                                next_arb_phase = 1'b1;
                                next_bit_cnt   = ARB_PHASE2_LEN;
                            end

                            else
                            begin
                                next_arb_phase = 1'b0;
                                next_state     = CONTROL;
                                next_bit_cnt   = CTRL_LEN_STD;
                            end
                        end
                    end

                    else
                    begin

                        /*
                         * Extended arbitration phase.
                         */
                        if (bit_cnt > 6'd1)
                        begin
                            next_bit_cnt = bit_cnt - 6'd1;
                        end

                        else
                        begin
                            next_state      = CONTROL;
                            next_bit_cnt    = CTRL_LEN_EXT;
                            next_arb_phase  = 1'b0;
                            next_active_ide = 1'b1;
                        end
                    end
                end
            end


            /* =================================================
             * DEFAULT
             * ================================================= */

            default:
            begin
                next_state           = IDLE;
                next_bit_cnt         = 6'd0;
                next_byte_idx        = 3'd0;
                next_arb_phase       = 1'b0;
                next_is_transmitting = 1'b0;
                next_active_ide      = 1'b0;
            end

        endcase

    end

end

endmodule
