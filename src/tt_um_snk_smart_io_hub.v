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

    // 32-channel PWM bank
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

    // LUT waveform generator
    reg [7:0] lut [0:31];
    reg [4:0] lut_idx;
    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            lut_idx <= 5'd0;
            for (i = 0; i < 32; i = i + 1) begin
                lut[i] <= {i[4:0], 3'b000}; // 0, 8, 16, ... 248
            end
        end else begin
            lut_idx <= lut_idx + 1'b1;
        end
    end

    // Simple ALU
    reg  [7:0] alu_a, alu_b;
    wire [7:0] alu_add = alu_a + alu_b;
    wire [7:0] alu_mul = alu_a * alu_b;

    // State machine
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

            // Auto-driving a few channels to make the design richer
            duty_bus[0 +: 8]  <= lut[lut_idx];
            duty_bus[8 +: 8]  <= alu_add;
            duty_bus[16 +: 8] <= alu_mul;
        end
    end

    assign uo_out  = pwm_out[7:0];
    assign uio_out = pwm_out[15:8];
    assign uio_oe  = 8'hFF;

    // Keep all remaining inputs/outputs considered used
    wire _unused = &{
        ena,
        uio_in,
        ui_in[7:2],
        pwm_out[31:16],
        1'b1
    };

endmodule

`default_nettype wire
