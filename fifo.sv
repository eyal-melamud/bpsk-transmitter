
module FIFO #(parameter MEMROY_SIZE = 16, parameter UNIT_SIZE = 8) (
    input clk, n_rst, push, pop,
    input [UNIT_SIZE - 1:0] data_in,
    output valid, buff_full, 
    output [UNIT_SIZE - 1:0] data_out);

    reg [MEMROY_SIZE-1:0][UNIT_SIZE-1:0] buffer;
    parameter COUNT_SIZE = $clog2(MEMROY_SIZE);
    reg [COUNT_SIZE:0] wr_ptr, re_ptr;
    reg last_comm;
    wire can_push, can_pop;

    initial begin
        buffer      <= 0;
        wr_ptr      <= 0;
        re_ptr      <= 0;
        last_comm   <= 1'b1;
    end

    always @(posedge clk, negedge n_rst) begin
        if (~n_rst) begin
            buffer      <= 0;
            wr_ptr      <= 0;
            re_ptr      <= 0;
            last_comm   <= 1'b1;  // 1 = pop, 0 = push
        end else begin
            if (can_pop) re_ptr <= (re_ptr < MEMROY_SIZE - 1) ? re_ptr + 1 : 0; // pop command  
            if (can_push) begin // push command
                buffer[wr_ptr] <= data_in;
                wr_ptr <= (wr_ptr < MEMROY_SIZE - 1) ? wr_ptr + 1 : 0;
            end
            last_comm <= (push^pop) ? pop : last_comm;
        end
    end

    assign can_pop      = pop&valid;
    assign can_push     = push&(pop ? can_pop : ~buff_full);
    assign buff_full    = (~|(wr_ptr^re_ptr))&(~last_comm);  // pointers are equal and last command was push. 
    assign data_out     = buffer[re_ptr];
    assign valid        = ~((~|(wr_ptr^re_ptr))&last_comm);     // pointers are equal and last command was pop.
    
endmodule

