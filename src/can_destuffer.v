`timescale 1ns/1ps

module can_destuffer(
    input wire       clk,
    input wire       rst_n,

    input wire       bit_en,
    input wire [3:0] state,

    input wire       rx_bit,
    input wire       stuff_en,

    output reg       rx_bit_destuffed,
    output reg       rx_bit_valid,

    output reg       stuff_error
);

    localparam SOF = 4'd1;

    /*
     * prev_bit:
     * Last logical bit that was accepted.
     *
     * count:
     * Number of consecutive identical logical bits.
     *
     * stuff_pending:
     * The previous logical bit completed a run of five.
     * Therefore the CURRENT physical bit must be the
     * complementary stuff bit.
     */
    reg       prev_bit;
    reg [2:0] count;
    reg       stuff_pending;


    /*
     * =========================================================
     * CURRENT RX BIT
     * =========================================================
     */

    always @(*)
    begin
        rx_bit_destuffed = rx_bit;
        rx_bit_valid     = 1'b0;
        stuff_error      = 1'b0;

        if (bit_en)
        begin

            /*
             * -------------------------------------------------
             * SOF
             * -------------------------------------------------
             *
             * SOF is always a normal logical bit.
             */
            if (state == SOF)
            begin
                rx_bit_destuffed = rx_bit;
                rx_bit_valid     = 1'b1;
            end

            /*
             * -------------------------------------------------
             * STUFFED REGION
             * -------------------------------------------------
             */
            else if (stuff_en)
            begin

                /*
                 * The previous logical bit completed a run
                 * of five identical bits.
                 *
                 * Therefore this physical bit is the stuff bit.
                 */
                if (stuff_pending)
                begin
                    rx_bit_valid = 1'b0;

                    /*
                     * Stuff bit must be complementary to the
                     * previous logical bit.
                     */
                    if (rx_bit == prev_bit)
                        stuff_error = 1'b1;
                end

                /*
                 * Normal logical bit.
                 */
                else
                begin
                    rx_bit_destuffed = rx_bit;
                    rx_bit_valid     = 1'b1;
                end
            end

            /*
             * -------------------------------------------------
             * STUFFING DISABLED
             * -------------------------------------------------
             */
            else
            begin
                rx_bit_destuffed = rx_bit;
                rx_bit_valid     = 1'b1;
            end

        end

    end


    /*
     * =========================================================
     * DESTUFFER STATE
     * =========================================================
     */

    always @(posedge clk or negedge rst_n)
    begin

        if (!rst_n)
        begin
            prev_bit     <= 1'b1;
            count        <= 3'd0;
            stuff_pending <= 1'b0;
        end

        else if (bit_en)
        begin

            /*
             * -------------------------------------------------
             * SOF
             * -------------------------------------------------
             */
            if (state == SOF)
            begin
                prev_bit      <= rx_bit;
                count         <= 3'd1;
                stuff_pending <= 1'b0;
            end

            /*
             * -------------------------------------------------
             * STUFFED REGION
             * -------------------------------------------------
             */
            else if (stuff_en)
            begin

                /*
                 * ------------------------------------------------
                 * Current physical bit is the required stuff bit.
                 * ------------------------------------------------
                 */
                if (stuff_pending)
                begin
                    /*
                     * The stuff bit is NOT a logical bit.
                     *
                     * Do not update prev_bit.
                     * Do not count the stuff bit.
                     */
                    prev_bit      <= prev_bit;
                    count         <= 3'd0;
                    stuff_pending <= 1'b0;
                end

                /*
                 * ------------------------------------------------
                 * Normal logical bit.
                 * ------------------------------------------------
                 */
                else
                begin

                    /*
                     * Same as previous logical bit.
                     */
                    if (rx_bit == prev_bit)
                    begin
                        prev_bit <= prev_bit;

                        /*
                         * This bit makes the run length five.
                         *
                         * The NEXT physical bit must therefore
                         * be the complementary stuff bit.
                         */
                        if (count == 3'd4)
                        begin
                            count         <= 3'd5;
                            stuff_pending <= 1'b1;
                        end

                        else
                        begin
                            count         <= count + 3'd1;
                            stuff_pending <= 1'b0;
                        end
                    end

                    /*
                     * Different from previous logical bit.
                     *
                     * Start a new run.
                     */
                    else
                    begin
                        prev_bit      <= rx_bit;
                        count         <= 3'd1;
                        stuff_pending <= 1'b0;
                    end

                end

            end

            /*
             * -------------------------------------------------
             * STUFFING DISABLED
             * -------------------------------------------------
             *
             * The logical stream is no longer stuffed.
             * Start a fresh run so that an old stuffing sequence
             * cannot leak into a later stuffed region.
             */
            else
            begin
                prev_bit      <= rx_bit;
                count         <= 3'd1;
                stuff_pending <= 1'b0;
            end

        end

    end

endmodule
