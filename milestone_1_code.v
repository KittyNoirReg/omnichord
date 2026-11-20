module vga_demo(CLOCK_50, SW, KEY, LEDR, PS2_CLK, PS2_DAT, HEX5, HEX4, HEX3, HEX2, HEX1, HEX0, 
                VGA_R, VGA_B, VGA_G,  VGA_HS, VGA_VS, VGA_BLANK_N, VGA_SYNC_N, VGA_CLK);
	
    
    parameter RESOLUTION = "160x120"; // "640x480" "320x240" "160x120"
    parameter COLOR_DEPTH = 9; // 9 6 3

    // specify the number of bits needed for an X (column) pixel coordinate on the VGA display
    parameter nX = 8;
    // specify the number of bits needed for a Y (row) pixel coordinate on the VGA display
    parameter nY = 7;

    // state names for the FSM that controls drawing of objects (LETTER KEYS ONLY)
    parameter Q_state = 5'b00000, W_state = 5'b00001, E_state = 5'b00010, R_state = 5'b00011, T_state = 5'b00100, Y_state = 5'b00101, U_state = 5'b00110, I_state = 5'b00111, O_state = 5'b01000, 
					A_state = 5'b01001, S_state = 5'b01010, D_state = 5'b01011, F_state = 5'b01100, G_state = 5'b01101, H_state = 5'b01110, J_state = 5'b01111, K_state = 5'b10000, L_state = 5'b10001, 
              Z_state = 5'b10010, X_state = 5'b10011, C_state = 5'b10100, V_state = 5'b10101, B_state = 5'b10111, N_state = 5'b11000, M_state = 5'b11001, COMMA_state = 5'b11010, PERIOD_state = 5'b11011, 
				  idle = 5'b11100, choose_state = 5'b11101;
				  				
	// state names for FSM that controls drawing of objects (NUMBER KEYS / STRUMPLATE)
	parameter idle_strum = 4'd0, ONE_state = 4'd1, TWO_state = 4'd2, THREE_state = 4'd3, FOUR_state = 4'd4, FIVE_state = 4'd5, SIX_state = 4'd6,
					SEVEN_state = 4'd7, EIGHT_state = 4'd8, NINE_state = 4'd9, ZERO_state = 4'd10, HYPHEN_state = 4'd11, EQUAL_state = 4'd12, choose_strum = 4'd13;
	
	// scancode parameters for keys, detected from SERIAL input
	parameter q = 8'h15, w = 8'h1d, e = 8'h24, r = 8'h2d, t = 8'h2c, y = 8'h35, u = 8'h3c, i = 8'h43, o = 8'h44, 
					a = 8'h1c, s = 8'h1b, d = 8'h23, f = 8'h2b, g = 8'h34, h = 8'h33, j = 8'h3b, k = 8'h42, l = 8'h4b,
					z = 8'h1a, x = 8'h22, c = 8'h21, v = 8'h2a, b = 8'h32, n = 8'h31, m = 8'h3a, comma = 8'h41, period = 8'h49,
					one = 8'h16, two = 8'h1e, three = 8'h26, four = 8'h25, five = 8'h2e, six = 8'h36, seven = 8'h3d, eight = 8'h3e, nine = 8'h46, zero = 8'h45,
					hyphen = 8'h4e, equal = 8'h55;
	
	// general port declarations
	input wire CLOCK_50;	
	input wire [9:0] SW;
	input wire [3:0] KEY;
	output wire [9:0] LEDR;     
    inout wire PS2_CLK;         // PS2 Clock
    inout wire PS2_DAT;         // PS2 Data
    output wire [6:0] HEX5, HEX4, HEX3, HEX2, HEX1, HEX0;    // used to show PS2 data
	 
	 //VGA port declarations (for VGA_adapter)
	 output [7:0] VGA_R;
    output [7:0] VGA_G;
    output [7:0] VGA_B;
    output VGA_HS;
    output VGA_VS;
    output VGA_BLANK_N;
    output VGA_SYNC_N;
    output VGA_CLK; 
	 
	 //FSM state controls for LETTER / CHORD keys
	 wire [4:0] current_state, next_state;
	 //FSM state controls for NUMBER / STRUMPLATE keys
	 reg [3:0] current_state_strum, next_state_strum;
	 
	 //FSM signal outputs - tells VGA display when to indicate button is pushed and line out what chord to play
	 wire q_signal, w_signal, e_signal, r_signal, t_signal, y_signal, u_signal, i_signal, o_signal, 
			a_signal, s_signal, d_signal, f_signal, g_signal, h_signal, j_signal, k_signal, l_signal,
			z_signal, x_signal, c_signal, v_signal, b_signal, n_signal, m_signal, comma_signal, period_signal;
	
	
	// The four signals below are used in demos that actively draw pixels on top of the background MIF.
	wire [8:0] color;     
    wire [nX-1:0] x_BG;         
    wire [nY-1:0] y_BG;       
    wire write;              

    reg prev_ps2_clk;               // ps2_clk value in the previous clock cycle
    wire negedge_ps2_clk;           // used for PS2 keyboard signals
    wire ps2_rec;                   // set when a PS2 packet has been received
    reg [32:0] Serial;              // each PS2 serial data packet has 11 bits:
                                    // STOP (1) PARITY d7 d6 d5 d4 d3 d2 d1 d0 START (0)
                                    // 33 total bits are received (scancode/release/scancode
    reg [3:0] Packet;               // used to know when 11 bits have been received
    wire [7:0] scancode;            // used to save the current ps2 scancode
    wire Esc;                        // enable scancode register
    reg step;                       // move an object


    wire Resetn, KEY1, KEY2;        // Reset, and synchronized versions of KEYs
    wire PS2_CLK_S, PS2_DAT_S;      // synchronized versions of PS2 signals

    assign Resetn = KEY[0];
    
	 
	 //FSM Module and outputs
	 letter_FSM do_FSM (CLOCK_50, current_state, next_state, Resetn, ps2_rec, scancode);
	 
		
		assign q_signal = (current_state == Q_state);
		assign w_signal = (current_state == W_state);
		assign e_signal = (current_state == E_state);
		assign r_signal = (current_state == R_state);
		assign t_signal = (current_state == T_state);
		assign y_signal = (current_state == Y_state);
		assign u_signal = (current_state == U_state);
		assign i_signal = (current_state == I_state);
		assign o_signal = (current_state == O_state);
		assign a_signal = (current_state == A_state);
		assign s_signal = (current_state == S_state);
		assign d_signal = (current_state == D_state);
		assign f_signal = (current_state == F_state);
		assign g_signal = (current_state == G_state);
		assign h_signal = (current_state == H_state);
		assign j_signal = (current_state == J_state);
		assign k_signal = (current_state == K_state);
		assign l_signal = (current_state == L_state);
		assign z_signal = (current_state == Z_state);
		assign x_signal = (current_state == X_state);
		assign c_signal = (current_state == C_state);
		assign v_signal = (current_state == V_state);
		assign b_signal = (current_state == B_state);
		assign n_signal = (current_state == N_state);
		assign m_signal = (current_state == M_state);
		assign comma_signal = (current_state == COMMA_state);
		assign period_signal = (current_state == PERIOD_state);
		
		
		
		//FSM STATE TESTING AND DEBUGGIN USING LEDS (IGNORE - NOT ACTUAL CODE FOR US)
		assign LEDR[0] = q_signal;
		assign LEDR[1] = e_signal;
		assign LEDR[2] = t_signal;
		assign LEDR[4] = a_signal;
		assign LEDR[5] = d_signal;
		assign LEDR[6] = g_signal;
		assign LEDR[7] = comma_signal;
		assign LEDR[8] = period_signal;
		assign LEDR[9] = (current_state == idle);
		//We will need another FSM for numbers but we can figure that out later. 
	
			
	 // instantiate the VGA adapter - print bg image (omnichord base)
    vga_adapter VGA (
        .resetn(KEY[0]),
        .clock(CLOCK_50),
        .color(color),
        .x(x_BG),
        .y(y_BG),
        .write(write),
        .VGA_R(VGA_R),
        .VGA_G(VGA_G),
        .VGA_B(VGA_B),
        .VGA_HS(VGA_HS),
        .VGA_VS(VGA_VS),
        .VGA_BLANK_N(VGA_BLANK_N),
        .VGA_SYNC_N(VGA_SYNC_N),
        .VGA_CLK(VGA_CLK));
		defparam VGA.BACKGROUND_IMAGE = "./MIF/bmp_640_9.mif" ;
		//defparam VGA.RESOLUTION = "160x120";
	
		drawkey KEY_Q (CLOCK_50, Resetn, x_BG, y_BG, color, write, q_signal, w_signal, e_signal, r_signal, t_signal, y_signal, u_signal);

    // display PS2 data
    hex7seg H0 (Serial[4:1], HEX0);
    hex7seg H1 (Serial[8:5], HEX1);
    hex7seg H2 (Serial[15:12], HEX2);
    hex7seg H3 (Serial[19:16], HEX3);
    hex7seg H4 (scancode[3:0], HEX4);
    hex7seg H5 (scancode[7:4], HEX5);

