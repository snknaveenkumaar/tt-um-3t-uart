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

    wire rx           = ui_in[0];
    wire cmd_enable   = ui_in[1];
    wire seq_enable   = ui_in[2];
    wire clear        = ui_in[3];
    wire [2:0] bank_sel = ui_in[6:4];
    wire debug_page   = ui_in[7];

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

    reg [7:0]  phase;
    reg [15:0] lfsr;
    reg [7:0]  pattern;
    reg [7:0]  alu_a;
    reg [7:0]  alu_b;

    wire [7:0] alu_add = alu_a + alu_b;
    wire [7:0] alu_mul_lo = (alu_a * alu_b)[7:0];

    reg [2:0] state;
    reg [4:0] idx;

    localparam ST_IDLE      = 3'd0;
    localparam ST_SET_PWM   = 3'd1;
    localparam ST_SET_PRES  = 3'd2;
    localparam ST_SET_ALUA  = 3'd3;
    localparam ST_SET_ALUB  = 3'd4;
    localparam ST_SET_PHASE = 3'd5;
    localparam ST_SET_LFSR  = 3'd6;

    function [7:0] select_bank8;
        input [31:0] bus;
        input [1:0] sel;
        begin
            case (sel)
                2'd0: select_bank8 = bus[7:0];
                2'd1: select_bank8 = bus[15:8];
                2'd2: select_bank8 = bus[23:16];
                2'd3: select_bank8 = bus[31:24];
                default: select_bank8 = 8'd0;
            endcase
        end
    endfunction

    function [7:0] lut_value;
        input [4:0] n;
        begin
            case (n)
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

    wire [7:0] status_page = {seq_enable, debug_page, bank_sel, phase[2:0]};

    always @(posedge clk) begin
        if (!rst_n) begin
            duty_bus <= 256'd0;
            prescale <= 8'd0;
            phase    <= 8'd0;
            lfsr     <= 16'h1ACE;
            pattern  <= 8'd0;
            alu_a    <= 8'd0;
            alu_b    <= 8'd0;
            state    <= ST_IDLE;
            idx      <= 5'd0;
        end else begin
            if (clear) begin
                duty_bus <= 256'd0;
                prescale <= 8'd0;
                phase    <= 8'd0;
                lfsr     <= 16'h1ACE;
                pattern  <= 8'd0;
                alu_a    <= 8'd0;
                alu_b    <= 8'd0;
                state    <= ST_IDLE;
                idx      <= 5'd0;
            end else begin
                if (rx_valid && cmd_enable) begin
                    case (state)
                        ST_IDLE: begin
                            case (rx_data[7:6])
                                2'b10: begin
                                    idx   <= rx_data[4:0];
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
                            if (idx < 5'd32)
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
                    phase   <= phase + 8'd1;
                    lfsr    <= {lfsr[14:0], lfsr[15] ^ lfsr[13]};
                    pattern <= {pattern[6:0], pattern[7] ^ lfsr[0]};
                end

                duty_bus[24*8 +: 8] <= phase;
                duty_bus[25*8 +: 8] <= lfsr[7:0];
                duty_bus[26*8 +: 8] <= lfsr[15:8];
                duty_bus[27*8 +: 8] <= pattern;
                duty_bus[28*8 +: 8] <= alu_add;
                duty_bus[29*8 +: 8] <= alu_mul_lo;
                duty_bus[30*8 +: 8] <= status_page;
                duty_bus[31*8 +: 8] <= lut_value(phase[4:0]);
            end
        end
    end

    assign uo_out  = select_bank8(pwm_out, bank_sel[1:0]);
    assign uio_out = debug_page ? status_page : select_bank8(pwm_out, bank_sel[1:0] + 2'd1);
    assign uio_oe  = 8'hFF;

    wire _unused = &{ena, uio_in, 1'b1};

endmodule

`default_nettype wire
