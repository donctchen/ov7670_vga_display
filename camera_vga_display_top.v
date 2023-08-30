`timescale 1ns/1ns
// Purpose: setup up OV7670 camera and get vidoe to VGA display
// Date: 2023/8
// Edit: 
//
module camera_vga_display_top(
input wire clk,  // system 100MHz clk
input wire reset, // System Reset 
// input from OV7670
input wire pclk,  // camera pixel clock
input wire vsync,  // camera frame signal
input wire href,  // camera pixel valid 
input wire [7:0] D_data, // camera D data input
input wire testmode, // skip ov7670 setup
// to LED light: show control state
output wire [5:0] control_state, // 6 bit to LED control
// output to VGA
output wire [3:0] vga_red,
output wire [3:0] vga_green,
output wire [3:0] vga_blue,
output wire vga_hsync,
output wire vga_vsync,
// output to OV7670 camera
output wire sioc_to_ov7670, // SCL
output wire siod_to_ov7670, // SDA
output wire ov7670_xclk, // to ov7670 input clk
output wire ov7670_pwdn, // To ov7670 power down
output wire ov7670_reset,  // to ov7670 reset signal
output wire ready_display
);

wire locked;
wire ov7670_setup_done;
wire start_ov7670_hw_setup;

wire clk_100mhz;
wire clk_50mhz;
wire clk_25mhz; // PLL generated clk

// wire [15:0] RGB565_data;
// wire pixel_valid;
// wire frame_done;
wire wea;  
wire [11:0] RGB_444_data; // din
wire [11:0] doutb;   // dout
wire [16:0] read_address;
wire [16:0] save_address;

assign ov7670_xclk = clk_25mhz;

// Integrated control FSM module
system_control_fsm system_control_fsm(
    .clk(clk_25mhz),
    .reset(reset),
    .locked(locked), 
    .ov7670_setup_done(ov7670_setup_done),
    .start_capture(start_capture),
    .start_ov7670_hw_setup(start_ov7670_hw_setup),
    .control_state(control_state), // to control LED light to show control state
    .ready_display(ready_display),
    .testmode(testmode)
);

// VGA control module
vga_control vga_control(
  .sys_clk(clk),
  .clk25(clk_25mhz),
  .reset(reset),
  .ram_output_data(doutb),
  .ready_display(ready_display),
  // to buffer RAM
  .read_RAM_address(read_address),
  // to VGA port
  .vga_red(vga_red),  
  .vga_green(vga_green),
  .vga_blue(vga_blue),
  .vga_hsync(vga_hsync),
  .vga_vsync(vga_vsync),
  .testmode(testmode)
);

// OV7670 Read
ov7670_read ov7670_read(
  // input for camera
  .pclk(pclk), // OV7670 operation pixel clock
  .reset(reset),
  .vsync(vsync),// start transfer signal, camera pixel vsync
  .href(href),// pixel data vaild signal
  .D_data(D_data), // from camera D - out data  
  // output to RAM save
  .save_data(RGB_444_data),// RRRRGGG_GGGBBBB, 16 bit RGB 565 data
  .save_address(save_address),// pixel data in valid time
  .write_enable(wea)
);

// OV7670 hardware setup control
ov7670_setup_module_top #(
    .INPUT_CLK_FREQ(25000000) 
) ov7670_setup_module_top (
.clk(clk_25mhz),  // system freq (INPUT_CLK_FREQ parameter)
.reset(reset),
.start(start_ov7670_hw_setup), // input from upper module, start ov7670 setup
.sioc_to_ov7670(sioc_to_ov7670),  // wire to ov7670
.siod_to_ov7670(siod_to_ov7670),  // wire to 0v7670
.done(ov7670_setup_done),    // finish signal to upper module
.ov7670_pwdn(ov7670_pwdn),
.ov7670_reset(ov7670_reset)
);

// 100, 50, 25MHz Clock PLL
clock_PLL_100_50_25MHz clock_PLL_100_50_25MHz(
  .clk_out1(clk_100mhz),
  .clk_out2(clk_50mhz),
  .clk_out3(clk_25mhz),  
  .resetn(reset), // Status and control signals            
  .locked(locked), 
  .clk_in1(clk) // Clock in ports, 100MHz input
  );

// Buffer RAM IP
buffer_RAM_12x131072 buffer_RAM_12x131072 (
  // write from camera ov7670
  .clka(clk_50mhz),    // input wire clka
  .wea(wea),      // input wire [0 : 0] wea
  .addra(save_address),  // input wire [16 : 0] addra
  .dina(RGB_444_data),    // input wire [11 : 0] dina
  // read to VGA output
  .clkb(clk_50mhz),    // input wire clkb
  .addrb(read_address),  // input wire [16 : 0] addrb
  .doutb(doutb)  // output wire [11 : 0] doutb
);

endmodule