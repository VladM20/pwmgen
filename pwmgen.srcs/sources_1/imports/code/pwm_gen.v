module pwm_gen (
    // peripheral clock signals
    input clk,
    input rst_n,
    // PWM signal register configuration
    input pwm_en,
    input[15:0] period,
    input[7:0] functions,
    input[15:0] compare1,
    input[15:0] compare2,
    input[15:0] count_val,
    // top facing signals
    output pwm_out
);

    // Bit 0: Aliniere Stanga (0) / Dreapta (1)
    wire F_ALIGN_LR = functions[0];
    // Bit 1: Aliniat (0) / Nealiniat (1)
    wire F_MODE_UNALIGNED = functions[1];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pwm_out <= 1'b0;
        end else if (pwm_en) begin

            // Modul ALINIAT (FUNCTIONS[1] = 0)
            if (F_MODE_UNALIGNED == 1'b0) begin
                
                // Aliniere Stânga (FUNCTIONS[0] = 0)
                if (F_ALIGN_LR == 1'b0) begin
                    // HIGH cât timp contorul este mai mic decât COMPARE1
                    if (count_val < compare1)
                        pwm_out <= 1'b1;
                    else
                        pwm_out <= 1'b0;
        
                // Aliniere Dreapta (FUNCTIONS[0] = 1)
                end else begin 
                    // HIGH pe ultima sectiune a perioadei (>= period - compare1)
                    if (count_val < (period - compare1))
                        pwm_out <= 1'b0;
                    else
                        pwm_out <= 1'b1;
                end
                
            // Modul NEALINIAT (FUNCTIONS[1] = 1) 
            end else begin 
                
                if (compare1 < compare2 && counter_val >= compare1 && counter_val < compare2) begin
                    pwm_out <= 1'b1;
                end else begin
                    pwm_out <= 1'b0;
                end

            end 
        end else begin
            pwm_out <= 1'b0; 
        end
    end
    
endmodule

