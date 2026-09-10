module can_rx_datapath(
    input wire        clk,
    input wire        rst_n,

    input wire        bit_en,

    input wire [3:0]  state,
    input wire [5:0]  bit_cnt,
    input wire [2:0]  byte_idx,
    input wire        arb_phase,
    input wire        active_ide,

    input wire        rx_bit_destuffed,
    input wire        rx_bit_valid,

    output reg [28:0] rx_identifier,
    output reg        rx_rtr,
    output reg        rx_ide,
    output reg [3:0]  rx_dlc,
    output reg [63:0] rx_data,
    output reg        rx_frame_valid
);


    /* =============================================================
     * CAN FRAME STATES
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


    /* =============================================================
     * ARBITRATION STORAGE
     * ============================================================= */

    reg [10:0] arb_base_id;
    reg [17:0] arb_extended_id;


    /* =============================================================
     * RX SEQUENTIAL LOGIC
     * ============================================================= */

    always @(posedge clk or negedge rst_n)
    begin
        if(!rst_n)
        begin
            arb_base_id     <= 11'd0;
            arb_extended_id <= 18'd0;

            rx_identifier   <= 29'd0;
            rx_rtr          <= 1'b0;
            rx_ide          <= 1'b0;
            rx_dlc          <= 4'd0;

            rx_data         <= 64'd0;

            rx_frame_valid  <= 1'b0;
        end
        else
        begin

            /*
             * rx_frame_valid is a one-clock registered pulse.
             *
             * can_controller also generates a combinational EOF
             * event for the FIFO so that the FIFO does not miss
             * the final frame write.
             */
            rx_frame_valid <= 1'b0;


            /* =====================================================
             * SOF
             * ===================================================== */

            if(bit_en &&
               (state == SOF))
            begin
                arb_base_id     <= 11'd0;
                arb_extended_id <= 18'd0;

                rx_identifier   <= 29'd0;
                rx_rtr          <= 1'b0;
                rx_ide          <= 1'b0;
                rx_dlc          <= 4'd0;

                /*
                 * Do NOT clear rx_data here.
                 *
                 * This preserves the previous RX data value for
                 * DLC=0 frames and avoids destroying valid data
                 * unnecessarily.
                 */
            end


            /* =====================================================
             * EOF
             * ===================================================== */

            else if(bit_en &&
                    (state == EOF) &&
                    (bit_cnt == 6'd1))
            begin
                rx_frame_valid <= 1'b1;
            end


            /* =====================================================
             * LOGICAL RX BIT
             * ===================================================== */

            else if(bit_en &&
                    rx_bit_valid)
            begin

                case(state)


                    /* =================================================
                     * ARBITRATION / RX_ONLY
                     * ================================================= */

                    ARBITRATION,
                    RX_ONLY:
                    begin

                        /*
                         * -------------------------------------------------
                         * PHASE 0
                         * -------------------------------------------------
                         *
                         * Standard frame:
                         *
                         * bit 13 ... 3 = Base ID
                         * bit 2        = RTR
                         * bit 1        = IDE
                         */

                        if(!arb_phase)
                        begin

                            /*
                             * Base identifier.
                             *
                             * bit_cnt 13 -> ID[10]
                             * bit_cnt 12 -> ID[9]
                             * ...
                             * bit_cnt 3  -> ID[0]
                             */

                            if((bit_cnt >= 6'd3) &&
                               (bit_cnt <= 6'd13))
                            begin
                                arb_base_id[bit_cnt - 6'd3]
                                    <= rx_bit_destuffed;
                            end


                            /*
                             * bit_cnt = 2
                             *
                             * RTR for standard frame.
                             *
                             * For extended frame this is SRR,
                             * therefore do not store it as RTR.
                             */

                            else if(bit_cnt == 6'd2)
                            begin
                                if(!active_ide)
                                begin
                                    rx_rtr <= rx_bit_destuffed;
                                end
                            end


                            /*
                             * bit_cnt = 1
                             *
                             * IDE determines standard vs extended.
                             */

                            else if(bit_cnt == 6'd1)
                            begin
                                rx_ide <= rx_bit_destuffed;


                                /*
                                 * STANDARD FRAME
                                 */

                                if(!rx_bit_destuffed)
                                begin
                                    rx_identifier <=
                                        {18'd0, arb_base_id};
                                end


                                /*
                                 * EXTENDED FRAME
                                 *
                                 * The extended identifier is completed
                                 * during the extended arbitration phase.
                                 */

                            end

                        end


                        /*
                         * -------------------------------------------------
                         * EXTENDED ARBITRATION PHASE
                         * -------------------------------------------------
                         */

                        else
                        begin

                            /*
                             * Extended ID bits.
                             *
                             * bit 18 ... 1 -> EXT_ID[17:0]
                             */

                            if((bit_cnt >= 6'd1) &&
                               (bit_cnt <= 6'd18))
                            begin
                                arb_extended_id[bit_cnt - 6'd1]
                                    <= rx_bit_destuffed;
                            end

                        end

                    end


                    /* =================================================
                     * CONTROL
                     * ================================================= */

                    CONTROL:
                    begin

                        /*
                         * DLC occupies four bits.
                         *
                         * DLC bit order:
                         *
                         * bit_cnt 4 -> DLC[3]
                         * bit_cnt 3 -> DLC[2]
                         * bit_cnt 2 -> DLC[1]
                         * bit_cnt 1 -> DLC[0]
                         */

                        if(bit_cnt == 6'd4)
                        begin
                            rx_dlc[3] <= rx_bit_destuffed;
                        end

                        else if(bit_cnt == 6'd3)
                        begin
                            rx_dlc[2] <= rx_bit_destuffed;
                        end

                        else if(bit_cnt == 6'd2)
                        begin
                            rx_dlc[1] <= rx_bit_destuffed;
                        end

                        else if(bit_cnt == 6'd1)
                        begin
                            rx_dlc[0] <= rx_bit_destuffed;
                        end

                    end


                    /* =================================================
                     * DATA
                     * ================================================= */

                    DATA:
                    begin

                        /*
                         * Data is received MSB first.
                         *
                         * The active payload is right-aligned in
                         * the 64-bit RX register.
                         *
                         * DLC=1:
                         *
                         *       00000000_000000XX
                         *
                         * DLC=2:
                         *
                         *       00000000_0000XXXX
                         *
                         * ...
                         *
                         * DLC=8:
                         *
                         *       XXXXXXXX_XXXXXXXX
                         */

                        case(rx_dlc)

                            4'd0:
                            begin
                                /*
                                 * No data field.
                                 *
                                 * Preserve rx_data.
                                 */
                            end


                            4'd1:
                            begin

                                if((byte_idx == 3'd0) &&
                                   (bit_cnt == 6'd8))
                                begin
                                    rx_data <=
                                        {56'd0, rx_bit_destuffed};
                                end
                                else
                                begin
                                    rx_data <=
                                        {rx_data[62:0],
                                         rx_bit_destuffed};
                                end

                            end


                            4'd2:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            4'd3:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            4'd4:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            4'd5:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            4'd6:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            4'd7:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            4'd8:
                            begin

                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};

                            end


                            default:
                            begin
                                /*
                                 * Invalid DLC values are not expected
                                 * because CAN 2.0B permits DLC 0..8.
                                 */
                                rx_data <=
                                    {rx_data[62:0],
                                     rx_bit_destuffed};
                            end

                        endcase

                    end


                    default:
                    begin
                        /*
                         * No RX payload operation in this field.
                         */
                    end

                endcase

            end

        end

    end

endmodule
