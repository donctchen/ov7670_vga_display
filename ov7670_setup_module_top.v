`timescale 1ns/1ns
// Integrate setup rom, sccb communication module
module ov7670_setup_module_top 
#(
    parameter INPUT_CLK_FREQ = 25000000
)
(
input wire clk,  // system freq (INPUT_CLK_FREQ parameter)
input wire reset,
input wire start, // input from upper module, start ov7670 setup
output wire sioc_to_ov7670,  // wire to ov7670
output wire siod_to_ov7670,  // wire to 0v7670
output wire done,    // finish signal to upper module
output wire ov7670_pwdn,
output wire ov7670_reset
);

wire [15:0] rom_out;
wire [7:0] rom_select;
wire [7:0] sccb_sub_address;
wire [7:0] sccb_set_data;
wire sccb_start_sign;
wire SCCB_ready_signal;
wire sioc;
wire siod;

// output to OV760 SCCB control singals
assign sioc_to_ov7670 = sioc;
assign siod_to_ov7670 = siod;
assign ov7670_pwdn = 1'b0;
assign ov7670_reset = 1'b1;


// setup module:
// get setup sub address and values from ROM
// assign SCCB communicaiton moudle to work with SCCB interface
ov767_setup #(.INPUT_CLK_FREQ(INPUT_CLK_FREQ)) ov767_setup(
    .clk(clk),
    .reset(reset),
    .SCCB_ready_signal(SCCB_ready_signal),
    .rom_out(rom_out),
    .start(start),    
    .rom_select(rom_select),
    .done(done),
    .sccb_sub_address(sccb_sub_address),
    .sccb_set_data(sccb_set_data),
    .sccb_start_sign(sccb_start_sign)
);

// save all function setting sub address and value data
ov7670_setup_rom ov7670_setup_rom(
    .clk(clk),
    .rom_select(rom_select),
    .rom_out(rom_out)
);

// input set sub address and value data
// work with SCCB to communicaiton OV7670 camera
// setup all HW parameters
sccb_communication #(
    .INPUT_CLK_FREQ(INPUT_CLK_FREQ)
) sccb_communication(
    .clk(clk),
    .reset(reset),
    .start(sccb_start_sign),
    .sub_address(sccb_sub_address),
    .set_data(sccb_set_data),
    .ready(SCCB_ready_signal),
    .SIOC(sioc),
    .SIOD(siod)
);

endmodule