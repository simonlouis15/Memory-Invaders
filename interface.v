`timescale 1ns/1ns

//combine with fill.v in lab tommorow to complete

module interface(iResetn,iPlotBox,iBlack,iColour,iLoadX,iXY_Coord,iClock,oX,oY,oColour,oPlot,oDone);

   parameter X_SCREEN_PIXELS = 8'd160;
   parameter Y_SCREEN_PIXELS = 7'd120;

   input wire iResetn, iPlotBox, iBlack, iLoadX;
   input wire [2:0] iColour;
   input wire [6:0] iXY_Coord;
   input wire 	     iClock;
   output wire [7:0] oX;         // VGA pixel coordinates
   output wire [6:0] oY;

   output wire [2:0] oColour;     // VGA pixel colour (0-7)
   output wire 	   oPlot;       // Pixel draw black
   output wire       oDone;       // goes high when finished drawing frame
		

	wire ld_x, ld_y,  black;
	wire [1:0] x_inc, y_inc;
	wire [7:0] black_x;
	wire [6:0] black_y;
	wire [2:0] black_c;

			
	// Put your code here. Your code should produce signals x,y,colour and writeEn
	// for the VGA controller, in addition to any other functionality your design may require.
Control c(iClock, iPlotBox, iBlack, iResetn, iLoadX, oPlot, ld_x, ld_y,  x_inc, y_inc, black, black_x, black_y, coord_c, oDone);
					 
DataPath dp (iClock, iResetn, iXY_Coord, iColour, ld_x, ld_y,  x_inc, y_inc, black, black_x, black_y, black_c, oX, oY, oColour);

endmodule

module Control (Clock, Plot, Clear, Reset_n, LoadX, plot_to_vga, ld_x, ld_y,  x_inc, y_inc, black, black_x, black_y, black_c, oDone);

	input Clock, Plot, Clear, Reset_n, LoadX;
	output reg ld_x, ld_y,  black, plot_to_vga, oDone;
	output reg [2:0] x_inc, y_inc;
	output reg [7:0] black_x;
	output reg [6:0] black_y;
	output reg [2:0] black_c;
	
	 reg [4:0] current_state, next_state;
	 reg [3:0] counter;
	 reg [13:0] clear;
	 reg [7:0] x_clear;
	 reg [6:0] y_clear;
	
	localparam  S_REST        	= 4'd0,
               S_LOAD_X   		= 4'd1,
               S_LOAD_WAIT  = 4'd2,
               S_LOAD_DATA   	= 4'd3,
               S_PLOT        	= 4'd4,
					S_PLOT_INCR		= 4'd5,
					S_PLOT_CHECK		= 4'd6,
					S_PLOT_CONFIRM = 4'd7,
               S_BLACK   		= 4'd8,
					S_BLACK_INCR	= 4'd9,
					S_BLACK_CHECK		= 4'd10;
	 
    
    always@(posedge Clock)
    begin
		case (current_state)
			 S_REST: next_state = Clear ? S_BLACK : Plot ? S_LOAD_DATA : LoadX ? S_LOAD_X : S_REST;
			 
			 S_LOAD_X: next_state = S_LOAD_WAIT;
			 S_LOAD_WAIT: next_state = LoadX ? S_LOAD_WAIT : S_LOAD_DATA;
			 S_LOAD_DATA: next_state = (ld_y) ? S_PLOT: S_LOAD_DATA;
			 
			 S_PLOT: next_state = S_PLOT_INCR;
			 S_PLOT_INCR: next_state = S_PLOT_CHECK;
			 S_PLOT_CHECK: next_state = !(counter == 4'b0) ? S_PLOT_INCR : S_PLOT_CONFIRM;
			 S_PLOT_CONFIRM: next_state = S_REST;
			 
			 S_BLACK: next_state = S_BLACK_INCR;
			 S_BLACK_INCR: next_state = S_BLACK_CHECK;
			 S_BLACK_CHECK: next_state = x_clear < 8'd160 ? S_BLACK_INCR : S_REST;
		default: next_state = S_REST;
		endcase

		
		ld_x = 0;
		ld_y = 0;
		
		x_clear = 8'b0;
		y_clear = 7'b0;
		black = 0;
		black_x = 8'b0;
		black_y = 7'b0;
		
		case (current_state)
			S_LOAD_X: begin
				ld_x <= 1;
			end
			S_LOAD_DATA: begin
				ld_y <= 1;

			end
			S_PLOT: begin
				counter <= 0;
			end
			S_PLOT_INCR: begin
				oDone <= 0;
				counter <= counter + 4'b0001;
					
				x_inc <= counter[1:0];
				y_inc <= counter[3:2];
				
				plot_to_vga <= 1;
			end
			
			S_PLOT_CONFIRM: begin
				oDone <= 1;
			end
			
			S_BLACK: begin
				clear <= 0;
			end
			S_BLACK_INCR: begin
				plot_to_vga = 1;
				oDone = 0;
				black = 1;
				black_x = clear;
				black_y = clear;
				black_c = 0;
				clear = clear + 14'd1;
				x_clear = clear[7:0];
				y_clear = clear[13:7];
				end
		endcase
		
	
		if (~Reset_n)
			current_state = S_REST;
		else
			current_state = next_state;
    end

endmodule

module DataPath (iClock, iResetn, iXY_Coord, iColour, ld_x, ld_y,  x_inc, y_inc, black, black_x, black_y, black_c, oX, oY, oColour);
    
	 input iClock, iResetn, ld_x, ld_y,  black;
    input [1:0] x_inc, y_inc;
    input [2:0] iColour, black_c;
    input [6:0] iXY_Coord, black_y;
    input [7:0] black_x;

    output [2:0] oColour;
    output [7:0] oX;
    output [6:0] oY;

    reg [7:0] reg_x;
    reg [6:0] reg_y;
    reg [2:0] reg_c;

    always @(posedge iClock)
    begin
        if (~iResetn) begin
            reg_x <= 8'b0;
            reg_y <= 7'b0;
            reg_c <= 2'b0;
        end
        else begin
            if (ld_x)
                reg_x <= {1'b0, iXY_Coord};
            if (ld_y)
                reg_y <= iXY_Coord;
					 reg_c <= iColour;
        end
    end

    assign oX = black ? black_x : (reg_x + x_inc);
    assign oY = black ? black_y : (reg_y + y_inc);
    assign oColour = black ? black_c : reg_c;

endmodule
