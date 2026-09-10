module reset_sync (
    input  wire clk,
    input  wire arst_n,
    output wire srst_n
);

reg sync1;
reg sync2;

always @(posedge clk or negedge arst_n)
begin
    if(!arst_n)
    begin
        sync1 <= 1'b0;
        sync2 <= 1'b0;
    end
    else
    begin
        sync1 <= 1'b1;
        sync2 <= sync1;
    end
end

assign srst_n = sync2;

endmodule

