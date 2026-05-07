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

    wire rx         = ui_in[0];
    wire enable     = ui_in[1];
    wire seq_gate   = ui_in[2];
    wire clear      = ui_in[3];

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .data(rx_data),
        .valid(rx_valid)
    );

    // 16 PWM duty registers
    reg [127:0] duty_bus;
    reg [7:0]   prescale;

    // Timer control
    reg [127:0] reload_bus;
    reg [7:0]   enable_bus;
    reg [7:0]   periodic_bus;
    reg [7:0]   reload_strobe;

    wire [7:0] timeout;
    wire [127:0] count_bus;

    timer_bank u_timer (
        .clk(clk),
        .rst_n(rst_n),
        .enable_bus(enable_bus),
        .periodic_bus(periodic_bus),
        .reload_strobe(reload_strobe),
        .reload_bus(reload_bus),
        .timeout_pulse(timeout),
        .count_bus(count_bus)
    );

    wire [15:0] pwm_out;

    pwm_bank u_pwm (
        .clk(clk),
        .rst_n(rst_n),
        .prescale_div(prescale),
        .duty_bus(duty_bus),
        .pwm_out(pwm_out)
    );

    // FSM
    reg [2:0] state;
    reg [3:0] pwm_idx;

    localparam IDLE = 3'd0;
    localparam PWM_SET = 3'd1;
    localparam PRESCALE_SET = 3'd2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n || clear) begin
            duty_bus <= 0;
            prescale <= 0;
            state <= IDLE;
        end else begin
            if (rx_valid && enable) begin
                case (state)
                    IDLE: begin
                        if (rx_data[7:4] == 4'h8) begin
                            pwm_idx <= rx_data[3:0];
                            state <= PWM_SET;
                        end else if (rx_data == 8'h90) begin
                            state <= PRESCALE_SET;
                        end
                    end

                    PWM_SET: begin
                        duty_bus[pwm_idx*8 +: 8] <= rx_data;
                        state <= IDLE;
                    end

                    PRESCALE_SET: begin
                        prescale <= rx_data;
                        state <= IDLE;
                    end
                endcase
            end
        end
    end

    assign uo_out  = pwm_out[7:0];
    assign uio_out = pwm_out[15:8];
    assign uio_oe  = 8'hFF;

    wire _unused = &{uio_in, ui_in[7:4], seq_gate, 1'b0};

endmodule

`default_nettype wire
