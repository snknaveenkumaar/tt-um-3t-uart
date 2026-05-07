`default_nettype none

module uart_rx (
    input  wire clk,
    input  wire rst_n,
    input  wire rx,
    output reg [7:0] data,
    output reg valid
);

    parameter CLK_DIV = 434;

    localparam IDLE  = 2'd0;
    localparam START = 2'd1;
    localparam DATA  = 2'd2;
    localparam STOP  = 2'd3;

    reg [1:0] state;
    reg [15:0] clk_cnt;
    reg [2:0] bit_idx;
    reg [7:0] shift;

    reg rx_sync1, rx_sync2;

    always @(posedge clk) begin
        if (!rst_n) begin
            state   <= IDLE;
            clk_cnt <= 0;
            bit_idx <= 0;
            shift   <= 0;
            data    <= 0;
            valid   <= 0;
            rx_sync1 <= 1;
            rx_sync2 <= 1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
            valid <= 0;

            case (state)
                IDLE: begin
                    if (!rx_sync2) begin
                        state <= START;
                        clk_cnt <= CLK_DIV >> 1;
                    end
                end

                START: begin
                    if (clk_cnt == 0) begin
                        state <= DATA;
                        clk_cnt <= CLK_DIV;
                        bit_idx <= 0;
                    end else clk_cnt <= clk_cnt - 1;
                end

                DATA: begin
                    if (clk_cnt == 0) begin
                        shift[bit_idx] <= rx_sync2;
                        clk_cnt <= CLK_DIV;

                        if (bit_idx == 7)
                            state <= STOP;
                        else
                            bit_idx <= bit_idx + 1;
                    end else clk_cnt <= clk_cnt - 1;
                end

                STOP: begin
                    if (clk_cnt == 0) begin
                        data <= shift;
                        valid <= 1;
                        state <= IDLE;
                    end else clk_cnt <= clk_cnt - 1;
                end
            endcase
        end
    end

endmodule

`default_nettype wire
