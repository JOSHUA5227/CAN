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

output reg reg_ide,
output reg [28:0] reg_identifier,
output reg [3:0] reg_dlc,
output reg [63:0] reg_data,
output reg reg_rtr
);

always@(posedge clk or negedge rst_n)
begin
	if(!rst_n)
	begin
		reg_ide <= 'b0;
		reg_identifier <= 'b0;
		reg_dlc <= 'b0;
		reg_data <= 'b0;
		reg_rtr <= 'b0;
	end
	else
	begin
		if(valid && !busy)
		begin
			reg_ide <= ide;
			reg_identifier <= identifier;
			reg_dlc <= dlc;
			reg_data <= data;
			reg_rtr <= rtr;
		end
		else
		begin	
			reg_ide <= reg_ide;
			reg_identifier <= reg_identifier;
			reg_dlc <= reg_dlc;
			reg_data <= reg_data;
			reg_rtr <= reg_rtr;
		end
	end
end
endmodule
