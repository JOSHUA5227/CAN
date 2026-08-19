module can_form_error_detector (
    input wire       clk,
    input wire       rst_n,
    input wire       bit_en,

    input wire [3:0] state,
    input wire       can_rx_sync,

    output reg       form_error
);

localparam CRC_DELIM = 4'd6;
localparam ACK_DELIM = 4'd8;
localparam EOF       = 4'd9;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        form_error <= 1'b0;
    end
    else if (bit_en)
    begin
        form_error <= 1'b0;

        if ((state == CRC_DELIM || state == ACK_DELIM || state == EOF) && (can_rx_sync == 1'b0))
        begin
            form_error <= 1'b1;
        end
    end
end

endmodule
