//==============================================================
// can_frame_fsm.v
//
// Unified control-path FSM for the CAN 2.0B controller.
// Sequences every frame (SOF -> ARBITRATION -> CONTROL -> DATA ->
// CRC -> ACK -> EOF -> INTERMISSION) for BOTH transmit and receive
// roles. is_transmitting is derived internally at ARBITRATION entry
// and cleared on arbitration loss -- the same field walk continues
// either way.
//
// Control path only: no CRC math, no stuffing counter, no TEC/REC
// counting lives here. This module only sequences and enables.
//==============================================================

module can_frame_fsm (
    // Clock & reset (can_clk domain)
    input  wire        clk,
    input  wire        rst_n,

    // Bit-timing interface
    input  wire        bit_en,          // one pulse per bit-time

    // Bus monitor
    input  wire        can_rx_sync,     // synchronized bus level

    // TX descriptor (latched values only, not raw data bytes)
    input  wire        tx_request,      // host has a message pending
    input  wire        rtr,             // 0 = data frame, 1 = remote frame
    input  wire        ide,             // 0 = standard, 1 = extended
    input  wire [3:0]  dlc,             // data length code

    // Bus monitor / comparator results
    input  wire        bit_error,       // tx != rx, exceptions already filtered
    input  wire        ack_received,    // dominant seen in ACK slot
    input  wire        crc_match,       // local CRC vs received CRC (RX role)
    input  wire        stuff_insert,    // this cycle is a stuffed bit

    // Fault confinement
    input  wire        node_state,      // 0 = error-active, 1 = error-passive

    // Acceptance filter
    input  wire        filter_match,    // ID matched a filter/mask pair

    // ---------------------------------------------------------
    // Outputs
    // ---------------------------------------------------------

    // Field sequencing, consumed by the datapath mux / stuffer / CRC
    output reg  [3:0]  field_sel,       // current field (see localparams below)
    output reg  [2:0]  byte_idx,        // current data byte, 0-7

    // Role
    output reg         is_transmitting, // drives TX pin mux + ACK-drive gating
    output reg         ext_fmt,         // 0 = standard, 1 = extended (latched from IDE, RX role)

    // Datapath enables
    output reg         crc_en,          // accumulate this bit into CRC_RG
    output reg         stuff_en,        // current field is subject to stuffing
    output reg         ack_drive,       // assert dominant during ACK slot (RX role)

    // Fault confinement interface
    output reg         error_detected,  // pulse: bump TEC/REC
    output reg         flag_type,       // 0 = dominant flag, 1 = recessive flag

    // Status back to APB register block
    output reg         tx_done,
    output reg         tx_busy,
    output reg         tx_lost_arb,

    // RX FIFO interface
    output reg         rx_push          // pulse: accept frame into RX FIFO
);

    // -----------------------------------------------------------
    // Field / state encoding (field_sel values)
    // -----------------------------------------------------------
    localparam IDLE           = 4'd0;
    localparam SOF            = 4'd1;
    localparam ARBITRATION    = 4'd2;
    localparam CONTROL        = 4'd3;
    localparam DATA           = 4'd4;
    localparam CRC            = 4'd5;
    localparam ACK            = 4'd6;
    localparam EOF            = 4'd7;
    localparam INTERMISSION   = 4'd8;
    localparam ERROR_FLAG     = 4'd9;
    localparam WAIT_RECESSIVE = 4'd10;
    localparam ERROR_DELIM    = 4'd11;

    // -----------------------------------------------------------
    // State register
    // -----------------------------------------------------------
    reg [3:0] state, next_state;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else if (bit_en)
            state <= next_state;
    end

    // -----------------------------------------------------------
    // Fixed field lengths, in bits
    // -----------------------------------------------------------
    // ARBITRATION is split into two phases because the format isn't
    // known until IDE arrives -- and IDE sits at the same absolute
    // bit position (13) in BOTH formats: Base ID(11) + RTR-or-SRR(1)
    // + IDE(1). So every frame always runs phase 1 first; only
    // extended frames continue into phase 2.
    //   phase 1 (always):        Base ID(11) + RTR/SRR(1) + IDE(1) = 13 bits
    //   phase 2 (extended only): Extended ID(18) + RTR(1)          = 19 bits
    localparam ARB_LEN_PHASE1 = 5'd13;
    localparam ARB_LEN_PHASE2 = 5'd19;
    localparam CTRL_LEN_STD   = 5'd5;   // r0 + DLC[3:0]        (IDE already consumed above)
    localparam CTRL_LEN_EXT   = 5'd6;   // r1 + r0 + DLC[3:0]   (IDE already consumed above)
    localparam CRC_LEN      = 5'd16;  // 15 CRC bits + 1 delimiter
    localparam ACK_LEN      = 5'd2;   // slot + delimiter
    localparam EOF_LEN      = 5'd7;
    localparam INTERM_LEN   = 5'd3;
    localparam ERR_FLAG_LEN = 5'd6;
    localparam ERR_DELIM_LEN= 5'd7;   // exit bit of WAIT_RECESSIVE = bit 1

    // -----------------------------------------------------------
    // Generic bit counter -- counts down within the current field.
    // Loaded on every state entry, decremented once per bit_en.
    // -----------------------------------------------------------
    reg [4:0] bit_cnt;
    reg       bit_in_byte_done;   // pulses when 8 bits of a data byte are done

    // bit-within-byte counter (DATA field only)
    reg [2:0] bit_in_byte;

    // -----------------------------------------------------------
    // Arbitration format detection (RX and TX both go through this --
    // for TX, can_rx_sync mirrors our own driven IDE bit as long as
    // arbitration hasn't been lost yet)
    // -----------------------------------------------------------
    reg arb_phase;   // 0 = still in phase 1 (base+IDE), 1 = extended tail
    // ext_fmt is declared in the port list above (needed outside this module too)

    wire field_done = (bit_cnt == 5'd1);   // this is the last bit of the field

    // true on the exact cycle the IDE bit is being resolved
    wire ide_resolve_cycle = (state == ARBITRATION) && field_done && (arb_phase == 1'b0);

    // -----------------------------------------------------------
    // Priority mux: error/stuff-error preempts every normal
    // transition, from any state, on any bit -- EXCEPT arbitration
    // loss, which is not an error (handled inside ARBITRATION below).
    // -----------------------------------------------------------
    wire genuine_bit_error = bit_error && !(state == ARBITRATION && can_rx_sync);
    // (arbitration loss is TX driving recessive, RX reading dominant --
    //  bit_error should already be filtered upstream per the two spec
    //  exceptions, but this line makes the intent explicit here too.)

    always @(*) begin
        next_state = state;   // default: hold

        if (genuine_bit_error || (state == ACK && field_done && !is_transmitting_ok)) begin
            next_state = ERROR_FLAG;
        end else begin
            case (state)
                IDLE:
                    if (tx_request || can_rx_sync == 1'b0)
                        next_state = SOF;

                SOF:
                    next_state = ARBITRATION;

                ARBITRATION:
                    if (ide_resolve_cycle) begin
                        if (can_rx_sync == 1'b1)
                            next_state = ARBITRATION;   // extended: fall through to phase 2
                        else
                            next_state = CONTROL;        // standard: format confirmed
                    end else if (field_done)
                        next_state = CONTROL;            // end of phase 2 (extended tail)
                    // arbitration loss handled by is_transmitting clear below,
                    // NOT a state change -- keep walking as receiver

                CONTROL:
                    if (field_done)
                        next_state = (rtr || dlc == 4'd0) ? CRC : DATA;

                DATA:
                    if (field_done && (byte_idx == dlc - 1'b1))
                        next_state = CRC;

                CRC:
                    if (field_done)
                        next_state = ACK;

                ACK:
                    if (field_done)
                        next_state = EOF;

                EOF:
                    if (field_done)
                        next_state = INTERMISSION;

                INTERMISSION:
                    if (field_done)
                        next_state = IDLE;

                ERROR_FLAG:
                    if (field_done)
                        next_state = WAIT_RECESSIVE;

                WAIT_RECESSIVE:
                    // level-triggered exit, NOT a counter --
                    // stay here until the bus itself reads recessive
                    if (can_rx_sync == 1'b1)
                        next_state = ERROR_DELIM;

                ERROR_DELIM:
                    if (field_done)
                        next_state = INTERMISSION;

                default:
                    next_state = IDLE;
            endcase
        end
    end

    // helper: was ACK actually received when transmitting (for the
    // ACK-error check folded into the priority mux above)
    wire is_transmitting_ok = !is_transmitting || ack_received;

    // -----------------------------------------------------------
    // bit_cnt / bit_in_byte load-and-count logic
    // -----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bit_cnt      <= 5'd1;
            bit_in_byte  <= 3'd0;
        end else if (bit_en) begin
            if (ide_resolve_cycle && can_rx_sync == 1'b1) begin
                // extended format detected: reload for phase 2, staying
                // in ARBITRATION -- next_state == state here, so this
                // has to be handled before the "entering a new field"
                // branch below, which only fires on a real state change
                bit_cnt <= ARB_LEN_PHASE2;
            end else if (next_state != state) begin
                // entering a new field: load its fixed length
                case (next_state)
                    ARBITRATION:    bit_cnt <= ARB_LEN_PHASE1;   // fresh frame from SOF
                    CONTROL:        bit_cnt <= ext_fmt ? CTRL_LEN_EXT : CTRL_LEN_STD;
                    DATA:           bit_cnt <= 5'd8;          // one byte at a time
                    CRC:            bit_cnt <= CRC_LEN;
                    ACK:            bit_cnt <= ACK_LEN;
                    EOF:            bit_cnt <= EOF_LEN;
                    INTERMISSION:   bit_cnt <= INTERM_LEN;
                    ERROR_FLAG:     bit_cnt <= ERR_FLAG_LEN;
                    ERROR_DELIM:    bit_cnt <= ERR_DELIM_LEN;
                    default:        bit_cnt <= 5'd1;          // SOF, IDLE, WAIT_RECESSIVE
                endcase
                bit_in_byte <= 3'd0;
            end else if (!stuff_insert) begin
                // stuffed bits do NOT advance the field counter --
                // only real field bits decrement bit_cnt
                bit_cnt     <= field_done ? bit_cnt : (bit_cnt - 5'd1);
                if (state == DATA)
                    bit_in_byte <= (bit_in_byte == 3'd7) ? 3'd0 : bit_in_byte + 3'd1;
            end
        end
    end

    // -----------------------------------------------------------
    // arb_phase / ext_fmt: latch the format decision made on the
    // IDE-resolve cycle, and reset for the next frame
    // -----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            arb_phase <= 1'b0;
            ext_fmt   <= 1'b0;
        end else if (bit_en) begin
            if (state == IDLE && next_state == SOF) begin
                arb_phase <= 1'b0;   // fresh frame
            end else if (ide_resolve_cycle) begin
                arb_phase <= can_rx_sync;   // 1 = extended, continue to phase 2
                ext_fmt   <= can_rx_sync;   // latched for CONTROL length + downstream use
            end
        end
    end

    // -----------------------------------------------------------
    // byte_idx: increments once per completed data byte
    // -----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            byte_idx <= 3'd0;
        else if (bit_en) begin
            if (state != DATA)
                byte_idx <= 3'd0;
            else if (field_done && !stuff_insert)
                byte_idx <= byte_idx + 3'd1;   // reload for next byte, or DATA exits
        end
    end

    // -----------------------------------------------------------
    // is_transmitting: set at ARBITRATION entry if a request was
    // pending, cleared the instant arbitration is lost
    // -----------------------------------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            is_transmitting <= 1'b0;
        else if (bit_en) begin
            if (state == IDLE && next_state == SOF)
                is_transmitting <= tx_request;
            else if (state == ARBITRATION && bit_error)
                is_transmitting <= 1'b0;   // lost arbitration
            else if (next_state == IDLE)
                is_transmitting <= 1'b0;   // reset for next frame
        end
    end

    // -----------------------------------------------------------
    // Output logic -- combinational, driven purely off `state`
    // (plus a couple of role/result inputs where noted)
    // -----------------------------------------------------------
    always @(*) begin
        // safe defaults every cycle
        field_sel      = state;
        crc_en         = 1'b0;
        stuff_en       = 1'b0;
        ack_drive      = 1'b0;
        error_detected = 1'b0;
        flag_type      = node_state;
        tx_done        = 1'b0;
        tx_busy        = (state != IDLE);
        tx_lost_arb    = 1'b0;
        rx_push        = 1'b0;

        case (state)
            SOF, ARBITRATION, CONTROL, DATA, CRC: begin
                crc_en   = 1'b1;   // SOF through end of DATA field only
                stuff_en = 1'b1;   // SOF through end of CRC sequence
            end
            ACK: begin
                ack_drive = !is_transmitting && crc_match && field_done;
            end
            default: ; // CRC delimiter/ACK/EOF/error frame: no crc_en, no stuff_en
        endcase

        if (state == ARBITRATION && bit_error)
            tx_lost_arb = 1'b1;

        if (genuine_bit_error || (state == ACK && field_done && !is_transmitting_ok))
            error_detected = 1'b1;

        if (state == EOF && field_done) begin
            if (is_transmitting)
                tx_done = 1'b1;
            else if (filter_match)
                rx_push = 1'b1;
        end
    end

endmodule
