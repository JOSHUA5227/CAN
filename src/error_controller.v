module error_controller(

input wire clk,
input wire rst_n,

input wire bit_en,

input wire is_transmitting,
input wire can_rx_sync,
input wire tx_done,
input wire rx_done,

input wire bit_error,
input wire ack_error,
input wire form_error,
input wire stuff_error,
input wire crc_error,


output reg [8:0] tec,
output reg [7:0] rec,

output wire [1:0] error_state,
output reg error_flag_active
);

localparam ERROR_ACTIVE  = 2'd0;
localparam ERROR_PASSIVE = 2'd1;
localparam BUS_OFF       = 2'd2;

reg [1:0] present_state,next_state;
reg [7:0] bus_off_count;
reg [3:0] bit_count;

wire count_en;
wire error_event;

assign error_state = present_state;
assign error_event = bit_error || ack_error || stuff_error || crc_error || form_error;
assign count_en = (present_state == BUS_OFF) ? 1 : 0;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		present_state <= ERROR_ACTIVE;
	end
	else
	begin
		present_state <= next_state;
	end
end

always@(*)
begin
	next_state = present_state;
	case(present_state)
	ERROR_ACTIVE:
	begin
		if(tec >= 128 || rec >= 128)
			next_state = ERROR_PASSIVE;
		else
			next_state = ERROR_ACTIVE;
	end
	
	ERROR_PASSIVE:
	begin
		if(tec >= 256)
			next_state = BUS_OFF;
		else if (tec < 128 && rec < 128)
			next_state = ERROR_ACTIVE;
		else
			next_state = ERROR_PASSIVE;
	end

	BUS_OFF:
	begin
		next_state = BUS_OFF;
	end

	default:
	begin
		next_state = ERROR_ACTIVE;
	end
	endcase
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		bit_count <= 0;
	end
	else
	begin
		if(bit_en && count_en)
		begin
			if(can_rx_sync == 1)
			begin
				if(bit_count == 10)
					bit_count <= 0;
				else
					bit_count <= bit_count + 1;
			end
			else
				bit_count <= 0;			
		end
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		bus_off_count <=0;
	end
	else
	begin
		if(bit_en && count_en)
		begin
			if(bit_count == 10)
			begin
				if(bus_off_count == 127)
					bus_off_count <= 0;
				else
					bus_off_count <= bus_off_count + 1;
			end
		end
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		tec <= 0;
		rec <= 0;
	end
	else if (bit_en)
	begin
		if(error_event)
		begin
			if(is_transmitting)
			begin
				if(tec  <= 247)
					tec <= tec + 8;
				else
					tec <= 9'd255;
			end
			else
			begin
				if(rec < 128)
					rec <= rec + 1;
				else
					rec <= 8'd128;
			end
		end
		else if (tx_done)
		begin
			if(tec != 0)
				tec <= tec - 1;
		end
		else if (rx_done)
		begin
			if(rec != 0)
				rec <= rec - 1;
		end
	end
	else
	begin

	end	
end
endmodule
