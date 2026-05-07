`default_nettype none

module pwm_bank (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  prescale_div,
    input  wire [127:0] duty_bus,
    output wire [15:0] pwm_out
);

    reg [7:0] carrier;
    reg [7:0] prescale_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            carrier      <= 8'd0;
            prescale_cnt <= 8'd0;
        end else begin
            if (prescale_cnt == prescale_div) begin
                prescale_cnt <= 8'd0;
                carrier      <= carrier + 1'b1;
            end else begin
                prescale_cnt <= prescale_cnt + 1'b1;
            end
        end
    end

    genvar i;
    generate
        for (i = 0; i < 16; i = i + 1) begin : GEN_PWM
            assign pwm_out[i] = (carrier < duty_bus[i*8 +: 8]);
        end
    endgenerate

endmodule

`default_nettype wire
