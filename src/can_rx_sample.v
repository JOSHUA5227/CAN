module can_rx_sample(
input wire clk,
input wire rst_n,
input wire sample_en,

input wire can_rx_sync,

output reg can_rx_sample
);

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        can_rx_sample <= 1'b1;
    else if(sample_en)
        can_rx_sample <= can_rx_sync;
end

endmodule
