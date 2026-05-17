// ============================================================
// 六步方波驱动（V/f + 占空限幅 + 缓升启动）
// 50 MHz 时钟，DRV8320 6PWM 模式
// 起始频率 0.5 Hz → 20 Hz，缓升 10 秒
// 占空最大 60%（PWM调制限幅）
// 可直接综合、上板使用
// ============================================================
module sixstep_vf_lut (
        input  wire clk_50m,
    input  wire rst_50m,
    output wire drv_ha, drv_la,
    output wire drv_hb, drv_lb,
    output wire drv_hc, drv_lc
);
    // ---------------- 参数 ----------------
    localparam integer F_CLK_HZ      = 50_000_000;
    localparam integer F_START_HZ    = 1;      // 启动频率 1Hz
    localparam integer F_END_HZ      = 5;     // 目标频率 20Hz
    localparam integer RAMP_TIME_MS  = 10_000; // 10秒缓升
    localparam integer DUTY_LIMIT_PCT= 40;     // 最大占空60%
    localparam integer F_PWM_HZ      = 20_000; // PWM调制频率20kHz

    // ---------------- 1Hz~20Hz 对应周期查表 ----------------
    // period = F_CLK_HZ / (freq * 6)
    reg [31:0] period_lut [1:20];
    initial begin
        period_lut[1]  = 50_000_000 / (1  * 6);  // ≈8.33e6
        period_lut[2]  = 50_000_000 / (2  * 6);
        period_lut[3]  = 50_000_000 / (3  * 6);
        period_lut[4]  = 50_000_000 / (4  * 6);
        period_lut[5]  = 50_000_000 / (5  * 6);
        period_lut[6]  = 50_000_000 / (6  * 6);
        period_lut[7]  = 50_000_000 / (7  * 6);
        period_lut[8]  = 50_000_000 / (8  * 6);
        period_lut[9]  = 50_000_000 / (9  * 6);
        period_lut[10] = 50_000_000 / (10 * 6);
        period_lut[11] = 50_000_000 / (11 * 6);
        period_lut[12] = 50_000_000 / (12 * 6);
        period_lut[13] = 50_000_000 / (13 * 6);
        period_lut[14] = 50_000_000 / (14 * 6);
        period_lut[15] = 50_000_000 / (15 * 6);
        period_lut[16] = 50_000_000 / (16 * 6);
        period_lut[17] = 50_000_000 / (17 * 6);
        period_lut[18] = 50_000_000 / (18 * 6);
        period_lut[19] = 50_000_000 / (19 * 6);
        period_lut[20] = 50_000_000 / (20 * 6);  // ≈416_666
    end

    // ---------------- 毫秒计数（10秒缓升） ----------------
    localparam integer MS_TICKS = F_CLK_HZ / 1000;
    reg [31:0] ms_cnt = 0;
    reg [31:0] ms_div = 0;

    always @(posedge clk_50m) begin
        if (rst_50m) begin
            ms_cnt <= 0;
            ms_div <= 0;
        end else if (ms_div == MS_TICKS - 1) begin
            ms_div <= 0;
            if (ms_cnt < RAMP_TIME_MS)
                ms_cnt <= ms_cnt + 1;
        end else begin
            ms_div <= ms_div + 1;
        end
    end

    // ---------------- 当前频率索引计算 ----------------
    // 每 500ms 提升一级：10000ms / 20级 = 500ms/Hz
    reg [5:0] freq_idx = 1;
    always @(posedge clk_50m) begin
        if (rst_50m)
            freq_idx <= 1;
        else if (ms_cnt < RAMP_TIME_MS)
            freq_idx <= 1 + (ms_cnt / 500);
        else
            freq_idx <= 20;
    end

    // ---------------- 六步换相定时器 ----------------
    reg [31:0] cnt = 0;
    reg [2:0]  step = 0;
    always @(posedge clk_50m) begin
        if (rst_50m) begin
            cnt  <= 0;
            step <= 0;
        end else if (cnt >= period_lut[freq_idx]) begin
            cnt  <= 0;
            step <= (step == 5) ? 0 : step + 1;
        end else begin
            cnt <= cnt + 1;
        end
    end

    // ---------------- PWM调制计数器（限占空） ----------------
    localparam integer PWM_TICKS = F_CLK_HZ / F_PWM_HZ; // 2500
    reg [11:0] pwm_cnt = 0;
    always @(posedge clk_50m)
        pwm_cnt <= (pwm_cnt == PWM_TICKS - 1) ? 0 : pwm_cnt + 1;

    // 生成PWM门控信号，占空比=60%
    wire pwm_gate = (pwm_cnt < (PWM_TICKS * DUTY_LIMIT_PCT / 100)) ? 1'b1 : 1'b0;

    // ---------------- 六步输出逻辑 + PWM限幅 ----------------
    reg ha_raw, la_raw, hb_raw, lb_raw, hc_raw, lc_raw;
    always @(*) begin
        {ha_raw, la_raw, hb_raw, lb_raw, hc_raw, lc_raw} = 6'b0;
        case (step)
            3'd0: begin ha_raw=1; la_raw=0; hb_raw=0; lb_raw=1; end // A+ B-
            3'd1: begin ha_raw=1; la_raw=0; hc_raw=0; lc_raw=1; end // A+ C-
            3'd2: begin hb_raw=1; lb_raw=0; hc_raw=0; lc_raw=1; end // B+ C-
            3'd3: begin hb_raw=1; lb_raw=0; ha_raw=0; la_raw=1; end // B+ A-
            3'd4: begin hc_raw=1; lc_raw=0; ha_raw=0; la_raw=1; end // C+ A-
            3'd5: begin hc_raw=1; lc_raw=0; hb_raw=0; lb_raw=1; end // C+ B-
        endcase
    end

    // PWM限幅输出
    assign drv_ha = ha_raw & pwm_gate;
    assign drv_la = la_raw & pwm_gate;
    assign drv_hb = hb_raw & pwm_gate;
    assign drv_lb = lb_raw & pwm_gate;
    assign drv_hc = hc_raw & pwm_gate;
    assign drv_lc = lc_raw & pwm_gate;

endmodule