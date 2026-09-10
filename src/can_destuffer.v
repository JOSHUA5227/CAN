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
    reg       stuff_pending;

    wire count_is_four;
    wire rx_bit_same_as_prev;

    assign count_is_four      = (count == 3'd4);
    assign rx_bit_same_as_prev = (rx_bit == prev_bit);

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
            if (state == SOF)
            begin
                rx_bit_destuffed = rx_bit;
                rx_bit_valid     = 1'b1;
            end
            else if (stuff_en)
            begin
                if (stuff_pending)
                begin
                    rx_bit_valid = 1'b0;

                    if (rx_bit_same_as_prev)
                        stuff_error = 1'b1;
                end
                else
                begin
                    rx_bit_destuffed = rx_bit;
                    rx_bit_valid     = 1'b1;
                end
            end
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
            prev_bit       <= 1'b1;
            count          <= 3'd0;
            stuff_pending  <= 1'b0;
        end
        else if (bit_en)
        begin
            if (state == SOF)
            begin
                prev_bit       <= rx_bit;
                count          <= 3'd1;
                stuff_pending  <= 1'b0;
            end
            else if (stuff_en)
            begin
                if (stuff_pending)
                begin
                    count         <= 3'd0;
                    stuff_pending <= 1'b0;
                end
                else if (rx_bit_same_as_prev)
                begin
                    if (count_is_four)
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
                else
                begin
                    prev_bit       <= rx_bit;
                    count          <= 3'd1;
                    stuff_pending  <= 1'b0;
                end
            end
            else
            begin
                prev_bit       <= rx_bit;
                count          <= 3'd1;
                stuff_pending  <= 1'b0;
            end
        end
    end

endmodule
