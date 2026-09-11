module can_apb_slave #(
    parameter ADDR_WIDTH = 12
)(
    input wire                  PCLK,
    input wire                  PRESETn,

    input wire [ADDR_WIDTH-1:0] PADDR,
    input wire                  PSEL,
    input wire                  PENABLE,
    input wire                  PWRITE,
    input wire [31:0]           PWDATA,
    input wire [3:0]            PSTRB,

    output reg [31:0]           PRDATA,
    output reg                  PREADY,
    output reg                  PSLVERR,

    /*
     * CONTROL
     */
    output reg                  can_enable,
    output reg                  loopback,
    output reg                  listen_only,

    /*
     * BIT TIMING
     */
    output reg [31:0]           brp,
    output reg [7:0]            prop_seg,
    output reg [7:0]            phase_seg1,
    output reg [7:0]            phase_seg2,
    output reg [3:0]            sjw,

    /*
     * TX
     */
    output reg [28:0]           tx_identifier,
    output reg                  tx_ide,
    output reg                  tx_rtr,
    output reg [3:0]            tx_dlc,
    output reg [63:0]           tx_data,
    output reg                  tx_request,

    /*
     * RX
     */
    output reg                  rx_pop,

    /*
     * FILTER 0
     */
    output reg [28:0]           filter0_id,
    output reg [28:0]           filter0_mask,
    output reg                  filter0_enable,
    output reg                  filter0_ide,

    /*
     * FILTER 1
     */
    output reg [28:0]           filter1_id,
    output reg [28:0]           filter1_mask,
    output reg                  filter1_enable,
    output reg                  filter1_ide,

    /*
     * TX STATUS
     */
    input wire                  tx_busy,
    input wire                  tx_pending,
    input wire                  tx_done,
    input wire                  tx_ack_received,
    input wire                  tx_arbitration_lost,
    input wire                  tx_error,

    /*
     * RX FIFO STATUS
     */
    input wire                  rx_available,
    input wire                  rx_fifo_full_pclk,
    input wire                  rx_overflow,
    input wire [7:0]            fifo_count,

    /*
     * RX DATA
     */
    input wire [28:0]            rx_identifier,
    input wire                   rx_ide,
    input wire                   rx_rtr,
    input wire [3:0]             rx_dlc,
    input wire [63:0]            rx_data,

    /*
     * ERROR STATUS
     */
    input wire [1:0]             error_state,
    input wire                   recovery_active,
    input wire                   last_error_valid,
    input wire [3:0]             last_error_type,

    /*
     * ERROR FLAGS
     */
    input wire                   arb_lost,
    input wire                   ack_error,
    input wire                   crc_error,
    input wire                   stuff_error,
    input wire                   form_error,
    input wire                   bit_error,

    /*
     * ERROR COUNTERS
     */
    input wire [8:0]             tec,
    input wire [7:0]             rec
);

    /*
     * ================================================================
     * REGISTER ADDRESSES
     * ================================================================
     */

    localparam [11:0] ADDR_VERSION       = 12'h000;
    localparam [11:0] ADDR_CONTROL       = 12'h004;
    localparam [11:0] ADDR_STATUS        = 12'h008;
    localparam [11:0] ADDR_ERROR_STATUS  = 12'h00C;
    localparam [11:0] ADDR_BRP           = 12'h010;
    localparam [11:0] ADDR_SEGMENTS      = 12'h014;
    localparam [11:0] ADDR_SJW_CONTROL   = 12'h018;

    localparam [11:0] ADDR_TX_ID         = 12'h01C;
    localparam [11:0] ADDR_TX_CTRL       = 12'h020;
    localparam [11:0] ADDR_TX_DATA_LO    = 12'h024;
    localparam [11:0] ADDR_TX_DATA_HI    = 12'h028;
    localparam [11:0] ADDR_TX_COMMAND    = 12'h02C;
    localparam [11:0] ADDR_TX_STATUS     = 12'h030;

    localparam [11:0] ADDR_RX_STATUS     = 12'h034;
    localparam [11:0] ADDR_RX_ID         = 12'h038;
    localparam [11:0] ADDR_RX_CTRL       = 12'h03C;
    localparam [11:0] ADDR_RX_DATA_LO    = 12'h040;
    localparam [11:0] ADDR_RX_DATA_HI    = 12'h044;
    localparam [11:0] ADDR_RX_COMMAND    = 12'h048;

    localparam [11:0] ADDR_FILTER0_ID    = 12'h04C;
    localparam [11:0] ADDR_FILTER0_MASK  = 12'h050;
    localparam [11:0] ADDR_FILTER0_CTRL  = 12'h054;

    localparam [11:0] ADDR_FILTER1_ID    = 12'h058;
    localparam [11:0] ADDR_FILTER1_MASK  = 12'h05C;
    localparam [11:0] ADDR_FILTER1_CTRL  = 12'h060;

    localparam [11:0] ADDR_TEC           = 12'h064;
    localparam [11:0] ADDR_REC           = 12'h068;


    /*
     * ================================================================
     * STICKY TX STATUS
     * ================================================================
     */

    reg tx_done_latched;
    reg tx_ack_received_latched;
    reg tx_arbitration_lost_latched;
    reg tx_error_latched;


    /*
     * ================================================================
     * CAN_CLK -> PCLK RX STATUS SYNCHRONIZERS
     * ================================================================
     *
     * rx_fifo_full_pclk is already generated in the PCLK domain
     * by the asynchronous FIFO.
     *
     * rx_overflow still originates in the CAN clock domain and
     * therefore continues to use a 2-FF synchronizer.
     */

    reg rx_overflow_sync1;
    reg rx_overflow_sync2;


    /*
     * ================================================================
     * APB ACCESS
     * ================================================================
     */

    wire apb_access;
    wire tx_command_start;

    assign apb_access = PSEL && PENABLE;
    assign tx_command_start = apb_access && PWRITE &&
                              (PADDR == ADDR_TX_COMMAND) &&
                              PSTRB[0] && PWDATA[0];


    /*
     * ================================================================
     * CAN_CLK -> PCLK RX STATUS SYNCHRONIZATION
     * ================================================================
     */

    always @(posedge PCLK or negedge PRESETn)
    begin
        if(!PRESETn)
        begin
            rx_overflow_sync1 <= 1'b0;
            rx_overflow_sync2 <= 1'b0;
        end
        else
        begin
            rx_overflow_sync1 <= rx_overflow;
            rx_overflow_sync2 <= rx_overflow_sync1;
        end
    end


    /*
     * ================================================================
     * SEQUENTIAL LOGIC
     * ================================================================
     */

    always @(posedge PCLK or negedge PRESETn)
    begin
        if(!PRESETn)
        begin
            can_enable <= 1'b0;
            loopback <= 1'b0;
            listen_only <= 1'b0;

            brp <= 32'd0;
            prop_seg <= 8'd0;
            phase_seg1 <= 8'd0;
            phase_seg2 <= 8'd0;
            sjw <= 4'd0;

            tx_identifier <= 29'd0;
            tx_ide <= 1'b0;
            tx_rtr <= 1'b0;
            tx_dlc <= 4'd0;
            tx_data <= 64'd0;
            tx_request <= 1'b0;

            rx_pop <= 1'b0;

            filter0_id <= 29'd0;
            filter0_mask <= 29'd0;
            filter0_enable <= 1'b0;
            filter0_ide <= 1'b0;

            filter1_id <= 29'd0;
            filter1_mask <= 29'd0;
            filter1_enable <= 1'b0;
            filter1_ide <= 1'b0;

            tx_done_latched <= 1'b0;
            tx_ack_received_latched <= 1'b0;
            tx_arbitration_lost_latched <= 1'b0;
            tx_error_latched <= 1'b0;
        end
        else
        begin
            /*
             * DEFAULT PULSES
             */

            tx_request <= 1'b0;
            rx_pop <= 1'b0;


            /*
             * CAPTURE CDC TX EVENTS INTO STICKY PCLK REGISTERS
             */

            tx_done_latched <= tx_command_start ? 1'b0 :
                               (tx_done ? 1'b1 : tx_done_latched);

            tx_ack_received_latched <= tx_command_start ? 1'b0 :
                                       (tx_ack_received ? 1'b1 :
                                        tx_ack_received_latched);

            tx_arbitration_lost_latched <= tx_command_start ? 1'b0 :
                                           (tx_arbitration_lost ? 1'b1 :
                                            tx_arbitration_lost_latched);

            tx_error_latched <= tx_command_start ? 1'b0 :
                                (tx_error ? 1'b1 : tx_error_latched);


            /*
             * APB WRITE
             */

            if(apb_access && PWRITE)
            begin
                case(PADDR)

                    /*
                     * CONTROL
                     */

                    ADDR_CONTROL:
                    begin
                        if(PSTRB[0])
                        begin
                            if(PWDATA[1] && PWDATA[2])
                            begin
                            end
                            else if(!PWDATA[0] && tx_busy)
                            begin
                            end
                            else
                            begin
                                can_enable <= PWDATA[0];
                                loopback <= PWDATA[1];
                                listen_only <= PWDATA[2];
                            end
                        end
                    end


                    /*
                     * BIT RATE PRESCALER
                     */

                    ADDR_BRP:
                    begin
                        if(!can_enable)
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
                    end


                    /*
                     * SEGMENTS
                     */

                    ADDR_SEGMENTS:
                    begin
                        if(!can_enable)
                        begin
                            if(PSTRB[0])
                                prop_seg <= PWDATA[7:0];

                            if(PSTRB[1])
                                phase_seg1 <= PWDATA[15:8];

                            if(PSTRB[2])
                                phase_seg2 <= PWDATA[23:16];
                        end
                    end


                    /*
                     * SJW
                     */

                    ADDR_SJW_CONTROL:
                    begin
                        if(!can_enable)
                        begin
                            if(PSTRB[0])
                                sjw <= PWDATA[3:0];
                        end
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
                        begin
                            tx_request <= 1'b1;
                        end
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
                        if(!can_enable)
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
                    end


                    /*
                     * FILTER 0 MASK
                     */

                    ADDR_FILTER0_MASK:
                    begin
                        if(!can_enable)
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
                    end


                    /*
                     * FILTER 0 CONTROL
                     */

                    ADDR_FILTER0_CTRL:
                    begin
                        if(!can_enable)
                        begin
                            if(PSTRB[0])
                            begin
                                filter0_enable <= PWDATA[0];
                                filter0_ide <= PWDATA[1];
                            end
                        end
                    end


                    /*
                     * FILTER 1 ID
                     */

                    ADDR_FILTER1_ID:
                    begin
                        if(!can_enable)
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
                    end


                    /*
                     * FILTER 1 MASK
                     */

                    ADDR_FILTER1_MASK:
                    begin
                        if(!can_enable)
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
                    end


                    /*
                     * FILTER 1 CONTROL
                     */

                    ADDR_FILTER1_CTRL:
                    begin
                        if(!can_enable)
                        begin
                            if(PSTRB[0])
                            begin
                                filter1_enable <= PWDATA[0];
                                filter1_ide <= PWDATA[1];
                            end
                        end
                    end


                    /*
                     * READ-ONLY REGISTERS
                     */

                    ADDR_VERSION:
                    begin
                    end

                    ADDR_STATUS:
                    begin
                    end

                    ADDR_ERROR_STATUS:
                    begin
                    end

                    ADDR_TX_STATUS:
                    begin
                    end

                    ADDR_RX_STATUS:
                    begin
                    end

                    ADDR_RX_ID:
                    begin
                    end

                    ADDR_RX_CTRL:
                    begin
                    end

                    ADDR_RX_DATA_LO:
                    begin
                    end

                    ADDR_RX_DATA_HI:
                    begin
                    end

                    ADDR_TEC:
                    begin
                    end

                    ADDR_REC:
                    begin
                    end


                    /*
                     * UNMAPPED
                     */

                    default:
                    begin
                    end

                endcase
            end
        end
    end


    /*
     * ================================================================
     * APB READ DATA
     * ================================================================
     */

    always @(*)
    begin
        PRDATA = 32'd0;
        PREADY = 1'b1;

        if(apb_access && !PWRITE)
        begin
            case(PADDR)

                /*
                 * VERSION
                 */

                ADDR_VERSION:
                begin
                    PRDATA = 32'h01002001;
                end


                /*
                 * CONTROL
                 */

                ADDR_CONTROL:
                begin
                    PRDATA = {29'd0, listen_only, loopback, can_enable};
                end


                /*
                 * STATUS
                 */

                ADDR_STATUS:
                begin
                    PRDATA = {21'd0, rx_overflow_sync2, bit_error, form_error,
                              stuff_error, crc_error, ack_error, arb_lost,
                              rx_fifo_full_pclk, rx_available,
                              tx_done_latched, tx_busy};
                end


                /*
                 * ERROR STATUS
                 */

                ADDR_ERROR_STATUS:
                begin
                    PRDATA = {24'd0, last_error_type, last_error_valid,
                              recovery_active, error_state};
                end


                /*
                 * BRP
                 */

                ADDR_BRP:
                begin
                    PRDATA = brp;
                end


                /*
                 * SEGMENTS
                 */

                ADDR_SEGMENTS:
                begin
                    PRDATA = {8'd0, phase_seg2, phase_seg1, prop_seg};
                end


                /*
                 * SJW
                 */

                ADDR_SJW_CONTROL:
                begin
                    PRDATA = {28'd0, sjw};
                end


                /*
                 * TX ID
                 */

                ADDR_TX_ID:
                begin
                    PRDATA = {3'd0, tx_identifier};
                end


                /*
                 * TX CTRL
                 */

                ADDR_TX_CTRL:
                begin
                    PRDATA = {26'd0, tx_dlc, tx_rtr, tx_ide};
                end


                /*
                 * TX DATA LOW
                 */

                ADDR_TX_DATA_LO:
                begin
                    PRDATA = tx_data[31:0];
                end


                /*
                 * TX DATA HIGH
                 */

                ADDR_TX_DATA_HI:
                begin
                    PRDATA = tx_data[63:32];
                end


                /*
                 * TX COMMAND
                 */

                ADDR_TX_COMMAND:
                begin
                    PRDATA = 32'd0;
                end


                /*
                 * TX STATUS
                 */

                ADDR_TX_STATUS:
                begin
                    PRDATA = {26'd0, tx_error_latched,
                              tx_arbitration_lost_latched,
                              tx_ack_received_latched, tx_done_latched,
                              tx_busy, tx_pending};
                end


                /*
                 * RX STATUS
                 */

                ADDR_RX_STATUS:
                begin
                    PRDATA = {21'd0, rx_overflow_sync2, rx_fifo_full_pclk,
                              !rx_available, fifo_count};
                end


                /*
                 * RX ID
                 */

                ADDR_RX_ID:
                begin
                    PRDATA = {3'd0, rx_identifier};
                end


                /*
                 * RX CTRL
                 */

                ADDR_RX_CTRL:
                begin
                    PRDATA = {26'd0, rx_dlc, rx_rtr, rx_ide};
                end


                /*
                 * RX DATA LOW
                 */

                ADDR_RX_DATA_LO:
                begin
                    PRDATA = rx_data[31:0];
                end


                /*
                 * RX DATA HIGH
                 */

                ADDR_RX_DATA_HI:
                begin
                    PRDATA = rx_data[63:32];
                end


                /*
                 * RX COMMAND
                 */

                ADDR_RX_COMMAND:
                begin
                    PRDATA = 32'd0;
                end


                /*
                 * FILTER 0 ID
                 */

                ADDR_FILTER0_ID:
                begin
                    PRDATA = {3'd0, filter0_id};
                end


                /*
                 * FILTER 0 MASK
                 */

                ADDR_FILTER0_MASK:
                begin
                    PRDATA = {3'd0, filter0_mask};
                end


                /*
                 * FILTER 0 CONTROL
                 */

                ADDR_FILTER0_CTRL:
                begin
                    PRDATA = {30'd0, filter0_ide, filter0_enable};
                end


                /*
                 * FILTER 1 ID
                 */

                ADDR_FILTER1_ID:
                begin
                    PRDATA = {3'd0, filter1_id};
                end


                /*
                 * FILTER 1 MASK
                 */

                ADDR_FILTER1_MASK:
                begin
                    PRDATA = {3'd0, filter1_mask};
                end


                /*
                 * FILTER 1 CONTROL
                 */

                ADDR_FILTER1_CTRL:
                begin
                    PRDATA = {30'd0, filter1_ide, filter1_enable};
                end


                /*
                 * TEC
                 */

                ADDR_TEC:
                begin
                    PRDATA = {23'd0, tec};
                end


                /*
                 * REC
                 */

                ADDR_REC:
                begin
                    PRDATA = {24'd0, rec};
                end


                /*
                 * UNMAPPED ADDRESS
                 */

                default:
                begin
                    PRDATA = 32'd0;
                end

            endcase
        end
    end


    /*
     * ================================================================
     * APB WRITE ERROR RESPONSE
     * ================================================================
     */

    always @(*)
    begin
        PSLVERR = 1'b0;

        if(PSEL && PENABLE && PWRITE)
        begin
            case(PADDR)

                ADDR_CONTROL:
                begin
                    if(PSTRB[0])
                    begin
                        if(PWDATA[1] && PWDATA[2])
                            PSLVERR = 1'b1;
                        else if(!PWDATA[0] && tx_busy)
                            PSLVERR = 1'b1;
                    end
                end


                ADDR_BRP:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_SEGMENTS:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_SJW_CONTROL:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_FILTER0_ID:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_FILTER0_MASK:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_FILTER0_CTRL:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_FILTER1_ID:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_FILTER1_MASK:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                ADDR_FILTER1_CTRL:
                begin
                    if(can_enable)
                        PSLVERR = 1'b1;
                end


                default:
                begin
                    PSLVERR = 1'b0;
                end

            endcase
        end
    end

endmodule

