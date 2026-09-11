/*
 * CAN 2.0B acceptance filter
 *
 * Mask semantics:
 *   mask bit = 1 -> compare that identifier bit
 *   mask bit = 0 -> don't care
 *
 * If both filters are disabled, all valid received frames are accepted.
 * If one or both filters are enabled, a valid frame is accepted when it
 * matches at least one enabled filter.
 */
module can_acceptance_filter #(
    parameter ID_WIDTH = 29
)(
    input  wire [ID_WIDTH-1:0] rx_identifier,
    input  wire                rx_ide,
    input  wire                rx_frame_valid,

    input  wire [ID_WIDTH-1:0] filter0_id,
    input  wire [ID_WIDTH-1:0] filter0_mask,
    input  wire                filter0_enable,
    input  wire                filter0_ide,

    input  wire [ID_WIDTH-1:0] filter1_id,
    input  wire [ID_WIDTH-1:0] filter1_mask,
    input  wire                filter1_enable,
    input  wire                filter1_ide,

    output wire                frame_accepted
);

    wire filter0_match;
    wire filter1_match;
    wire any_filter_enabled;

    assign any_filter_enabled = filter0_enable | filter1_enable;

    assign filter0_match =
        filter0_enable &&
        rx_frame_valid &&
        (rx_ide == filter0_ide) &&
        ((rx_identifier & filter0_mask) ==
         (filter0_id   & filter0_mask));

    assign filter1_match =
        filter1_enable &&
        rx_frame_valid &&
        (rx_ide == filter1_ide) &&
        ((rx_identifier & filter1_mask) ==
         (filter1_id   & filter1_mask));

    /*
     * No filters enabled:
     *     accept every valid frame.
     *
     * One or more filters enabled:
     *     accept only a matching enabled filter.
     */
    assign frame_accepted =
        rx_frame_valid &&
        ((!any_filter_enabled) ||
         filter0_match ||
         filter1_match);

endmodule

