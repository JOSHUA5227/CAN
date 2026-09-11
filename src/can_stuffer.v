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


assign stuff_insert = stuff_en && (count == 3'd5);

assign tx_bit_stuffed =
        stuff_insert ? ~prev_bit : tx_bit;


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        prev_bit <= 1'b0;
        count    <= 3'd0;
    end

    else if (bit_en)
    begin

        if (stuff_insert)
        begin
            prev_bit <= ~prev_bit;
            count    <= 3'd1;
        end

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
                count <= 3'd0;
            end
        end
    end
end

endmodule
