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
reg stuff_pending;

always @(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		prev_bit <= 1'b0;
		count <= 1'b0;
		stuff_pending <= 1'b0;
	end
	else
	begin
		if(bit_en)
		begin
			if(!stuff_en)
			begin
				prev_bit <= 1'b0;
				count <= 1'b0;
				stuff_pending <= 1'b0;
			end
			else
			begin
				if(stuff_pending)
				begin
					stuff_pending <= 1'b0;
					count <= 3'b0;
				end
				else
				begin
					if(count ==3'd0)
					begin
						prev_bit <= tx_bit;
						count <= 3'd1;
					end
					else
					begin
						if(tx_bit == prev_bit)
						begin
							if(count == 3'd4)
							begin
								stuff_pending <= 1'b1;
							end
							else
								stuff_pending <= 1'b0;

							count <= count + 3'd1;
						end
						else
						begin
							count <= 3'd1;
							prev_bit <= tx_bit;
						end
					end
				end	
			end
		end
		else
		begin
			prev_bit <= prev_bit;
			count <= count;
			stuff_pending <= stuff_pending;
		end
	end
end



always @(*) begin

    if (stuff_pending) begin
        tx_bit_stuffed = ~prev_bit;
        stuff_insert   = 1'b1;
    end
    else begin
        // Normal logical bit
        tx_bit_stuffed = tx_bit;
        stuff_insert   = 1'b0;
    end

end
endmodule
