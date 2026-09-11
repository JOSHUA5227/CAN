module can_rx_fifo_bridge #(
    parameter FIFO_DEPTH = 8 
)(
    input  wire        can_clk,
    input  wire        can_rst_n,

    input  wire        rx_frame_valid,
    input  wire [28:0] rx_identifier,
    input  wire        rx_ide,
    input  wire        rx_rtr,
    input  wire [3:0]  rx_dlc,
    input  wire [63:0] rx_data,

    input  wire        is_transmitting,
    input  wire        loopback,

    input  wire        pclk,
    input  wire        p_rst_n,

    input  wire        rx_pop,

    output wire [28:0] rx_identifier_out,
    output wire        rx_ide_out,
    output wire        rx_rtr_out,
    output wire [3:0]  rx_dlc_out,
    output wire [63:0] rx_data_out,

    output wire [7:0]  fifo_count,
    output wire        fifo_empty,
    output wire        fifo_full,
    output wire        fifo_full_pclk,
    output reg         fifo_overflow
);


    localparam FIFO_WIDTH = 128;

    wire [FIFO_WIDTH-1:0] fifo_wdata;
    wire [FIFO_WIDTH-1:0] fifo_rdata;

    wire fifo_rfull;
    wire fifo_wfull;
    wire fifo_rempty;

    wire fifo_write_en;
    wire fifo_read_en;

    wire [3:0] fifo_count_raw;

    assign fifo_wdata = {
        29'd0,
        rx_identifier,
        rx_ide,
        rx_rtr,
        rx_dlc,
        rx_data
    };


    assign fifo_write_en =
        rx_frame_valid &&
        (!is_transmitting || loopback) &&
        !fifo_wfull;


    assign fifo_read_en = rx_pop && !fifo_rempty;


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

        .r_full     (fifo_rfull),
        .full       (fifo_wfull),
        .empty      (fifo_rempty),

        .fifo_count (fifo_count_raw)
    );


    assign fifo_empty = fifo_rempty;

    assign fifo_full = fifo_wfull;

    assign fifo_full_pclk = fifo_rfull;

    assign fifo_count = {4'd0, fifo_count_raw};

    assign rx_identifier_out = fifo_rdata[98:70];

    assign rx_ide_out = fifo_rdata[69];

    assign rx_rtr_out = fifo_rdata[68];

    assign rx_dlc_out = fifo_rdata[67:64];

    assign rx_data_out = fifo_rdata[63:0];


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
