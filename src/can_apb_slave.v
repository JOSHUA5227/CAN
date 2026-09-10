module can_apb_slave #(
    parameter ADDR_WIDTH = 12
)(
    input  wire                  PCLK,
    input  wire                  PRESETn,

    input  wire [ADDR_WIDTH-1:0] PADDR,
    input  wire                  PSEL,
    input  wire                  PENABLE,
    input  wire                  PWRITE,
    input  wire [31:0]           PWDATA,
    input  wire [3:0]            PSTRB,

    output reg  [31:0]           PRDATA,
    output reg                   PREADY,
    output reg                   PSLVERR,

    /*
     * CAN configuration outputs
     */
    output reg                   can_enable,
    output reg                   loopback,
    output reg                   listen_only,

    output reg  [31:0]           brp,
    output reg  [7:0]            prop_seg,
    output reg  [7:0]            phase_seg1,
    output reg  [7:0]            phase_seg2,
    output reg  [3:0]            sjw,

    /*
     * TX registers
     */
    output reg  [28:0]           tx_identifier,
    output reg                   tx_ide,
    output reg                   tx_rtr,
    output reg  [3:0]            tx_dlc,
    output reg  [63:0]           tx_data,

    output reg                   tx_request,

    /*
     * RX command
     */
    output reg                   rx_pop,

    /*
     * Acceptance filters
     */
    output reg  [28:0]           filter0_id,
    output reg  [28:0]           filter0_mask,
    output reg                   filter0_enable,
    output reg                   filter0_ide,

    output reg  [28:0]           filter1_id,
    output reg  [28:0]           filter1_mask,
    output reg                   filter1_enable,
    output reg                   filter1_ide,

    /*
     * Status inputs from CAN core / RX FIFO
     */
    input  wire                  tx_busy,
    input  wire                  tx_pending,
    input  wire                  tx_done,
    input  wire                  tx_ack_received,
    input  wire                  tx_arbitration_lost,
    input  wire                  tx_error,

    input  wire                  rx_available,
    input  wire                  rx_fifo_full,
    input  wire                  rx_overflow,
    input  wire [7:0]            fifo_count,

    input  wire                  arb_lost,
    input  wire                  ack_error,
    input  wire                  crc_error,
    input  wire                  stuff_error,
    input  wire                  form_error,
    input  wire                  bit_error,

    input  wire [1:0]            error_state,
    input  wire                  recovery_active,
    input  wire                  last_error_valid,
    input  wire [3:0]            last_error_type,

    input  wire [8:0]            tec,
    input  wire [7:0]            rec,

    /*
     * RX head registers
     */
    input  wire [28:0]            rx_identifier,
    input  wire                   rx_ide,
    input  wire                   rx_rtr,
    input  wire [3:0]             rx_dlc,
    input  wire [63:0]            rx_data
);


/* ============================================================
 * REGISTER ADDRESSES
 * ============================================================ */

localparam [ADDR_WIDTH-1:0] ADDR_VERSION       = 12'h000;
localparam [ADDR_WIDTH-1:0] ADDR_CONTROL       = 12'h004;
localparam [ADDR_WIDTH-1:0] ADDR_STATUS        = 12'h008;
localparam [ADDR_WIDTH-1:0] ADDR_ERROR_STATUS  = 12'h00C;

localparam [ADDR_WIDTH-1:0] ADDR_BRP           = 12'h010;
localparam [ADDR_WIDTH-1:0] ADDR_SEGMENTS      = 12'h014;
localparam [ADDR_WIDTH-1:0] ADDR_SJW_CONTROL   = 12'h018;

localparam [ADDR_WIDTH-1:0] ADDR_TX_ID         = 12'h01C;
localparam [ADDR_WIDTH-1:0] ADDR_TX_CTRL       = 12'h020;
localparam [ADDR_WIDTH-1:0] ADDR_TX_DATA_LO    = 12'h024;
localparam [ADDR_WIDTH-1:0] ADDR_TX_DATA_HI    = 12'h028;
localparam [ADDR_WIDTH-1:0] ADDR_TX_COMMAND    = 12'h02C;
localparam [ADDR_WIDTH-1:0] ADDR_TX_STATUS     = 12'h030;

