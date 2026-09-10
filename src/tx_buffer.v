module tx_buffer(

input wire clk,
input wire rst_n,

input wire ide,
input wire [28:0] identifier,
input wire [3:0] dlc,
input wire [63:0] data,
input wire rtr,
input wire valid,
input wire busy,

input wire [2:0] byte_idx,

output reg reg_ide,
output reg [28:0] reg_identifier,
output reg [3:0] reg_dlc,
output reg [63:0] reg_data,
output reg reg_rtr,

output reg [7:0] tx_byte
);

always @(posedge clk or negedge rst_n)
begin
    if(!rst_n)
    begin
        reg_ide        <= 1'b0;
        reg_identifier <= 29'd0;
        reg_dlc        <= 4'd0;
        reg_data       <= 64'd0;
        reg_rtr        <= 1'b0;
    end
    else
    begin
        if(valid && !busy)
        begin
            reg_ide        <= ide;
            reg_identifier <= identifier;
            reg_dlc        <= dlc;
            reg_data       <= data;
            reg_rtr        <= rtr;
        end
    end
end


// ------------------------------------------------------------
// TX byte selection
//
// Payload is RIGHT-ALIGNED according to DLC.
//
// DLC = 1:
//   byte_idx 0 -> data[7:0]
//
// DLC = 2:
//   byte_idx 0 -> data[15:8]
//   byte_idx 1 -> data[7:0]
//
// DLC = 3:
//   byte_idx 0 -> data[23:16]
//   byte_idx 1 -> data[15:8]
//   byte_idx 2 -> data[7:0]
//
// ...
//
// DLC = 8:
//   byte_idx 0 -> data[63:56]
//   ...
//   byte_idx 7 -> data[7:0]
//
// Therefore the first transmitted byte is always the MSB
// of the ACTIVE payload region.
// ------------------------------------------------------------

always @(*)
begin
    tx_byte = 8'd0;

    case(reg_dlc)

        4'd1:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd2:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[15:8];
                3'd1: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd3:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[23:16];
                3'd1: tx_byte = reg_data[15:8];
                3'd2: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd4:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[31:24];
                3'd1: tx_byte = reg_data[23:16];
                3'd2: tx_byte = reg_data[15:8];
                3'd3: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd5:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[39:32];
                3'd1: tx_byte = reg_data[31:24];
                3'd2: tx_byte = reg_data[23:16];
                3'd3: tx_byte = reg_data[15:8];
                3'd4: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd6:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[47:40];
                3'd1: tx_byte = reg_data[39:32];
                3'd2: tx_byte = reg_data[31:24];
                3'd3: tx_byte = reg_data[23:16];
                3'd4: tx_byte = reg_data[15:8];
                3'd5: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd7:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[55:48];
                3'd1: tx_byte = reg_data[47:40];
                3'd2: tx_byte = reg_data[39:32];
                3'd3: tx_byte = reg_data[31:24];
                3'd4: tx_byte = reg_data[23:16];
                3'd5: tx_byte = reg_data[15:8];
                3'd6: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        4'd8:
        begin
            case(byte_idx)
                3'd0: tx_byte = reg_data[63:56];
                3'd1: tx_byte = reg_data[55:48];
                3'd2: tx_byte = reg_data[47:40];
                3'd3: tx_byte = reg_data[39:32];
                3'd4: tx_byte = reg_data[31:24];
                3'd5: tx_byte = reg_data[23:16];
                3'd6: tx_byte = reg_data[15:8];
                3'd7: tx_byte = reg_data[7:0];
                default: tx_byte = 8'd0;
            endcase
        end

        default:
            tx_byte = 8'd0;

    endcase
end

endmodule

