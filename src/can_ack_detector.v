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

localparam ACK = 4'd7;

always@(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        ack_received <= 1'b0;
        ack_error <= 1'b0;
    end
    else if(bit_en)
    begin
        ack_received <= 1'b0;
        ack_error <= 1'b0;

        if (state == ACK && is_transmitting)
        begin
            if (can_rx_sync == 1'b0)
                ack_received <= 1'b1;
            else
                ack_error <= 1'b1;
        end
    end
end

endmodule
