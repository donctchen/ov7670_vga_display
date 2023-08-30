`timescale 1ns/1ns
// system control
// use 50 MHz, align with ov7670 sccb frequency
// 1. initial set ov7670
// 2. start to get video and display
// 
module system_control_fsm (
input wire clk, // 25MHz
input wire reset,
input wire locked, // PLL locked signal
input wire ov7670_setup_done,
input wire testmode,
output wire start_capture,
output wire start_ov7670_hw_setup,
output wire [5:0] control_state, // to control LED light to show control state
output wire ready_display
);

// Define FSM state
localparam FSM_START = 0;
localparam FSM_START_SET = 1;
localparam FSM_SETUP_OV7670 = 2;
localparam FSM_VGA_DISPLAY = 3;
localparam FSM_TIMER = 4;

reg ready_display_reg = 0;
reg [2:0] CONTROL_FSM_state = 0;
reg [31:0] timer = 0;
reg [2:0] FSM_return_state = 0;
reg start_capture_reg = 0;
reg start_ov7670_hw_setup_reg = 0;
reg [5:0] control_state_reg = 3'b000_000;

assign ready_display = ready_display_reg;
assign start_capture = start_capture_reg;
assign control_state = control_state_reg; // TO outside LED unit
assign start_ov7670_hw_setup = start_ov7670_hw_setup_reg;


always @(posedge clk or negedge reset) begin
    if (!reset) begin
        CONTROL_FSM_state <= #1 FSM_START;
    end
    else begin
    case (CONTROL_FSM_state)

        FSM_START: begin
            ready_display_reg <= #1 1'b0;
            if (testmode) begin
                CONTROL_FSM_state <= #1 FSM_VGA_DISPLAY;                
                end
            else begin
                CONTROL_FSM_state <= #1 FSM_TIMER;
                timer <= #1 50;
                FSM_return_state <= #1 FSM_START_SET;
                
            end               
            
            control_state_reg <= #1 6'b000_001;                        
        end

        FSM_START_SET: begin
            CONTROL_FSM_state <= #1 FSM_TIMER;
            timer <= #1 1;
            FSM_return_state <= #1 FSM_SETUP_OV7670;
            start_ov7670_hw_setup_reg <= #1 1'b1;
            control_state_reg <= #1 6'b000_011;   
        end

        FSM_SETUP_OV7670: begin                
            // start setup OV7670
            start_ov7670_hw_setup_reg <= #1 1'b0; // generate a start signal

            if (ov7670_setup_done || testmode) begin
                // setup finished
                CONTROL_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_VGA_DISPLAY;                    
                // 300 ms time for register change stable, OV7670 spec
                timer <= #1 7500000; // normal setting
                //timer <= #1 5;// for test test

            end
            else begin
                // wait Setup done singal
                CONTROL_FSM_state <= #1 FSM_SETUP_OV7670;
            end
            control_state_reg <= #1 6'b001_111;
        end

        FSM_VGA_DISPLAY: begin                
            // start capture camera data
            ready_display_reg <= #1 1'b1;
            // save to buffer RAM                 
            // VGA output display
            start_capture_reg <= #1 1'b1;  // to OV7670 read module              
            control_state_reg <= #1 6'b111_111;
        end

        FSM_TIMER: begin                
            CONTROL_FSM_state <= #1 (timer == 0) ? FSM_return_state : FSM_TIMER;
            timer <= #1 (timer == 0) ? 0 : timer - 1;
            control_state_reg <= #1 6'b101_010;
        end

        default: begin
            CONTROL_FSM_state <= #1 FSM_START;    
        end
    endcase

    end
end

endmodule