endmodule


//FSM module for letter key inputs
module letter_FSM (CLOCK_50, current_state, next_state, Resetn, ps2_rec, scancode);

	// state names for the FSM that controls drawing of objects (LETTER KEYS ONLY)
    parameter Q_state = 5'b00000, W_state = 5'b00001, E_state = 5'b00010, R_state = 5'b00011, T_state = 5'b00100, Y_state = 5'b00101, U_state = 5'b00110, I_state = 5'b00111, O_state = 5'b01000, 
					A_state = 5'b01001, S_state = 5'b01010, D_state = 5'b01011, F_state = 5'b01100, G_state = 5'b01101, H_state = 5'b01110, J_state = 5'b01111, K_state = 5'b10000, L_state = 5'b10001, 
              Z_state = 5'b10010, X_state = 5'b10011, C_state = 5'b10100, V_state = 5'b10101, B_state = 5'b10111, N_state = 5'b11000, M_state = 5'b11001, COMMA_state = 5'b11010, PERIOD_state = 5'b11011, 
				  idle = 5'b11100, choose_state = 5'b11101;
				  
	// scancode parameters for keys, detected from SERIAL input
	parameter q = 8'h15, w = 8'h1d, e = 8'h24, r = 8'h2d, t = 8'h2c, y = 8'h35, u = 8'h3c, i = 8'h43, o = 8'h44, 
					a = 8'h1c, s = 8'h1b, d = 8'h23, f = 8'h2b, g = 8'h34, h = 8'h33, j = 8'h3b, k = 8'h42, l = 8'h4b,
					z = 8'h1a, x = 8'h22, c = 8'h21, v = 8'h2a, b = 8'h32, n = 8'h31, m = 8'h3a, comma = 8'h41, period = 8'h49,
					one = 8'h16, two = 8'h1e, three = 8'h26, four = 8'h25, five = 8'h2e, six = 8'h36, seven = 8'h3d, eight = 8'h3e, nine = 8'h46, zero = 8'h45,
					hyphen = 8'h4e, equal = 8'h55;
					
					
	input CLOCK_50, Resetn, ps2_rec;
	output reg [4:0] current_state, next_state;
	input [7:0] scancode;

	 // FSM state table to choose states, specifically for the letter (chord) keys. Idle state is default; no audio is playing.
	 // choose_state is to decide which "state" (i.e. which chord to play) based on scancode input (defined by parameters above).
	 // every other state corresponds to one singular letter key. FSM stays in that state indefinitely until one of two cases are reached:
	 // 1) reset occurs or 2) another scancode from one of the letter keys is detected. therefore input of number keys and other non-used
	 // keys should not affect the state of the FSM
	 always @ (*) begin
		case (current_state) 
			idle: if (!ps2_rec || !Resetn) next_state = idle;
					else next_state = choose_state;
			choose_state:
					if (!Resetn) next_state = idle;
					else if (scancode == q) next_state = Q_state;
					else if (scancode == w) next_state = W_state;
					else if (scancode == e) next_state = E_state;
					else if (scancode == r) next_state = R_state;
					else if (scancode == t) next_state = T_state;
					else if (scancode == y) next_state = Y_state;
					else if (scancode == u) next_state = U_state;
					else if (scancode == i) next_state = I_state;
					else if (scancode == o) next_state = O_state;
					else if (scancode == a) next_state = A_state;
					else if (scancode == s) next_state = S_state;
					else if (scancode == d) next_state = D_state;
					else if (scancode == f) next_state = F_state;
					else if (scancode == g) next_state = G_state;
					else if (scancode == h) next_state = H_state;
					else if (scancode == j) next_state = J_state;
					else if (scancode == k) next_state = K_state;
					else if (scancode == l) next_state = L_state;
					else if (scancode == z) next_state = Z_state;
					else if (scancode == x) next_state = X_state;
					else if (scancode == c) next_state = C_state;
					else if (scancode == v) next_state = V_state;
					else if (scancode == b) next_state = B_state;
					else if (scancode == n) next_state = N_state;
					else if (scancode == m) next_state = M_state;
					else if (scancode == comma) next_state = COMMA_state;
					else if (scancode == period) next_state = PERIOD_state;
					else next_state = idle;
				Q_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = Q_state;
				W_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = W_state;
				E_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = E_state;
				R_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = R_state;
				T_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = T_state;
				Y_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = Y_state;
				U_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = U_state;
				I_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = I_state;
				O_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = O_state;
				A_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = A_state;
				S_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = S_state;
				D_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = D_state;
				F_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = F_state;
				G_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = G_state;
				H_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = H_state;
				J_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = J_state;
				K_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = K_state;
				L_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = L_state;
				Z_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = Z_state;
				X_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = X_state;
				C_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = C_state;
				V_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = V_state;
				B_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = B_state;
				N_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = N_state;
				M_state: if (!Resetn) next_state = idle;
							else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = M_state;
				COMMA_state: if (!Resetn) next_state = idle;
									else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = COMMA_state;
				PERIOD_state: if (!Resetn) next_state = idle;
									else if (scancode == q) next_state = Q_state;
							else if (scancode == w) next_state = W_state;
							else if (scancode == e) next_state = E_state;
							else if (scancode == r) next_state = R_state;
							else if (scancode == t) next_state = T_state;
							else if (scancode == y) next_state = Y_state;
							else if (scancode == u) next_state = U_state;
							else if (scancode == i) next_state = I_state;
							else if (scancode == o) next_state = O_state;
							else if (scancode == a) next_state = A_state;
							else if (scancode == s) next_state = S_state;
							else if (scancode == d) next_state = D_state;
							else if (scancode == f) next_state = F_state;
							else if (scancode == g) next_state = G_state;
							else if (scancode == h) next_state = H_state;
							else if (scancode == j) next_state = J_state;
							else if (scancode == k) next_state = K_state;
							else if (scancode == l) next_state = L_state;
							else if (scancode == z) next_state = Z_state;
							else if (scancode == x) next_state = X_state;
							else if (scancode == c) next_state = C_state;
							else if (scancode == v) next_state = V_state;
							else if (scancode == b) next_state = B_state;
							else if (scancode == n) next_state = N_state;
							else if (scancode == m) next_state = M_state;
							else if (scancode == comma) next_state = COMMA_state;
							else if (scancode == period) next_state = PERIOD_state;
							else next_state = PERIOD_state;
				default: next_state = idle;
		endcase
	end

		//FSM flip flops
		always @ (posedge CLOCK_50) begin
			if (!Resetn)
				current_state <= idle;
			else 
				current_state <= next_state;
		end
		
