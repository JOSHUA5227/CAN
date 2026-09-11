module can_error_status_cdc (

    /* ========================================================
     * PCLK DOMAIN
     * ======================================================== */

    input wire        pclk,
    input wire        p_rst_n,

    /* ========================================================
     * CAN CLK DOMAIN
     * ======================================================== */

    input wire        can_clk,
    input wire        can_rst_n,

    /* ========================================================
     * ERROR EVENT FROM CAN DOMAIN
     * ======================================================== */

    input wire        error_event_toggle,
    input wire        can_last_error_valid,
    input wire [3:0]  can_last_error_type,

    /* ========================================================
     * CAN STATUS
     * ======================================================== */

    input wire        can_line_busy,
    input wire        can_is_transmitting,

    input wire        can_tx_done,
    input wire        can_ack_received,

    input wire        can_arbitration_lost,

    input wire [1:0]  can_error_state,
    input wire [8:0]  can_tec,
    input wire [7:0]  can_rec,

    input wire        can_recovery_active,

    /* ========================================================
     * PCLK DOMAIN STATUS OUTPUTS
     * ======================================================== */

    output reg        line_busy,
    output reg        is_transmitting,

    output reg        tx_done,
    output reg        ack_received,

    output reg        arbitration_lost,

    output reg [1:0]  error_state,
    output reg [8:0]  tec,
    output reg [7:0]  rec,

    output reg        recovery_active,

    /* ========================================================
     * PCLK DOMAIN ERROR STATUS
     * ======================================================== */

    output reg        last_error_valid,
    output reg [3:0]  last_error_type,

    output reg        error_event,

    output reg        bit_error,
    output reg        stuff_error,
    output reg        crc_error,
    output reg        form_error,
    output reg        ack_error
);


    /* ========================================================
     * EVENT TYPE DEFINITIONS
     * ======================================================== */

    localparam EVENT_NONE     = 4'd0;
    localparam EVENT_BIT      = 4'd1;
    localparam EVENT_STUFF    = 4'd2;
    localparam EVENT_CRC      = 4'd3;
    localparam EVENT_FORM     = 4'd4;
    localparam EVENT_ACK      = 4'd5;
    localparam EVENT_ARB_LOST = 4'd6;


    /* ========================================================
     * STATE SYNCHRONIZERS
     *
     * Single-bit level signals use conventional two-flop
     * synchronizers.
     * ======================================================== */

    reg line_busy_sync1;
    reg line_busy_sync2;

    reg transmitting_sync1;
    reg transmitting_sync2;

    reg recovery_sync1;
    reg recovery_sync2;


    /* ========================================================
     * ERROR EVENT TOGGLE SYNCHRONIZER
     * ======================================================== */

    reg error_toggle_sync1;
    reg error_toggle_sync2;
    reg error_toggle_seen;


    /* ========================================================
     * TX DONE EVENT TOGGLE
     * ======================================================== */

    reg tx_done_toggle_can;
    reg tx_done_toggle_sync1;
    reg tx_done_toggle_sync2;
    reg tx_done_toggle_seen;


    /* ========================================================
     * ACK RECEIVED EVENT TOGGLE
     * ======================================================== */

    reg ack_toggle_can;
    reg ack_toggle_sync1;
    reg ack_toggle_sync2;
    reg ack_toggle_seen;


    /* ========================================================
     * ARBITRATION LOSS EVENT TOGGLE
     * ======================================================== */

    reg arb_toggle_can;
    reg arb_toggle_sync1;
    reg arb_toggle_sync2;
    reg arb_toggle_seen;


    /* ========================================================
     * STATUS SNAPSHOT
     *
     * Multi-bit CAN status values are captured together in the
     * CAN clock domain and transferred using a toggle.
     * ======================================================== */

    reg [1:0] can_error_state_snapshot;
    reg [8:0] can_tec_snapshot;
    reg [7:0] can_rec_snapshot;

    reg status_toggle_can;

    reg status_toggle_sync1;
    reg status_toggle_sync2;
    reg status_toggle_seen;


    /* ========================================================
     * ERROR EVENT INFORMATION
     *
     * Error information is held stable in the CAN domain while
     * the event toggle crosses into the PCLK domain.
     * ======================================================== */

    reg        error_toggle_seen_can;
    reg        can_last_error_valid_hold;
    reg [3:0]  can_last_error_type_hold;


    /* ========================================================
     * CAN-DOMAIN EVENT LATCHING
     * ======================================================== */

    always @(posedge can_clk or negedge can_rst_n)
    begin
        if(!can_rst_n)
        begin
            tx_done_toggle_can        <= 1'b0;
            ack_toggle_can            <= 1'b0;
            arb_toggle_can            <= 1'b0;

            status_toggle_can         <= 1'b0;

            can_error_state_snapshot  <= 2'd0;
            can_tec_snapshot          <= 9'd0;
            can_rec_snapshot          <= 8'd0;

            error_toggle_seen_can     <= 1'b0;
            can_last_error_valid_hold <= 1'b0;
            can_last_error_type_hold  <= EVENT_NONE;
        end
        else
        begin

            /* -------------------------------------------------
             * TX DONE EVENT
             * ------------------------------------------------- */

            if(can_tx_done)
                tx_done_toggle_can <= ~tx_done_toggle_can;


            /* -------------------------------------------------
             * ACK RECEIVED EVENT
             * ------------------------------------------------- */

            if(can_ack_received)
                ack_toggle_can <= ~ack_toggle_can;


            /* -------------------------------------------------
             * ARBITRATION LOSS EVENT
             * ------------------------------------------------- */

            if(can_arbitration_lost)
                arb_toggle_can <= ~arb_toggle_can;


            /* -------------------------------------------------
             * ERROR EVENT INFORMATION
             *
             * IMPORTANT:
             * Compare the incoming error event toggle against
             * a dedicated CAN-domain toggle tracker.
             * Do not compare it against error-valid.
             * ------------------------------------------------- */

            if(error_event_toggle != error_toggle_seen_can)
            begin
                error_toggle_seen_can     <= error_event_toggle;

                can_last_error_valid_hold <=
                    can_last_error_valid;

                can_last_error_type_hold <=
                    can_last_error_type;
            end


            /* -------------------------------------------------
             * STATUS SNAPSHOT
             *
             * Capture TEC, REC and error state together when
             * an important CAN event occurs.
             * ------------------------------------------------- */

            if(can_tx_done ||
               can_ack_received ||
               can_arbitration_lost ||
               (error_event_toggle != error_toggle_seen_can))
            begin
                can_error_state_snapshot <= can_error_state;
                can_tec_snapshot         <= can_tec;
                can_rec_snapshot         <= can_rec;

                status_toggle_can <=
                    ~status_toggle_can;
            end

        end
    end


    /* ========================================================
     * PCLK DOMAIN CDC
     * ======================================================== */

    always @(posedge pclk or negedge p_rst_n)
    begin
        if(!p_rst_n)
        begin
            /* -------------------------------------------------
             * LEVEL SYNCHRONIZERS
             * ------------------------------------------------- */

            line_busy_sync1     <= 1'b0;
            line_busy_sync2     <= 1'b0;

            transmitting_sync1  <= 1'b0;
            transmitting_sync2  <= 1'b0;

            recovery_sync1      <= 1'b0;
            recovery_sync2      <= 1'b0;


            /* -------------------------------------------------
             * ERROR EVENT TOGGLE
             * ------------------------------------------------- */

            error_toggle_sync1  <= 1'b0;
            error_toggle_sync2  <= 1'b0;
            error_toggle_seen   <= 1'b0;


            /* -------------------------------------------------
             * TX DONE TOGGLE
             * ------------------------------------------------- */

            tx_done_toggle_sync1 <= 1'b0;
            tx_done_toggle_sync2 <= 1'b0;
            tx_done_toggle_seen   <= 1'b0;


            /* -------------------------------------------------
             * ACK TOGGLE
             * ------------------------------------------------- */

            ack_toggle_sync1 <= 1'b0;
            ack_toggle_sync2 <= 1'b0;
            ack_toggle_seen  <= 1'b0;


            /* -------------------------------------------------
             * ARBITRATION LOSS TOGGLE
             * ------------------------------------------------- */

            arb_toggle_sync1 <= 1'b0;
            arb_toggle_sync2 <= 1'b0;
            arb_toggle_seen  <= 1'b0;


            /* -------------------------------------------------
             * STATUS SNAPSHOT TOGGLE
             * ------------------------------------------------- */

            status_toggle_sync1 <= 1'b0;
            status_toggle_sync2 <= 1'b0;
            status_toggle_seen  <= 1'b0;


            /* -------------------------------------------------
             * PCLK STATUS OUTPUTS
             * ------------------------------------------------- */

            line_busy       <= 1'b0;
            is_transmitting <= 1'b0;
            recovery_active <= 1'b0;

            tx_done          <= 1'b0;
            ack_received     <= 1'b0;
            arbitration_lost <= 1'b0;

            error_state <= 2'd0;
            tec         <= 9'd0;
            rec         <= 8'd0;

            last_error_valid <= 1'b0;
            last_error_type  <= EVENT_NONE;

            error_event <= 1'b0;

            bit_error   <= 1'b0;
            stuff_error <= 1'b0;
            crc_error   <= 1'b0;
            form_error  <= 1'b0;
            ack_error   <= 1'b0;
        end
        else
        begin

            /* -------------------------------------------------
             * TWO-FLOP STATE SYNCHRONIZERS
             * ------------------------------------------------- */

            line_busy_sync1 <= can_line_busy;
            line_busy_sync2 <= line_busy_sync1;

            transmitting_sync1 <= can_is_transmitting;
            transmitting_sync2 <= transmitting_sync1;

            recovery_sync1 <= can_recovery_active;
            recovery_sync2 <= recovery_sync1;

            line_busy       <= line_busy_sync2;
            is_transmitting <= transmitting_sync2;
            recovery_active <= recovery_sync2;


            /* -------------------------------------------------
             * EVENT TOGGLE SYNCHRONIZERS
             * ------------------------------------------------- */

            error_toggle_sync1 <= error_event_toggle;
            error_toggle_sync2 <= error_toggle_sync1;

            tx_done_toggle_sync1 <= tx_done_toggle_can;
            tx_done_toggle_sync2 <= tx_done_toggle_sync1;

            ack_toggle_sync1 <= ack_toggle_can;
            ack_toggle_sync2 <= ack_toggle_sync1;

            arb_toggle_sync1 <= arb_toggle_can;
            arb_toggle_sync2 <= arb_toggle_sync1;


            /* -------------------------------------------------
             * STATUS SNAPSHOT TOGGLE
             * ------------------------------------------------- */

            status_toggle_sync1 <= status_toggle_can;
            status_toggle_sync2 <= status_toggle_sync1;


            /* -------------------------------------------------
             * DEFAULT EVENT PULSES
             * ------------------------------------------------- */

            tx_done      <= 1'b0;
            ack_received <= 1'b0;
            error_event  <= 1'b0;


            /* -------------------------------------------------
             * TX DONE EVENT
             * ------------------------------------------------- */

            if(tx_done_toggle_sync2 != tx_done_toggle_seen)
            begin
                tx_done_toggle_seen <= tx_done_toggle_sync2;
                tx_done <= 1'b1;
            end


            /* -------------------------------------------------
             * ACK RECEIVED EVENT
             * ------------------------------------------------- */

            if(ack_toggle_sync2 != ack_toggle_seen)
            begin
                ack_toggle_seen <= ack_toggle_sync2;
                ack_received <= 1'b1;
            end


            /* -------------------------------------------------
             * ARBITRATION LOSS EVENT
             * ------------------------------------------------- */

            if(arb_toggle_sync2 != arb_toggle_seen)
            begin
                arb_toggle_seen <= arb_toggle_sync2;
                arbitration_lost <= 1'b1;
            end


            /* -------------------------------------------------
             * ERROR EVENT
             * ------------------------------------------------- */

            if(error_toggle_sync2 != error_toggle_seen)
            begin
                error_toggle_seen <= error_toggle_sync2;

                error_event <= 1'b1;

                last_error_valid <=
                    can_last_error_valid_hold;

                last_error_type <=
                    can_last_error_type_hold;


                if(can_last_error_type_hold == EVENT_BIT)
                    bit_error <= 1'b1;

                if(can_last_error_type_hold == EVENT_STUFF)
                    stuff_error <= 1'b1;

                if(can_last_error_type_hold == EVENT_CRC)
                    crc_error <= 1'b1;

                if(can_last_error_type_hold == EVENT_FORM)
                    form_error <= 1'b1;

                if(can_last_error_type_hold == EVENT_ACK)
                    ack_error <= 1'b1;

                if(can_last_error_type_hold == EVENT_ARB_LOST)
                    arbitration_lost <= 1'b1;
            end


            /* -------------------------------------------------
             * STATUS SNAPSHOT
             * ------------------------------------------------- */

            if(status_toggle_sync2 != status_toggle_seen)
            begin
                status_toggle_seen <= status_toggle_sync2;

                error_state <= can_error_state_snapshot;
                tec         <= can_tec_snapshot;
                rec         <= can_rec_snapshot;
            end

        end
    end

endmodule
