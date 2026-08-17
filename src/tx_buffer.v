module tx_buffer(clk,rst,id,rtr,ide,dlc,data,valid,busy,);

input wire clk,rst;
input wire [28:0] ide;
input wire [3:0] dlc;
input wire [63:0] data;
input wire rtr;
input wire valid,busy;

output reg [28:0] reg_ide;
output reg [3:0] reg_dlc;
output reg [63:0] reg_data;
output reg reg_rtr;

always@(posedge clk or negedge rst)
begin
	if(!rst)
	begin
		reg_ide <= 'b0;
		reg_dlc <= 'b0;
		reg_data <= 'b0;
		reg_rtr <= 'b0;
	end
	else
	begin
		if(valid && !busy)
		begin
			reg_ide <= ide;
			reg_dlc <= dlc;
			reg_data <= data;
			reg_rtr <= rtr;
		end
		else
		begin	
			reg_ide <= reg_ide;
			reg_dlc <= reg_dlc;
			reg_data <= reg_data;
			reg_rtr <= reg_rtr;
		end
	end
end
endmodule