localparam [ADDR_WIDTH-1:0] ADDR_RX_STATUS     = 12'h034;
localparam [ADDR_WIDTH-1:0] ADDR_RX_ID         = 12'h038;
localparam [ADDR_WIDTH-1:0] ADDR_RX_CTRL       = 12'h03C;
localparam [ADDR_WIDTH-1:0] ADDR_RX_DATA_LO    = 12'h040;
localparam [ADDR_WIDTH-1:0] ADDR_RX_DATA_HI    = 12'h044;
localparam [ADDR_WIDTH-1:0] ADDR_RX_COMMAND    = 12'h048;

localparam [ADDR_WIDTH-1:0] ADDR_FILTER0_ID    = 12'h04C;
localparam [ADDR_WIDTH-1:0] ADDR_FILTER0_MASK  = 12'h050;
localparam [ADDR_WIDTH-1:0] ADDR_FILTER0_CTRL  = 12'h054;

localparam [ADDR_WIDTH-1:0] ADDR_FILTER1_ID    = 12'h058;
localparam [ADDR_WIDTH-1:0] ADDR_FILTER1_MASK  = 12'h05C;
localparam [ADDR_WIDTH-1:0] ADDR_FILTER1_CTRL  = 12'h060;

localparam [ADDR_WIDTH-1:0] ADDR_TEC           = 12'h064;
localparam [ADDR_WIDTH-1:0] ADDR_REC           = 12'h068;


/* ============================================================
 * CONSTANTS
 * ============================================================ */

localparam [31:0] VERSION_VALUE = 32'h01002001;


/* ============================================================
 * APB ACCESS DETECTION
 * ============================================================ */

wire apb_access;
wire apb_write;
wire apb_read;

assign apb_access = PSEL && PENABLE;
assign apb_write  = apb_access && PWRITE;
assign apb_read   = apb_access && !PWRITE;


/* ============================================================
 * ADDRESS VALIDITY
 * ============================================================ */

reg address_valid;

always @(*)
begin
    case(PADDR)

        ADDR_VERSION,
        ADDR_CONTROL,
        ADDR_STATUS,
        ADDR_ERROR_STATUS,

        ADDR_BRP,
        ADDR_SEGMENTS,
        ADDR_SJW_CONTROL,

        ADDR_TX_ID,
        ADDR_TX_CTRL,
        ADDR_TX_DATA_LO,
        ADDR_TX_DATA_HI,
        ADDR_TX_COMMAND,
        ADDR_TX_STATUS,

        ADDR_RX_STATUS,
        ADDR_RX_ID,
        ADDR_RX_CTRL,
        ADDR_RX_DATA_LO,
        ADDR_RX_DATA_HI,
        ADDR_RX_COMMAND,

        ADDR_FILTER0_ID,
        ADDR_FILTER0_MASK,
        ADDR_FILTER0_CTRL,

        ADDR_FILTER1_ID,
        ADDR_FILTER1_MASK,
        ADDR_FILTER1_CTRL,

        ADDR_TEC,
        ADDR_REC:

            address_valid = 1'b1;

        default:

            address_valid = 1'b0;

    endcase
end


/* ============================================================
 * WRITE VALIDITY / ILLEGAL ACCESS DETECTION
 * ============================================================ */

reg illegal_write;

