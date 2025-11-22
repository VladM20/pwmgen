// regs.v
// Register file pentru perifericul PWM (byte-addressable).
// Permite configurarea PWM și a contorului prin registre accesibile pe octet.

module regs (
    // semnale de ceas și reset
    input  wire        clk,       // ceas periferic
    input  wire        rst_n,     // reset activ LOW

    // semnale de interfață cu decoderul de adresă
    input  wire        read,      // semnal de citire
    input  wire        write,     // semnal de scriere
    input  wire [5:0]  addr,      // adresa byte-ului
    output reg  [7:0]  data_read, // datele returnate la citire
    input  wire [7:0]  data_write,// datele scrise

    // semnale pentru contor
    input  wire [15:0] counter_val, // valoarea curentă a contorului
    output reg  [15:0] period,      // perioada PWM
    output reg         en,          // activare contor
    output reg         count_reset, // puls reset contor
    output reg         upnotdown,   // direcția contorului (UP/DOWN)
    output reg  [7:0]  prescale,    // prescaler

    // semnale pentru PWM
    output reg         pwm_en,      // activare PWM
    output reg  [7:0]  functions,   // funcții PWM
    output reg  [15:0] compare1,    // comparator 1
    output reg  [15:0] compare2     // comparator 2
);

//////////////////////////
// Shift-register intern pentru pulsul de reset al contorului
//////////////////////////
reg [1:0] reset_shift; 
// Funcționează astfel:
// - la scriere pe adresa 0x07, reset_shift <= 2'b11
// - la fiecare ciclu de ceas se face shift spre LSB: reset_shift <= {reset_shift[0], 1'b0}
// - count_reset este legat de bitul MSB și rămâne activ două cicluri

//////////////////////////
// Bloc principal: scriere, citire și reset
//////////////////////////
always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        // Inițializare la reset (reset activ LOW)
        period       <= 16'h0000; // perioada PWM
        en           <= 1'b0;     // contor dezactivat
        prescale     <= 8'h00;    // prescaler 0
        upnotdown    <= 1'b1;     // contor crescător implicit
        pwm_en       <= 1'b0;     // PWM dezactivat
        functions    <= 8'h00;    // funcții PWM = 0
        compare1     <= 16'h0000; // comparator 1 = 0
        compare2     <= 16'h0000; // comparator 2 = 0
        data_read    <= 8'h00;    // date citite = 0
        reset_shift  <= 2'b00;    // shift-register reset
        count_reset  <= 1'b0;     // reset contor inactiv
    end else begin
        // Valoare implicită de citire (dacă read=0)
        data_read <= 8'h00;

        //////////////////////////
        // SCRIERE
        //////////////////////////
        if (write) begin
            case (addr)
                6'h00: period[7:0]   <= data_write;   // scriere LSB perioadă
                6'h01: period[15:8]  <= data_write;   // scriere MSB perioadă

                6'h02: en <= data_write[0];           // activare contor (bit0)

                6'h03: compare1[7:0]  <= data_write;  // comparator 1 LSB
                6'h04: compare1[15:8] <= data_write;  // comparator 1 MSB

                6'h05: compare2[7:0]  <= data_write;  // comparator 2 LSB
                6'h06: compare2[15:8] <= data_write;  // comparator 2 MSB

                6'h07: begin                           // RESET contor (write-only)
                    reset_shift <= 2'b11;             // orice scriere declanșează puls de 2 cicluri
                end

                6'h0A: prescale <= data_write;        // prescaler
                6'h0B: upnotdown <= data_write[0];    // direcția contorului (UP/DOWN)
                6'h0C: pwm_en <= data_write[0];       // activare PWM
                6'h0D: functions <= {6'b0, data_write[1:0]}; // stocare funcții în biții LSB

                default: begin
                    // adrese neutilizate -> ignorăm scrierea
                end
            endcase
        end // if(write)

        //////////////////////////
        // Generare puls reset contor
        //////////////////////////
        if (reset_shift != 2'b00) begin
            count_reset <= reset_shift[1];        // count_reset activ MSB
            reset_shift <= { reset_shift[0], 1'b0}; // shift spre LSB
        end else begin
            count_reset <= 1'b0;                  // reset contor inactiv
        end

        //////////////////////////
        // CITIRE
        //////////////////////////
        if (read) begin
            case (addr)
                6'h00: data_read <= period[7:0];        // perioadă LSB
                6'h01: data_read <= period[15:8];       // perioadă MSB

                6'h02: data_read <= {7'b0, en};         // enable contor
                6'h03: data_read <= compare1[7:0];      // comparator 1 LSB
                6'h04: data_read <= compare1[15:8];     // comparator 1 MSB
                6'h05: data_read <= compare2[7:0];      // comparator 2 LSB
                6'h06: data_read <= compare2[15:8];     // comparator 2 MSB

                6'h07: data_read <= 8'h00;              // write-only -> 0 la citire
                6'h08: data_read <= counter_val[7:0];   // contor LSB
                6'h09: data_read <= counter_val[15:8];  // contor MSB

                6'h0A: data_read <= prescale;           // prescaler
                6'h0B: data_read <= {7'b0, upnotdown};  // direcție contor
                6'h0C: data_read <= {7'b0, pwm_en};     // PWM enable
                6'h0D: data_read <= {6'b0, functions[1:0]}; // funcții PWM LSB

                default: data_read <= 8'h00;            // adrese neutilizate -> 0
            endcase
        end // if(read)
    end // else !rst_n
end // always

endmodule
