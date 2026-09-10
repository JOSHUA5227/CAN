module bit_error_detector(
    input wire bit_en,

    input wire tx_bit,
    input wire can_rx_sync,

    input wire is_transmitting,
    input wire [3:0] state,

    output wire bit_error
);

localparam ACK = 4'd7;

assign bit_error =
       bit_en &&
       is_transmitting &&
       (state != ACK) &&
       (tx_bit != can_rx_sync);

endmodule
