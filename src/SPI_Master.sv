module spi_master #(
    parameter TX_WIDTH = 8,
    parameter RX_WIDTH = 24
)(
    input  logic        clk,        // System clock
    input  logic        rst_n,      // Active-low reset
    input  logic        start,      // Start transfer
    input  logic [TX_WIDTH-1:0] data_in,  // Data to transmit
    output logic [RX_WIDTH-1:0] data_out, // Received data
    output logic        busy,       // Indicates transfer in progress

    // SPI interface
    output logic        sclk,
    output logic        mosi,
    input  logic        miso,
    output logic        ss_n
);

    typedef enum logic [1:0] {IDLE, LOAD, TRANSFER, DONE} state_t;
    state_t state, next_state;

    logic [RX_WIDTH-1:0] shift_reg_rx;
    logic [TX_WIDTH-1:0] shift_reg_tx;
    logic [5:0] bit_cnt; // enough to count up to 24
    logic sclk_en;
    logic sclk_int;

    // ===== State Machine =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            state <= IDLE;
        else
            state <= next_state;
    end

    always_comb begin
        next_state = state;
        case (state)
            IDLE:     if (start) next_state = LOAD;
            LOAD:     next_state = TRANSFER;
            TRANSFER: if (bit_cnt == RX_WIDTH && !sclk_en) next_state = DONE;
            DONE:     next_state = IDLE;
        endcase
    end

    assign busy = (state != IDLE);

    // ===== Bit Counter =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            bit_cnt <= 0;
        else if (state == LOAD)
            bit_cnt <= 0;
        else if (sclk_en && sclk_int)
            bit_cnt <= bit_cnt + 1;
    end

    // ===== SPI Clock (divide-by-2 for demonstration) =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            sclk_int <= 0;
        else if (state == TRANSFER)
            sclk_int <= ~sclk_int;
        else
            sclk_int <= 0;
    end
    assign sclk = (state == TRANSFER) ? sclk_int : 1'b0;
    assign sclk_en = (state == TRANSFER);

    // ===== Transmit Shift Register (MOSI) =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg_tx <= '0;
        else if (state == LOAD)
            shift_reg_tx <= data_in;
        else if (sclk_int && bit_cnt < TX_WIDTH)
            shift_reg_tx <= {shift_reg_tx[TX_WIDTH-2:0], 1'b0}; // shift left, fill with 0
    end

    // MOSI outputs valid data for first 8 bits, then dummy zeros
    assign mosi = (bit_cnt < TX_WIDTH) ? shift_reg_tx[TX_WIDTH-1] : 1'b0;

    // ===== Receive Shift Register (MISO) =====
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            shift_reg_rx <= '0;
        else if (state == TRANSFER && sclk_int)
            shift_reg_rx <= {shift_reg_rx[RX_WIDTH-2:0], miso};
    end

    assign data_out = shift_reg_rx;

    // ===== Slave Select =====
    assign ss_n = (state == IDLE) ? 1'b1 : 1'b0;

endmodule
