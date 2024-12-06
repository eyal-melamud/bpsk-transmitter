
module UART_TX #(
    parameter BAUD_RATE     = 115_200,
    parameter CLOCK_FREQ    = 12_000_000
) (
    input clk, n_rst, send,
    input [7:0] data,

    output tx, busy);

    parameter CLK_COUNT         = CLOCK_FREQ / (BAUD_RATE) - 1;
    parameter CLK_COUNT_WIDTH   = $clog2(CLK_COUNT);


    parameter IDLE = 2'h0, START_BIT = 2'h1, DATA_BITS = 2'h2, STOP_BIT = 2'h3;

    reg [1:0] state, next_state;
    reg [2:0] data_bits_counter;

    reg start_sending;
    

    reg [7:0] data_to_send;
    reg [CLK_COUNT_WIDTH:0] clk_counter;

    
    initial begin
        state               <= IDLE;
        data_bits_counter   <= 3'h0;
        clk_counter         <= 0;
        start_sending       <= 1'b0; 
    end

    always @(*) begin 
        case (state)
            IDLE        : next_state <= send                                                ? START_BIT : IDLE ;
            START_BIT   : next_state <= (CLK_COUNT == clk_counter)                          ? DATA_BITS : START_BIT;
            DATA_BITS   : next_state <= ((CLK_COUNT == clk_counter)&(&data_bits_counter))   ? STOP_BIT  : DATA_BITS;
            STOP_BIT    : next_state <= (CLK_COUNT == clk_counter)                          ? IDLE      : STOP_BIT;
            default     : next_state <= IDLE;
        endcase   
    end

    always @(posedge clk) begin
        if (~n_rst) begin 
            data_bits_counter   <= 3'h0;
            clk_counter         <= 0;
            start_sending       <= 1'b0; 
        end else begin 
            if (state == IDLE) begin
                data_bits_counter   <= 0;
                clk_counter         <= 0;
                data_to_send        <= data;
            end else if (state == START_BIT) begin
                clk_counter <= (CLK_COUNT == clk_counter) ? 0 : clk_counter + 1;
            end else if (state == DATA_BITS) begin
                if (CLK_COUNT == clk_counter) begin
                    data_bits_counter <= data_bits_counter + 1;
                end     
                clk_counter <= (CLK_COUNT == clk_counter) ? 0 : clk_counter + 1;
            end else if (state == STOP_BIT) begin
                clk_counter <= clk_counter + 1;
            end
            state <= next_state;
        end
    end


    assign tx   = (state == IDLE || state == STOP_BIT) ? 1'b1 : ((state == START_BIT) ? 1'b0 : data_to_send[data_bits_counter]);
    assign busy = (|state)|start_sending; // any state other than IDLE
    
endmodule