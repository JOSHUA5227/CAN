module can_destuffer (
    input  wire clk,
    input  wire rst_n,
    input  wire bit_en,

    input  wire rx_bit,              // physical bit from CAN bus
    input  wire stuff_en,

    output reg  rx_bit_destuffed,   // logical/destuffed bit
    output wire rx_bit_valid,       // 1 = current physical bit is logical
    output wire stuff_error         // 1 = expected stuff bit is incorrect
);

reg prev_bit;
reg [2:0] count;

wire stuff_pending;

assign stuff_pending = stuff_en && (count == 3'd5);
assign rx_bit_valid = (bit_en) ? !(stuff_en && stuff_pending) : 1'b0;

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
        begin
            prev_bit <= rx_bit;
        end
	else
	begin
	    prev_bit <= prev_bit;
	end
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
            begin
                count <= 3'd1;
            end
            else if (rx_bit != prev_bit)
            begin
                count <= 3'd1;
            end
            else
            begin
                count <= count + 3'd1;
            end
        end

        else
        begin
            count <= 3'd0;
        end
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
        begin
            rx_bit_destuffed <= rx_bit_destuffed;
        end

        else
        begin
            rx_bit_destuffed <= rx_bit;
        end
    end
end

endmodule
