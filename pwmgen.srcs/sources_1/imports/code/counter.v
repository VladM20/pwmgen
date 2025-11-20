// counter.v
// Contor up/down cu prescaler și wrap pe perioada definită.
// - prescale este interpretat ca exponent: effective_div = (1 << prescale)
//   ex: prescale = 0 -> tick la fiecare ciclu de ceas
//       prescale = 1 -> tick la fiecare 2 cicluri
//       prescale = 2 -> tick la fiecare 4 cicluri, etc.
// - count_reset este sincron și forțează count_val la 0.
// - en activează numărătoarea; dacă en==0, contorul rămâne blocat și prescaler-ul se resetează.

module counter (
    // semnale de ceas și reset
    input  wire        clk,        // ceas periferic
    input  wire        rst_n,      // reset activ LOW

    // semnale de interfață cu registrele
    output reg  [15:0] count_val,  // valoarea curentă a contorului
    input  wire [15:0] period,     // perioada pentru wrap
    input  wire        en,         // enable contor
    input  wire        count_reset,// reset contor (prioritate mare)
    input  wire        upnotdown,  // direcția contorului (1=up, 0=down)
    input  wire [7:0]  prescale    // exponent prescaler
);

//////////////////////////
// Prescaler intern
//////////////////////////
reg [31:0] prescaler_cnt; 
// folosim 32 biți pentru a putea gestiona shift-uri până la 31 fără probleme

//////////////////////////
// Limitare shift pentru siguranță
//////////////////////////
wire [4:0] safe_shift;
assign safe_shift = (prescale > 8'd31) ? 5'd31 : prescale[4:0]; 
// dacă prescale > 31, îl limităm la 31 pentru a evita shift-uri nedefinite

//////////////////////////
// Prag pentru tick
//////////////////////////
wire [31:0] threshold;
assign threshold = (32'h1 << safe_shift); 
// numărul de ceasuri pentru un tick al contorului
// ex: prescale = 0 -> threshold = 1 -> tick la fiecare ciclu
// ex: prescale = 1 -> threshold = 2 -> tick la fiecare 2 cicluri

// tick activ atunci când prescaler_cnt ajunge la threshold-1
wire tick = (prescaler_cnt == (threshold - 1));

//////////////////////////
// Bloc principal: numărătoare și prescaler
//////////////////////////
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // reset activ LOW -> inițializare contor și prescaler
        prescaler_cnt <= 32'd0;
        count_val <= 16'd0;
    end else begin
        // reset sincron are prioritate maximă
        if (count_reset) begin
            prescaler_cnt <= 32'd0; // resetează prescaler
            count_val <= 16'd0;     // resetează contor
        end else begin
            if (en) begin
                // contor activ
                if (tick) begin
                    // tick = momentul în care contorul trebuie actualizat
                    prescaler_cnt <= 32'd0; // resetează prescaler

                    // comportament sigur dacă period = 0
                    if (period == 16'd0) begin
                        count_val <= 16'd0; // rămâne la 0
                    end else begin
                        if (upnotdown) begin
                            // contor crescător
                            if (count_val >= period) begin
                                count_val <= 16'd0; // wrap la 0 după perioadă
                            end else begin
                                count_val <= count_val + 16'd1; // increment normal
                            end
                        end else begin
                            // contor descrescător
                            if (count_val == 16'd0) begin
                                count_val <= period; // wrap la perioadă după 0
                            end else begin
                                count_val <= count_val - 16'd1; // decrement normal
                            end
                        end
                    end
                end else begin
                    // tick încă nu a apărut -> increment prescaler
                    prescaler_cnt <= prescaler_cnt + 32'd1;
                end
            end else begin
                // en == 0 -> contor blocat, reset prescaler
                prescaler_cnt <= 32'd0;
                // count_val rămâne neschimbat
            end
        end
    end
end

endmodule
