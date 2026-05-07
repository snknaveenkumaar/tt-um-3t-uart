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

    wire rx            = ui_in[0];
    wire cmd_enable    = ui_in[1];
    wire seq_enable    = ui_in[2];
    wire clear         = ui_in[3];
    wire [2:0] bank_sel = ui_in[6:4];
    wire debug_page    = ui_in[7];

    wire [2:0] bank_next = bank_sel + 3'd1;

    wire [7:0] rx_data;
    wire       rx_valid;

    uart_rx u_rx (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .data(rx_data),
        .valid(rx_valid)
    );

    reg  [511:0] duty_bus;
    reg  [7:0]   prescale;
    wire [63:0]  pwm_out;

    pwm_bank u_pwm (
        .clk(clk),
        .rst_n(rst_n),
        .prescale_div(prescale),
        .duty_bus(duty_bus),
        .pwm_out(pwm_out)
    );

    reg [7:0]  phase;
    reg [15:0] lfsr;
    reg [7:0]  pattern;
    reg [7:0]  alu_a;
    reg [7:0]  alu_b;

    wire [7:0] alu_add = alu_a + alu_b;
    wire [15:0] alu_mul_full = alu_a * alu_b;

    wire [7:0] aux_mix = uio_in ^ {8{debug_page}};

    reg [2:0] state;
    reg [5:0] idx;

    localparam ST_IDLE      = 3'd0;
    localparam ST_SET_PWM   = 3'd1;
    localparam ST_SET_PRES  = 3'd2;
    localparam ST_SET_ALUA  = 3'd3;
    localparam ST_SET_ALUB  = 3'd4;
    localparam ST_SET_PHASE = 3'd5;
    localparam ST_SET_LFSR  = 3'd6;

    function [7:0] select_bank8;
        input [63:0] bus;
        input [2:0] sel;
        begin
            case (sel)
                3'd0: select_bank8 = bus[7:0];
                3'd1: select_bank8 = bus[15:8];
                3'd2: select_bank8 = bus[23:16];
                3'd3: select_bank8 = bus[31:24];
                3'd4: select_bank8 = bus[39:32];
                3'd5: select_bank8 = bus[47:40];
                3'd6: select_bank8 = bus[55:48];
                3'd7: select_bank8 = bus[63:56];
                default: select_bank8 = 8'd0;
            endcase
        end
    endfunction

    wire [7:0] status_page = {seq_enable, debug_page, bank_sel, phase[2:0]};

    always @(posedge clk) begin
        if (!rst_n) begin
            duty_bus <= 512'd0;
            prescale <= 8'd0;
            phase    <= 8'd0;
            lfsr     <= 16'h1ACE;
            pattern  <= 8'd0;
            alu_a    <= 8'd0;
            alu_b    <= 8'd0;
            idx      <= 6'd0;
            state    <= ST_IDLE;
        end else begin
            if (clear) begin
                duty_bus <= 512'd0;
                prescale <= 8'd0;
                phase    <= 8'd0;
                lfsr     <= 16'h1ACE;
                pattern  <= 8'd0;
                alu_a    <= 8'd0;
                alu_b    <= 8'd0;
                idx      <= 6'd0;
                state    <= ST_IDLE;
            end else begin
                if (rx_valid && cmd_enable) begin
                    case (state)
                        ST_IDLE: begin
                            case (rx_data[7:6])
                                2'b10: begin
                                    idx   <= rx_data[5:0];
                                    state <= ST_SET_PWM;
                                end

                                2'b11: begin
                                    case (rx_data[5:0])
                                        6'd0: state <= ST_SET_PRES;
                                        6'd1: state <= ST_SET_ALUA;
                                        6'd2: state <= ST_SET_ALUB;
                                        6'd3: state <= ST_SET_PHASE;
                                        6'd4: state <= ST_SET_LFSR;
                                        default: state <= ST_IDLE;
                                    endcase
                                end

                                default: begin
                                    state <= ST_IDLE;
                                end
                            endcase
                        end

                        ST_SET_PWM: begin
                            duty_bus[idx*8 +: 8] <= rx_data;
                            state <= ST_IDLE;
                        end

                        ST_SET_PRES: begin
                            prescale <= rx_data;
                            state <= ST_IDLE;
                        end

                        ST_SET_ALUA: begin
                            alu_a <= rx_data;
                            state <= ST_IDLE;
                        end

                        ST_SET_ALUB: begin
                            alu_b <= rx_data;
                            state <= ST_IDLE;
                        end

                        ST_SET_PHASE: begin
                            phase <= rx_data;
                            state <= ST_IDLE;
                        end

                        ST_SET_LFSR: begin
                            lfsr <= {rx_data, 8'hA5};
                            state <= ST_IDLE;
                        end

                        default: begin
                            state <= ST_IDLE;
                        end
                    endcase
                end

                if (seq_enable) begin
                    phase   <= phase + 8'd1 + {7'd0, aux_mix[0]};
                    lfsr    <= {lfsr[14:0], lfsr[15] ^ lfsr[13] ^ aux_mix[0] ^ debug_page};
                    pattern <= {pattern[6:0], pattern[7] ^ aux_mix[0]};
                end

                // High-area internal channels reserved for live modulation
                duty_bus[56*8 +: 8] <= phase;
                duty_bus[57*8 +: 8] <= lfsr[7:0];
                duty_bus[58*8 +: 8] <= lfsr[15:8];
                duty_bus[59*8 +: 8] <= alu_add;
                duty_bus[60*8 +: 8] <= alu_mul_full[7:0];
                duty_bus[61*8 +: 8] <= alu_mul_full[15:8];
                duty_bus[62*8 +: 8] <= pattern;
                duty_bus[63*8 +: 8] <= aux_mix;
            end
        end
    end

    assign uo_out = select_bank8(pwm_out, bank_sel);

    assign uio_out = debug_page ? status_page : select_bank8(pwm_out, bank_next);

    assign uio_oe = 8'hFF;

endmodule

`default_nettype wire
