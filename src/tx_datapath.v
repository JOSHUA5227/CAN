module tx_datapath(
input wire clk,
input wire rst_n,
input wire bit_en,

input wire is_transmitting,
input wire [3:0] state,
input wire arb_phase,

input wire rtr,
input wire ide,
input wire [28:0] identifier,
input wire [3:0] dlc,
input wire [7:0] data,

input wire [5:0] bit_cnt,

input wire [1:0] error_mode,

output reg tx_data
);

localparam IDLE            = 4'd0;
localparam SOF             = 4'd1;
localparam ARBITRATION     = 4'd2;
localparam CONTROL         = 4'd3;
localparam DATA            = 4'd4;
localparam CRC             = 4'd5;
localparam CRC_DELIM       = 4'd6;
localparam ACK             = 4'd7;
localparam ACK_DELIM       = 4'd8;
localparam EOF             = 4'd9;
localparam INTERMISSION    = 4'd10;
localparam ERROR_FLAG      = 4'd11;
localparam WAIT_RECESSIVE  = 4'd12;
localparam ERROR_DELIM     = 4'd13;
localparam RX_ONLY         = 4'd14;

localparam ERROR_ACTIVE  = 2'd0;
localparam ERROR_PASSIVE = 2'd1;
localparam BUS_OFF       = 2'd2;

// ------------------------------------------------------------------
// TX data generation
//
// IMPORTANT:
// tx_data is intentionally COMBINATIONAL.
//
// The frame FSM updates state/bit_cnt at a bit boundary. The TX
// datapath must decode the CURRENT state/bit_cnt before that boundary
// so that can_stuffer and the TX CRC logic sample the correct logical
// bit on the same bit_en edge.
//
// The previous implementation registered tx_data on bit_en. That
// caused a one-bit pipeline delay:
//
//     frame FSM -> tx_datapath register -> stuffer
//                    ^ old bit sampled
//
// which made the first transmitted bit appear as recessive instead
// of SOF.
//
// Keeping this module combinational preserves the existing interface
// while removing that one-bit latency.
// ------------------------------------------------------------------

