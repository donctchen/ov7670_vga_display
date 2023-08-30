`timescale 1ns/1ns
// control OV7670 SCCB setup
// get sub address and values from ov7670_setup_rom
// change funcation setting sub address
// input rom output subaddr+values -->2 output: sub addr and values 
module ov767_setup 
# (parameter INPUT_CLK_FREQ = 25000000)
(
input wire clk,               //  system operation clock, ex. 25MHz
input wire reset,
input wire SCCB_ready_signal,  // check sccb ready for work
input wire [15:0] rom_out,   // get form ov7670 ROM database
input wire start,            // start working signal
output wire [7:0] rom_select, // get sub addr & values from ROM
output wire done,             // feedback setup finished
output wire [7:0] sccb_sub_address,  // to sccb control
output wire [7:0] sccb_set_data,     // to sccb control
output wire sccb_start_sign          // to sccb control
);

reg [2:0] OV7670_SETUP_FSM_state = 0;
reg [2:0] FSM_return_state = 0;
reg [31:0] timer = 0;
reg [7:0] rom_select_reg;
reg done_reg;
reg [7:0] sccb_sub_address_reg;
reg [7:0] sccb_set_data_reg;
reg sccb_start_sign_reg;

assign done = done_reg;
assign rom_select = rom_select_reg;
assign sccb_sub_address = sccb_sub_address_reg;
assign sccb_set_data = sccb_set_data_reg;
assign sccb_start_sign = sccb_start_sign_reg;

// initial begin
//     // set initial output values
//     rom_select_reg = 0;  // rom select 0,1,2....
//     done_reg = 0;
//     sccb_sub_address_reg = 0;
//     sccb_set_data_reg = 0;
//     sccb_start_sign_reg = 0;  // sccb wait for start signal
// end

// define FSM Stat
localparam FSM_IDLE = 0;
localparam FSM_SEND = 1;
localparam FSM_DONE = 2;
localparam FSM_TIMER = 3;

always @(posedge clk or negedge reset) begin
    if (!reset) begin
        // set initial output values
        rom_select_reg <= 0;  // rom select 0,1,2....
        done_reg <= 0;
        sccb_sub_address_reg <= 0;
        sccb_set_data_reg <= 0;
        sccb_start_sign_reg <= 0;  // sccb wait for start signal
    end
    else begin
        case (OV7670_SETUP_FSM_state) 

            FSM_IDLE: begin
                OV7670_SETUP_FSM_state <= #1 start ? FSM_SEND : FSM_IDLE;
                rom_select_reg <= #1 0;
                done_reg <= start ? 0 : done_reg;  // if start working, setup module busy
            end

            FSM_SEND: begin
                // check rom select: decide normal, delay, or end job
                case (rom_out)

                    16'hFFFF: begin
                        // recive final ending singal form ROM: 16'hFFFF
                        // to finish setup
                        OV7670_SETUP_FSM_state <= #1 FSM_DONE;    
                        sccb_start_sign_reg <= #1 0;                
                    end

                    16'hFFF0:  begin
                        // delay signal: 16'hFFF0, delay after inital
                        //10 ms delay
                        
                        timer <= #1 (INPUT_CLK_FREQ / 100); // normal setting
                        //timer <= #1 1; // test seeting

                        OV7670_SETUP_FSM_state <= #1 FSM_TIMER;
                        FSM_return_state <= #1 FSM_SEND;
                        rom_select_reg <= #1 rom_select_reg + 1;                        
                    end

                    default: begin
                        // normal sccb process 
                        if (SCCB_ready_signal) begin
                            // wait until sccb ready or finish previous job
                            // set new job to sccb 
                            // when 
                            // ready = 1, change data
                            // ready = 0, hold the data
                            OV7670_SETUP_FSM_state <= #1 FSM_TIMER;
                            FSM_return_state <= #1 FSM_SEND;
                            timer <= 0;  // one cycle delay
                            rom_select_reg <= #1 rom_select_reg + 1;
                            // rom_out = {sub_address, set_data}
                            sccb_sub_address_reg <= #1 rom_out[15:8];  // sub_address
                            sccb_set_data_reg <= #1 rom_out[7:0];      // set_data
                            sccb_start_sign_reg <= #1 1;  // control sccb to strat
                        end
                        // if  SCCB_ready_signal = 0, wait
                    end
                endcase
            end

            FSM_DONE: begin
                // output finish signal
                // return to idle state
                OV7670_SETUP_FSM_state <= #1 FSM_IDLE;
                done_reg <= #1 1;
                sccb_start_sign_reg <= #1 0;
            end

            FSM_TIMER: begin
                // Timer count
                OV7670_SETUP_FSM_state <= #1 (timer == 0) ? FSM_return_state : FSM_TIMER;
                timer <= #1 (timer == 0) ? 0 : timer - 1;
                sccb_start_sign_reg <= #1 0;  // let SCCB wait
            end
        endcase
    end
end

endmodule