module can_frame_controller(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_en,          // one pulse per bit-time

    input  wire        can_rx_sync,     // synchronized bus level

    input  wire        tx_request,      // host has a message pending
    input  wire        rtr,             // 0 = data frame, 1 = remote frame
    input  wire        ide,             // 0 = standard, 1 = extended
    input  wire [3:0]  dlc,             // data length code
 
    input  wire        bit_error,       // tx != rx, exceptions already filtered
    input  wire        ack_recieved,    // dominant seen in ACK slot
    input  wire        stuff_insert,    // this cycle is a stuffed bit
 
    input  wire        node_state,      // 0 = error-active, 1 = error-passive
 
    output reg  [3:0]  field_sel,       // current field (see localparams below)
    output reg  [2:0]  byte_idx,        // current data byte, 0-7
 
    output reg         crc_en,          // accumulate this bit into CRC_RG
    output reg         stuff_en,        // current field is subject to stuffing
 
    output reg         error_detected,  // pulse: bump TEC/REC
    output reg         flag_type,       // 0 = dominant flag, 1 = recessive flag
 
    output reg         tx_done,
    output reg         tx_busy
);

localparam IDLE           = 4'd0;
localparam SOF            = 4'd1;
localparam ARBITRATION    = 4'd2;
localparam CONTROL        = 4'd3;
localparam DATA           = 4'd4;
localparam CRC            = 4'd5;
localparam CRC_DELIM      = 4'd6;
localparam ACK            = 4'd7;
localparam EOF            = 4'd8;
localparam INTERMISSION   = 4'd9;
localparam ERROR_FLAG     = 4'd10;
localparam WAIT_RECESSIVE = 4'd11;
localparam ERROR_DELIM    = 4'd12;

localparam ARB_LEN_STD = 6'd12;
localparam ARB_LEN_EXT = 6'd32;
localparam CTRL_LEN = 6'd6;
localparam CRC_LEN = 6'd16;  // 15 CRC bits + 1 delimiter
localparam ACK_LEN = 6'd2;   // slot + delimiter
localparam EOF_LEN = 6'd7;
localparam INTERM_LEN = 6'd3;
localparam ERR_FLAG_LEN = 6'd6;
localparam ERR_DELIM_LEN= 6'd7;   // exit bit of WAIT_RECESSIVE = bit 1


reg [3:0] present_state,next_state;

reg [5:0] bit_cnt; //general purpose counter for each bit of each state
reg byte_done; //pulse when the byte itself is done


wire bit_error_occured = (bit_error && (present_state != ARBITRATION)); // simplyfing use later
wire ack_error_occured =  (!ack_recieved && (present_state == ACK));

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		present_state <= IDLE;
	end
	else
	begin
		present_state <= next_state;
	end
end


