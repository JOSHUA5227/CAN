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

    reg       prev_bit;
    reg [2:0] count;


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
             * SOF is always a normal logical bit.
             */
            if (state == SOF)
            begin
                rx_bit_destuffed = rx_bit;
                rx_bit_valid     = 1'b1;
            end

            /*
             * Stuffing is enabled.
             */
            else if (stuff_en)
            begin

                /*
                 * Five consecutive logical bits have already
                 * been received.
                 *
                 * Therefore this physical bit must be the
                 * complementary stuff bit.
                 */
                if (count == 3'd5)
                begin
                    rx_bit_valid = 1'b0;

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
             * Stuffing disabled.
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
            prev_bit <= 1'b1;
            count    <= 3'd0;
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
                prev_bit <= rx_bit;
                count    <= 3'd1;
            end

            /*
             * -------------------------------------------------
             * STUFFED REGION
             * -------------------------------------------------
             */
            else if (stuff_en)
            begin

                /*
                 * Current physical bit is the stuff bit.
                 */
                if (count == 3'd5)
                begin

                    /*
                     * Stuff bit is NOT part of the logical
                     * stream.
                     *
                     * Keep prev_bit unchanged.
                     *
                     * Reset count so the NEXT logical bit
                     * starts a new run.
                     */
                    prev_bit <= prev_bit;
                    count    <= 3'd0;

                end

                /*
                 * Normal logical bit.
                 */
                else
                begin

                    prev_bit <= rx_bit;

                    if (rx_bit == prev_bit)
                        count <= count + 3'd1;
                    else
                        count <= 3'd1;

                end

            end

            /*
             * -------------------------------------------------
             * STUFFING DISABLED
             * -------------------------------------------------
             */
            else
            begin
                prev_bit <= rx_bit;
                count    <= 3'd1;
            end

        end

    end

endmodule
