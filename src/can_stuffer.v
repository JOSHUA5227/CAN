module can_stuffer (
    input  wire clk,
    input  wire rst_n,
    input  wire bit_en,

    input  wire tx_bit,
    input  wire stuff_en,

    output reg  tx_bit_stuffed,
    output reg  stuff_insert
);

reg prev_bit;
reg [2:0] count;
wire stuff_pending;

assign stuff_pending = (count == 3'd5) ? 1: 0;
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		tx_bit_stuffed <= 1'b0;
	else
	begin
		if(bit_en)
		begin
			if(stuff_en)
			begin
				if(stuff_pending)
					tx_bit_stuffed <= ~prev_bit;
				else
					tx_bit_stuffed <= tx_bit;
			end
			else
				tx_bit_stuffed <= tx_bit;
		end
	end
end


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		prev_bit <= 1'b0;
	end
	else
	begin
		if(bit_en)
		begin
			if(stuff_en && stuff_pending)
				prev_bit <= ~prev_bit;
			else
				prev_bit <= tx_bit;
		end
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		count <= 0;
	end
	else
	begin
		if(bit_en)
		begin
			if(stuff_en)
			begin
				if(tx_bit != prev_bit || stuff_pending)
					count <= 3'd1;
				else
					count <= count + 1;
			end
			else
				count <= 0;
		end
	end
end

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        stuff_insert <= 1'b0;
    else if(bit_en)
    begin
        if(stuff_en && stuff_pending)
            stuff_insert <= 1'b1;
        else
            stuff_insert <= 1'b0;
    end
end

endmodule
