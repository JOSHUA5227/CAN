module can_rx_datapath(
    input wire        clk,
    input wire        rst_n,

    input wire        bit_en,

    input wire [3:0]  state,
    input wire [5:0]  bit_cnt,
    input wire [2:0]  byte_idx,
    input wire        arb_phase,
    input wire        active_ide,

    input wire        rx_bit_destuffed,
    input wire        rx_bit_valid,

    output reg [28:0] rx_identifier,
    output reg        rx_rtr,
    output reg        rx_ide,
    output reg [3:0]  rx_dlc,
    output reg [63:0] rx_data,
    output reg        rx_frame_valid
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

reg [10:0] arb_base_id;
reg [17:0] arb_extended_id;

wire [3:0] arb_base_id_index;
wire [4:0] arb_extended_id_index;

assign arb_base_id_index =
    bit_cnt[3:0] - 4'd3;

assign arb_extended_id_index =
    bit_cnt[4:0] - 5'd2;

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        arb_base_id     <= 11'd0;
        arb_extended_id <= 18'd0;

        rx_identifier   <= 29'd0;
        rx_rtr          <= 1'b0;
        rx_ide          <= 1'b0;
        rx_dlc          <= 4'd0;

        rx_data         <= 64'd0;

        rx_frame_valid  <= 1'b0;
    end
    else
    begin
        rx_frame_valid <= 1'b0;

        if(bit_en &&
           (state == SOF))
        begin
            arb_base_id     <= 11'd0;
            arb_extended_id <= 18'd0;

            rx_identifier   <= 29'd0;
            rx_rtr          <= 1'b0;
            rx_ide          <= 1'b0;
            rx_dlc          <= 4'd0;

        end

        else if(bit_en &&
                (state == EOF) &&
                (bit_cnt == 6'd1))
        begin
            rx_frame_valid <= 1'b1;
        end

        else if(bit_en &&
                rx_bit_valid)
        begin

            case(state)

                ARBITRATION,
                RX_ONLY:
                begin

                    if(!arb_phase)
                    begin

                        if((bit_cnt >= 6'd3) &&
                           (bit_cnt <= 6'd13))
                        begin
                            arb_base_id[arb_base_id_index]
                                <= rx_bit_destuffed;
                        end

                        else if(bit_cnt == 6'd2)
                        begin
                            if(!active_ide)
                            begin
                                rx_rtr <= rx_bit_destuffed;
                            end
                        end

                        else if(bit_cnt == 6'd1)
                        begin
                            rx_ide <= rx_bit_destuffed;

                            if(!rx_bit_destuffed)
                            begin
                                rx_identifier <=
                                    {18'd0, arb_base_id};
                            end
                        end

                    end

                    else
                    begin

                        if((bit_cnt >= 6'd2) &&
                           (bit_cnt <= 6'd19))
                        begin
                            arb_extended_id[arb_extended_id_index]
                                <= rx_bit_destuffed;
                        end

                        else if(bit_cnt == 6'd1)
                        begin
                            rx_rtr <= rx_bit_destuffed;

                            rx_identifier <=
                                {arb_base_id, arb_extended_id};
                        end

                    end

                end

                CONTROL:
                begin


                    if(bit_cnt == 6'd4)
                    begin
                        rx_dlc[3] <= rx_bit_destuffed;
                    end

                    else if(bit_cnt == 6'd3)
                    begin
                        rx_dlc[2] <= rx_bit_destuffed;
                    end

                    else if(bit_cnt == 6'd2)
                    begin
                        rx_dlc[1] <= rx_bit_destuffed;
                    end

                    else if(bit_cnt == 6'd1)
                    begin
                        rx_dlc[0] <= rx_bit_destuffed;
                    end

                end

                DATA:
                begin

                    case(rx_dlc)

                        4'd0:
                        begin
                        end

                        4'd1:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd2:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd3:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[23] <= rx_bit_destuffed;
                                        6'd7: rx_data[22] <= rx_bit_destuffed;
                                        6'd6: rx_data[21] <= rx_bit_destuffed;
                                        6'd5: rx_data[20] <= rx_bit_destuffed;
                                        6'd4: rx_data[19] <= rx_bit_destuffed;
                                        6'd3: rx_data[18] <= rx_bit_destuffed;
                                        6'd2: rx_data[17] <= rx_bit_destuffed;
                                        6'd1: rx_data[16] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd2:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd4:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[31] <= rx_bit_destuffed;
                                        6'd7: rx_data[30] <= rx_bit_destuffed;
                                        6'd6: rx_data[29] <= rx_bit_destuffed;
                                        6'd5: rx_data[28] <= rx_bit_destuffed;
                                        6'd4: rx_data[27] <= rx_bit_destuffed;
                                        6'd3: rx_data[26] <= rx_bit_destuffed;
                                        6'd2: rx_data[25] <= rx_bit_destuffed;
                                        6'd1: rx_data[24] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[23] <= rx_bit_destuffed;
                                        6'd7: rx_data[22] <= rx_bit_destuffed;
                                        6'd6: rx_data[21] <= rx_bit_destuffed;
                                        6'd5: rx_data[20] <= rx_bit_destuffed;
                                        6'd4: rx_data[19] <= rx_bit_destuffed;
                                        6'd3: rx_data[18] <= rx_bit_destuffed;
                                        6'd2: rx_data[17] <= rx_bit_destuffed;
                                        6'd1: rx_data[16] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd2:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd3:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd5:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[39] <= rx_bit_destuffed;
                                        6'd7: rx_data[38] <= rx_bit_destuffed;
                                        6'd6: rx_data[37] <= rx_bit_destuffed;
                                        6'd5: rx_data[36] <= rx_bit_destuffed;
                                        6'd4: rx_data[35] <= rx_bit_destuffed;
                                        6'd3: rx_data[34] <= rx_bit_destuffed;
                                        6'd2: rx_data[33] <= rx_bit_destuffed;
                                        6'd1: rx_data[32] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[31] <= rx_bit_destuffed;
                                        6'd7: rx_data[30] <= rx_bit_destuffed;
                                        6'd6: rx_data[29] <= rx_bit_destuffed;
                                        6'd5: rx_data[28] <= rx_bit_destuffed;
                                        6'd4: rx_data[27] <= rx_bit_destuffed;
                                        6'd3: rx_data[26] <= rx_bit_destuffed;
                                        6'd2: rx_data[25] <= rx_bit_destuffed;
                                        6'd1: rx_data[24] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd2:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[23] <= rx_bit_destuffed;
                                        6'd7: rx_data[22] <= rx_bit_destuffed;
                                        6'd6: rx_data[21] <= rx_bit_destuffed;
                                        6'd5: rx_data[20] <= rx_bit_destuffed;
                                        6'd4: rx_data[19] <= rx_bit_destuffed;
                                        6'd3: rx_data[18] <= rx_bit_destuffed;
                                        6'd2: rx_data[17] <= rx_bit_destuffed;
                                        6'd1: rx_data[16] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd3:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd4:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd6:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[47] <= rx_bit_destuffed;
                                        6'd7: rx_data[46] <= rx_bit_destuffed;
                                        6'd6: rx_data[45] <= rx_bit_destuffed;
                                        6'd5: rx_data[44] <= rx_bit_destuffed;
                                        6'd4: rx_data[43] <= rx_bit_destuffed;
                                        6'd3: rx_data[42] <= rx_bit_destuffed;
                                        6'd2: rx_data[41] <= rx_bit_destuffed;
                                        6'd1: rx_data[40] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[39] <= rx_bit_destuffed;
                                        6'd7: rx_data[38] <= rx_bit_destuffed;
                                        6'd6: rx_data[37] <= rx_bit_destuffed;
                                        6'd5: rx_data[36] <= rx_bit_destuffed;
                                        6'd4: rx_data[35] <= rx_bit_destuffed;
                                        6'd3: rx_data[34] <= rx_bit_destuffed;
                                        6'd2: rx_data[33] <= rx_bit_destuffed;
                                        6'd1: rx_data[32] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd2:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[31] <= rx_bit_destuffed;
                                        6'd7: rx_data[30] <= rx_bit_destuffed;
                                        6'd6: rx_data[29] <= rx_bit_destuffed;
                                        6'd5: rx_data[28] <= rx_bit_destuffed;
                                        6'd4: rx_data[27] <= rx_bit_destuffed;
                                        6'd3: rx_data[26] <= rx_bit_destuffed;
                                        6'd2: rx_data[25] <= rx_bit_destuffed;
                                        6'd1: rx_data[24] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd3:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[23] <= rx_bit_destuffed;
                                        6'd7: rx_data[22] <= rx_bit_destuffed;
                                        6'd6: rx_data[21] <= rx_bit_destuffed;
                                        6'd5: rx_data[20] <= rx_bit_destuffed;
                                        6'd4: rx_data[19] <= rx_bit_destuffed;
                                        6'd3: rx_data[18] <= rx_bit_destuffed;
                                        6'd2: rx_data[17] <= rx_bit_destuffed;
                                        6'd1: rx_data[16] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd4:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd5:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd7:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[55] <= rx_bit_destuffed;
                                        6'd7: rx_data[54] <= rx_bit_destuffed;
                                        6'd6: rx_data[53] <= rx_bit_destuffed;
                                        6'd5: rx_data[52] <= rx_bit_destuffed;
                                        6'd4: rx_data[51] <= rx_bit_destuffed;
                                        6'd3: rx_data[50] <= rx_bit_destuffed;
                                        6'd2: rx_data[49] <= rx_bit_destuffed;
                                        6'd1: rx_data[48] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[47] <= rx_bit_destuffed;
                                        6'd7: rx_data[46] <= rx_bit_destuffed;
                                        6'd6: rx_data[45] <= rx_bit_destuffed;
                                        6'd5: rx_data[44] <= rx_bit_destuffed;
                                        6'd4: rx_data[43] <= rx_bit_destuffed;
                                        6'd3: rx_data[42] <= rx_bit_destuffed;
                                        6'd2: rx_data[41] <= rx_bit_destuffed;
                                        6'd1: rx_data[40] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd2:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[39] <= rx_bit_destuffed;
                                        6'd7: rx_data[38] <= rx_bit_destuffed;
                                        6'd6: rx_data[37] <= rx_bit_destuffed;
                                        6'd5: rx_data[36] <= rx_bit_destuffed;
                                        6'd4: rx_data[35] <= rx_bit_destuffed;
                                        6'd3: rx_data[34] <= rx_bit_destuffed;
                                        6'd2: rx_data[33] <= rx_bit_destuffed;
                                        6'd1: rx_data[32] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd3:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[31] <= rx_bit_destuffed;
                                        6'd7: rx_data[30] <= rx_bit_destuffed;
                                        6'd6: rx_data[29] <= rx_bit_destuffed;
                                        6'd5: rx_data[28] <= rx_bit_destuffed;
                                        6'd4: rx_data[27] <= rx_bit_destuffed;
                                        6'd3: rx_data[26] <= rx_bit_destuffed;
                                        6'd2: rx_data[25] <= rx_bit_destuffed;
                                        6'd1: rx_data[24] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd4:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[23] <= rx_bit_destuffed;
                                        6'd7: rx_data[22] <= rx_bit_destuffed;
                                        6'd6: rx_data[21] <= rx_bit_destuffed;
                                        6'd5: rx_data[20] <= rx_bit_destuffed;
                                        6'd4: rx_data[19] <= rx_bit_destuffed;
                                        6'd3: rx_data[18] <= rx_bit_destuffed;
                                        6'd2: rx_data[17] <= rx_bit_destuffed;
                                        6'd1: rx_data[16] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd5:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd6:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        4'd8:
                        begin
                            case(byte_idx)

                                3'd0:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[63] <= rx_bit_destuffed;
                                        6'd7: rx_data[62] <= rx_bit_destuffed;
                                        6'd6: rx_data[61] <= rx_bit_destuffed;
                                        6'd5: rx_data[60] <= rx_bit_destuffed;
                                        6'd4: rx_data[59] <= rx_bit_destuffed;
                                        6'd3: rx_data[58] <= rx_bit_destuffed;
                                        6'd2: rx_data[57] <= rx_bit_destuffed;
                                        6'd1: rx_data[56] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd1:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[55] <= rx_bit_destuffed;
                                        6'd7: rx_data[54] <= rx_bit_destuffed;
                                        6'd6: rx_data[53] <= rx_bit_destuffed;
                                        6'd5: rx_data[52] <= rx_bit_destuffed;
                                        6'd4: rx_data[51] <= rx_bit_destuffed;
                                        6'd3: rx_data[50] <= rx_bit_destuffed;
                                        6'd2: rx_data[49] <= rx_bit_destuffed;
                                        6'd1: rx_data[48] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd2:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[47] <= rx_bit_destuffed;
                                        6'd7: rx_data[46] <= rx_bit_destuffed;
                                        6'd6: rx_data[45] <= rx_bit_destuffed;
                                        6'd5: rx_data[44] <= rx_bit_destuffed;
                                        6'd4: rx_data[43] <= rx_bit_destuffed;
                                        6'd3: rx_data[42] <= rx_bit_destuffed;
                                        6'd2: rx_data[41] <= rx_bit_destuffed;
                                        6'd1: rx_data[40] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd3:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[39] <= rx_bit_destuffed;
                                        6'd7: rx_data[38] <= rx_bit_destuffed;
                                        6'd6: rx_data[37] <= rx_bit_destuffed;
                                        6'd5: rx_data[36] <= rx_bit_destuffed;
                                        6'd4: rx_data[35] <= rx_bit_destuffed;
                                        6'd3: rx_data[34] <= rx_bit_destuffed;
                                        6'd2: rx_data[33] <= rx_bit_destuffed;
                                        6'd1: rx_data[32] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd4:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[31] <= rx_bit_destuffed;
                                        6'd7: rx_data[30] <= rx_bit_destuffed;
                                        6'd6: rx_data[29] <= rx_bit_destuffed;
                                        6'd5: rx_data[28] <= rx_bit_destuffed;
                                        6'd4: rx_data[27] <= rx_bit_destuffed;
                                        6'd3: rx_data[26] <= rx_bit_destuffed;
                                        6'd2: rx_data[25] <= rx_bit_destuffed;
                                        6'd1: rx_data[24] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd5:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[23] <= rx_bit_destuffed;
                                        6'd7: rx_data[22] <= rx_bit_destuffed;
                                        6'd6: rx_data[21] <= rx_bit_destuffed;
                                        6'd5: rx_data[20] <= rx_bit_destuffed;
                                        6'd4: rx_data[19] <= rx_bit_destuffed;
                                        6'd3: rx_data[18] <= rx_bit_destuffed;
                                        6'd2: rx_data[17] <= rx_bit_destuffed;
                                        6'd1: rx_data[16] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd6:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[15] <= rx_bit_destuffed;
                                        6'd7: rx_data[14] <= rx_bit_destuffed;
                                        6'd6: rx_data[13] <= rx_bit_destuffed;
                                        6'd5: rx_data[12] <= rx_bit_destuffed;
                                        6'd4: rx_data[11] <= rx_bit_destuffed;
                                        6'd3: rx_data[10] <= rx_bit_destuffed;
                                        6'd2: rx_data[9]  <= rx_bit_destuffed;
                                        6'd1: rx_data[8]  <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                3'd7:
                                begin
                                    case(bit_cnt)
                                        6'd8: rx_data[7] <= rx_bit_destuffed;
                                        6'd7: rx_data[6] <= rx_bit_destuffed;
                                        6'd6: rx_data[5] <= rx_bit_destuffed;
                                        6'd5: rx_data[4] <= rx_bit_destuffed;
                                        6'd4: rx_data[3] <= rx_bit_destuffed;
                                        6'd3: rx_data[2] <= rx_bit_destuffed;
                                        6'd2: rx_data[1] <= rx_bit_destuffed;
                                        6'd1: rx_data[0] <= rx_bit_destuffed;
                                        default: begin end
                                    endcase
                                end

                                default:
                                begin
                                end

                            endcase
                        end

                        default:
                        begin
                        end

                    endcase

                end

                default:
                begin
                end

            endcase

        end

    end
end

endmodule
