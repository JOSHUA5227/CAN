module can_frame_controller(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        bit_en,          // one pulse per bit-time

    input  wire        can_rx_sync,     // synchronized bus level

    input  wire        sof_detected,

    input  wire        tx_request,      // host has a message pending
    input  wire        rtr,             // 0 = data frame, 1 = remote frame
    input  wire        ide,             // 0 = standard, 1 = extended
    input  wire [3:0]  dlc,             // data length code
 
    input  wire        bit_error,       // tx != rx
    input  wire        error_event,
    input  wire        stuff_insert,    // this cycle is a stuffed bit
    input  wire        rx_bit_valid,

    input wire 	       rx_rtr,
    input wire  [3:0]  rx_dlc,
    input wire         rx_ide, 

    output reg         ack_drive,
    output reg         is_transmitting, // 0 = listening, 1 = our own frame
    output reg  [3:0]  field_sel,       // current field (see localparams below)
    output reg  [5:0]  bit_cnt, 	//general purpose counter for each bit of each state
    output reg  [2:0]  byte_idx,        // current data byte, 0-7
 
    output reg         crc_en,          // accumulate this bit into CRC_RG
    output reg         stuff_en,        // current field is subject to stuffing
 
    output wire        bit_error_occured,
    output reg         tx_done,
    output reg	       rx_done,
    output reg         line_busy
);

localparam IDLE           = 4'd0;
localparam SOF            = 4'd1;
localparam ARBITRATION    = 4'd2;
localparam CONTROL        = 4'd3;
localparam DATA           = 4'd4;
localparam CRC            = 4'd5;
localparam CRC_DELIM      = 4'd6;
localparam ACK            = 4'd7;
localparam ACK_DELIM	  = 4'd8;
localparam EOF            = 4'd9;
localparam INTERMISSION   = 4'd10;
localparam ERROR_FLAG     = 4'd11;
localparam WAIT_RECESSIVE = 4'd12;
localparam ERROR_DELIM    = 4'd13;
localparam RX_ONLY = 4'd14;

localparam ARB_PHASE1_LEN = 6'd13;  // Base ID + RTR/SRR + IDE -- ALWAYS, both formats
localparam ARB_PHASE2_LEN = 6'd19;  // Extended ID + RTR -- extended only
localparam CTRL_LEN_STD   = 6'd5;   // r0 + DLC        (IDE already consumed above)
localparam CTRL_LEN_EXT   = 6'd6;   // r1 + r0 + DLC   (IDE already consumed above)
localparam CRC_LEN = 6'd15;  // 15 CRC bits 
localparam EOF_LEN = 6'd7;
localparam INTERM_LEN = 6'd3;
localparam ERR_FLAG_LEN = 6'd6;
localparam ERR_DELIM_LEN= 6'd7;   // exit bit of WAIT_RECESSIVE = bit 1

localparam BIT_CNT_MIN = 6'd1;

reg [3:0] present_state,next_state;
reg arb_phase;

wire active_rtr        = is_transmitting ? rtr : rx_rtr;
wire [3:0] active_dlc  = is_transmitting ? dlc : rx_dlc;
wire active_ide	       = is_transmitting ? ide : rx_ide;

wire logical_bit_valid = is_transmitting ? !stuff_insert : rx_bit_valid;
wire ide_resolve_cycle = (present_state == ARBITRATION || present_state == RX_ONLY) &&(bit_cnt == 6'd1) && (arb_phase == 1'b0) && logical_bit_valid;
assign bit_error_occured = present_state == ARBITRATION && is_transmitting && bit_error;

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		present_state <= IDLE;
	end
	else
	begin
		if(bit_en)
			present_state <= next_state;
		else
			present_state <= present_state;
	end
end


