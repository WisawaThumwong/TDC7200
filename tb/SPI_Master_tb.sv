initial begin
    clk = 0; rst_n = 0; start = 0;
    #20 rst_n = 1;

    // Send 8 bits, expect to read 24 bits
    master.data_in = 8'hA5;
    start = 1; #10 start = 0;

    wait(!master.busy);
    $display("Received data = %h", master.data_out);
    #50 $finish;
end
