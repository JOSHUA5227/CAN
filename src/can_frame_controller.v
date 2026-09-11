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

localparam SUSPEND_TRANSMISSION = 4'd15;

localparam ERROR_ACTIVE  = 2'd0;
localparam ERROR_PASSIVE = 2'd1;
localparam BUS_OFF       = 2'd2;



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



reg [3:0] present_state;
reg [3:0] next_state;

reg [5:0] next_bit_cnt;
reg [2:0] next_byte_idx;

reg       next_arb_phase;
reg       next_is_transmitting;
reg       next_active_ide;

reg suspend_required;


assign field_sel = present_state;


wire arbitration_loss;

assign arbitration_loss =
    (present_state == ARBITRATION) &&
    is_transmitting &&
    bit_error;

assign arbitration_lost = arbitration_loss;

assign bit_error_occured =
    (present_state != ARBITRATION) &&
    is_transmitting &&
    bit_error;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        present_state <= IDLE;
    else if (bit_en)
        present_state <= next_state;
end

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
        tx_done <= 1'b0;
        rx_done <= 1'b0;

        ack_drive <= 1'b0;

        if ((present_state == ACK) &&
            !is_transmitting &&
            (error_state != BUS_OFF))
        begin
            ack_drive <= 1'b1;
        end

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

        if (bit_en)
        begin
            bit_cnt         <= next_bit_cnt;
            byte_idx        <= next_byte_idx;
            arb_phase       <= next_arb_phase;
            is_transmitting <= next_is_transmitting;
            active_ide      <= next_active_ide;
        end


        line_busy <= (present_state != IDLE);

        if (bit_en &&
            (present_state == EOF) &&
            (bit_cnt == 6'd1))
        begin
            if (is_transmitting)
                tx_done <= 1'b1;
            else
                rx_done <= 1'b1;
        end

        if (bit_en &&
            (present_state == EOF) &&
            (bit_cnt == 6'd1) &&
            is_transmitting &&
            (error_state == ERROR_PASSIVE))
        begin
            suspend_required <= 1'b1;
        end

        else if (bit_en &&
                 (present_state == SUSPEND_TRANSMISSION) &&
                 (can_rx_sync == 1'b0))
        begin
            suspend_required <= 1'b0;
        end

        else if (bit_en &&
                 (present_state == SUSPEND_TRANSMISSION) &&
                 (bit_cnt == 6'd1))
        begin
            suspend_required <= 1'b0;
        end

        else if (bit_en &&
                 (present_state == IDLE))
        begin
            suspend_required <= 1'b0;
        end

    end
end

always @(*)
begin

    next_state           = present_state;
    next_bit_cnt         = bit_cnt;
    next_byte_idx        = byte_idx;
    next_arb_phase       = arb_phase;
    next_is_transmitting = is_transmitting;
    next_active_ide      = active_ide;


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

            IDLE:
            begin
                next_bit_cnt         = 6'd0;
                next_byte_idx        = 3'd0;
                next_arb_phase       = 1'b0;
                next_is_transmitting = 1'b0;
                next_active_ide      = 1'b0;

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

            ARBITRATION:
            begin

              if (arbitration_loss)
              begin
                  next_is_transmitting = 1'b0;
                  next_state = RX_ONLY;

                  if (bit_cnt > 6'd1)
                      next_bit_cnt = bit_cnt - 6'd1;
                  else
                      next_bit_cnt = 6'd1;
              end
              else if (!is_transmitting &&
                       !rx_bit_valid)
              begin
                  next_state   = ARBITRATION;
                  next_bit_cnt = bit_cnt;
              end

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

            CONTROL:
            begin

                if (!is_transmitting &&
                    !rx_bit_valid)
                begin
                    next_state   = CONTROL;
                    next_bit_cnt = bit_cnt;
                end

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


            DATA:
            begin

                if (!is_transmitting &&
                    !rx_bit_valid)
                begin
                    next_state   = DATA;
                    next_bit_cnt = bit_cnt;
                end

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

            CRC:
            begin
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

            CRC_DELIM:
            begin
                if (bit_en)
                begin
                    next_state   = ACK;
                    next_bit_cnt = 6'd1;
                end
            end

            ACK:
            begin
                if (bit_en)
                begin
                    next_state   = ACK_DELIM;
                    next_bit_cnt = 6'd1;
                end
            end

            ACK_DELIM:
            begin
                if (bit_en)
                begin
                    next_state   = EOF;
                    next_bit_cnt = EOF_LEN;
                end
            end

            EOF:
            begin

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

            INTERMISSION:
            begin

                if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_bit_cnt = bit_cnt - 6'd1;
                    end

                    else
                    begin

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

            SUSPEND_TRANSMISSION:
            begin
                next_is_transmitting = 1'b0;
                next_active_ide      = 1'b0;
                next_arb_phase       = 1'b0;

                if (can_rx_sync == 1'b0)
                begin
                    next_state   = ARBITRATION;
                    next_bit_cnt = ARB_PHASE1_LEN;
                end

                else if (bit_en)
                begin

                    if (bit_cnt > 6'd1)
                    begin
                        next_state   = SUSPEND_TRANSMISSION;
                        next_bit_cnt = bit_cnt - 6'd1;
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

            ERROR_FLAG:
            begin
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

            WAIT_RECESSIVE:
            begin
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

            ERROR_DELIM:
            begin
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

            RX_ONLY:
            begin
                next_is_transmitting = 1'b0;

                if (!rx_bit_valid)
                begin
                    next_state   = RX_ONLY;
                    next_bit_cnt = bit_cnt;
                end

                else if (bit_en)
                begin

                    if (!arb_phase)
                    begin

                        if (bit_cnt > 6'd1)
                        begin
                            next_bit_cnt = bit_cnt - 6'd1;
                        end

                        else
                        begin
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