// FSM TRANSISTIONS 
always@(*)
begin
	if (error_event)
		next_state = ERROR_FLAG;
	else if (bit_error_occured)
    		next_state = RX_ONLY; //should make this into a recieve only mode
	else
	begin
		case(present_state)
		IDLE:
		begin
			if (tx_request || sof_detected)
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

			if(bit_cnt == 6'd1 && logical_bit_valid)
			begin
				if(arb_phase == 1'b0)
					next_state = active_ide ? ARBITRATION : CONTROL;	
				else
					next_state = CONTROL;
			end
			else
				next_state = ARBITRATION;
		end

		RX_ONLY:
		begin
			if(bit_cnt == 6'd1 && logical_bit_valid)
                        begin
                                if(arb_phase == 1'b0)
                                        next_state = active_ide ? RX_ONLY : CONTROL;
                                else
                                        next_state = CONTROL;
                        end
                        else
                                next_state = RX_ONLY;
		end
		CONTROL:
		begin
			if(bit_cnt == 6'd1 && logical_bit_valid)
				next_state = (active_rtr || active_dlc == 0) ? CRC: DATA;
			else
				next_state = CONTROL;
		end

		DATA:
		begin
			if(bit_cnt == 6'd1 && (byte_idx == active_dlc - 6'b1) && logical_bit_valid)
				next_state = CRC;
			else
				next_state = DATA;
		end

		CRC:
		begin
			if(bit_cnt == 6'd1 && logical_bit_valid)
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
			next_state = ACK_DELIM;
		end

		ACK_DELIM:
		begin
			next_state = EOF;
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
			if(bit_cnt == BIT_CNT_MIN)
				next_state = INTERMISSION;
			else
				next_state = ERROR_DELIM;
		end

		default:
			next_state = IDLE;
		endcase	
	end
end


always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
		is_transmitting <= 0;
	else if(bit_en)
	begin
		if(present_state == IDLE && next_state == SOF)
		begin
			if(sof_detected)
				is_transmitting <= 1'b0;
			else
				is_transmitting <= 1'b1;
		end
		else
		begin
			if(present_state == ARBITRATION && bit_error)
				is_transmitting <=0;
			else
			begin
				if(next_state == IDLE)
					is_transmitting <= 0;
				else
					is_transmitting <= is_transmitting;
			end
		end
	end
	else
		is_transmitting <= is_transmitting;
end

always @(posedge clk or negedge rst_n) 
begin
        if (!rst_n)
            arb_phase <= 1'b0;
        else if (bit_en) 
	begin
            if (present_state == IDLE && next_state == SOF)
                arb_phase <= 1'b0;                 // fresh frame
            else if (ide_resolve_cycle)
                arb_phase <= active_ide;           // 1 = extended, continue to phase 2
        end
end


// LOADING COUNTER VALUES BASED ON THE FRAME LENGTH
always @(posedge clk or negedge rst_n) 
begin
        if (!rst_n) 
	begin
            bit_cnt <= 6'd1;
        end 
	else if (bit_en) 
	begin
            if (ide_resolve_cycle && active_ide) 
	    begin
                bit_cnt <= ARB_PHASE2_LEN;
            end
	    else if(present_state == DATA && bit_cnt == 6'd1 && logical_bit_valid && byte_idx != active_dlc - 3'd1)
 	    begin
		bit_cnt <= 6'd8;
 	    end 
	    else if (next_state != present_state) 
	    begin
                case (next_state)
                    ARBITRATION:  bit_cnt <= ARB_PHASE1_LEN;         // always 13 now, both roles
                    RX_ONLY:      bit_cnt <= bit_cnt;                // entering mid-field -- hold
                    CONTROL:      bit_cnt <= arb_phase ? CTRL_LEN_EXT : CTRL_LEN_STD;
                    DATA:         bit_cnt <= 6'd8;
                    CRC:          bit_cnt <= CRC_LEN;
                    EOF:          bit_cnt <= EOF_LEN;
                    INTERMISSION: bit_cnt <= INTERM_LEN;
                    ERROR_FLAG:   bit_cnt <= ERR_FLAG_LEN;
                    ERROR_DELIM:  bit_cnt <= ERR_DELIM_LEN;
                    default:      bit_cnt <= 6'd1;
                endcase
            end 
	    else if (logical_bit_valid)
	    begin
                bit_cnt <= (bit_cnt == 6'd1) ? bit_cnt : (bit_cnt - 6'd1);
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
	else if(bit_en)
	begin
		if(present_state != DATA)
		begin
			byte_idx <= 0;
		end
		else
		begin
			if( (bit_cnt == 6'd1) && logical_bit_valid)
				byte_idx <= byte_idx + 1;
			else
				byte_idx <= byte_idx;
		end	
	end
	else
		byte_idx <= byte_idx;
end

// OUTPUT LOGIC
always@(*)
begin
 	field_sel      = present_state;
	line_busy        = (present_state != IDLE);


	if (present_state == ACK && !is_transmitting)
	    	ack_drive = 1'b1;
    	else
		ack_drive = 1'b0;

	case(present_state)
	
	SOF, ARBITRATION,RX_ONLY, CONTROL, DATA:
       	begin
		crc_en = 1'b1;
		stuff_en = 1'b1;
	end

	CRC:
	begin
		crc_en = !is_transmitting; // IF 0 means tx should start shifting out data, if 1 means RX should keep calculating to detect error
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
		tx_done <= 1'b0;

        	if (present_state == EOF && (bit_cnt == 6'd1)  && is_transmitting)
            		tx_done <= 1'b1;
   	end
    end
end

always @(posedge clk or negedge rst_n) begin
    if (!rst_n)
        rx_done <= 1'b0;
    else
    begin
        rx_done <= 1'b0;

        if (bit_en)
        begin
            if ((present_state == EOF) && (bit_cnt == 6'd1) && !is_transmitting)
                rx_done <= 1'b1;
        end
    end
end
endmodule
