module instr_dcd (

    input clk,
    input rst_n,
    
    input byte_sync,      // Semnal puls când un byte nou a fost primit/transmis complet
    input [7:0] data_in,  // Datele primite de la MOSI
    output [7:0] data_out,// Datele de trimis pe MISO
    
    output reg read,        // Semnal activare citire
    output reg write,       // Semnal activare scriere
    output [5:0] addr,      // Adresa calculată pentru registre
    input [7:0] data_read,  // Date venite din registre
    output [7:0] data_write // Date de scris în registre
);

    // Stari FSM
    localparam STATE_SETUP = 1'b0; // Primul byte - astept comanda
    localparam STATE_DATA  = 1'b1; // Al doilea byte - procesez datele

    reg state;          // Registru pentru starea curenta
    reg rw_internal;    // Retin daca e R sau W
    reg [5:0] addr_reg; // Retine adresa calculata

    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_SETUP;
            addr_reg <= 6'b0;
            rw_internal <= 1'b0;
        end else begin
            // avansez cand SPI anunta ca a terminat un byte
            if (byte_sync) begin
                case (state)
                    STATE_SETUP: begin
        
                        rw_internal <= data_in[7];
                        
                        addr_reg <= data_in[5:0] + {5'b0, data_in[6]};
                        
                        state <= STATE_DATA;
                    end

                    STATE_DATA: begin
                        state <= STATE_SETUP;
                    end
                endcase
            end
        end
    end


    assign addr = addr_reg;
    assign data_write = data_in;

    // Semnalul de WRITE:
    // Activ doar daca suntem in faza DATA, a venit pulsul de byte_sync (avem datele complete),
    // si operatia memorata a fost de scriere 
    always @(*) begin
        if (state == STATE_DATA && byte_sync && rw_internal) begin
            write = 1'b1;
        end else begin
            write = 1'b0;
        end
    end

    always @(*) begin
        if (state == STATE_DATA && !rw_internal) begin
            read = 1'b1;
        end else begin
            read = 1'b0;
        end
    end
    assign data_out = data_read;

endmodule