always @*
begin
    // CAN bus is recessive by default.
    tx_data = 1'b1;

    // Only the transmitting node generates normal frame bits.
    // ACK is generated separately by the frame controller.
    if (state == ERROR_FLAG)
    begin
        // Active error flag = six dominant bits.
        // Passive error flag = six recessive bits.
        if (error_mode == ERROR_ACTIVE)
            tx_data = 1'b0;
        else
            tx_data = 1'b1;
    end
    else if (is_transmitting)
    begin
        case (state)

            // ------------------------------------------------------
            // Start Of Frame
            // ------------------------------------------------------
            SOF:
                tx_data = 1'b0;

            // ------------------------------------------------------
            // Arbitration
            //
            // Architecture used here:
            //
            // Standard:
            //   phase 0:
            //     bit 13..3 = ID[10:0]
            //     bit 2     = RTR
            //     bit 1     = IDE = 0
            //
            // Extended:
            //   phase 0:
            //     bit 13..3 = base ID [28:18]
            //     bit 2     = SRR = 1
            //     bit 1     = IDE = 1
            //
            //   phase 1:
            //     bit 19..2 = extended ID [17:0]
            //     bit 1     = RTR
            //
            // The FSM controls whether phase 0 or phase 1 is active.
            // ------------------------------------------------------
            ARBITRATION:
            begin
                if (!ide)
                begin
                    // Standard CAN
                    case (bit_cnt)
                        6'd13: tx_data = identifier[10];
                        6'd12: tx_data = identifier[9];
                        6'd11: tx_data = identifier[8];
                        6'd10: tx_data = identifier[7];
                        6'd9 : tx_data = identifier[6];
                        6'd8 : tx_data = identifier[5];
                        6'd7 : tx_data = identifier[4];
                        6'd6 : tx_data = identifier[3];
                        6'd5 : tx_data = identifier[2];
                        6'd4 : tx_data = identifier[1];
                        6'd3 : tx_data = identifier[0];

                        6'd2 : tx_data = rtr;
                        6'd1 : tx_data = 1'b0;       // IDE

                        default: tx_data = 1'b1;
                    endcase
                end
                else
                begin
                    // Extended CAN
                    if (!arb_phase)
                    begin
                        // Base identifier + SRR + IDE
                        case (bit_cnt)
                            6'd13: tx_data = identifier[28];
                            6'd12: tx_data = identifier[27];
                            6'd11: tx_data = identifier[26];
                            6'd10: tx_data = identifier[25];
                            6'd9 : tx_data = identifier[24];
                            6'd8 : tx_data = identifier[23];
                            6'd7 : tx_data = identifier[22];
                            6'd6 : tx_data = identifier[21];
                            6'd5 : tx_data = identifier[20];
                            6'd4 : tx_data = identifier[19];
                            6'd3 : tx_data = identifier[18];

                            6'd2 : tx_data = 1'b1;     // SRR
                            6'd1 : tx_data = 1'b1;     // IDE

                            default: tx_data = 1'b1;
                        endcase
                    end
                    else
                    begin
                        // Extended identifier + RTR
                        case (bit_cnt)
                            6'd19: tx_data = identifier[17];
                            6'd18: tx_data = identifier[16];
                            6'd17: tx_data = identifier[15];
                            6'd16: tx_data = identifier[14];
                            6'd15: tx_data = identifier[13];
                            6'd14: tx_data = identifier[12];
                            6'd13: tx_data = identifier[11];
                            6'd12: tx_data = identifier[10];
                            6'd11: tx_data = identifier[9];
                            6'd10: tx_data = identifier[8];
                            6'd9 : tx_data = identifier[7];
                            6'd8 : tx_data = identifier[6];
                            6'd7 : tx_data = identifier[5];
                            6'd6 : tx_data = identifier[4];
                            6'd5 : tx_data = identifier[3];
                            6'd4 : tx_data = identifier[2];
                            6'd3 : tx_data = identifier[1];
                            6'd2 : tx_data = identifier[0];

                            6'd1 : tx_data = rtr;

                            default: tx_data = 1'b1;
                        endcase
                    end
                end
            end

            // ------------------------------------------------------
            // Control
            //
            // Standard:
            //   bit 5 = r0
            //   bit 4..1 = DLC
            //
            // Extended:
            //   bit 6 = r1
            //   bit 5 = r0
            //   bit 4..1 = DLC
            // ------------------------------------------------------
            CONTROL:
            begin
                if (!ide)
                begin
                    case (bit_cnt)
                        6'd5: tx_data = 1'b0;       // r0
                        6'd4: tx_data = dlc[3];
                        6'd3: tx_data = dlc[2];
                        6'd2: tx_data = dlc[1];
                        6'd1: tx_data = dlc[0];

                        default: tx_data = 1'b1;
                    endcase
                end
                else
                begin
                    case (bit_cnt)
                        6'd6: tx_data = 1'b0;       // r1
                        6'd5: tx_data = 1'b0;       // r0
                        6'd4: tx_data = dlc[3];
                        6'd3: tx_data = dlc[2];
                        6'd2: tx_data = dlc[1];
                        6'd1: tx_data = dlc[0];

                        default: tx_data = 1'b1;
                    endcase
                end
            end

            // ------------------------------------------------------
            // Data
            //
            // tx_buffer supplies one byte at a time through 'data'.
            // Each byte is transmitted MSB first.
            // ------------------------------------------------------
            DATA:
            begin
                case (bit_cnt)
                    6'd8: tx_data = data[7];
                    6'd7: tx_data = data[6];
                    6'd6: tx_data = data[5];
                    6'd5: tx_data = data[4];
                    6'd4: tx_data = data[3];
                    6'd3: tx_data = data[2];
                    6'd2: tx_data = data[1];
                    6'd1: tx_data = data[0];

                    default: tx_data = 1'b1;
                endcase
            end

            // ------------------------------------------------------
            // CRC
            //
            // CRC bits are selected in can_controller from crc_out,
            // so this module does not generate CRC bits directly.
            // ------------------------------------------------------
            CRC:
                tx_data = 1'b1;

            CRC_DELIM:
                tx_data = 1'b1;

            ACK:
                tx_data = 1'b1;

            ACK_DELIM:
                tx_data = 1'b1;

            EOF:
                tx_data = 1'b1;

            INTERMISSION:
                tx_data = 1'b1;

            WAIT_RECESSIVE:
                tx_data = 1'b1;

            ERROR_DELIM:
                tx_data = 1'b1;

            default:
                tx_data = 1'b1;

        endcase
    end
end

endmodule

