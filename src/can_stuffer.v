module can_stuffer(

    input wire clk,
    input wire rst_n,
    input wire bit_en,
    input wire tx_bit,
    input wire stuff_en,

    output wire tx_bit_stuffed,
    output wire stuff_insert
);

reg prev_bit;
reg [2:0] count;


/*
 * ============================================================
 * STUFF INSERTION DECISION
 * ============================================================
 *
 * count == 5 means that five consecutive identical physical
 * bits have already been transmitted.
 *
 * Therefore the CURRENT physical bit must be a stuff bit.
 */
assign stuff_insert = stuff_en && (count == 3'd5);


/*
 * ============================================================
 * PHYSICAL TRANSMITTED BIT
 * ============================================================
 *
 * If stuffing is required:
 *      transmit the opposite of the previous physical bit.
 *
 * Otherwise:
 *      transmit the current logical bit.
 */
assign tx_bit_stuffed =
        stuff_insert ? ~prev_bit : tx_bit;


/*
 * ============================================================
 * STATE UPDATE
 * ============================================================
 *
 * prev_bit = previous physical bit
 * count    = number of consecutive identical physical bits
 *
 * Both describe bits that have ALREADY been transmitted.
 */
always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        prev_bit <= 1'b0;
        count    <= 3'd0;
    end

    else if (bit_en)
    begin

        /*
         * ----------------------------------------------------
         * STUFF BIT
         * ----------------------------------------------------
         *
         * tx_bit_stuffed is ~prev_bit.
         *
         * Therefore the new run starts at one.
         */
        if (stuff_insert)
        begin
            prev_bit <= ~prev_bit;
            count    <= 3'd1;
        end

        /*
         * ----------------------------------------------------
         * NORMAL LOGICAL BIT
         * ----------------------------------------------------
         */
        else
        begin
            prev_bit <= tx_bit;

            if (stuff_en)
            begin
                if (tx_bit == prev_bit)
                    count <= count + 3'd1;
                else
                    count <= 3'd1;
            end

            else
            begin
                /*
                 * Stuffing is disabled outside the stuffed
                 * fields, so there is no active stuffing run.
                 */
                count <= 3'd0;
            end
        end
    end
end

endmodule
