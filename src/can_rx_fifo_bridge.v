`timescale 1ns/1ps

module can_rx_fifo_bridge #(
    parameter FIFO_DEPTH = 8
)(
    /* =========================================================
     * CAN clock domain
     * ========================================================= */
    input  wire        can_clk,
    input  wire        can_rst_n,

    input  wire        rx_frame_valid,
    input  wire [28:0] rx_identifier,
    input  wire        rx_ide,
    input  wire        rx_rtr,
    input  wire [3:0]  rx_dlc,
    input  wire [63:0] rx_data,

    /*
     * Indicates that this CAN controller is the transmitter
     * for the current frame.
     *
     * Used only to prevent the controller's own transmitted
     * frame from being written into the RX FIFO.
     *
     * The CAN controller still monitors CAN RX internally
     * during transmission for arbitration, ACK and bit errors.
     */
    input  wire        is_transmitting,
    input  wire        loopback,

    /* =========================================================
     * PCLK domain
     * ========================================================= */
    input  wire        pclk,
    input  wire        p_rst_n,

    input  wire        rx_pop,

    /* =========================================================
     * RX register outputs
     * ========================================================= */
    output wire [28:0] rx_identifier_out,
    output wire        rx_ide_out,
    output wire        rx_rtr_out,
    output wire [3:0]  rx_dlc_out,
    output wire [63:0] rx_data_out,

    /* =========================================================
     * FIFO status
     * ========================================================= */
    output wire [7:0]  fifo_count,
    output wire        fifo_empty,
    output wire        fifo_full,
    output reg         fifo_overflow
);


    /* =========================================================
     * Parameters
     * ========================================================= */

    localparam FIFO_WIDTH = 128;


    /* =========================================================
     * FIFO data signals
     * ========================================================= */

    wire [FIFO_WIDTH-1:0] fifo_wdata;
    wire [FIFO_WIDTH-1:0] fifo_rdata;

    wire fifo_wfull;
    wire fifo_rempty;

    wire fifo_write_en;
    wire fifo_read_en;

    /*
     * async_fifo internally uses a 4-bit count for DEPTH=8.
     * Keep that internal width separate from the 8-bit APB
     * visible FIFO_COUNT field.
     */
    wire [3:0] fifo_count_raw;


    /* =========================================================
     * Pack received CAN frame
     *
     * FIFO entry:
     *
     * [127:99] RESERVED
     * [98:70]  ID
     * [69]     IDE
     * [68]     RTR
     * [67:64]  DLC
     * [63:0]   DATA
     * ========================================================= */

    assign fifo_wdata = {
        29'd0,
        rx_identifier,
        rx_ide,
        rx_rtr,
        rx_dlc,
        rx_data
    };


    /* =========================================================
     * FIFO write control
     *
     * A received frame is written only when:
     *
     * 1. A valid accepted RX frame exists
     * 2. This controller is NOT transmitting the frame
     * 3. The FIFO is not full
     *
     * This prevents a controller from placing its own
     * transmitted frame into its RX FIFO.
     *
     * IMPORTANT:
     *
     * is_transmitting does NOT disable CAN RX inside the
     * CAN controller. The CAN controller continues monitoring
     * the physical bus during TX for:
     *
     * - arbitration
     * - ACK
     * - bit error detection
     *
     * Only the FIFO write is suppressed here.
     * ========================================================= */

    assign fifo_write_en =
        rx_frame_valid &&
        (!is_transmitting || loopback) &&
        !fifo_wfull;


    /* =========================================================
     * FIFO read control
     *
     * RX_COMMAND.POP generates rx_pop.
     *
     * The read only occurs when the FIFO is not empty.
     * ========================================================= */

    assign fifo_read_en = rx_pop && !fifo_rempty;


    /* =========================================================
     * Asynchronous FIFO
     * ========================================================= */

    async_fifo #(
        .WIDTH(FIFO_WIDTH),
        .DEPTH(FIFO_DEPTH)
    ) rx_fifo (
        .rclk       (pclk),
        .wclk       (can_clk),

        .w_rst_n    (can_rst_n),
        .r_rst_n    (p_rst_n),

        .r_data     (fifo_rdata),
        .w_data     (fifo_wdata),

        .r_en       (fifo_read_en),
        .w_en       (fifo_write_en),

        .full       (fifo_wfull),
        .empty      (fifo_rempty),

        .fifo_count (fifo_count_raw)
    );


    /* =========================================================
     * FIFO status
     * ========================================================= */

    assign fifo_empty = fifo_rempty;
    assign fifo_full  = fifo_wfull;


    /*
     * Expand internal 4-bit count to the 8-bit APB-visible
     * FIFO_COUNT field.
     *
     * DEPTH=8:
     *
     *     0 -> 8'h00
     *     1 -> 8'h01
     *     ...
     *     8 -> 8'h08
     */

    assign fifo_count = {4'd0, fifo_count_raw};


    /* =========================================================
     * RX register outputs
     *
     * These outputs come directly from the FIFO's registered
     * read-data register.
     *
     * RX_COMMAND.POP
     *       |
     *       v
     * FIFO read enable
     *       |
     *       v
     * next PCLK edge
     *       |
     *       v
     * fifo_rdata updated
     *       |
     *       v
     * RX_ID / RX_CTRL / RX_DATA updated
     * ========================================================= */

    assign rx_identifier_out = fifo_rdata[98:70];

    assign rx_ide_out = fifo_rdata[69];

    assign rx_rtr_out = fifo_rdata[68];

    assign rx_dlc_out = fifo_rdata[67:64];

    assign rx_data_out = fifo_rdata[63:0];


    /* =========================================================
     * RX FIFO overflow
     *
     * If a valid CAN frame arrives while the FIFO is full,
     * the frame is discarded and overflow is latched.
     *
     * No REC penalty is applied here.
     *
     * A self-transmitted frame is not considered an RX FIFO
     * overflow condition because it is intentionally suppressed
     * by fifo_write_en above.
     * ========================================================= */

    always @(posedge can_clk or negedge can_rst_n)
    begin
        if(!can_rst_n)
        begin
            fifo_overflow <= 1'b0;
        end
        else if(rx_frame_valid &&
                (!is_transmitting || loopback) &&
                fifo_wfull)
        begin
            fifo_overflow <= 1'b1;
        end
    end

endmodule
