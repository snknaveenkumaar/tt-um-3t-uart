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

    // Inputs
    wire rx      = ui_in[0];
    wire enable  = ui_in[1];
    wire clear   = ui_in[3];

    // UART
    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .data(rx_data),
        .valid(rx_valid)
    );

    // PWM + control registers
    reg [127:0] duty_bus;
    reg [7:0]   prescale;

    // Timer signals (kept but safely tied)
    reg [127:0] reload_bus;
    reg [7:0]   enable_bus;
    reg [7:0]   periodic_bus;
    reg [7:0]   reload_strobe;

    wire [7:0]  timeout;
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

    localparam IDLE           = 3'd0;
    localparam PWM_SET        = 3'd1;
    localparam PRESCALE_SET   = 3'd2;

    // ✅ FIXED ALWAYS BLOCK (NO MULTI-EDGE ISSUE)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            duty_bus        <= 128'd0;
            prescale        <= 8'd0;
            state           <= IDLE;
            pwm_idx         <= 4'd0;

            // Fix undriven signals
            reload_bus      <= 128'd0;
            enable_bus      <= 8'd0;
            periodic_bus    <= 8'd0;
            reload_strobe   <= 8'd0;

        end else begin

            // synchronous clear
            if (clear) begin
                duty_bus <= 128'd0;
                prescale <= 8'd0;
                state    <= IDLE;
            end else begin

                // default: no reload pulses
                reload_strobe <= 8'd0;

                if (rx_valid && enable) begin
                    case (state)

                        IDLE: begin
                            if (rx_data[7:4] == 4'h8) begin
                                pwm_idx <= rx_data[3:0];
                                state   <= PWM_SET;
                            end else if (rx_data == 8'h90) begin
                                state   <= PRESCALE_SET;
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

                        default: begin
                            state <= IDLE;
                        end

                    endcase
                end

            end
        end
    end

    // Outputs
    assign uo_out  = pwm_out[7:0];
    assign uio_out = pwm_out[15:8];
    assign uio_oe  = 8'hFF;

    // Prevent unused warnings
    wire _unused = &{ena, uio_in, ui_in[7:4], timeout, count_bus[0], 1'b0};

endmodule

`default_nettype wire
