module cmd #(
    parameter TX_WIDTH = 8,
    parameter RX_WIDTH = 24
)(
    input logic clk,
    input logic rstn,

    //SPI
    input logic [TX_WIDTH-1:0] o_RX_Count,
    input logic o_RX_DV,
    input logic [7:0] o_RX_Byte,

    output logic [RX_WIDTH-1:0] i_TX_Count,
    output logic [7:0]  i_TX_Byte,
    output logic i_TX_DV,
    input logic o_TX_Ready,

    //TDC7200
    output logic Enable,
    input logic Trigg,
    output logic Start,
    output logic Stop,
    output logic sClk,
    input logic INTb,
    input logic Din,
    output logic Dout,

    //UART
    output logic [7:0]   s_axis_tdata,
    output logic         s_axis_tvalid,
    input logic          s_axis_tready,

    input logic [7:0]  m_axis_tdata,
    input logic        m_axis_tvalid,
    output logic       m_axis_tready,

    input logic tx_busy,
    input logic rx_busy

);

///////////////////////////////////////////////////////////////////////////////
//Internal Signal
logic [5:0] cnt_cmd;
logic [9:0] cnt_int;

logic rEnable;
logic rStart;
logic rStop;
logic rsClk;
logic rDout;

//FSM
reg [3:0] state, n_state;
localparam st_idel = 1;
localparam st_reg = 2;
localparam st_write = 3;
localparam st_read = 4;
localparam st_receive = 5;
localparam st_int = 6;
localparam st_stop = 7;

//Internal Parameter
localparam Byte_read = 5;                   //1 Addr + 4 Data
localparam Byte_write = 11;                 //1 Addr + 10 Command
///////////////////////////////////////////////////////////////////////////////
//Assignment
 

///////////////////////////////////////////////////////////////////////////////
//State Machine
always @(posedge clk) begin
    if (!rstn) begin
        state <= st_idel;
    end else begin
        state <= n_state;
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        n_state <= st_idel;
    end else begin
        case (state)
            st_idel :   if (rx_busy == 1) begin
                            n_state <= st_reg;
                        end else begin
                            n_state <= n_state;
                        end 

            st_reg :    if (s_axis_tvalid == 1 && s_axis_tready == 1) begin
                            if (read/writebit) begin
                                n_state <= st_write;
                            end else begin
                                n_state <= st_read;
                            end
                        end

            st_write :  if (cnt_cmd == Byte_write) begin
                            if (m_axis_tready == 1 && m_axis_tvalid == 1) begin
                                n_state <= st_stop;
                            end else begin
                                n_state <= n_state;
                            end
                        end

            st_read :   if (cnt_cmd == 1) begin
                            if (s_axis_tvalid == 1 && s_axis_tready == 1) begin
                                n_state <= st_receive;
                            end else begin
                                n_state <= n_state;
                            end
                        end else begin
                            n_state <= n_state;
                        end

            st_receive :    if (!tx_busy) begin
                                if (o_RX_DV == 1 && cnt_int == Byte_read) begin
                                    n_state <= st_int;
                                end else begin
                                    n_state <= n_state;
                                end
                            end

            

        endcase
    end
end


///////////////////////////////////////////////////////////////////////////////


always @(posedge clk) begin
    if (!rstn) begin
        Enable <= 0;
    end else begin
        if () begin
            Enable <= 1;
        end else begin
            Enable <= 0;
        end
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        Start <= 0;
    end else begin
        if () begin
            Start <= 1;
        end else begin
            Start <= 0;
        end
    end
end

always @(posedge clk) begin
    if (!rstn) begin
        Stop <= 0;
    end else begin
        if () begin
            Stop <= 1;
        end else begin
            Stop <= 0;
        end
    end
end

always @(posedge clk) begin
    if (!rstn) begin


endmodule