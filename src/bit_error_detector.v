module bit_error_detector(
    input  wire clk,
    input  wire rst_n,
    input  wire bit_en,

    input  wire tx_bit,
    input  wire can_rx_sync,

    output reg bit_error
);

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        bit_error <= 1'b0;
    end
    else
    begin
        bit_error <= 1'b0;

        if(bit_en)
        begin
            if(tx_bit != can_rx_sync)
                bit_error <= 1'b1;
        end
    end
end

endmodule
