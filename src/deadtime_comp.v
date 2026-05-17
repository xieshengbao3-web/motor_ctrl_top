// ============================================================
// 互补死区注入：边沿翻转时，先同时关断，等待 DEAD_CYCLES，再只打开目标一侧
// 可综合；in_hi/in_lo 不要求严格互补（内部自处理）
// ============================================================
module deadtime_comp #(
    parameter integer DEAD_CYCLES = 25  // 50MHz时 25 => 500ns
)(
    input  wire clk, rst,
    input  wire in_hi, in_lo,
    output reg  out_hi, out_lo
);
    reg in_hi_d, in_lo_d;
    always @(posedge clk) begin
        if (rst) begin in_hi_d <= 0; in_lo_d <= 0; end
        else begin in_hi_d <= in_hi; in_lo_d <= in_lo; end
    end

    wire hi_rise =  in_hi & ~in_hi_d;
    wire lo_rise =  in_lo & ~in_lo_d;
    // wire hi_fall = ~in_hi &  in_hi_d; // 如需用可保留
    // wire lo_fall = ~in_lo &  in_lo_d;

    reg [15:0] dt_cnt = 0;
    reg target_hi = 1'b0;
    reg [1:0] st;
    localparam IDLE=2'd0, BLANK=2'd1, TURNON=2'd2;

    always @(posedge clk) begin
        if (rst) begin
            st <= IDLE; dt_cnt <= 0; target_hi <= 1'b0;
            out_hi <= 1'b0; out_lo <= 1'b0;
        end else begin
            case (st)
                IDLE: begin
                    // 正常跟随，除非检测到需要从一侧切到另一侧（任一上升）
                    if (hi_rise && out_lo) begin
                        out_hi <= 1'b0; out_lo <= 1'b0;
                        target_hi <= 1'b1; dt_cnt <= 0; st <= BLANK;
                    end else if (lo_rise && out_hi) begin
                        out_hi <= 1'b0; out_lo <= 1'b0;
                        target_hi <= 1'b0; dt_cnt <= 0; st <= BLANK;
                    end else begin
                        // 无交叉切换时，直接跟随输入
                        out_hi <= in_hi;
                        out_lo <= in_lo;
                    end
                end
                BLANK: begin
                    if (dt_cnt >= DEAD_CYCLES) st <= TURNON;
                    else dt_cnt <= dt_cnt + 1;
                end
                TURNON: begin
                    if (target_hi) begin out_hi <= 1'b1; out_lo <= 1'b0; end
                    else              begin out_hi <= 1'b0; out_lo <= 1'b1; end
                    st <= IDLE;
                end
            endcase
        end
    end
endmodule