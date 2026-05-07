`default_nettype none

module uart_rx (
    input  wire      clk,
    input  wire      rst_n,
    input  wire      rx,
    output reg [7:0] data,
    output reg       valid
);
    parameter CLK_DIV = 434; // 50 MHz / 115200 ≈ 434

    localparam S_IDLE  = 2'd0;
    localparam S_START = 2'd1;
    localparam S_DATA  = 2'd2;
    localparam S_STOP  = 2'd3;

    reg [1:0]  state;
    reg [15:0] clk_cnt;
    reg [2:0]  bit_idx;
    reg [7:0]  rx_shift;

    reg rx_sync1;
    reg rx_sync2;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state    <= S_IDLE;
            clk_cnt  <= 16'd0;
            bit_idx  <= 3'd0;
            rx_shift <= 8'd0;
            data     <= 8'd0;
            valid    <= 1'b0;
            rx_sync1  <= 1'b1;
            rx_sync2  <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            valid    <= 1'b0;

            case (state)
                S_IDLE: begin
                    if (rx_sync2 == 1'b0) begin
                        state   <= S_START;
                        clk_cnt <= (CLK_DIV >> 1);
                    end
                end

                S_START: begin
                    if (clk_cnt == 0) begin
                        if (rx_sync2 == 1'b0) begin
                            state   <= S_DATA;
                            clk_cnt <= CLK_DIV - 1;
                            bit_idx <= 3'd0;
                        end else begin
                            state <= S_IDLE;
                        end
                    end else begin
                        clk_cnt <= clk_cnt - 1'b1;
                    end
                end

                S_DATA: begin
                    if (clk_cnt == 0) begin
                        rx_shift[bit_idx] <= rx_sync2;
                        clk_cnt <= CLK_DIV - 1;

                        if (bit_idx == 3'd7) begin
                            state <= S_STOP;
                        end else begin
                            bit_idx <= bit_idx + 1'b1;
                        end
                    end else begin
                        clk_cnt <= clk_cnt - 1'b1;
                    end
                end

                S_STOP: begin
                    if (clk_cnt == 0) begin
                        data  <= rx_shift;
                        valid <= 1'b1;
                        state <= S_IDLE;
                    end else begin
                        clk_cnt <= clk_cnt - 1'b1;
                    end
                end

                default: begin
                    state <= S_IDLE;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
