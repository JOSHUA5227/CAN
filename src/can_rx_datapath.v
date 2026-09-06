`timescale 1ns/1ps

module can_rx_datapath(

    input wire        clk,
    input wire        rst_n,

    input wire        bit_en,

    input wire [3:0]  state,
    input wire [5:0]  bit_cnt,
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


    /*
     * =========================================================
     * CAN FRAME STATES
     * =========================================================
     */

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
     * =========================================================
     * ARBITRATION STORAGE
     * =========================================================
     *
     * PHASE 0:
     *
     *   bit 13 ... 3 = 11-bit base identifier
     *   bit 2        = RTR (standard) / SRR (extended)
     *   bit 1        = IDE
     *
     * PHASE 1 (extended only):
     *
     *   bit 19 ... 2 = extended identifier [17:0]
     *   bit 1        = RTR
     */

    reg [10:0] arb_base_id;
    reg [17:0] arb_extended_id;


    /*
     * =========================================================
     * RX DATA BYTE INDEX
     * =========================================================
     */

    reg [2:0] rx_byte_idx;


    /*
     * =========================================================
     * RX SEQUENTIAL LOGIC
     * =========================================================
     */

    always @(posedge clk or negedge rst_n)
    begin

        if (!rst_n)
        begin
            arb_base_id    <= 11'd0;
            arb_extended_id <= 18'd0;

            rx_byte_idx <= 3'd0;

            rx_identifier <= 29'd0;
            rx_rtr        <= 1'b0;
            rx_ide        <= 1'b0;
            rx_dlc        <= 4'd0;

            rx_data <= 64'd0;

            rx_frame_valid <= 1'b0;
        end

        else
        begin

            /*
             * One-clock pulse.
             */

            rx_frame_valid <= 1'b0;


            /*
             * =================================================
             * SOF
             * =================================================
             */

            if (bit_en && (state == SOF))
            begin

                arb_base_id     <= 11'd0;
                arb_extended_id <= 18'd0;

                rx_byte_idx <= 3'd0;

                rx_identifier <= 29'd0;
                rx_rtr        <= 1'b0;
                rx_ide        <= 1'b0;
                rx_dlc        <= 4'd0;

                rx_data <= 64'd0;

            end


            /*
             * =================================================
             * EOF
             * =================================================
             *
             * EOF is not stuffed.
             */

            else if (bit_en &&
                     (state == EOF) &&
                     (bit_cnt == 6'd1))
            begin
                rx_frame_valid <= 1'b1;
            end


            /*
             * =================================================
             * LOGICAL RX BIT
             * =================================================
             *
             * A stuff bit has rx_bit_valid = 0 and therefore
             * does not enter the RX datapath.
             */

            else if (bit_en && rx_bit_valid)
            begin

                case (state)


                    /*
                     * =================================================
                     * ARBITRATION
                     * =================================================
                     */

                    ARBITRATION,
                    RX_ONLY:
                    begin

                        /*
                         * -----------------------------------------
                         * PHASE 0
                         * -----------------------------------------
                         *
                         * bit 13 ... 3 = base identifier
                         * bit 2        = RTR / SRR
                         * bit 1        = IDE
                         *
                         * We do NOT use active_ide to decide where
                         * these first 11 bits go.
                         *
                         * IDE has not been received yet.
                         */

                        if (!arb_phase)
                        begin

                            /*
                             * Base identifier
                             *
                             * bit_cnt 13 -> ID[10]
                             * bit_cnt 12 -> ID[9]
                             * ...
                             * bit_cnt 3  -> ID[0]
                             */

                            if ((bit_cnt >= 6'd3) &&
                                (bit_cnt <= 6'd13))
                            begin

                                arb_base_id[
                                    bit_cnt - 6'd3
                                ] <= rx_bit_destuffed;

                            end


                            /*
                             * Standard RTR
                             *
                             * bit_cnt = 2
                             *
                             * For an extended frame this is SRR,
                             * so it must not become rx_rtr.
                             *
                             * active_ide is still the previous
                             * frame-format indication here, but
                             * for a normal receiver entering a new
                             * frame it is 0. The definitive frame
                             * format is established by IDE below.
                             */

                            if ((bit_cnt == 6'd2) &&
                                !active_ide)
                            begin
                                rx_rtr <= rx_bit_destuffed;
                            end


                            /*
                             * IDE
                             *
                             * bit_cnt = 1
                             *
                             * This is the bit that determines
                             * standard vs extended format.
                             */

                            if (bit_cnt == 6'd1)
                            begin

                                rx_ide <= rx_bit_destuffed;

                                /*
                                 * Standard frame:
                                 *
                                 * The complete identifier is
                                 * already in arb_base_id.
                                 */

                                if (!rx_bit_destuffed)
                                begin
                                    rx_identifier <=
                                        {18'd0, arb_base_id};
                                end

                                /*
                                 * Extended frame:
                                 *
                                 * The base ID becomes bits [28:18].
                                 * The lower 18 bits arrive in phase 1.
                                 */

                                else
                                begin
                                    rx_identifier <=
                                        {arb_base_id, 18'd0};
                                end

                            end

                        end


                        /*
                         * -----------------------------------------
                         * PHASE 1 - EXTENDED ID
                         * -----------------------------------------
                         *
                         * bit 19 ... 2 = ID[17:0]
                         * bit 1        = RTR
                         */

                        else
                        begin

                            /*
                             * Extended identifier
                             *
                             * bit_cnt 19 -> ID[17]
                             * ...
                             * bit_cnt 2  -> ID[0]
                             */

                            if ((bit_cnt >= 6'd2) &&
                                (bit_cnt <= 6'd19))
                            begin

                                arb_extended_id[
                                    bit_cnt - 6'd2
                                ] <= rx_bit_destuffed;

                            end


                            /*
                             * Extended RTR
                             *
                             * bit_cnt = 1
                             *
                             * The lower 18 ID bits have all already
                             * been received.
                             */

                            if (bit_cnt == 6'd1)
                            begin

                                rx_rtr <= rx_bit_destuffed;

                                rx_identifier <=
                                    {
                                        arb_base_id,
                                        arb_extended_id
                                    };

                            end

                        end

                    end


                    /*
                     * =================================================
                     * CONTROL
                     * =================================================
                     *
                     * STANDARD:
                     *
                     *   5 -> r0
                     *   4 -> DLC[3]
                     *   3 -> DLC[2]
                     *   2 -> DLC[1]
                     *   1 -> DLC[0]
                     *
                     * EXTENDED:
                     *
                     *   6 -> r1
                     *   5 -> r0
                     *   4 -> DLC[3]
                     *   3 -> DLC[2]
                     *   2 -> DLC[1]
                     *   1 -> DLC[0]
                     */

                    CONTROL:
                    begin

                        case (bit_cnt)

                            6'd4:
                                rx_dlc[3] <= rx_bit_destuffed;

                            6'd3:
                                rx_dlc[2] <= rx_bit_destuffed;

                            6'd2:
                                rx_dlc[1] <= rx_bit_destuffed;

                            6'd1:
                                rx_dlc[0] <= rx_bit_destuffed;

                            default:
                            begin
                                /*
                                 * bit 5 = r0
                                 *
                                 * bit 6 = r1 for extended frames.
                                 *
                                 * Reserved bits are not stored.
                                 */
                            end

                        endcase

                    end


                    /*
                     * =================================================
                     * DATA
                     * =================================================
                     *
                     * MSB first.
                     */

                    DATA:
                    begin

                        if (rx_byte_idx <= 3'd7)
                        begin

                            case (bit_cnt)

                                6'd8:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 0
                                    ] <= rx_bit_destuffed;

                                6'd7:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 1
                                    ] <= rx_bit_destuffed;

                                6'd6:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 2
                                    ] <= rx_bit_destuffed;

                                6'd5:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 3
                                    ] <= rx_bit_destuffed;

                                6'd4:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 4
                                    ] <= rx_bit_destuffed;

                                6'd3:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 5
                                    ] <= rx_bit_destuffed;

                                6'd2:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 6
                                    ] <= rx_bit_destuffed;

                                6'd1:
                                    rx_data[
                                        63 - (rx_byte_idx * 8) - 7
                                    ] <= rx_bit_destuffed;

                                default:
                                begin
                                end

                            endcase


                            /*
                             * Last bit of this byte.
                             */

                            if (bit_cnt == 6'd1)
                            begin
                                rx_byte_idx <= rx_byte_idx + 3'd1;
                            end

                        end

                    end


                    /*
                     * =================================================
                     * OTHER STATES
                     * =================================================
                     */

                    default:
                    begin
                    end

                endcase

            end

        end

    end

endmodule
