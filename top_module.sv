



module bpsk_top_module (
    input clk,
    input sel_bpsk_cycle,
    input n_rst,

    input uart_rx,
    output uart_tx,
	
	output led_uart_rx_valid,
		
    output bpsk_wave_out,
    output [2:0] led_mode,
    output led_sel_bpsk_cycle,
    output led_n_rst);

	parameter CLOCK_FRQ = 12_000_000;

// ======================================================================================================================================================================
// Wire decleration section
// ======================================================================================================================================================================

	wire [7:0] memory_data_out, memory_data_in;
		
	wire uart_valid_out, uart_full_in, uart_full_out;
    wire [7:0] uart_data_out;
	
	wire bpsk_2_wave, bpsk_2_data_finish;
    wire bpsk_4_wave, bpsk_4_data_finish;
    wire bpsk_data_finish, bpsk_n_rst;

    wire uart_n_rst;
	
	wire uart_tx_0;
	
	
// ======================================================================================================================================================================
// Controller section
// ======================================================================================================================================================================

    // main state machine vars and params
    parameter IDLE=3'h0, LOAD=3'h1, RUN=3'h2, CLEAR=3'h3, FROM_UART=3'h4; // main modes
    reg [2:0] state;
    
    // uart controller state machines vars and params
    reg [7:0] message_to_send;
    reg uart_sync_in, uart_sync_out, uart_read_ready;

    // memory controller state machine vars and parms
    reg [7:0] memory_address, max_address;
    reg memory_reg_wr;

    // run from uart state machine vars and parms
    reg [7:0] data_to_bpsk_uart, data_to_bpsk_uart_buff;
    reg stop_to_send;



    initial begin
        state                   = IDLE;

        
        message_to_send         = 8'h0;
        uart_sync_in            = 1'h0;
        uart_sync_out           = 1'h0;
        uart_read_ready         = 1'h1;

        memory_address          = 8'h0;
        max_address             = 8'h1;
        memory_reg_wr           = 1'h0;

        data_to_bpsk_uart       = 8'h0;
        data_to_bpsk_uart_buff  = 8'h0;
        stop_to_send            = 1'h0;
    end





    // state machine logic
    always @(posedge clk) begin
        //-----------------------------------------------------------------------------------------------------------------------
        // after reset registers valuse 
        //-----------------------------------------------------------------------------------------------------------------------
        if (~n_rst) begin
            state <= IDLE;
            memory_address          <= 0;
            memory_reg_wr           <= 0;
            message_to_send         <= 8'h0;
            uart_sync_in            <= 1'h0;
            uart_sync_out           <= 1'h0;
            uart_read_ready         <= 1'h1;
            data_to_bpsk_uart       <= 8'h0;
            data_to_bpsk_uart_buff  <= 8'h0;
            stop_to_send            <= 1'h0;
        end else begin
        //-----------------------------------------------------------------------------------------------------------------------
        // UART RX buffer clearing  
        //-----------------------------------------------------------------------------------------------------------------------
            if ((~uart_read_ready) & (~uart_sync_out)) begin
                uart_sync_out <= 1;
            end else if ((~uart_read_ready) & (uart_sync_out)) begin
                uart_sync_out   <= 0;
                uart_read_ready <= 1;
            end
            case (state)
        //-----------------------------------------------------------------------------------------------------------------------
        // IDLE state logic, waits for UART command
        //-----------------------------------------------------------------------------------------------------------------------
                IDLE: begin
                    uart_sync_in <= 1'b0; 
                    if (uart_read_ready & uart_valid_out) begin
                        case (uart_data_out)
                            8'h4c   :   begin                                   // 8'h4c: ASCII for - L for LOAD
                                        state                   <= LOAD;
                                        max_address             <= 0;  
                                        memory_address          <= 0;
                            end     
                            8'h52   :   state                   <= RUN;         // 8'h52: ASCII for - R for RUN
                            8'h43   :   state                   <= CLEAR;       // 8'h43: ASCII for - C for CLEAR
                            8'h55   :   begin                                   // 8'h55: ASCII for - U for from UART
                                        state                   <= FROM_UART;   
                                        stop_to_send            <= 1'h0;
                                        data_to_bpsk_uart       <= 8'h0;
                                        data_to_bpsk_uart_buff  <= 8'h0;
                            end 
                            default :   state                   <= IDLE;        // if none of the data is like this set to IDLE 
                        endcase
                        uart_read_ready <= 0;
                    end
                end
        //-----------------------------------------------------------------------------------------------------------------------
        // LOAD state logic, firs the max_address is set to 0 to get the new max address then it gets all the needed data
        //-----------------------------------------------------------------------------------------------------------------------
                LOAD: begin
                    if ((|max_address)&(memory_address == max_address)&((~uart_read_ready) & uart_valid_out)) begin
                        memory_address   <= 0;
                        memory_reg_wr   <= 0;
                        state           <= IDLE; 
                    end else if (~(|max_address)) begin
                        if (uart_read_ready & uart_valid_out) begin
                            // max_address      <= (~(|memory_data_in)) ? 8'h1 : memory_data_in;
                            max_address      <= 8'h10;
                            uart_read_ready <= 1'h0;
                        end
                    end else begin
                        if (uart_read_ready & uart_valid_out) begin
                            memory_reg_wr   <= 1;
                            uart_read_ready <= 1'h0;
                        end else if ((~uart_read_ready) & uart_sync_out) begin
                            memory_reg_wr <= 0;
                            memory_address <= memory_address + 1;
                        end
                    end
                end
        //-----------------------------------------------------------------------------------------------------------------------
        // RUN state logic, lets the BPSK module run on a loop on the data in the RAM, waits for a stop command from UART
        //-----------------------------------------------------------------------------------------------------------------------
                RUN: begin
                    if (uart_read_ready & uart_valid_out) begin
                        if (uart_data_out==8'h53) begin // 8'h53: ASCII for - S for STOP
                            state <= IDLE;
                        end
                        uart_read_ready <= 1'h0;
                    end
                    if (bpsk_data_finish) begin
                        memory_address <= (memory_address + 1 <= max_address) ? memory_address + 1 : 0;
                    end
                end
        //-----------------------------------------------------------------------------------------------------------------------
        // CLEAR state logic, sets the data in the ram to 0
        //-----------------------------------------------------------------------------------------------------------------------
                CLEAR: begin
                    if (memory_address == max_address) begin
                        memory_address  <= 0;
                        max_address     <= 1;
                        memory_reg_wr   <= 0;
                        state           <= IDLE; 
                    end else begin
                        if (memory_reg_wr) begin
                            memory_address <= memory_address + 1;
                        end else begin
                            memory_reg_wr <= 1;
                            memory_address <= 0;
                        end
                    end
                end 
        //-----------------------------------------------------------------------------------------------------------------------
        // FROM_UART state logic, gets the data for the BPSK transmission from the UART live.
        //-----------------------------------------------------------------------------------------------------------------------
                FROM_UART : begin
                    if (uart_read_ready & uart_valid_out) begin // read the data
                        data_to_bpsk_uart_buff  <= uart_data_out;
                        uart_read_ready         <= 1'h0;
                    end
                    if (bpsk_data_finish) begin
                        if ((data_to_bpsk_uart == 8'h53) && (data_to_bpsk_uart_buff == 8'h53)) begin
                            state <=  IDLE;
                        end
                        data_to_bpsk_uart       <= data_to_bpsk_uart_buff;
                        uart_sync_in            <= 1'b1;
                        message_to_send         <= data_to_bpsk_uart_buff;
                        // data_to_bpsk_uart_buff  <= 8'b0;
                        
                    end else begin
                        uart_sync_in        <= 1'b0; 
                    end
                end
        //-----------------------------------------------------------------------------------------------------------------------
        // default case, when the command dose not match, its resetting the params.
        //-----------------------------------------------------------------------------------------------------------------------
                default: begin
                    memory_address   <= 0;
                    memory_reg_wr   <= 0;
                end
            endcase
        end 
    end
  



// ======================================================================================================================================================================
// Memory section
// ======================================================================================================================================================================
    
    // lattice ram code
    BPSK_RAM_256B bpsk_ram_256 (.Address(memory_address), 
                                .Data(memory_data_in), 
                                .Clock(clk), 
                                .WE(memory_reg_wr), 
                                .ClockEn(1'h1), 
                                .Q(memory_data_out));




// ======================================================================================================================================================================
// Assign section
// ======================================================================================================================================================================



    assign bpsk_wave_out        = sel_bpsk_cycle          	? bpsk_4_wave           : bpsk_2_wave;        // "LOW" - 2 cycle bpsk, "HIGH" - 4 cycle bpsk.
    assign bpsk_data_finish     = sel_bpsk_cycle            ? bpsk_4_data_finish    : bpsk_2_data_finish; // "LOW" - 2 cycle bpsk, "HIGH" - 4 cycle bpsk.
    assign bpsk_n_rst           = n_rst & ((state == RUN) | (state == FROM_UART));

    assign uart_n_rst           = n_rst & (state != CLEAR);

    assign memory_data_in       = (state == CLEAR)    		? 0                     : uart_data_out;

    assign led_mode             = state;

    assign led_n_rst            = ~n_rst;
    assign led_sel_bpsk_cycle   = ~sel_bpsk_cycle;


	assign led_uart_rx_valid    = ~(uart_read_ready & uart_valid_out);
	
	//assign uart_tx = uart_tx_0 & uart_rx;



// ======================================================================================================================================================================
// Modules section
// ======================================================================================================================================================================
    wire [7:0] data_to_bpsk;
    assign data_to_bpsk = (state == RUN) ? memory_data_out : ((state == FROM_UART) ? data_to_bpsk_uart : 8'b0);
    
    
	UART_TOP #(		  .RX_BUFFER_SIZE	  (8),
					  .TX_BUFFER_SIZE 	  (8),
					  .CLK_FRQ			  (CLOCK_FRQ),
					  .UART_BOUAD     	  (230_400))
			 my_uart (.clk                (clk),
                      .n_rst              (uart_n_rst),
                      .rx                 (uart_rx),
                      .data_in            (message_to_send),
                      .data_in_sync       (uart_sync_in),
                      .data_out_sync      (uart_sync_out),
                      .tx                 (uart_tx),
                      .data_out           (uart_data_out),
                      .full_out           (uart_full_out),
                      .valid_out          (uart_valid_out),
                      .full_in            (uart_full_in));


    BPSK_MODULE #(.CLOCK_IN               (CLOCK_FRQ),
                  .CLOCK_CARRIER          (64_000),
                  .DATA_WIDTH             (8),
                  .CYCLE_COUNT            (2)) 
                
                bpsk_2_cycle(.clk         (clk),
                            .n_rst        (bpsk_n_rst),
                            .data_in      (data_to_bpsk),
                            .wave_out     (bpsk_2_wave),
                            .data_finish  (bpsk_2_data_finish));



    BPSK_MODULE #(.CLOCK_IN               (CLOCK_FRQ),
                  .CLOCK_CARRIER          (64_000),
                  .DATA_WIDTH             (8),
                  .CYCLE_COUNT            (4)) 
                
                bpsk_4_cycle(.clk         (clk),
                            .n_rst        (bpsk_n_rst),
                            .data_in      (data_to_bpsk),
                            .wave_out     (bpsk_4_wave),
                            .data_finish  (bpsk_4_data_finish));




    
endmodule
