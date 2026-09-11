`timescale 1ns/1ps

module tb_can_controller_top;

reg pclk;
reg can_clk;

reg p_rst_n;
reg can_rst_n;

reg [11:0] PADDR_A;
reg PSEL_A;
reg PENABLE_A;
reg PWRITE_A;
reg [31:0] PWDATA_A;
reg [3:0] PSTRB_A;

wire [31:0] PRDATA_A;
wire PREADY_A;
wire PSLVERR_A;

reg [11:0] PADDR_B;
reg PSEL_B;
reg PENABLE_B;
reg PWRITE_B;
reg [31:0] PWDATA_B;
reg [3:0] PSTRB_B;

wire [31:0] PRDATA_B;
wire PREADY_B;
wire PSLVERR_B;

wire can_tx_A;
wire can_tx_B;
wire can_bus;

integer pass_count;
integer fail_count;
integer i;

reg [31:0] rdata_A;
reg [31:0] rdata_B;

reg tx_done_seen;
reg ack_seen;
reg rx_fifo_seen;

reg [31:0] tx_status_A;
reg [31:0] rx_status_B;
reg [31:0] status_A;
reg [31:0] status_B;

reg [31:0] rx_id_B;
reg [31:0] rx_ctrl_B;
reg [31:0] rx_data_lo_B;
reg [31:0] rx_data_hi_B;

assign can_bus = can_tx_A & can_tx_B;

can_controller_top #(
    .CAN_CLK_FREQ(100_000_000),
    .CAN_BIT_RATE(1_000_000),
    .FIFO_DEPTH(8)
) dut_A (
    .pclk      (pclk),
    .p_rst_n   (p_rst_n),
    .can_clk   (can_clk),
    .can_rst_n (can_rst_n),
    .PADDR     (PADDR_A),
    .PSEL      (PSEL_A),
    .PENABLE   (PENABLE_A),
    .PWRITE    (PWRITE_A),
    .PWDATA    (PWDATA_A),
    .PSTRB     (PSTRB_A),
    .PRDATA    (PRDATA_A),
    .PREADY    (PREADY_A),
    .PSLVERR   (PSLVERR_A),
    .can_rx    (can_bus),
    .can_tx    (can_tx_A)
);

can_controller_top #(
    .CAN_CLK_FREQ(100_000_000),
    .CAN_BIT_RATE(1_000_000),
    .FIFO_DEPTH(8)
) dut_B (
    .pclk      (pclk),
    .p_rst_n   (p_rst_n),
    .can_clk   (can_clk),
    .can_rst_n (can_rst_n),
    .PADDR     (PADDR_B),
    .PSEL      (PSEL_B),
    .PENABLE   (PENABLE_B),
    .PWRITE    (PWRITE_B),
    .PWDATA    (PWDATA_B),
    .PSTRB     (PSTRB_B),
    .PRDATA    (PRDATA_B),
    .PREADY    (PREADY_B),
    .PSLVERR   (PSLVERR_B),
    .can_rx    (can_bus),
    .can_tx    (can_tx_B)
);

initial
begin
    pclk = 1'b0;
end

always #5 pclk = ~pclk;

initial
begin
    can_clk = 1'b0;
end

always #50 can_clk = ~can_clk;

task apb_write_A;
input [11:0] addr;
input [31:0] data;
begin
    @(posedge pclk);
    PADDR_A <= addr;
    PWDATA_A <= data;
    PWRITE_A <= 1'b1;
    PSEL_A <= 1'b1;
    PENABLE_A <= 1'b0;
    PSTRB_A <= 4'hF;

    @(posedge pclk);
    PENABLE_A <= 1'b1;

    @(posedge pclk);
    while(!PREADY_A)
        @(posedge pclk);

    PSEL_A <= 1'b0;
    PENABLE_A <= 1'b0;
    PWRITE_A <= 1'b0;
    PADDR_A <= 12'd0;
    PWDATA_A <= 32'd0;
    PSTRB_A <= 4'd0;
end
endtask

task apb_write_B;
input [11:0] addr;
input [31:0] data;
begin
    @(posedge pclk);
    PADDR_B <= addr;
    PWDATA_B <= data;
    PWRITE_B <= 1'b1;
    PSEL_B <= 1'b1;
    PENABLE_B <= 1'b0;
    PSTRB_B <= 4'hF;

    @(posedge pclk);
    PENABLE_B <= 1'b1;

    @(posedge pclk);
    while(!PREADY_B)
        @(posedge pclk);

    PSEL_B <= 1'b0;
    PENABLE_B <= 1'b0;
    PWRITE_B <= 1'b0;
    PADDR_B <= 12'd0;
    PWDATA_B <= 32'd0;
    PSTRB_B <= 4'd0;
end
endtask

task apb_read_A;
input [11:0] addr;
output [31:0] data;
begin
    @(posedge pclk);
    PADDR_A <= addr;
    PWRITE_A <= 1'b0;
    PSEL_A <= 1'b1;
    PENABLE_A <= 1'b0;
    PSTRB_A <= 4'hF;

    @(posedge pclk);
    PENABLE_A <= 1'b1;

    @(posedge pclk);
    while(!PREADY_A)
        @(posedge pclk);

    data = PRDATA_A;

    PSEL_A <= 1'b0;
    PENABLE_A <= 1'b0;
    PADDR_A <= 12'd0;
    PSTRB_A <= 4'd0;
end
endtask

task apb_read_B;
input [11:0] addr;
output [31:0] data;
begin
    @(posedge pclk);
    PADDR_B <= addr;
    PWRITE_B <= 1'b0;
    PSEL_B <= 1'b1;
    PENABLE_B <= 1'b0;
    PSTRB_B <= 4'hF;

    @(posedge pclk);
    PENABLE_B <= 1'b1;

    @(posedge pclk);
    while(!PREADY_B)
        @(posedge pclk);

    data = PRDATA_B;

    PSEL_B <= 1'b0;
    PENABLE_B <= 1'b0;
    PADDR_B <= 12'd0;
    PSTRB_B <= 4'd0;
end
endtask

task check_value;
input [31:0] actual;
input [31:0] expected;
input [127:0] name;
begin
    if(actual === expected)
    begin
        pass_count = pass_count + 1;
        $display("PASS: %s expected=%h actual=%h", name, expected, actual);
    end
    else
    begin
        fail_count = fail_count + 1;
        $display("FAIL: %s expected=%h actual=%h", name, expected, actual);
    end
end
endtask

task check_bit;
input actual;
input expected;
input [127:0] name;
begin
    if(actual === expected)
    begin
        pass_count = pass_count + 1;
        $display("PASS: %s expected=%b actual=%b", name, expected, actual);
    end
    else
    begin
        fail_count = fail_count + 1;
        $display("FAIL: %s expected=%b actual=%b", name, expected, actual);
    end
end
endtask

initial
begin
    PADDR_A = 12'd0;
    PSEL_A = 1'b0;
    PENABLE_A = 1'b0;
    PWRITE_A = 1'b0;
    PWDATA_A = 32'd0;
    PSTRB_A = 4'd0;

    PADDR_B = 12'd0;
    PSEL_B = 1'b0;
    PENABLE_B = 1'b0;
    PWRITE_B = 1'b0;
    PWDATA_B = 32'd0;
    PSTRB_B = 4'd0;

    p_rst_n = 1'b0;
    can_rst_n = 1'b0;

    pass_count = 0;
    fail_count = 0;

    tx_done_seen = 1'b0;
    ack_seen = 1'b0;
    rx_fifo_seen = 1'b0;

    tx_status_A = 32'd0;
    rx_status_B = 32'd0;
    status_A = 32'd0;
    status_B = 32'd0;

    rx_id_B = 32'd0;
    rx_ctrl_B = 32'd0;
    rx_data_lo_B = 32'd0;
    rx_data_hi_B = 32'd0;

    $display("==============================================");
    $display("CAN 2.0B SINGLE-FRAME TOP-LEVEL TEST");
    $display("==============================================");

    repeat(10)
        @(posedge pclk);

    p_rst_n = 1'b1;
    can_rst_n = 1'b1;

    repeat(20)
        @(posedge pclk);

    $display("STEP 1: VERIFY RESET STATE");

    apb_read_A(12'h004, rdata_A);
    check_value(rdata_A, 32'h00000000, "NODE A CONTROL RESET");

    apb_read_B(12'h004, rdata_B);
    check_value(rdata_B, 32'h00000000, "NODE B CONTROL RESET");

    apb_read_A(12'h000, rdata_A);
    check_value(rdata_A, 32'h01002001, "NODE A VERSION");

    apb_read_B(12'h000, rdata_B);
    check_value(rdata_B, 32'h01002001, "NODE B VERSION");

    $display("STEP 2: CONFIGURE NODE A WHILE DISABLED");

    apb_write_A(12'h010, 32'd1);
    apb_write_A(12'h014, 32'h00020205);
    apb_write_A(12'h018, 32'd1);

    apb_write_A(12'h04C, 32'h00000155);
    apb_write_A(12'h050, 32'h000007FF);
    apb_write_A(12'h054, 32'h00000001);

    apb_write_A(12'h058, 32'h00000000);
    apb_write_A(12'h05C, 32'h00000000);
    apb_write_A(12'h060, 32'h00000000);

    apb_write_A(12'h01C, 32'h00000155);
    apb_write_A(12'h020, 32'h00000010);
    apb_write_A(12'h024, 32'hA5A5A5A5);
    apb_write_A(12'h028, 32'h00000000);

    apb_read_A(12'h010, rdata_A);
    check_value(rdata_A, 32'd1, "NODE A BRP");

    apb_read_A(12'h014, rdata_A);
    check_value(rdata_A, 32'h00020205, "NODE A SEGMENTS");

    apb_read_A(12'h018, rdata_A);
    check_value(rdata_A, 32'd1, "NODE A SJW");

    apb_read_A(12'h04C, rdata_A);
    check_value(rdata_A, 32'h00000155, "NODE A FILTER ID");

    apb_read_A(12'h050, rdata_A);
    check_value(rdata_A, 32'h000007FF, "NODE A FILTER MASK");

    apb_read_A(12'h054, rdata_A);
    check_bit(rdata_A[0], 1'b1, "NODE A FILTER ENABLE");

    $display("STEP 3: CONFIGURE NODE B WHILE DISABLED");

    apb_write_B(12'h010, 32'd1);
    apb_write_B(12'h014, 32'h00020205);
    apb_write_B(12'h018, 32'd1);

    apb_write_B(12'h04C, 32'h00000155);
    apb_write_B(12'h050, 32'h000007FF);
    apb_write_B(12'h054, 32'h00000001);

    apb_write_B(12'h058, 32'h00000000);
    apb_write_B(12'h05C, 32'h00000000);
    apb_write_B(12'h060, 32'h00000000);

    apb_read_B(12'h010, rdata_B);
    check_value(rdata_B, 32'd1, "NODE B BRP");

    apb_read_B(12'h014, rdata_B);
    check_value(rdata_B, 32'h00020205, "NODE B SEGMENTS");

    apb_read_B(12'h018, rdata_B);
    check_value(rdata_B, 32'd1, "NODE B SJW");

    apb_read_B(12'h04C, rdata_B);
    check_value(rdata_B, 32'h00000155, "NODE B FILTER ID");

    apb_read_B(12'h050, rdata_B);
    check_value(rdata_B, 32'h000007FF, "NODE B FILTER MASK");

    apb_read_B(12'h054, rdata_B);
    check_bit(rdata_B[0], 1'b1, "NODE B FILTER ENABLE");

    $display("STEP 4: ENABLE BOTH NODES");

    apb_write_A(12'h004, 32'h00000001);
    apb_write_B(12'h004, 32'h00000001);

    repeat(20)
        @(posedge can_clk);

    apb_read_A(12'h004, rdata_A);
    check_bit(rdata_A[0], 1'b1, "NODE A ENABLED");

    apb_read_B(12'h004, rdata_B);
    check_bit(rdata_B[0], 1'b1, "NODE B ENABLED");

    $display("STEP 5: VERIFY TX REGISTERS");

    apb_read_A(12'h01C, rdata_A);
    check_value(rdata_A, 32'h00000155, "NODE A TX ID");

    apb_read_A(12'h020, rdata_A);
    check_value(rdata_A, 32'h00000010, "NODE A TX CTRL");

    apb_read_A(12'h024, rdata_A);
    check_value(rdata_A, 32'hA5A5A5A5, "NODE A TX DATA LO");

    apb_read_A(12'h028, rdata_A);
    check_value(rdata_A, 32'h00000000, "NODE A TX DATA HI");

    $display("STEP 6: ISSUE TX COMMAND");

    apb_write_A(12'h02C, 32'h00000001);

    repeat(20)
        @(posedge pclk);

    apb_read_A(12'h030, tx_status_A);

    $display("DEBUG: NODE A TX STATUS AFTER COMMAND=%h", tx_status_A);

    $display("STEP 7: WAIT FOR NODE A TX COMPLETION");

    tx_done_seen = 1'b0;
    ack_seen = 1'b0;

    for(i = 0; i < 1500; i = i + 1)
    begin
        @(posedge pclk);

        apb_read_A(12'h030, tx_status_A);

        if(tx_status_A[2])
            tx_done_seen = 1'b1;

        if(tx_status_A[3])
            ack_seen = 1'b1;

        if(tx_done_seen)
            i = 1500;
    end

    check_bit(tx_done_seen, 1'b1, "NODE A TX DONE");
    check_bit(ack_seen, 1'b1, "NODE A ACK RECEIVED");

    apb_read_A(12'h030, tx_status_A);

    check_bit(tx_status_A[4], 1'b0, "NODE A ARBITRATION LOST");
    check_bit(tx_status_A[5], 1'b0, "NODE A TX ERROR");

    $display("STEP 8: WAIT FOR NODE B RX FIFO");

    rx_fifo_seen = 1'b0;

    for(i = 0; i < 1500; i = i + 1)
    begin
        @(posedge pclk);

        apb_read_B(12'h034, rx_status_B);

        if(!rx_status_B[8])
        begin
            rx_fifo_seen = 1'b1;
            i = 1500;
        end
    end

    check_bit(rx_fifo_seen, 1'b1, "NODE B RX FIFO AVAILABLE");

    if(rx_fifo_seen)
    begin
        check_value(rx_status_B[7:0], 32'd1, "NODE B FIFO COUNT");

        apb_read_B(12'h038, rx_id_B);
        check_value(rx_id_B, 32'h00000155, "NODE B RX ID");

        apb_read_B(12'h03C, rx_ctrl_B);
        check_value(rx_ctrl_B, 32'h00000010, "NODE B RX CTRL");

        apb_read_B(12'h040, rx_data_lo_B);
        check_value(rx_data_lo_B, 32'hA5A5A5A5, "NODE B RX DATA LO");

        apb_read_B(12'h044, rx_data_hi_B);
        check_value(rx_data_hi_B, 32'h00000000, "NODE B RX DATA HI");
    end

    $display("STEP 9: VERIFY NODE B CAN STATUS");

    apb_read_B(12'h008, status_B);

    check_bit(status_B[4], 1'b0, "NODE B ARBITRATION LOST");
    check_bit(status_B[5], 1'b0, "NODE B ACK ERROR");
    check_bit(status_B[6], 1'b0, "NODE B CRC ERROR");
    check_bit(status_B[7], 1'b0, "NODE B STUFF ERROR");
    check_bit(status_B[8], 1'b0, "NODE B FORM ERROR");
    check_bit(status_B[9], 1'b0, "NODE B BIT ERROR");
    check_bit(status_B[10], 1'b0, "NODE B RX OVERFLOW");

    $display("STEP 10: POP NODE B RX FIFO");

    apb_write_B(12'h048, 32'h00000001);

    repeat(20)
        @(posedge pclk);

    apb_read_B(12'h034, rx_status_B);

    check_bit(rx_status_B[8], 1'b1, "NODE B FIFO EMPTY AFTER POP");
    check_value(rx_status_B[7:0], 32'd0, "NODE B FIFO COUNT AFTER POP");

    $display("STEP 11: FINAL NODE A STATUS");

    apb_read_A(12'h008, status_A);

    check_bit(status_A[4], 1'b0, "NODE A ARBITRATION LOST");
    check_bit(status_A[5], 1'b0, "NODE A ACK ERROR");
    check_bit(status_A[6], 1'b0, "NODE A CRC ERROR");
    check_bit(status_A[7], 1'b0, "NODE A STUFF ERROR");
    check_bit(status_A[8], 1'b0, "NODE A FORM ERROR");
    check_bit(status_A[9], 1'b0, "NODE A BIT ERROR");

    $display("==============================================");
    $display("FINAL RESULTS");
    $display("PASS COUNT = %0d", pass_count);
    $display("FAIL COUNT = %0d", fail_count);

    if(fail_count == 0)
    begin
        $display("==============================================");
        $display("SINGLE-FRAME TOP-LEVEL TEST PASSED");
        $display("==============================================");
    end
    else
    begin
        $display("==============================================");
        $display("SINGLE-FRAME TOP-LEVEL TEST FAILED");
        $display("==============================================");
    end

    $finish;
end

endmodule
