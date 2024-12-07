


module BPSK_MODULE #(parameter CLOCK_IN=20_000_000,
                     parameter CLOCK_CARRIER=64_000,
                     parameter DATA_WIDTH=8,
                     parameter CYCLE_COUNT=4) (
    input clk, 
    input n_rst,
    input [DATA_WIDTH-1:0] data_in,

    output wave_out,
    output data_finish);


    parameter CYCLE_COUNT_FULL  = 2*CYCLE_COUNT;
    parameter CLK_DIV_COUNT     = CLOCK_IN/(CLOCK_CARRIER*2);
    parameter CLK_DIV_WIDTH     = $clog2(CLK_DIV_COUNT);
    parameter CYCLE_WIDTH       = $clog2(CYCLE_COUNT_FULL);
    parameter DATA_COUNT        = $clog2(DATA_WIDTH);

    

    reg [CLK_DIV_WIDTH-1:0] clk_counter;
    reg [CYCLE_WIDTH-1:0]   cycle_counter;
    reg [DATA_COUNT-1:0]    data_counter;
    reg carrier_reg, faze, last_data;


    initial begin
        clk_counter     <= 0;
        cycle_counter   <= 0;
        data_counter    <= 0;
        carrier_reg     <= 0;
        faze            <= 0;
        last_data       <= 0;
    end


    always @(posedge clk) begin
        if (~n_rst) begin
            clk_counter     <= 0;
            cycle_counter   <= 0;
            data_counter    <= 0;
            carrier_reg     <= 0;
            faze            <= data_in[0];
            last_data       <= data_in[0];
        end else begin
            if (clk_counter + 1 == CLK_DIV_COUNT) begin
                carrier_reg <= ~carrier_reg;
                if (cycle_counter + 1 == CYCLE_COUNT_FULL) begin
                    faze            <= (last_data ^ data_in[data_counter]) ? ~faze : faze;
                    last_data       <= data_in[data_counter];
                    data_counter    <= (data_counter + 1 >= DATA_WIDTH) ? 0 : data_counter + 1;
                end
                cycle_counter <= (cycle_counter + 1 >= CYCLE_COUNT_FULL) ? 0 : cycle_counter + 1;
            end
            clk_counter <= (clk_counter + 1 >= CLK_DIV_COUNT) ? 0 : clk_counter + 1;
        end
    end

    assign data_finish  = (data_counter == (DATA_WIDTH-1)) & (cycle_counter == (CYCLE_COUNT_FULL-1)) & (clk_counter + 1 == CLK_DIV_COUNT);
    assign wave_out     = carrier_reg ^ faze;

endmodule
