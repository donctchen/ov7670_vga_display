`timescale 1ns/1ns
// Purpose: 
// control VGA read RAM address
// if no input image, RAM is blank, therefore VGA always on

module vga_control(
    input wire sys_clk, // 100MHz
    input wire clk25,  // 25 MHz for VGA 640X480
    input wire reset,
    input wire [11:0] ram_output_data, // RRRR_GGGG_BBBB from buffer RAM
    input wire ready_display,  // Ready to display signal
    // read address for buffer RAM  
    output wire [16:0] read_RAM_address, 
    // output wire to VGA Port    
    output wire [3:0] vga_red, // R G B data, 4 bits  
    output wire [3:0] vga_green,
    output wire [3:0] vga_blue,
    // HSYNC and VSYNC 
    output wire vga_hsync,
    output wire vga_vsync,
    input wire testmode
);

reg [3:0] vga_red_reg;
reg [3:0] vga_green_reg;
reg [3:0] vga_blue_reg;
reg hsync_reg = 0;
reg vsync_reg = 0;
reg [9:0] hcount = 0;
reg [9:0] vcount = 0;
reg [16:0] read_RAM_address_reg;

assign read_RAM_address = read_RAM_address_reg;
assign vga_red = vga_red_reg;
assign vga_green = vga_green_reg;
assign vga_blue = vga_blue_reg;
assign vga_hsync = hsync_reg;
assign vga_vsync = vsync_reg;

always @(posedge clk25 or negedge reset) begin
    if (!reset) begin
        read_RAM_address_reg <= #1 {17{1'b0}};    
        hcount <= #1 1'b0;
        vcount <= #1 1'b0;
        vga_red_reg <= #1 4'b0000;
        vga_green_reg <= #1 4'b0000;
        vga_blue_reg <= #1 4'b0000;
    end
    else begin
        hcount <= #1 (hcount == 799)? 0: hcount + 1;    
        hsync_reg <= #1 (hcount >= 659 && hcount <=755)? 0 : 1;  // Hsync signal region

        if (hcount == 699)
            vcount <= #1 (vcount == 524) ? 0 : vcount + 1;
        
        vsync_reg <= #1 (vcount == 494) ? 0 : 1;

        // Define vidoe display 320x240 region        
        if (hcount < 320 && vcount < 240) begin
            if (testmode) begin
                vga_red_reg <= #1 4'b0111;
                vga_green_reg <= #1 4'b0111;
                vga_blue_reg <= #1 4'b0111; 
            end
            else begin                
                vga_red_reg[3:0] <= #1 ram_output_data[11:8];
                vga_green_reg[3:0] <= #1 ram_output_data[7:4];
                vga_blue_reg[3:0] <= #1 ram_output_data[3:0];
            // end
            
            read_RAM_address_reg <= #1 hcount + 320*vcount + 1;
            end
        end
        else begin
            // out of video region 320x240 or not ready to display
            // show gray screen
            vga_red_reg <= #1 4'b0000;
            vga_green_reg <= #1 4'b0000;
            vga_blue_reg <= #1 4'b0000; 
         
        end
        
        if (vcount >= 240) 
            read_RAM_address_reg <= #1 0;
        
        // next read address
//        if (hcount < 319 && vcount < 240)
//            read_RAM_address_reg <= #1 hcount + 320*vcount + 1;
//        else if (vcount >= 240) 
//            read_RAM_address_reg <= #1 0;
    end    
end

//always @(posedge sys_clk) begin
//    if (hcount < 320 && vcount < 240)
//        read_RAM_address_reg <= #1 hcount + 320*vcount;
//    else if (vcount >= 240) 
//        read_RAM_address_reg <= #1 0;
//end

endmodule