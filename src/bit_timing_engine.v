module can_bit_timing_engine #(
    parameter CAN_CLK_FREQ = 100_000_000,
    parameter CAN_BIT_RATE = 1_000_000
)(
    input  wire clk,
    input  wire rst_n,
    input  wire can_rx_sync,
    input  wire [3:0] state,

    input wire [31:0] brp,
    input wire [7:0] prop_seg,
    input wire [7:0] phase_seg1,
    input wire [7:0] phase_seg2,
    input wire [3:0] sjw,

    output reg sample_en,
    output wire bit_en
);
localparam IDLE = 4'd0;

localparam BTE_IDLE = 2'd0;
localparam HARD_SYNC = 2'd1;
localparam RUN = 2'd2;
localparam RESYNC = 2'd3;

reg [1:0] bte_state;
reg [1:0] next_bte_state;

wire [31:0] tq_per_bit;
assign tq_per_bit = prop_seg + phase_seg1 + phase_seg2 + 1; //sync_seg

reg [31:0] brp_count;
reg [31:0] tq_count;
reg [31:0] phase1_current;
reg [31:0] phase2_current;

reg sync_done;

wire tq_en;
assign tq_en = (brp_count == brp -1);

assign bit_en = tq_en && (tq_count == tq_per_bit -1);

reg can_rx_prev;

wire falling_edge;
assign falling_edge = can_rx_prev && !can_rx_sync;


wire [31:0] sample_point;
assign sample_point = 32'd1 + prop_seg + phase_seg1;

wire [31:0] positive_phase_error;
assign positive_phase_error = tq_count;

always@(posedge clk or negedege rst_n)
begin
	if(!rst_n)
	begin
		brp_count <= 0;
	end
	else
	begin
		if(bte_state == HARD_SYNC)
		begin
			brp_count <= 0;
		end
		else if(tq_en)
		begin
			brp_count <=0;
		end
		else
		begin
			brp_count <= brp_count + 1;
		end
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		tq_count <= 0;
	end
	else
	begin
		if(bte_state == HARD_SYNC)
			tq_count <= 0;
		else if(bit_en)
			tq_count <= 0;
		else if(tq_en)
		begin
			if(tq_count == effective_tq_per_bit -1)
				tq_count <= 0;
			else
				tq_count <= tq_count + 1;
		end
		else
			tq_count <= tq_count;
	end
end

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		can_rx_prev <= 1;
	end
	else
	begin
		can_rx_prev <= can_rx_sync;
	end
end

always @(posedge clk or negedge rst_n)
begin
	if (!rst_n)
	begin
	    bte_state <= BTE_IDLE;
	end
	else
	begin
	    bte_state <= next_bte_state;
	end
end

always @(*)
begin
        next_bte_state = bte_state;
        case (bte_state)
            BTE_IDLE:
            begin
                if ((state == IDLE) && falling_edge)
                begin
                    next_bte_state = HARD_SYNC;
                end
                else
                begin
                    next_bte_state = BTE_IDLE;
                end
            end

            HARD_SYNC:
            begin
                next_bte_state = RUN;
            end

            RUN:
            begin
                next_bte_state = RUN;
            end

            RESYNC:
            begin
                next_bte_state = RUN;
            end

            default:
            begin
                next_bte_state = BTE_IDLE;
            end

        endcase
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        sync_done <= 1'b0;
    end
    else if (bit_en)
    begin
        sync_done <= 1'b0;
    end
    else if (falling_edge)
    begin
        sync_done <= 1'b1;
    end
end
endmodule
