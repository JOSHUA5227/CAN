module can_controller #(
    parameter CAN_CLK_FREQ = 100_000_000,
    parameter CAN_BIT_RATE = 1_000_000
)(
input wire clk,
input wire rst_n,

input wire can_rx,
output wire can_tx,

input wire [31:0] brp,
input wire [7:0] prop_seg,
input wire [7:0] phase_seg1,
input wire [7:0] phase_seg2,
input wire [3:0] sjw,

input wire tx_valid,
input wire tx_ide,
input wire [28:0] tx_identifier,
input wire [3:0] tx_dlc,
input wire [63:0] tx_data,
input wire tx_rtr,

output wire [28:0] rx_identifier,
output wire rx_rtr,
output wire rx_ide,
output wire [3:0] rx_dlc,
output wire [63:0] rx_data,
output wire rx_frame_valid,

output wire tx_done,
output wire rx_done,
output wire line_busy,

output wire [8:0] tec,
output wire [7:0] rec,
output wire [1:0] error_state,
output wire ack_received,

output wire bit_en,
output wire sample_en,
output wire can_rx_sync,
output wire can_rx_sample
);

localparam IDLE           = 4'd0;
localparam SOF            = 4'd1;
localparam ARBITRATION    = 4'd2;
localparam CONTROL        = 4'd3;
localparam DATA           = 4'd4;
localparam CRC            = 4'd5;
localparam CRC_DELIM      = 4'd6;
localparam ACK            = 4'd7;
localparam ACK_DELIM      = 4'd8;
localparam EOF            = 4'd9;
localparam INTERMISSION   = 4'd10;
localparam ERROR_FLAG     = 4'd11;
localparam WAIT_RECESSIVE = 4'd12;
localparam ERROR_DELIM    = 4'd13;
localparam RX_ONLY        = 4'd14;

localparam ERROR_ACTIVE  = 2'd0;
localparam ERROR_PASSIVE = 2'd1;
localparam BUS_OFF       = 2'd2;

wire sof_detected;

wire [3:0] field_sel;
wire [5:0] bit_cnt;
wire [2:0] byte_idx;
wire arb_phase;
wire is_transmitting;
wire active_ide;
wire crc_en;
wire stuff_en;
wire ack_drive;
wire bit_error_occured;

wire rx_rtr_int;
wire [3:0] rx_dlc_int;
wire rx_ide_int;

wire rx_bit_destuffed;
wire rx_bit_valid;
wire stuff_error;

wire tx_data_bit;
wire tx_bit_pre_stuff;
wire tx_bit_stuffed;
wire stuff_insert;

wire tx_crc_out;
wire tx_crc_error;
wire rx_crc_error;

wire ack_error;
wire form_error;
wire bit_error;

wire error_event;
wire error_flag_request;
wire error_flag_active;

wire [14:0] tx_crc_value;
wire [14:0] rx_crc_value;

wire tx_crc_select;
wire tx_bus_bit;
wire sof_request;

reg tx_pending;
reg sof_pending;

assign sof_request = sof_pending || sof_detected;

// ------------------------------------------------------------
// TX bit selection
//
// tx_datapath is combinational in the fixed version, so the
// current logical frame bit is available before bit_en.
// During CRC, crc_out supplies the generated CRC bit.
// ------------------------------------------------------------
assign tx_crc_select = is_transmitting && (field_sel == CRC);
assign tx_bit_pre_stuff = tx_crc_select ? tx_crc_out : tx_data_bit;

// The stuffer output is the physical TX bit.
assign tx_bus_bit = stuff_en ? tx_bit_stuffed : tx_bit_pre_stuff;

