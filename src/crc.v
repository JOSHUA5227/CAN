module crc (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_en,

    input  wire [3:0]  state,
    input  wire        crc_en,
    input  wire        data_bit,

    input  wire        crc_done,

    output wire [14:0] crc_value,
    output wire        crc_out,
    output reg         crc_error
);

localparam SOF = 4'd1;
localparam CRC = 4'd5;

reg [14:0] crc_reg;

wire fb_bit = data_bit ^ crc_reg[14];
wire [14:0] shifted = {crc_reg[13:0], 1'b0};

wire [14:0] accumulate_nxt = fb_bit ? (shifted ^ 15'h4599) : shifted;


assign crc_value = crc_reg;
assign crc_out = crc_reg[14];

always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
	    crc_reg   <= 15'd0;
	    crc_error <= 1'b0;
	end
	else if (bit_en)
	begin

	    if (state == SOF)
	    begin
		crc_reg   <= 15'd0;
		crc_error <= 1'b0;
	    end

	    else if (crc_en)
	    begin
		crc_reg <= accumulate_nxt;

		if (crc_done)
		begin
		    crc_error <= (accumulate_nxt != 15'd0);
		end
	    end

	    else if (state == CRC)
	    begin
		crc_reg <= shifted;
	    end

	end
end
endmodule
