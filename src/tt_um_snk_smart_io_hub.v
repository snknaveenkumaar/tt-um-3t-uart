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

    // ✅ FIXED WIDTHS
    reg [255:0] duty_bus;
    reg [7:0]   prescale;

    wire [31:0] pwm_out;

    pwm_bank u_pwm (
        .clk(clk),
        .rst_n(rst_n),
        .prescale_div(prescale),
        .duty_bus(duty_bus),
        .pwm_out(pwm_out)
    );

    // LUT
    reg [7:0] lut [0:31];
    reg [4:0] lut_idx;

    integer i;

    always @(posedge clk) begin
        if (!rst_n) begin
            lut_idx <= 0;
            for (i = 0; i < 32; i = i + 1)
                lut[i] <= i * 8;
        end else begin
            lut_idx <= lut_idx + 1;
        end
    end

    // ALU
    reg [7:0] alu_a, alu_b;
    wire [7:0] alu_add = alu_a + alu_b;
    wire [7:0] alu_mul = alu_a * alu_b;

    // FSM
    reg [2:0] state;
    reg [4:0] idx;

    localparam IDLE = 0;
    localparam PWM_SET = 1;
    localparam PRESCALE = 2;
    localparam ALU_A = 3;
    localparam ALU_B = 4;

    always @(posedge clk) begin
        if (!rst_n) begin
            duty_bus <= 0;
            prescale <= 0;
            state <= IDLE;
            alu_a <= 0;
            alu_b <= 0;
        end else begin

            if (clear) begin
                duty_bus <= 0;
                prescale <= 0;
                state <= IDLE;
            end else if (rx_valid && enable) begin

                case (state)

                    IDLE: begin
                        case (rx_data[7:4])
                            4'h8: begin
                                idx <= rx_data[4:0];
                                state <= PWM_SET;
                            end
                            4'h9: state <= PRESCALE;
                            4'hA: state <= ALU_A;
                            4'hB: state <= ALU_B;
                        endcase
                    end

                    PWM_SET: begin
                        duty_bus[idx*8 +: 8] <= rx_data;
                        state <= IDLE;
                    end

                    PRESCALE: begin
                        prescale <= rx_data;
                        state <= IDLE;
                    end

                    ALU_A: begin
                        alu_a <= rx_data;
                        state <= IDLE;
                    end

                    ALU_B: begin
                        alu_b <= rx_data;
                        state <= IDLE;
                    end

                endcase
            end

            // dynamic sources
            duty_bus[0 +: 8]  <= lut[lut_idx];
            duty_bus[8 +: 8]  <= alu_add;
            duty_bus[16 +: 8] <= alu_mul;

        end
    end

    assign uo_out  = pwm_out[7:0];
    assign uio_out = pwm_out[15:8];
    assign uio_oe  = 8'hFF;

    // ✅ FIX ALL UNUSED
    wire _unused = &{
        ena,
        uio_in,
        ui_in[7:2],
        pwm_out[31:16],
        1'b0
    };

endmodule

`default_nettype wire
