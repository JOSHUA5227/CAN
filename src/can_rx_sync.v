module can_rx_sync(
input wire clk,
input wire rst_n,

input wire din,

output wire rx_sync
);

reg q1,q0;

assign rx_sync = q1;

always@(posedge clk or negedge rst_n)
begin
  if(!rst_n)
  begin
      {q1,q0} <=2'b11;
  end
  else
      {q1,q0} <= {q0,din};
end

endmodule
