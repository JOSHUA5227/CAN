`timescale 1ns/1ps

module bit_timing_engine #(
    parameter CAN_CLK_FREQ = 100_000_000,
    parameter CAN_BIT_RATE = 1_000_000
)
(
    input wire clk,
    input wire rst_n,
    input wire can_rx_sync,
    input wire [3:0] state,

    input wire [31:0] brp,
    input wire [7:0] prop_seg,
    input wire [7:0] phase_seg1,
    input wire [7:0] phase_seg2,
    input wire [3:0] sjw,

    output wire sample_en,
    output wire sof_detected,
    output wire bit_en
);

localparam IDLE = 4'd0;


/* =========================================================
 * TIMING REGISTERS
 * ========================================================= */

reg [31:0] brp_count;
reg [9:0]  tq_count;

reg [8:0]  phase1_current;
reg [7:0]  phase2_current;

reg can_rx_prev;


/* =========================================================
 * BUS EDGE DETECTION
 * ========================================================= */

wire falling_edge;

assign falling_edge =
       can_rx_prev && !can_rx_sync;


/* =========================================================
 * TIME QUANTA CALCULATION
 * ========================================================= */

wire [9:0] tq_per_bit;
wire [9:0] effective_tq_per_bit;
wire [9:0] sample_point;

assign tq_per_bit =
       10'd1 +
       prop_seg +
       phase_seg1 +
       phase_seg2;

assign effective_tq_per_bit =
       10'd1 +
       prop_seg +
       phase1_current +
       phase2_current;

assign sample_point =
       10'd1 +
       prop_seg +
       phase1_current;


/* =========================================================
 * BRP DIVIDER
 *
 * One TQ is generated whenever brp_count reaches BRP-1.
 *
 * BRP = 1 therefore gives one TQ every clock.
 * ========================================================= */

wire tq_en;

assign tq_en =
       (brp_count == brp - 32'd1);


/* =========================================================
 * SAMPLE / BIT EVENTS
 * ========================================================= */

assign sample_en =
       tq_en &&
       (tq_count == sample_point - 10'd1);

assign bit_en =
       tq_en &&
       (tq_count == effective_tq_per_bit - 10'd1);


/* =========================================================
 * SOF DETECTION
 *
 * A recessive -> dominant transition while the bus is idle
 * is the CAN START OF FRAME edge.
 *
 * The edge itself is the synchronization event.
 * ========================================================= */

assign sof_detected =
       falling_edge &&
       (state == IDLE);


/* =========================================================
 * PHASE ERROR
 *
 * Used for resynchronization when an edge occurs while a
 * frame is already in progress.
 * ========================================================= */

wire [10:0] phase_error;
wire [3:0]  correction;

assign phase_error =
       (tq_count < sample_point) ?
       {1'b0, tq_count} :

       ((tq_count > sample_point) ?
       (tq_per_bit - tq_count) :

       11'd0);

assign correction =
       (phase_error < {7'b0, sjw}) ?
       phase_error[3:0] :
       sjw;


/* =========================================================
 * RECEIVE BUS HISTORY
 * ========================================================= */

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
        can_rx_prev <= 1'b1;
    else
        can_rx_prev <= can_rx_sync;
end


/* =========================================================
 * BRP COUNTER
 *
 * Runs continuously.
 *
 * A synchronization edge does NOT stop the timer. It resets
 * the current timing position so that the new CAN bit starts
 * from SYNC_SEG.
 * ========================================================= */

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        brp_count <= 32'd0;
    end
    else if (falling_edge)
    begin
        /*
         * Hard synchronization:
         *
         * The R->D edge is the beginning of SOF.
         *
         * Restart the TQ generator from the beginning of the
         * synchronized bit time.
         */
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


/* =========================================================
 * TIME-QUANTA COUNTER
 *
 * Runs continuously.
 *
 * tq_count represents the current time quantum inside the
 * CAN bit.
 * ========================================================= */

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        tq_count <= 10'd0;
    end
    else if (falling_edge)
    begin
        /*
         * Hard synchronization / resynchronization.
         *
         * The detected edge becomes the start of the
         * synchronized bit.
         */
        tq_count <= 10'd0;
    end
    else if (tq_en)
    begin
        if (tq_count == effective_tq_per_bit - 10'd1)
            tq_count <= 10'd0;
        else
            tq_count <= tq_count + 10'd1;
    end
end


/* =========================================================
 * PHASE SEGMENT CONTROL
 *
 * Normal operation:
 *     PHASE1 = configured PHASE_SEG1
 *     PHASE2 = configured PHASE_SEG2
 *
 * On an edge during an active frame:
 *
 *     edge before sample point:
 *         extend PHASE_SEG1
 *
 *     edge after sample point:
 *         shorten PHASE_SEG2
 *
 * The correction is limited by SJW.
 * ========================================================= */

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        phase1_current <= {1'b0, phase_seg1};
        phase2_current <= phase_seg2;
    end

    /*
     * HARD SYNCHRONIZATION.
     *
     * Return to the nominal configured timing.
     */
    else if (falling_edge && (state == IDLE))
    begin
        phase1_current <= {1'b0, phase_seg1};
        phase2_current <= phase_seg2;
    end

    /*
     * RESYNCHRONIZATION during an active frame.
     */
    else if (falling_edge && (state != IDLE))
    begin
        if (tq_count < sample_point)
        begin
            /*
             * Edge occurred before the sample point.
             *
             * Lengthen PHASE_SEG1.
             */
            phase1_current <=
                {1'b0, phase_seg1} + correction;

            phase2_current <=
                phase_seg2;
        end

        else if (tq_count > sample_point)
        begin
            /*
             * Edge occurred after the sample point.
             *
             * Shorten PHASE_SEG2.
             */
            phase1_current <=
                {1'b0, phase_seg1};

            if (phase_seg2 > {4'b0, correction})
                phase2_current <=
                    phase_seg2 - correction;
            else
                phase2_current <= 8'd1;
        end

        else
        begin
            /*
             * Edge exactly at sample point.
             */
            phase1_current <=
                {1'b0, phase_seg1};

            phase2_current <=
                phase_seg2;
        end
    end

    /*
     * At a normal bit boundary return to nominal timing.
     */
    else if (bit_en)
    begin
        phase1_current <= {1'b0, phase_seg1};
        phase2_current <= phase_seg2;
    end
end


endmodule
