module bit_timing_engine #(
    parameter CAN_CLK_FREQ = 100_000_000,
    parameter CAN_BIT_RATE = 1_000_000
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        can_rx_sync,
    input  wire [3:0]  state,

    input wire [31:0] brp,
    input wire [7:0]  prop_seg,
    input wire [7:0]  phase_seg1,
    input wire [7:0]  phase_seg2,
    input wire [3:0]  sjw,

    output reg         sample_en,
    output wire        sof_detected,
    output wire        bit_en
);

localparam IDLE       = 4'd0;

localparam BTE_IDLE   = 2'd0;
localparam HARD_SYNC  = 2'd1;
localparam RUN        = 2'd2;
localparam RESYNC     = 2'd3;

reg [1:0] bte_state;
reg [1:0] next_bte_state;

reg [31:0] brp_count;
reg [9:0] tq_count;

reg [8:0] phase1_current;
reg [7:0] phase2_current;

reg can_rx_prev;
reg sync_done;

wire falling_edge;
wire tq_en;

wire [9:0] tq_per_bit;
wire [9:0] effective_tq_per_bit;
wire [9:0] sample_point;

wire [10:0] phase_error;
wire [3:0] correction;

assign falling_edge = can_rx_prev && !can_rx_sync;

assign tq_per_bit = 1 + prop_seg + phase_seg1 + phase_seg2;

assign effective_tq_per_bit = 1 + prop_seg + phase1_current + phase2_current;

assign sample_point = 1 + prop_seg + phase1_current;

assign tq_en = (brp_count == brp - 1);

assign bit_en = tq_en && (tq_count == effective_tq_per_bit - 1);

assign phase_error = (tq_count < sample_point) ? {1'b0,tq_count} : ((tq_count > sample_point) ? (tq_per_bit - tq_count) : 0);

assign correction = (phase_error < {7'b0,sjw}) ? phase_error[3:0] : sjw;
 
assign sof_detected = (bte_state == HARD_SYNC);

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        can_rx_prev <= 1'b1;
    else
        can_rx_prev <= can_rx_sync;
end

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        brp_count <= 32'd0;
    end
    else if (falling_edge && ((state == IDLE) || ((bte_state == RUN) && !sync_done)))
    begin
        brp_count <= 32'd0;
    end
    else if (tq_en)
    begin
        brp_count <= 32'd0;
    end
    else
    begin
        brp_count <= brp_count + 32'd1;
    end
end


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        tq_count <= 32'd0;
    end
    else if (falling_edge && ((state == IDLE) || ((bte_state == RUN) && !sync_done)))
    begin
        tq_count <= 32'd0;
    end
    else if (tq_en)
    begin
        if (tq_count == effective_tq_per_bit - 1)
            tq_count <= 32'd0;
        else
            tq_count <= tq_count + 32'd1;
    end
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
    else if (falling_edge && ((state == IDLE) || (bte_state == RUN)))
    begin
        sync_done <= 1'b1;
    end
end


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        phase1_current <= {1'b0,phase_seg1};
        phase2_current <= phase_seg2;
    end
    else if (falling_edge && (state == IDLE))
    begin
        phase1_current <= {1'b0,phase_seg1};
        phase2_current <= phase_seg2;
    end
    else if (falling_edge &&
             (bte_state == RUN) &&
             !sync_done)
    begin
        if (tq_count < sample_point)
        begin
            phase1_current <= phase_seg1 + correction;
            phase2_current <= phase_seg2;
        end
        else if (tq_count > sample_point)
        begin
            phase1_current <= {1'b0,phase_seg1};

            if (phase_seg2 > {4'b0,correction})
                phase2_current <= phase_seg2 - correction;
            else
                phase2_current <= 32'd1;
        end
        else
        begin
            phase1_current <= {1'b0,phase_seg1};
            phase2_current <= phase_seg2;
        end
    end
    else if (bit_en)
    begin
        phase1_current <= {1'b0,phase_seg1};
        phase2_current <= phase_seg2;
    end
end


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        sample_en <= 1'b0;
    end
    else
    begin
        sample_en <= 1'b0;

        if (tq_en &&
            (tq_count == sample_point - 1))
        begin
            sample_en <= 1'b1;
        end
    end
end


always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        bte_state <= BTE_IDLE;
    else
        bte_state <= next_bte_state;
end


always @(*)
begin
    next_bte_state = bte_state;

    case (bte_state)

        BTE_IDLE:
        begin
            if ((state == IDLE) && falling_edge)
                next_bte_state = HARD_SYNC;
        end

        HARD_SYNC:
        begin
            next_bte_state = RUN;
        end

        RUN:
        begin
            if (falling_edge && !sync_done)
                next_bte_state = RESYNC;
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

endmodule
