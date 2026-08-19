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

localparam IDLE = 4'd0;
localparam SOF = 4'd1;
localparam ARBITRATION = 4'd2;
localparam CONTROL = 4'd3;
localparam DATA = 4'd4;
localparam CRC = 4'd5;
localparam CRC_DELIM = 4'd6;
localparam ACK = 4'd7;
localparam ACK_DELIM = 4'd8;
localparam EOF = 4'd9;
localparam INTERMISSION = 4'd10;
localparam ERROR_FLAG = 4'd11;
localparam WAIT_RECESSIVE = 4'd12;
localparam ERROR_DELIM = 4'd13;
localparam RX_ONLY = 4'd14;

localparam ERROR_ACTIVE = 2'd0;
localparam ERROR_PASSIVE = 2'd1;
localparam BUS_OFF = 2'd2;

always @(posedge clk or negedge rst_n)
begin
    if (!rst_n)
    begin
        tx_data <= 1'b1;
    end
    else if (bit_en)
    begin
        if (state == ERROR_FLAG)
        begin
            if (error_mode == ERROR_ACTIVE)
                tx_data <= 1'b0;
            else
                tx_data <= 1'b1;
        end
        else if (!is_transmitting)
                tx_data <= 1'b1;
        else
        begin
            case (state)

                SOF:
                    tx_data <= 1'b0;

                ARBITRATION:
                begin
                    if (ide == 1'b0)
                    begin
                        case (bit_cnt)
                            6'd13: tx_data <= identifier[10];
                            6'd12: tx_data <= identifier[9];
                            6'd11: tx_data <= identifier[8];
                            6'd10: tx_data <= identifier[7];
                            6'd9 : tx_data <= identifier[6];
                            6'd8 : tx_data <= identifier[5];
                            6'd7 : tx_data <= identifier[4];
                            6'd6 : tx_data <= identifier[3];
                            6'd5 : tx_data <= identifier[2];
                            6'd4 : tx_data <= identifier[1];
                            6'd3 : tx_data <= identifier[0];
                            6'd2 : tx_data <= rtr;
                            6'd1 : tx_data <= ide;
                            default: tx_data <= 1'b1;
                        endcase
                    end
                    else
                    begin
                        if (arb_phase == 1'b0)
                        begin
                            case (bit_cnt)
                                6'd13: tx_data <= identifier[28];
                                6'd12: tx_data <= identifier[27];
                                6'd11: tx_data <= identifier[26];
                                6'd10: tx_data <= identifier[25];
                                6'd9 : tx_data <= identifier[24];
                                6'd8 : tx_data <= identifier[23];
                                6'd7 : tx_data <= identifier[22];
                                6'd6 : tx_data <= identifier[21];
                                6'd5 : tx_data <= identifier[20];
                                6'd4 : tx_data <= identifier[19];
                                6'd3 : tx_data <= identifier[18];
                                6'd2 : tx_data <= 1'b1;
                                6'd1 : tx_data <= ide;
                                default: tx_data <= 1'b1;
                            endcase
                        end
                        else
                        begin
                            case (bit_cnt)
                                6'd19: tx_data <= identifier[17];
                                6'd18: tx_data <= identifier[16];
                                6'd17: tx_data <= identifier[15];
                                6'd16: tx_data <= identifier[14];
                                6'd15: tx_data <= identifier[13];
                                6'd14: tx_data <= identifier[12];
                                6'd13: tx_data <= identifier[11];
                                6'd12: tx_data <= identifier[10];
                                6'd11: tx_data <= identifier[9];
                                6'd10: tx_data <= identifier[8];
                                6'd9 : tx_data <= identifier[7];
                                6'd8 : tx_data <= identifier[6];
                                6'd7 : tx_data <= identifier[5];
                                6'd6 : tx_data <= identifier[4];
                                6'd5 : tx_data <= identifier[3];
                                6'd4 : tx_data <= identifier[2];
                                6'd3 : tx_data <= identifier[1];
                                6'd2 : tx_data <= identifier[0];
                                6'd1 : tx_data <= rtr;
                                default: tx_data <= 1'b1;
                            endcase
                        end
                    end
                end

                CONTROL:
                begin
                    if (ide == 1'b0)
                    begin
                        case (bit_cnt)
                            6'd5: tx_data <= 1'b0;
                            6'd4: tx_data <= dlc[3];
                            6'd3: tx_data <= dlc[2];
                            6'd2: tx_data <= dlc[1];
                            6'd1: tx_data <= dlc[0];
                            default: tx_data <= 1'b1;
                        endcase
                    end
                    else
                    begin
                        case (bit_cnt)
                            6'd6: tx_data <= 1'b0;
                            6'd5: tx_data <= 1'b0;
                            6'd4: tx_data <= dlc[3];
                            6'd3: tx_data <= dlc[2];
                            6'd2: tx_data <= dlc[1];
                            6'd1: tx_data <= dlc[0];
                            default: tx_data <= 1'b1;
                        endcase
                    end
                end

                DATA:
                begin
                    tx_data <= data[bit_cnt - 6'd1];
                end

                default:
                begin
                    tx_data <= 1'b1;
                end

            endcase
        end
    end
end

endmodule
