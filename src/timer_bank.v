`default_nettype none

module timer_bank (
    input  wire        clk,
    input  wire        rst_n,
    input  wire [7:0]  enable_bus,
    input  wire [7:0]  periodic_bus,
    input  wire [7:0]  reload_strobe,
    input  wire [127:0] reload_bus,
    output reg  [7:0]  timeout_pulse,
    output wire [127:0] count_bus
);

    reg [15:0] reload_reg [0:7];
    reg [15:0] count_reg  [0:7];
    reg        expired_reg [0:7];

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            timeout_pulse <= 8'd0;
            for (i = 0; i < 8; i = i + 1) begin
                reload_reg[i]  <= 16'd0;
                count_reg[i]   <= 16'd0;
                expired_reg[i] <= 1'b0;
            end
        end else begin
            timeout_pulse <= 8'd0;

            for (i = 0; i < 8; i = i + 1) begin
                if (reload_strobe[i]) begin
                    reload_reg[i]  <= reload_bus[i*16 +: 16];
                    count_reg[i]   <= reload_bus[i*16 +: 16];
                    expired_reg[i] <= 1'b0;
                end else if (enable_bus[i] && !expired_reg[i]) begin
                    if (count_reg[i] <= 16'd1) begin
                        timeout_pulse[i] <= 1'b1;

                        if (periodic_bus[i]) begin
                            count_reg[i] <= reload_reg[i];
                        end else begin
                            count_reg[i]   <= 16'd0;
                            expired_reg[i]  <= 1'b1;
                        end
                    end else begin
                        count_reg[i] <= count_reg[i] - 1'b1;
                    end
                end
            end
        end
    end

    assign count_bus = {
        count_reg[7], count_reg[6], count_reg[5], count_reg[4],
        count_reg[3], count_reg[2], count_reg[1], count_reg[0]
    };

endmodule

`default_nettype wire
