`timescale 1ns/1ns
// Create Date: 2023/8
// Engineer: Don CT Chen
// Target: transfer setting data to OV7670 via SCCB interface
// Module Name: sccb_communication
// 
// Revision:
//

module sccb_communication 
#(
    // Outside setting parameter
    parameter INPUT_CLK_FREQ = 25000000,  // 25MHz
    parameter SCCB_FREQ = 100000  // 100kHz, constant
)
(
    input wire clk,  // system operation clock
    input wire reset,
    input wire start,
    input wire [7:0] sub_address, // OV7670 Function setting address (for phase 2 txm)
    input wire [7:0] set_data,  // for phase 3 txm
    output wire ready,
    output wire SIOC,  // to SCCB setting clock
    inout wire SIOD    // SCCB Data, based on SCCB Spec doc
);

reg ready_reg = 1'b1;
reg SIOC_reg = 1'b1;
reg SIOD_reg = 1'b1;
// to ouside of module
assign ready = ready_reg;
assign SIOC = SIOC_reg;
assign SIOD = SIOD_reg;

// OV7670 HW Address
localparam CAMERA_ADDRESS = 8'h42; // for phase 1 txm

// Define FSM State
// To generate SIO_C, SIO_D data waveform
// To fit SCCB timing specification
// Use 4 transmit steps
// 4 ending process steps to produce stop signal
localparam FSM_IDLE = 4'd0,
           FSM_START = 4'd1,
           FSM_LOAD = 4'd2,
           FSM_TXM1 = 4'd3,
           FSM_TXM2 = 4'd4,
           FSM_TXM3 = 4'd5,
           FSM_TXM4 = 4'd6,
           FSM_END_PROC1 = 4'd7,
           FSM_END_PROC2 = 4'd8,
           FSM_END_PROC3 = 4'd9,
           FSM_END_PROC4 = 4'd10,
           FSM_DONE = 4'd11,
           FSM_TIMER = 4'd12;

// Define FSM using variables
reg [3:0] SCCB_FSM_state = 0;
reg [3:0] FSM_return_state = 0;
reg [31:0] timer = 0;  // set delay time
reg [7:0] sub_address_reg; // function setting address
reg [7:0] set_data_reg;    // function setting values
reg [1:0] byte_counter = 0;  // descide transfer sequence(Address, sub_address, data)
reg [3:0] bit_index = 0;
reg [7:0] load_txm_byte = 0;  // 8 bits address or data, wait to trasnfer

//FSM
always @(posedge clk or negedge reset) begin
    if (!reset) begin
        SCCB_FSM_state <= FSM_IDLE;
    end
    else begin
        case (SCCB_FSM_state)

            FSM_IDLE: begin
                // initial clean
                bit_index <= #1 4'b0000;
                byte_counter <= #1 2'b00;
                // if receive Start singal, start txm process
                if (start) begin
                    // Start the SCCB transmit process
                    SCCB_FSM_state <= #1 FSM_START;
                    // latch setting address and data for txm
                    sub_address_reg <= #1 sub_address;
                    set_data_reg <= #1 set_data;
                    // change to module busy singal
                    ready_reg <= #1 1'b0;
                end
                else begin
                    // if not receive Start singal
                    // wait for input start signal
                    // txm process is ready for input new data                
                    ready_reg <= #1 1'b1; 
                end
            end

            FSM_START: begin
                // go to timer, set next step
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_LOAD;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                // SCCB Start singal: SIO_C high, SIO_D low
                SIOC_reg <= #1 1'b1; // high
                SIOD_reg <= #1 1'b0; // low 
            end

            FSM_LOAD: begin            
                // if finish 3 type data txm, go to END step
                // else go to transmit step
                SCCB_FSM_state <= #1 (byte_counter == 3) ? FSM_END_PROC1 : FSM_TXM1;
                byte_counter <= #1 byte_counter + 1;
                bit_index <= #1 0; // inital counter for txm bit number
                // In order to transmit 3 phases
                // load txm data sequence
                // 0: HW Address
                // 1: sub address
                // 2: setting data
                case (byte_counter)
                    0: load_txm_byte <= #1 CAMERA_ADDRESS;
                    1: load_txm_byte <= #1 sub_address_reg;
                    2: load_txm_byte <= #1 set_data_reg;
                    default: load_txm_byte <= #1 set_data_reg;
                endcase            
            end

            FSM_TXM1: begin
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_TXM2;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                // Delay 1/4 SIOC CLK to new SIO_C/D signal
                SIOC_reg <= #1 1'b0;
                // SIO_C to low, delay 1/4 SIOC and to change SIOD under SIOC Low
            end

            FSM_TXM2: begin
                // read txm data or address bit
                // SIOD change while SIOC low 
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_TXM3;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                // set SIOD value
                // after txm 8 bits value, add 1 bit z
                // total txm 9 bits (8 + 1) for a SIO_D phase
                if (bit_index < 8)
                    SIOD_reg <= #1 load_txm_byte[7]; // 0~7 bit txm
                else
                    SIOD_reg <= #1 1'bz; // After 8 bit txm, 9th bit = z
            end

            FSM_TXM3: begin
                // produce SIO_C Clk high singal
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_TXM4;
                // 1/2 SIOD CLK = 1 SIOC Clk peak
                // SIOD CLK High range time = 
                // 2 X SIOC CLK High range time
                timer <= #1 (INPUT_CLK_FREQ / (2*SCCB_FREQ));
                SIOC_reg <= #1 1'b1; // rising SIO_C clk high to generate SIO_C sign
            end

            FSM_TXM4: begin
                // If txm bit < 9 (0~8: 9 bit), continue txm
                // If txm bit = 9, load new txm data
                SCCB_FSM_state <= #1 (bit_index == 8) ? FSM_LOAD : FSM_TXM1;
                // change next txm data bit: left shift 1 bit
                load_txm_byte <= #1 load_txm_byte << 1;
                // add 1 bit count
                bit_index <= bit_index + 1;
            end

            FSM_END_PROC1: begin
                // reset SIOC to low, prepare for end signal
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_END_PROC2;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                SIOC_reg <= #1 1'b0;  // SIO_C to low
            end

            FSM_END_PROC2: begin
                // than change SIO_D to low, prepare for end signal
                // SIO_D can change only SIO_C low
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_END_PROC3;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                SIOD_reg <= #1 1'b0;
                // both SIO_D & SIO_C to low
            end

            FSM_END_PROC3: begin
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_END_PROC4;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                // END signal 1st step, SIOC to high
                SIOC_reg <= #1 1'b1; 
            end

            FSM_END_PROC4: begin
                // END signal 2nd step, SIOD to high
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_DONE;
                timer <= #1 (INPUT_CLK_FREQ / (4*SCCB_FREQ));
                SIOD_reg <= #1 1'b1;
            end

            FSM_DONE: begin
                // delay to fit hold time demand
                SCCB_FSM_state <= #1 FSM_TIMER;
                FSM_return_state <= #1 FSM_IDLE;
                timer <= #1 (INPUT_CLK_FREQ / (2*SCCB_FREQ));
                byte_counter <= #1 0;
            end

            FSM_TIMER: begin
                // count clock cycle to delay change signal
                // use timer value to fit SCCB timing spec
                SCCB_FSM_state <= #1 (timer == 0) ? FSM_return_state : FSM_TIMER;
                timer <= #1 (timer == 0) ? 0 : timer - 1;
            end

            default: begin
                SCCB_FSM_state <= #1 FSM_IDLE;
            end
            
        endcase  
        
    end  
end

    
endmodule