always @(*)
begin
    illegal_write = 1'b0;

    if(apb_write)
    begin
        case(PADDR)

            /*
             * VERSION is read-only
             */
            ADDR_VERSION:
                illegal_write = 1'b1;

            /*
             * STATUS registers are read-only
             */
            ADDR_STATUS,
            ADDR_ERROR_STATUS:
                illegal_write = 1'b1;

            /*
             * TX_STATUS is read-only
             */
            ADDR_TX_STATUS:
                illegal_write = 1'b1;

            /*
             * RX_STATUS and RX data are read-only
             */
            ADDR_RX_STATUS,
            ADDR_RX_ID,
            ADDR_RX_CTRL,
            ADDR_RX_DATA_LO,
            ADDR_RX_DATA_HI:
                illegal_write = 1'b1;

            /*
             * TEC / REC are read-only
             */
            ADDR_TEC,
            ADDR_REC:
                illegal_write = 1'b1;

            /*
             * TX_COMMAND and RX_COMMAND are write-only.
             */

            default:
                illegal_write = 1'b0;

        endcase


        /*
         * Timing configuration cannot be changed
         * while CAN is enabled.
         */
        if(can_enable)
        begin
            case(PADDR)

                ADDR_BRP,
                ADDR_SEGMENTS,
                ADDR_SJW_CONTROL:
                    illegal_write = 1'b1;

                ADDR_FILTER0_ID,
                ADDR_FILTER0_MASK,
                ADDR_FILTER0_CTRL,
                ADDR_FILTER1_ID,
                ADDR_FILTER1_MASK,
                ADDR_FILTER1_CTRL:
                    illegal_write = 1'b1;

                default:
                begin
                end

            endcase
        end


        /*
         * Clearing CAN_ENABLE while TX is active
         * is illegal.
         */
        if(PADDR == ADDR_CONTROL)
        begin
            if(can_enable && !PWDATA[0] && tx_busy)
                illegal_write = 1'b1;

            /*
             * LOOPBACK + LISTEN_ONLY is illegal.
             */
            if(PWDATA[1] && PWDATA[2])
                illegal_write = 1'b1;
        end

    end
end


/* ============================================================
 * APB RESPONSE
 * ============================================================ */

always @(*)
begin
    PREADY  = 1'b0;
    PSLVERR = 1'b0;

    if(apb_access)
    begin
        PREADY = 1'b1;

        if(!address_valid)
            PSLVERR = 1'b1;

        else if(illegal_write)
            PSLVERR = 1'b1;
    end
end


/* ============================================================
 * READ DATA
 * ============================================================ */

always @(*)
begin
    PRDATA = 32'h00000000;

    if(apb_read)
    begin
        case(PADDR)

            /*
             * VERSION
             */
            ADDR_VERSION:
                PRDATA = VERSION_VALUE;


            /*
             * CONTROL
             */
            ADDR_CONTROL:
            begin
                PRDATA[0] = can_enable;
                PRDATA[1] = loopback;
                PRDATA[2] = listen_only;
            end


            /*
             * STATUS
             */
            ADDR_STATUS:
            begin
                PRDATA[0]  = tx_busy;
                PRDATA[1]  = tx_done;
                PRDATA[2]  = rx_available;
                PRDATA[3]  = rx_fifo_full;
                PRDATA[4]  = arb_lost;
                PRDATA[5]  = ack_error;
                PRDATA[6]  = crc_error;
                PRDATA[7]  = stuff_error;
                PRDATA[8]  = form_error;
                PRDATA[9]  = bit_error;
                PRDATA[10] = rx_overflow;
            end


            /*
             * ERROR STATUS
             */
            ADDR_ERROR_STATUS:
            begin
                PRDATA[1:0] = error_state;
                PRDATA[2]   = recovery_active;
                PRDATA[3]   = last_error_valid;
                PRDATA[7:4] = last_error_type;
            end


            /*
             * BIT TIMING
             */
            ADDR_BRP:
                PRDATA = brp;

            ADDR_SEGMENTS:
            begin
                PRDATA[7:0]   = prop_seg;
                PRDATA[15:8]  = phase_seg1;
                PRDATA[23:16] = phase_seg2;
            end

            ADDR_SJW_CONTROL:
                PRDATA[3:0] = sjw;


            /*
             * TX
             */
            ADDR_TX_ID:
                PRDATA[28:0] = tx_identifier;

            ADDR_TX_CTRL:
            begin
                PRDATA[0]   = tx_ide;
                PRDATA[1]   = tx_rtr;
                PRDATA[5:2] = tx_dlc;
            end

            ADDR_TX_DATA_LO:
                PRDATA = tx_data[31:0];

            ADDR_TX_DATA_HI:
                PRDATA = tx_data[63:32];

            ADDR_TX_STATUS:
            begin
                PRDATA[0] = tx_pending;
                PRDATA[1] = tx_busy;
                PRDATA[2] = tx_done;
                PRDATA[3] = tx_ack_received;
                PRDATA[4] = tx_arbitration_lost;
                PRDATA[5] = tx_error;
            end


            /*
             * RX
             */
            ADDR_RX_STATUS:
            begin
                /*
                 * FIFO_COUNT comes directly from the RX FIFO
                 * read domain.
                 */
                PRDATA[7:0] = fifo_count;

                PRDATA[8]   = !rx_available;
                PRDATA[9]   = rx_fifo_full;
                PRDATA[10]  = rx_overflow;
            end

            ADDR_RX_ID:
                PRDATA[28:0] = rx_identifier;

            ADDR_RX_CTRL:
            begin
                PRDATA[0]   = rx_ide;
                PRDATA[1]   = rx_rtr;
                PRDATA[5:2] = rx_dlc;
            end

            ADDR_RX_DATA_LO:
                PRDATA = rx_data[31:0];

            ADDR_RX_DATA_HI:
                PRDATA = rx_data[63:32];


            /*
             * FILTER 0
             */
            ADDR_FILTER0_ID:
                PRDATA[28:0] = filter0_id;

            ADDR_FILTER0_MASK:
                PRDATA[28:0] = filter0_mask;

            ADDR_FILTER0_CTRL:
            begin
                PRDATA[0] = filter0_enable;
                PRDATA[1] = filter0_ide;
            end


            /*
             * FILTER 1
             */
            ADDR_FILTER1_ID:
                PRDATA[28:0] = filter1_id;

            ADDR_FILTER1_MASK:
                PRDATA[28:0] = filter1_mask;

            ADDR_FILTER1_CTRL:
            begin
                PRDATA[0] = filter1_enable;
                PRDATA[1] = filter1_ide;
            end


            /*
             * ERROR COUNTERS
             */
            ADDR_TEC:
                PRDATA[8:0] = tec;

            ADDR_REC:
                PRDATA[7:0] = rec;

            default:
                PRDATA = 32'h00000000;

        endcase
    end
