module can_ack_detector (
    input wire clk,
    input wire rst_n,
    input wire bit_en,

    input wire [3:0] state,
    input wire is_transmitting,
    input wire can_rx_sync,

    output reg ack_received,
    output reg ack_error
);

localparam IDLE = 4'd0;
localparam ACK  = 4'd7;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        ack_received <= 1'b0;
        ack_error    <= 1'b0;
    end

    else if (bit_en)
    begin
        /*
         * ACK error is an event, so clear it every bit.
         */
        ack_error <= 1'b0;

        /*
         * Start a new ACK status when a new frame begins.
         */
        if (state == IDLE)
        begin
            ack_received <= 1'b0;
        end

        /*
         * Transmitter checks the ACK slot.
         *
         * Dominant bus = another node acknowledged the frame.
         */
        else if (state == ACK && is_transmitting)
        begin
            if (can_rx_sync == 1'b0)
                ack_received <= 1'b1;
            else
                ack_error <= 1'b1;
        end
    end
end

endmodule
