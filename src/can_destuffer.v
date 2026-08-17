module can_destuffer (
    input  wire clk,
    input  wire rst_n,
    input  wire bit_en,

    input  wire rx_bit,          // physical bit from CAN bus
    input  wire stuff_en,        // stuffing active in this field

    output reg  rx_bit_destuffed, // logical/destuffed bit
    output reg  stuff_remove,     // 1 when a physical stuff bit is discarded
    output reg  stuff_error       // 1 when expected stuff bit is incorrect
);

reg prev_bit;
reg [2:0] count;

wire stuff_pending;

assign stuff_pending = (count == 3'd5) ? 1'b1 : 1'b0;

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
        rx_bit_destuffed <= 1'b0;

    else if (bit_en)
    begin
        if (stuff_en)
        begin
            if (stuff_pending)
            begin
                rx_bit_destuffed <= rx_bit_destuffed; // dont sample a new bit
            end
            else
            begin
                rx_bit_destuffed <= rx_bit;
            end
        end
        else
        begin
            rx_bit_destuffed <= rx_bit;
        end
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        stuff_error <= 1'b0;

    else if (bit_en)
    begin
        if (stuff_en && stuff_pending)
        begin
            if (rx_bit == prev_bit)
                stuff_error <= 1'b1;
            else
                stuff_error <= 1'b0;
        end
        else
        begin
            stuff_error <= 1'b0;
        end
    end
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        stuff_remove <= 1'b0;

    else if (bit_en)
    begin
        if (stuff_en && stuff_pending && (rx_bit != prev_bit))
            stuff_remove <= 1'b1;
        else
            stuff_remove <= 1'b0;
    end
end

endmodule