endmodule






module drawkey(CLOCK_50, Resetn, x_BG, y_BG, color, write, q_signal, w_signal, e_signal, r_signal, t_signal, y_signal, u_signal);

	input CLOCK_50, Resetn, q_signal, w_signal, e_signal, r_signal, t_signal, y_signal, u_signal;
	output reg [7:0] x_BG, y_BG;
	output reg [8:0] color;
	output reg write;

	//draw a key
	//this continuously draws everything on the screen
	always @ (posedge CLOCK_50) begin
		if (x_BG==159 | !Resetn) begin
			x_BG<= 0;
			y_BG<= (y_BG==119 | !Resetn) ? 0 : y_BG+1'b1;
		end
		else
			x_BG<=x_BG + 1'b1;
	end
	
	always @ (posedge CLOCK_50) begin
		color = 9'b111111111;
		write = 0;
		case (y_BG)	
			20: if (x_BG > 20 & x_BG < 30) begin
						write = 1;
						color = (q_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 40 & x_BG < 50) begin
						write = 1;
						color = (w_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 60 & x_BG < 70) begin
						write = 1;
						color = (e_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 80 & x_BG < 90) begin
						write = 1;
						color = (r_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 100 & x_BG < 110) begin
						write = 1;
						color = (t_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 120 & x_BG < 130) begin
						write = 1;
						color = (y_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 140 & x_BG < 150) begin
						write = 1;
						color = (u_signal) ? 9'b111000000 : 9'b000111000;
					end
					else begin color = 9'b111111111; write = 0; end
			21: if (x_BG > 20 & x_BG < 30) begin
						write = 1;
						color = (q_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 40 & x_BG < 50) begin
						write = 1;
						color = (w_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 60 & x_BG < 70) begin
						write = 1;
						color = (e_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 80 & x_BG < 90) begin
						write = 1;
						color = (r_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 100 & x_BG < 110) begin
						write = 1;
						color = (t_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 120 & x_BG < 130) begin
						write = 1;
						color = (y_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 140 & x_BG < 150) begin
						write = 1;
						color = (u_signal) ? 9'b111000000 : 9'b000111000;
					end
					else begin color = 9'b111111111; write = 0; end
			22: if (x_BG > 20 & x_BG < 30) begin
						write = 1;
						color = (q_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 40 & x_BG < 50) begin
						write = 1;
						color = (w_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 60 & x_BG < 70) begin
						write = 1;
						color = (e_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 80 & x_BG < 90) begin
						write = 1;
						color = (r_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 100 & x_BG < 110) begin
						write = 1;
						color = (t_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 120 & x_BG < 130) begin
						write = 1;
						color = (y_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 140 & x_BG < 150) begin
						write = 1;
						color = (u_signal) ? 9'b111000000 : 9'b000111000;
					end
					else begin color = 9'b111111111; write = 0; end
			23: if (x_BG > 20 & x_BG < 30) begin
						write = 1;
						color = (q_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 40 & x_BG < 50) begin
						write = 1;
						color = (w_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 60 & x_BG < 70) begin
						write = 1;
						color = (e_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 80 & x_BG < 90) begin
						write = 1;
						color = (r_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 100 & x_BG < 110) begin
						write = 1;
						color = (t_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 120 & x_BG < 130) begin
						write = 1;
						color = (y_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 140 & x_BG < 150) begin
						write = 1;
						color = (u_signal) ? 9'b111000000 : 9'b000111000;
					end
					else begin color = 9'b111111111; write = 0; end
			24: if (x_BG > 20 & x_BG < 30) begin
						write = 1;
						color = (q_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 40 & x_BG < 50) begin
						write = 1;
						color = (w_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 60 & x_BG < 70) begin
						write = 1;
						color = (e_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 80 & x_BG < 90) begin
						write = 1;
						color = (r_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 100 & x_BG < 110) begin
						write = 1;
						color = (t_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 120 & x_BG < 130) begin
						write = 1;
						color = (y_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 140 & x_BG < 150) begin
						write = 1;
						color = (u_signal) ? 9'b111000000 : 9'b000111000;
					end
					else begin color = 9'b111111111; write = 0; end
			25: if (x_BG > 20 & x_BG < 30) begin
						write = 1;
						color = (q_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 40 & x_BG < 50) begin
						write = 1;
						color = (w_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 60 & x_BG < 70) begin
						write = 1;
						color = (e_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 80 & x_BG < 90) begin
						write = 1;
						color = (r_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 100 & x_BG < 110) begin
						write = 1;
						color = (t_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 120 & x_BG < 130) begin
						write = 1;
						color = (y_signal) ? 9'b111000000 : 9'b000111000;
					end
					else if (x_BG > 140 & x_BG < 150) begin
						write = 1;
						color = (u_signal) ? 9'b111000000 : 9'b000111000;
					end
					else begin color = 9'b111111111; write = 0; end
			default: begin color = 9'b111111111; write = 0; end
		endcase
	end
