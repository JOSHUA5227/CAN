//==============================================================
// tb_can_crc.v
//
// Self-checking testbench for the state/crc_done-based can_crc.
// Covers both roles:
//   TX: accumulate through SOF..DATA, then state=CRC with crc_en=0
//       shifts the frozen value out via crc_out.
//   RX: accumulate through SOF..DATA, then state=CRC with crc_en=1
//       keeps accumulating the received CRC bits themselves --
//       crc_done pulses on the last one, crc_error should read 0
//       for a correctly-received frame, 1 for a corrupted one.
//==============================================================

`timescale 1ns/1ps

module tb_can_crc;

    localparam SOF_ST = 4'd1;
    localparam ARB_ST = 4'd2;
    localparam DATA_ST = 4'd4;
    localparam CRC_ST = 4'd5;

    reg clk = 0, rst_n, bit_en;
    reg [3:0] state;
    reg crc_en, data_bit, crc_done;
    wire [14:0] crc_value;
    wire crc_out, crc_error;

    can_crc dut (
        .clk(clk), .rst_n(rst_n), .bit_en(bit_en), .state(state),
        .crc_en(crc_en), .data_bit(data_bit), .crc_done(crc_done),
        .crc_value(crc_value), .crc_out(crc_out), .crc_error(crc_error)
    );

    always #5 clk = ~clk;

    integer pass = 0, fail = 0;
    task check(input cond, input [300*8-1:0] msg);
        begin
            if (cond) begin pass = pass + 1; $display("[PASS] %0s", msg); end
            else begin fail = fail + 1; $display("[FAIL] %0s", msg); end
        end
    endtask

    task pulse; begin @(negedge clk); bit_en = 1; @(negedge clk); bit_en = 0; end endtask

    task reset_dut;
        begin
            rst_n = 0; bit_en = 0; state = 4'd0;
            crc_en = 0; data_bit = 0; crc_done = 0;
            repeat (2) @(posedge clk);
            rst_n = 1; @(negedge clk);
        end
    endtask

    // Software reference: standard CRC-15 shift-and-XOR
    task compute_ref(input [0:63] bits, input integer len, output [14:0] result);
        integer i; reg [14:0] r; reg fb;
        begin
            r = 15'd0;
            for (i = 0; i < len; i = i + 1) begin
                fb = bits[i] ^ r[14];
                r = {r[13:0], 1'b0};
                if (fb) r = r ^ 15'h4599;
            end
            result = r;
        end
    endtask

    reg [0:63] payload;      // SOF + arbitration/control/data bits (payload[0] = SOF = 0)
    integer payload_len;
    reg [14:0] ref_crc;
    integer i;
    reg [14:0] shifted_out;

    initial begin
        $display("\n=== can_crc (state/crc_done interface) testbench ===\n");

        // -----------------------------------------------------
        // Common payload used by every test: SOF(0) + 20 bits
        // -----------------------------------------------------
        payload = 0;
        payload[0] = 1'b0;                     // SOF
        payload[1:20] = 20'b11010010110100101101;
        payload_len = 21;
        compute_ref(payload, payload_len, ref_crc);
        $display("Reference CRC for this payload: %h\n", ref_crc);

        // -----------------------------------------------------
        // TEST 1: TX role -- accumulate, then verify frozen value
        // -----------------------------------------------------
        reset_dut;
        state = SOF_ST; crc_en = 1; data_bit = payload[0];
        pulse;
        state = ARB_ST;
        for (i = 1; i < payload_len; i = i + 1) begin
            data_bit = payload[i];
            pulse;
        end
        crc_en = 0;
        $display("T1: dut=%h ref=%h", crc_value, ref_crc);
        check(crc_value == ref_crc, "T1: TX-side accumulation matches reference");

        // -----------------------------------------------------
        // TEST 2: TX role -- shift the frozen value out, MSB first
        // -----------------------------------------------------
        state = CRC_ST; // crc_en already 0 -- takes the shift branch
        for (i = 0; i < 15; i = i + 1) begin
            shifted_out[14-i] = crc_out;
            pulse;
        end
        $display("T2: shifted=%h", shifted_out);
        check(shifted_out == ref_crc, "T2: TX shift-out sequence matches frozen value");

        // -----------------------------------------------------
        // TEST 3: RX role -- keep accumulating through a CORRECT
        // trailing CRC field, crc_done on the last bit -> crc_error=0
        // -----------------------------------------------------
        reset_dut;
        state = SOF_ST; crc_en = 1; data_bit = payload[0];
        pulse;
        state = ARB_ST;
        for (i = 1; i < payload_len; i = i + 1) begin
            data_bit = payload[i];
            pulse;
        end
        // now the CRC field itself -- crc_en STAYS 1 (RX role)
        state = CRC_ST;
        for (i = 14; i >= 0; i = i - 1) begin
            data_bit = ref_crc[i];
            crc_done = (i == 0); // pulse only on the very last CRC bit
            pulse;
        end
        crc_done = 0; crc_en = 0;
        check(crc_error == 1'b0,
              "T3: RX self-check on a correctly-received CRC -> crc_error=0");

        // -----------------------------------------------------
        // TEST 4: RX role -- same payload, but corrupt one CRC bit
        // -----------------------------------------------------
        reset_dut;
        state = SOF_ST; crc_en = 1; data_bit = payload[0];
        pulse;
        state = ARB_ST;
        for (i = 1; i < payload_len; i = i + 1) begin
            data_bit = payload[i];
            pulse;
        end
        state = CRC_ST;
        for (i = 14; i >= 0; i = i - 1) begin
            data_bit = (i == 3) ? ~ref_crc[i] : ref_crc[i]; // flip one bit
            crc_done = (i == 0);
            pulse;
        end
        crc_done = 0; crc_en = 0;
        check(crc_error == 1'b1,
              "T4: RX self-check on a CORRUPTED CRC bit -> crc_error=1");

        // -----------------------------------------------------
        // TEST 5: crc_done gating -- error flag only updates when
        // crc_done actually pulses, not on every accumulate cycle
        // -----------------------------------------------------
        reset_dut;
        state = SOF_ST; crc_en = 1; data_bit = 0;
        pulse;
        state = ARB_ST; data_bit = 1; crc_done = 0;
        pulse; // crc_done not asserted -- crc_error must stay at its reset value
        check(crc_error == 1'b0,
              "T5: crc_error does not change on a cycle where crc_done=0");

        $display("\n============================================");
        $display("  RESULTS: %0d passed, %0d failed", pass, fail);
        $display("============================================\n");
        $finish;
    end

    initial begin
        #100000;
        $display("[TIMEOUT] simulation hung");
        $finish;
    end

endmodule
