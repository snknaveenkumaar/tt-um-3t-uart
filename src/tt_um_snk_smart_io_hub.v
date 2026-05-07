`default_nettype none

module tt_um_snk_smart_io_hub (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire rx     = ui_in[0];
    wire enable = ui_in[1];
    wire clear  = ui_in[3];

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .data(rx_data),
        .valid(rx_valid)
    );

    reg  [255:0] duty_bus;
    reg  [7:0]   prescale;
    wire [31:0]  pwm_out;

    pwm_bank u_pwm (
        .clk(clk),
        .rst_n(rst_n),
        .prescale_div(prescale),
        .duty_bus(duty_bus),
        .pwm_out(pwm_out)
    );

    reg [4:0] lut_idx;

    always @(posedge clk) begin
        if (!rst_n) begin
            lut_idx <= 5'd0;
        end else begin
            lut_idx <= lut_idx + 1'b1;
        end
    end

    function [7:0] lut_value;
        input [4:0] idx;
        begin
            case (idx)
                5'd0:  lut_value = 8'd0;
                5'd1:  lut_value = 8'd8;
                5'd2:  lut_value = 8'd16;
                5'd3:  lut_value = 8'd24;
                5'd4:  lut_value = 8'd32;
                5'd5:  lut_value = 8'd40;
                5'd6:  lut_value = 8'd48;
                5'd7:  lut_value = 8'd56;
                5'd8:  lut_value = 8'd64;
                5'd9:  lut_value = 8'd72;
                5'd10: lut_value = 8'd80;
                5'd11: lut_value = 8'd88;
                5'd12: lut_value = 8'd96;
                5'd13: lut_value = 8'd104;
                5'd14: lut_value = 8'd112;
                5'd15: lut_value = 8'd120;
                5'd16: lut_value = 8'd128;
                5'd17: lut_value = 8'd136;
                5'd18: lut_value = 8'd144;
                5'd19: lut_value = 8'd152;
                5'd20: lut_value = 8'd160;
                5'd21: lut_value = 8'd168;
                5'd22: lut_value = 8'd176;
                5'd23: lut_value = 8'd184;
                5'd24: lut_value = 8'd192;
                5'd25: lut_value = 8'd200;
                5'd26: lut_value = 8'd208;
                5'd27: lut_value = 8'd216;
                5'd28: lut_value = 8'd224;
                5'd29: lut_value = 8'd232;
                5'd30: lut_value = 8'd240;
                5'd31: lut_value = 8'd248;
                default: lut_value = 8'd0;
            endcase
        end
    endfunction

    reg  [7:0] alu_a, alu_b;
    wire [7:0] alu_add = alu_a + alu_b;
    wire [15:0] alu_mul_full = alu_a * alu_b;
    wire [7:0]  alu_mul = alu_mul_full[7:0];

    reg [2:0] state;
    reg [4:0] idx;

    localparam IDLE     = 3'd0;
    localparam PWM_SET  = 3'd1;
    localparam PRESCALE = 3'd2;
    localparam ALU_A    = 3'd3;
    localparam ALU_B    = 3'd4;

    always @(posedge clk) begin
        if (!rst_n) begin
            duty_bus <= 256'd0;
            prescale <= 8'd0;
            state    <= IDLE;
            alu_a    <= 8'd0;
            alu_b    <= 8'd0;
            idx      <= 5'd0;
        end else begin
            if (clear) begin
                duty_bus <= 256'd0;
                prescale <= 8'd0;
                state    <= IDLE;
            end else if (rx_valid && enable) begin
                case (state)
                    IDLE: begin
                        case (rx_data[7:4])
                            4'h8: begin
                                idx   <= rx_data[4:0];
                                state <= PWM_SET;
                            end
                            4'h9: begin
                                state <= PRESCALE;
                            end
                            4'hA: begin
                                state <= ALU_A;
                            end
                            4'hB: begin
                                state <= ALU_B;
                            end
                            default: begin
                                state <= IDLE;
                            end
                        endcase
                    end

                    PWM_SET: begin
                        duty_bus[idx*8 +: 8] <= rx_data;
                        state <= IDLE;
                    end

                    PRESCALE: begin
                        prescale <= rx_data;
                        state    <= IDLE;
                    end

                    ALU_A: begin
                        alu_a <= rx_data;
                        state <= IDLE;
                    end

                    ALU_B: begin
                        alu_b <= rx_data;
                        state <= IDLE;
                    end

                    default: begin
                        state <= IDLE;
                    end
                endcase
            end

            duty_bus[28*8 +: 8] <= lut_value(lut_idx);
            duty_bus[29*8 +: 8] <= alu_add;
            duty_bus[30*8 +: 8] <= alu_mul;
        end
    end

    assign uo_out  = pwm_out[7:0];
    assign uio_out = pwm_out[15:8];
    assign uio_oe  = 8'hFF;

    wire _unused = &{
        ena,
        uio_in,
        ui_in[7:2],
        pwm_out[31:16],
        alu_mul_full[15:8],
        1'b1
    };

endmodule

`default_nettype wire
