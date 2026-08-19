module can_destuffer (
input wire clk,
input wire rst_n,

input wire bit_en,

input wire rx_bit,         
input wire stuff_en,

output reg rx_bit_destuffed,   
output wire rx_bit_valid,       
output wire stuff_error         
);

reg prev_bit;
reg [2:0] count;

wire stuff_pending;

assign stuff_pending = stuff_en && (count == 3'd5);
assign rx_bit_valid = bit_en && !stuff_pending;

assign stuff_error =(bit_en && stuff_en && stuff_pending && (rx_bit == prev_bit));


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        prev_bit <= 1'b0;
    end

    else if (bit_en)
    begin
        if (stuff_en)
            prev_bit <= rx_bit;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        count <= 3'd0;
    end
    else if (bit_en)
    begin
        if (stuff_en)
        begin
            if (stuff_pending)
                count <= 3'd1;
            else if (rx_bit != prev_bit)
                count <= 3'd1;
            else
                count <= count + 3'd1;
        end
        else
            count <= 3'd0;
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        rx_bit_destuffed <= 1'b0;
    end
    else if (bit_en)
    begin
        if (stuff_en && stuff_pending)
            rx_bit_destuffed <= rx_bit_destuffed;
        else
            rx_bit_destuffed <= rx_bit;
    end
end

endmodule
