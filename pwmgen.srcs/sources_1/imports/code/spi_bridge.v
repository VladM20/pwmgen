module spi_bridge (
    // peripheral clock signals
    input clk,
    input rst_n,
    // SPI master facing signals
    input sclk,
    input cs_n,
    input mosi,
    output miso,
    // internal facing 
    output byte_sync,
    output[7:0] data_in,
    input[7:0] data_out
);

<<<<<<< HEAD
reg sclk_d1;
reg sclk_d2;

always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            sclk_d1 <= 1'b0;
            sclk_d2 <= 1'b0;
        end 
        else begin
            sclk_d1 <= sclk;
            sclk_d2 <= sclk_d1;
        end
end

wire sclk_rising  = (sclk_d1 == 1'b1) && (sclk_d2 == 1'b0);
wire sclk_falling = (sclk_d1 == 1'b0) && (sclk_d2 == 1'b1);

// --- Registre interne ---
reg [2:0] bit_cnt;      // Contor pentru cei 8 bi?i (0-7)
reg [7:0] shift_reg_rx; // Registru de deplasare pentru recep?ie (MOSI)
reg [7:0] shift_reg_tx; // Registru de deplasare pentru transmisie (MISO)

always @(posedge clk or negedge rst_n) begin
    if(!rst_n) begin
        miso <= 1'b0;
        byte_sync <= 1'b0;
        data_in <= 1'b0;
        bit_cnt <= 3'd0;
        shift_reg_rx <= 8'b0;
        shift_reg_tx <= 8'b0;
    end
    else begin
        byte_sync <= 1'b0;
        if(cs_n) begin
            bit_cnt <= 3'd7;
            miso <= 1'bZ;
            shift_reg_tx <= data_out;
        end
        else begin
            if(sclk_falling) begin
                miso <= shift_reg_tx[7];
                shift_reg_tx <= {shift_reg_tx[6:0], 1'b0};
            end
            if(sclk_rising) begin
                shift_reg_rx <= {shift_reg_rx[6:0], mosi};
                if(bit_cnt == 3'd0) begin
                    bit_cnt <= 3'd7;
                    data_in <= {shift_reg_rx[6:0], mosi};
                    byte_sync <= 1'b1;
                    shift_reg_tx <= data_out;
                end
                else begin
                    bit_cnt <= bit_cnt - 1'b1;
                end
            end
        end
    end
end
=======
>>>>>>> d4da8f8a5efe705891e635479e9a3bed58d2cfa4
endmodule