// CAN idle is recessive. Do not expose the stuffer reset value
// while the controller is idle.
assign can_tx = (field_sel == IDLE) ? 1'b1 :
                (ack_drive ? 1'b0 :
                (is_transmitting ? tx_bus_bit : 1'b1));

// Any actual protocol error requests an error flag.
assign error_event =
       bit_error_occured ||
       ack_error ||
       form_error ||
       stuff_error ||
       rx_crc_error;

// ------------------------------------------------------------
// RX synchronization and sampling
// ------------------------------------------------------------
can_rx_sync u_rx_sync(
    .clk(clk),
    .rst_n(rst_n),
    .din(can_rx),
    .rx_sync(can_rx_sync)
);

can_rx_sample u_rx_sample(
    .clk(clk),
    .rst_n(rst_n),
    .sample_en(sample_en),
    .can_rx_sync(can_rx_sync),
    .can_rx_sample(can_rx_sample)
);

// ------------------------------------------------------------
// Bit timing
// ------------------------------------------------------------
bit_timing_engine #(
    .CAN_CLK_FREQ(CAN_CLK_FREQ),
    .CAN_BIT_RATE(CAN_BIT_RATE)
) u_bte (
    .clk(clk),
    .rst_n(rst_n),
    .can_rx_sync(can_rx_sync),
    .state(field_sel),
    .brp(brp),
    .prop_seg(prop_seg),
    .phase_seg1(phase_seg1),
    .phase_seg2(phase_seg2),
    .sjw(sjw),
    .sample_en(sample_en),
    .sof_detected(sof_detected),
    .bit_en(bit_en)
);

// ------------------------------------------------------------
// TX buffer
// ------------------------------------------------------------
wire [28:0] tx_identifier_reg;
wire [3:0]  tx_dlc_reg;
wire        tx_ide_reg;
wire        tx_rtr_reg;
wire [7:0]  tx_byte_selected;
wire [63:0] tx_data_buffered;

// tx_byte_selected is already the selected byte from tx_buffer.
// Keep this separate from the buffered 64-bit word for clarity.

tx_buffer u_tx_buffer(
    .clk(clk),
    .rst_n(rst_n),
    .ide(tx_ide),
    .identifier(tx_identifier),
    .dlc(tx_dlc),
    .data(tx_data),
    .rtr(tx_rtr),
    .valid(tx_valid && !line_busy),
    .busy(line_busy),
    .byte_idx(byte_idx),
    .reg_ide(tx_ide_reg),
    .reg_identifier(tx_identifier_reg),
    .reg_dlc(tx_dlc_reg),
    .reg_data(tx_data_buffered),
    .reg_rtr(tx_rtr_reg),
    .tx_byte(tx_byte_selected)
);

// ------------------------------------------------------------
// TX datapath
// ------------------------------------------------------------
tx_datapath u_tx_datapath(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .is_transmitting(is_transmitting),
    .state(field_sel),
    .arb_phase(arb_phase),
    .rtr(tx_rtr_reg),
    .ide(tx_ide_reg),
    .identifier(tx_identifier_reg),
    .dlc(tx_dlc_reg),
    .data(tx_byte_selected),
    .bit_cnt(bit_cnt),
    .error_mode(error_flag_active ? ERROR_ACTIVE : ERROR_PASSIVE),
    .tx_data(tx_data_bit)
);

// ------------------------------------------------------------
// TX stuffer
// ------------------------------------------------------------
can_stuffer u_stuffer(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .tx_bit(tx_bit_pre_stuff),
    .stuff_en(stuff_en),
    .tx_bit_stuffed(tx_bit_stuffed),
    .stuff_insert(stuff_insert)
);

// ------------------------------------------------------------
// RX destuffer
// ------------------------------------------------------------
can_destuffer u_destuffer(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .rx_bit(can_rx_sample),
    .stuff_en(stuff_en),
    .rx_bit_destuffed(rx_bit_destuffed),
    .rx_bit_valid(rx_bit_valid),
    .stuff_error(stuff_error)
);

// ------------------------------------------------------------
// RX datapath
// ------------------------------------------------------------
can_rx_datapath u_rx_datapath(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .state(field_sel),
    .bit_cnt(bit_cnt),
    .arb_phase(arb_phase),
    .active_ide(active_ide),
    .rx_bit_destuffed(rx_bit_destuffed),
    .rx_bit_valid(rx_bit_valid),
    .rx_identifier(rx_identifier),
    .rx_rtr(rx_rtr_int),
    .rx_ide(rx_ide_int),
    .rx_dlc(rx_dlc_int),
    .rx_data(rx_data),
    .rx_frame_valid(rx_frame_valid)
);

assign rx_rtr = rx_rtr_int;
assign rx_ide = rx_ide_int;
assign rx_dlc = rx_dlc_int;

// ------------------------------------------------------------
// TX CRC
//
// The logical tx_data_bit is generated combinationally from the
// current FSM position. The CRC accumulator therefore consumes
// the same logical sequence as the stuffer, not tx_bit_stuffed.
// ------------------------------------------------------------
crc u_tx_crc(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .state(field_sel),
    .crc_en(crc_en && is_transmitting && !stuff_insert),
    .data_bit(tx_data_bit),
    .crc_done(1'b0),
    .crc_value(tx_crc_value),
    .crc_out(tx_crc_out),
    .crc_error(tx_crc_error)
);

// ------------------------------------------------------------
// RX CRC
//
// rx_bit_valid is used because the registered destuffer marks a
// physical stuff cycle invalid. This prevents a stuff bit from
// being counted as another CRC input bit.
// ------------------------------------------------------------
crc u_rx_crc(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .state(field_sel),
    .crc_en(crc_en && !is_transmitting && rx_bit_valid),
    .data_bit(rx_bit_destuffed),
    .crc_done((field_sel == CRC) &&
              (bit_cnt == 6'd1) &&
              rx_bit_valid),
    .crc_value(rx_crc_value),
    .crc_out(),
    .crc_error(rx_crc_error)
);

// ------------------------------------------------------------
// ACK detector
// ------------------------------------------------------------
can_ack_detector u_ack_detector(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .state(field_sel),
    .is_transmitting(is_transmitting),
    .can_rx_sync(can_rx_sample),
    .ack_received(ack_received),
    .ack_error(ack_error)
);

// ------------------------------------------------------------
// Bit error detection
//
// tx_bus_bit represents the physical bit being driven during the
// current bit interval. For a transmitter it is compared with the
// sampled bus; for a receiver there is no local transmitted bit.
// ------------------------------------------------------------
wire bit_error_compare_bit;
assign bit_error_compare_bit = is_transmitting ? tx_bus_bit : can_rx_sample;

bit_error_detector u_bit_error_detector(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .tx_bit(bit_error_compare_bit),
    .can_rx_sync(can_rx_sample),
    .bit_error(bit_error)
);

// ------------------------------------------------------------
// Form error detection
// ------------------------------------------------------------
can_form_error_detector u_form_error_detector(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .state(field_sel),
    .can_rx_sync(can_rx_sample),
    .form_error(form_error)
);

// ------------------------------------------------------------
// Error controller
// ------------------------------------------------------------
error_controller u_error_controller(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .state(field_sel),
    .is_transmitting(is_transmitting),
    .can_rx_sync(can_rx_sample),
    .bit_error(bit_error),
    .bit_error_occured(bit_error_occured),
    .tx_bit(tx_bus_bit),
    .bit_cnt(bit_cnt),
    .arb_phase(arb_phase),
    .active_ide(active_ide),
    .ack_error(ack_error),
    .form_error(form_error),
    .stuff_error(stuff_error),
    .crc_error(rx_crc_error),
    .tx_done(tx_done),
    .rx_done(rx_done),
    .tec(tec),
    .rec(rec),
    .error_state(error_state),
    .error_flag_active(error_flag_active),
    .error_flag_request(error_flag_request)
);

// ------------------------------------------------------------
// Frame controller
// ------------------------------------------------------------
can_frame_controller u_frame_controller(
    .clk(clk),
    .rst_n(rst_n),
    .bit_en(bit_en),
    .can_rx_sync(can_rx_sample),
    .sof_detected(sof_request),
    .tx_request(tx_pending),
    .rtr(tx_rtr_reg),
    .ide(tx_ide_reg),
    .dlc(tx_dlc_reg),
    .bit_error(bit_error),
    .error_event(error_event),
    .error_flag_request(error_flag_request),
    .stuff_insert(stuff_insert),
    .rx_bit_valid(rx_bit_valid),
    .rx_rtr(rx_rtr_int),
    .rx_dlc(rx_dlc_int),
    .rx_ide(rx_ide_int),
    .error_state(error_state),
    .ack_drive(ack_drive),
    .arb_phase(arb_phase),
    .is_transmitting(is_transmitting),
    .field_sel(field_sel),
    .bit_cnt(bit_cnt),
    .byte_idx(byte_idx),
    .crc_en(crc_en),
    .stuff_en(stuff_en),
    .bit_error_occured(bit_error_occured),
    .active_ide(active_ide),
    .tx_done(tx_done),
    .rx_done(rx_done),
    .line_busy(line_busy)
);

// ------------------------------------------------------------
// TX request latch
// ------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        tx_pending <= 1'b0;
    else
    begin
        if(tx_valid && !line_busy)
            tx_pending <= 1'b1;
        else if(line_busy && is_transmitting)
            tx_pending <= 1'b0;
    end
end

// ------------------------------------------------------------
// Receive SOF pending latch
// ------------------------------------------------------------
always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
        sof_pending <= 1'b0;
    else
    begin
        if(sof_detected && (field_sel == IDLE))
            sof_pending <= 1'b1;
        else if(bit_en && (field_sel == IDLE))
            sof_pending <= 1'b0;
    end
end

endmodule

