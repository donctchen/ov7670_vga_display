`timescale 1ns/1ns
// capture OV7670 Video data 
// save to buffer RAM for VGA display
// edit:
// 8/24: modify FSM method to simple method
// 

module ov7670_read(
    // input from camera
    input wire pclk,  // OV7670 operation pixel clock
    input wire reset,
    input wire vsync, // start transfer signal
    input wire href,  // pixel data vaild signal    
    input wire [7:0] D_data, // from camera D - out data        
    // output
    output wire [11:0] save_data,  // dout
    output wire [16:0] save_address, // RAM Address
    output wire write_enable  // RAM WE
    );

    // RAM address
    reg [16:0] save_address_reg;
    reg [18:0] save_address_next;  // for 640*480 = 307200 --> 19 bits

    // reg [16:0] save_address_reg = {17{1'b0}};
    // reg [16:0] save_address_next = {17{1'b0}};
    // RAM din
    reg [11:0] save_data_reg;
    // RAM WR
    reg [1:0] write_enable_check; // 2 times check 
    reg write_enable_reg;

    // D data latch 
    reg [15:0] d_latch;

    assign save_data = save_data_reg;
    assign save_address = save_address_reg;
    assign write_enable = write_enable_reg;


    always @(posedge pclk or negedge reset) 
    begin
        if (!reset) begin        

            save_address_reg <= #1 {17{1'b0}};
            save_address_next <= #1 {19{1'b0}};
            write_enable_check <= #1 2'b00;
            d_latch <= #1 {16{1'b0}};
            write_enable_check <= #1 2'b00;
            save_data_reg <= #1 {12{1'b0}};
            write_enable_reg <= #1 0;

        end
        else begin

            if (vsync == 1) begin
                // begin a new frame
                save_address_reg <= #1 {17{1'b0}};
                save_address_next <= #1 {19{1'b0}};
                write_enable_check <= #1 2'b00;
                d_latch <= #1 {16{1'b0}};
            end
            else begin
                
                // Get RGB 565: RRRR_R: 15~12, GGGG_GG: 10~7, BBBB_B: 4~1 
                // into RGB 444
                save_data_reg <= #1 {d_latch[15:12], d_latch[10:7], d_latch[4:1]};
                //save_address_reg <= #1 save_address_next[18:2];  // 1/4 pixel save
                save_address_reg <= #1 save_address_next[16:0];  

                write_enable_reg <= #1 write_enable_check[1]; // 2nd time
                // left shift, href high, write_enable_check 0 --> 1
                write_enable_check <= #1 {write_enable_check[0], (href && !write_enable_check[0])};
                // latch & left shift d data, and latch next new input d data
                d_latch <= #1 {d_latch[7:0], D_data};

                if (write_enable_check[1] == 1) begin
                    // if 2 time, finished a completed RGB pixel data, 
                    // change next save RAM address
                    save_address_next <= #1 save_address_next + 1;
                end
            end 

        end
    end
endmodule