endmodule



// syncronizer, implemented as two FFs in series
module sync(D, Resetn, Clock, Q);
    input wire D;
    input wire Resetn, Clock;
    output reg Q;

    reg Qi; // internal node

    always @(posedge Clock)
        if (Resetn == 0) begin
            Qi <= 1'b0;
            Q <= 1'b0;
        end
        else begin
            Qi <= D;
            Q <= Qi;
        end
endmodule

// n-bit register with enable
module regn(R, Resetn, E, Clock, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Resetn, E, Clock;
    output reg [n-1:0] Q;

    always @(posedge Clock)
        if (!Resetn)
            Q <= 0;
        else if (E)
            Q <= R;
endmodule

// n-bit up/down-counter with reset, load, enable, and direction control
module upDn_count (R, Clock, Resetn, L, E, Dir, Q);
    parameter n = 8;
    input wire [n-1:0] R;
    input wire Clock, Resetn, E, L, Dir;
    output reg [n-1:0] Q;

    always @ (posedge Clock)
        if (Resetn == 0)
            Q <= {n{1'b0}};
        else if (L == 1)
            Q <= R;
        else if (E)
            if (Dir)
                Q <= Q + {{n-1{1'b0}},1'b1};
            else
                Q <= Q - {{n-1{1'b0}},1'b1};
endmodule

module hex7seg (hex, display);
    input wire [3:0] hex;
    output reg [6:0] display;

    /*
     *       0  
     *      ---  
     *     |   |
     *    5|   |1
     *     | 6 |
     *      ---  
     *     |   |
     *    4|   |2
     *     |   |
     *      ---  
     *       3  
     */
    always @ (hex)
        case (hex)
            4'h0: display = 7'b1000000;
            4'h1: display = 7'b1111001;
            4'h2: display = 7'b0100100;
            4'h3: display = 7'b0110000;
            4'h4: display = 7'b0011001;
            4'h5: display = 7'b0010010;
            4'h6: display = 7'b0000010;
            4'h7: display = 7'b1111000;
            4'h8: display = 7'b0000000;
            4'h9: display = 7'b0011000;
            4'hA: display = 7'b0001000;
            4'hB: display = 7'b0000011;
            4'hC: display = 7'b1000110;
            4'hD: display = 7'b0100001;
            4'hE: display = 7'b0000110;
            4'hF: display = 7'b0001110;
        endcase
endmodule