// FSM TRANSISTIONS 
always@(*)
begin
	if (bit_error_occured || ack_error_occured)
    		next_state = ERROR_FLAG;
	else if (present_state == ARBITRATION && bit_error)
    		next_state = IDLE; //should make this into a recieve only mode
	else
	begin
		case(present_state)
		IDLE:
		begin
			if( tx_request || (can_rx_sync == 1'b0) )
				next_state = SOF;
			else
				next_state = IDLE;
		end

		SOF:
		begin
			next_state = ARBITRATION;
		end

		ARBITRATION:
		begin
			if(bit_cnt == 6'd1)
				next_state = CONTROL;
			else
				next_state = ARBITRATION;
		end

		CONTROL:
		begin
			if(bit_cnt == 6'd1)
				next_state = (rtr || dlc == 0) ? CRC: DATA;
			else
				next_state = CONTROL;
		end

		DATA:
		begin
			if(bit_cnt == 6'd1 && (byte_idx == dlc - 6'b1))
				next_state = CRC;
			else
				next_state = DATA;
		end

		CRC:
		begin
			if(bit_cnt == 6'd1)
				next_state = CRC_DELIM;
			else
				next_state =  CRC;	
		end
		
		CRC_DELIM:
		begin
			next_state = ACK;
		end
		ACK:
		begin
			if(bit_cnt == 6'd1)
				next_state = EOF;
			else
				next_state = ACK;
		end

		EOF:
		begin
			if(bit_cnt == 6'd1)
				next_state = INTERMISSION;
			else
				next_state = EOF;
		end

		INTERMISSION:
		begin
			if(bit_cnt == 6'd1)
				next_state = IDLE;
			else
				next_state = INTERMISSION;
		end

		ERROR_FLAG:
		begin
			if(bit_cnt == 6'd1)
				next_state = WAIT_RECESSIVE;
			else
				next_state = ERROR_FLAG;
		end

		WAIT_RECESSIVE:
		begin
			if(can_rx_sync == 6'd1)
				next_state = ERROR_DELIM;
			else
				next_state = WAIT_RECESSIVE;
		end

		ERROR_DELIM:
		begin
			if(bit_cnt == 6'd1)
				next_state = INTERMISSION;
			else
				next_state = ERROR_DELIM;
		end

		default:
			next_state = IDLE;
		endcase	
	end
end


// LOADING COUNTER VALUES BASED ON THE FRAME LENGTH
always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		bit_cnt <= 6'd1;
	end
	else
	begin
		if(bit_en)
		begin
			if(next_state != present_state)
			begin
				case(next_state)
				ARBITRATION: bit_cnt <= ide ? ARB_LEN_EXT : ARB_LEN_STD;
				CONTROL: bit_cnt <= CTRL_LEN;
				DATA: bit_cnt <= 6'd8;
				CRC: bit_cnt <= CRC_LEN;
				ACK: bit_cnt <= ACK_LEN;
				EOF: bit_cnt <= EOF_LEN;
				INTERMISSION: bit_cnt <= INTERM_LEN;
				ERROR_FLAG: bit_cnt <= ERR_FLAG_LEN;
				ERROR_DELIM: bit_cnt <= ERR_DELIM_LEN;

				default: bit_cnt <= 6'd1;
				endcase
			end
			else
			begin
				if(!stuff_insert)
				begin
					bit_cnt <= (bit_cnt == 6'd1) ? bit_cnt : (bit_cnt - 6'd1);
				end
				else
				begin
					bit_cnt <= bit_cnt;
				end
				
			end
		end
		else
		begin
			bit_cnt <= bit_cnt;
		end
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		byte_idx <= 0;
	end
	else
	begin
		if(present_state != DATA)
		begin
			byte_idx <= 0;
		end
		else
		begin
			if( (bit_cnt == 6'd1) && !stuff_insert)
				byte_idx <= byte_idx + 1;
			else
				byte_idx <= byte_idx;
		end	
	end
end

// OUTPUT LOGIC
always@(*)
begin
 	field_sel      = present_state;
        flag_type      = node_state;
        tx_busy        = (present_state != IDLE);

        if (bit_error_occured || ack_error_occured)
        	error_detected = 1'b1;
    	else
		error_detected = 1'b0;

	case(present_state)
	
	SOF, ARBITRATION, CONTROL, DATA:
       	begin
		crc_en = 1'b1;
		stuff_en = 1'b1;
	end

	CRC:
	begin
		crc_en = 1'b0;
		stuff_en = 1'b1;
	end
	
	default:
	begin
		crc_en = 1'b0;
		stuff_en = 1'b0;
	end

	endcase	
 
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        tx_done <= 1'b0;
    else
    begin 
    	if (bit_en)
	begin
        	if (present_state == IDLE && next_state == SOF)
            		tx_done <= 1'b0;                          // clear for the new attempt
        	else if (present_state == EOF && (bit_cnt == 6'd1))
            		tx_done <= 1'b1;      		// latch successful completion
		else
			tx_done <= tx_done;
   	 end
    end
end

endmodule