end


/* ============================================================
 * APB WRITE LOGIC
 * ============================================================ */

always @(posedge PCLK or negedge PRESETn)
begin
    if(!PRESETn)
    begin

        /*
         * CONTROL
         */
        can_enable  <= 1'b0;
        loopback    <= 1'b0;
        listen_only <= 1'b0;

        /*
         * BIT TIMING
         */
        brp        <= 32'd1;
        prop_seg   <= 8'd0;
        phase_seg1 <= 8'd0;
        phase_seg2 <= 8'd0;
        sjw        <= 4'd0;

        /*
         * TX
         */
        tx_identifier <= 29'd0;
        tx_ide        <= 1'b0;
        tx_rtr        <= 1'b0;
        tx_dlc        <= 4'd0;
        tx_data       <= 64'd0;
        tx_request    <= 1'b0;

        /*
         * RX
         */
        rx_pop <= 1'b0;

        /*
         * FILTER 0
         */
        filter0_id     <= 29'd0;
        filter0_mask   <= 29'd0;
        filter0_enable <= 1'b0;
        filter0_ide    <= 1'b0;

        /*
         * FILTER 1
         */
        filter1_id     <= 29'd0;
        filter1_mask   <= 29'd0;
        filter1_enable <= 1'b0;
        filter1_ide    <= 1'b0;

    end
    else
    begin

        /*
         * One-cycle command pulses.
         */
        tx_request <= 1'b0;
        rx_pop     <= 1'b0;


        if(apb_write && !illegal_write && address_valid)
        begin

            case(PADDR)

                /*
                 * CONTROL
                 */
                ADDR_CONTROL:
                begin
                    if(PSTRB[0])
                    begin
                        can_enable  <= PWDATA[0];
                        loopback    <= PWDATA[1];
                        listen_only <= PWDATA[2];
                    end
                end


                /*
                 * BIT TIMING
                 */
                ADDR_BRP:
                begin
                    if(PSTRB[0])
                        brp[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        brp[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        brp[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        brp[31:24] <= PWDATA[31:24];
                end


                ADDR_SEGMENTS:
                begin
                    if(PSTRB[0])
                        prop_seg <= PWDATA[7:0];

                    if(PSTRB[1])
                        phase_seg1 <= PWDATA[15:8];

                    if(PSTRB[2])
                        phase_seg2 <= PWDATA[23:16];
                end


                ADDR_SJW_CONTROL:
                begin
                    if(PSTRB[0])
                        sjw <= PWDATA[3:0];
                end


                /*
                 * TX ID
                 */
                ADDR_TX_ID:
                begin
                    if(PSTRB[0])
                        tx_identifier[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        tx_identifier[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        tx_identifier[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        tx_identifier[28:24] <= PWDATA[28:24];
                end


                /*
                 * TX CONTROL
                 */
                ADDR_TX_CTRL:
                begin
                    if(PSTRB[0])
                    begin
                        tx_ide <= PWDATA[0];
                        tx_rtr <= PWDATA[1];
                        tx_dlc <= PWDATA[5:2];
                    end
                end


                /*
                 * TX DATA LOW
                 */
                ADDR_TX_DATA_LO:
                begin
                    if(PSTRB[0])
                        tx_data[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        tx_data[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        tx_data[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        tx_data[31:24] <= PWDATA[31:24];
                end


                /*
                 * TX DATA HIGH
                 */
                ADDR_TX_DATA_HI:
                begin
                    if(PSTRB[0])
                        tx_data[39:32] <= PWDATA[7:0];

                    if(PSTRB[1])
                        tx_data[47:40] <= PWDATA[15:8];

                    if(PSTRB[2])
                        tx_data[55:48] <= PWDATA[23:16];

                    if(PSTRB[3])
                        tx_data[63:56] <= PWDATA[31:24];
                end


                /*
                 * TX COMMAND
                 */
                ADDR_TX_COMMAND:
                begin
                    if(PSTRB[0] && PWDATA[0])
                        tx_request <= 1'b1;
                end


                /*
                 * RX COMMAND
                 */
                ADDR_RX_COMMAND:
                begin
                    if(PSTRB[0] && PWDATA[0])
                        rx_pop <= 1'b1;
                end


                /*
                 * FILTER 0 ID
                 */
                ADDR_FILTER0_ID:
                begin
                    if(PSTRB[0])
                        filter0_id[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        filter0_id[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        filter0_id[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        filter0_id[28:24] <= PWDATA[28:24];
                end


                /*
                 * FILTER 0 MASK
                 */
                ADDR_FILTER0_MASK:
                begin
                    if(PSTRB[0])
                        filter0_mask[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        filter0_mask[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        filter0_mask[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        filter0_mask[28:24] <= PWDATA[28:24];
                end


                /*
                 * FILTER 0 CONTROL
                 */
                ADDR_FILTER0_CTRL:
                begin
                    if(PSTRB[0])
                    begin
                        filter0_enable <= PWDATA[0];
                        filter0_ide    <= PWDATA[1];
                    end
                end


                /*
                 * FILTER 1 ID
                 */
                ADDR_FILTER1_ID:
                begin
                    if(PSTRB[0])
                        filter1_id[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        filter1_id[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        filter1_id[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        filter1_id[28:24] <= PWDATA[28:24];
                end


                /*
                 * FILTER 1 MASK
                 */
                ADDR_FILTER1_MASK:
                begin
                    if(PSTRB[0])
                        filter1_mask[7:0] <= PWDATA[7:0];

                    if(PSTRB[1])
                        filter1_mask[15:8] <= PWDATA[15:8];

                    if(PSTRB[2])
                        filter1_mask[23:16] <= PWDATA[23:16];

                    if(PSTRB[3])
                        filter1_mask[28:24] <= PWDATA[28:24];
                end


                /*
                 * FILTER 1 CONTROL
                 */
                ADDR_FILTER1_CTRL:
                begin
                    if(PSTRB[0])
                    begin
                        filter1_enable <= PWDATA[0];
                        filter1_ide    <= PWDATA[1];
                    end
                end


                default:
                begin
                end

            endcase
        end
    end
end

endmodule
