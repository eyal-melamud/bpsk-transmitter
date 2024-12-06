

module UART_RX #(
    parameter BAUD_RATE     = 115_200,
    parameter CLOCK_FREQ    = 12_000_000
) (
    input clk, 
    input n_rst, 
    input done,
    input rx,

    output [7:0] data_out,
    output data_ready);

    parameter HALF_CLK_COUNT    = CLOCK_FREQ / (BAUD_RATE*2) - 1;
    parameter CLK_COUNT         = CLOCK_FREQ / (BAUD_RATE) - 1;
    parameter CLK_COUNT_WIDTH   = $clog2(CLK_COUNT);

    parameter IDLE = 2'h0, START_BIT = 2'h1, DATA_BITS = 2'h2, STOP_BIT = 2'h3;
    reg [1:0] state, next_state;

    reg data_ready_reg;

    reg [CLK_COUNT_WIDTH:0] clk_counter;
    reg [2:0] data_bits_counter;
    reg [7:0] data, data_buff;

    initial begin
        state               = IDLE;
        clk_counter         = 0;
        data_bits_counter   = 0;
        data                = 0;
        data_buff           = 0;
        data_ready_reg      = 0;
    end

    always_comb begin
        case (state)
            IDLE        : next_state = rx                                                  ? IDLE                      : START_BIT;
            START_BIT   : next_state = (HALF_CLK_COUNT == clk_counter)                     ? (rx ? IDLE : DATA_BITS)   : START_BIT;
            DATA_BITS   : next_state = ((CLK_COUNT == clk_counter)&(&data_bits_counter))   ? STOP_BIT                  : DATA_BITS;
            STOP_BIT    : next_state = (CLK_COUNT + HALF_CLK_COUNT == clk_counter)         ? IDLE                      : STOP_BIT;
            default     : next_state = IDLE;
        endcase
    end


    always @(posedge clk) begin
        if (~n_rst) begin
            state               <= IDLE;
            clk_counter         <= 0;
            data_bits_counter   <= 0;
            data                <= 0;
            data_ready_reg      <= 0;
        end else begin 
            if (state == IDLE) begin
                clk_counter         <= 0;
                data_bits_counter   <= 0;
                data_ready_reg      <= (done | (next_state == START_BIT)) ? 1'b0 : data_ready_reg;
            end else if (state == START_BIT) begin
                clk_counter <= (HALF_CLK_COUNT == clk_counter) ? 0 : clk_counter + 1;
            end else if (state == DATA_BITS) begin
                if (CLK_COUNT == clk_counter) begin
                    data_buff[data_bits_counter]    <= rx;
                    data_bits_counter               <= data_bits_counter + 1;
                end     
                clk_counter <= (CLK_COUNT == clk_counter) ? 0 : clk_counter + 1;
            end else if (state == STOP_BIT) begin
                if (next_state == IDLE) begin
                    data_ready_reg <= 1'b1;
                    data <= data_buff;
                end
                clk_counter <= clk_counter + 1;
            end
            state <= next_state;
        end
        
    end
    assign data_out     = data;
    assign data_ready   = data_ready_reg & (state == IDLE);

endmodule