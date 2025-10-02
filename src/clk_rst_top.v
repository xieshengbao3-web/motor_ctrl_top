`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: xieshengbao
// 
// Create Date: 17.07.2025 21:55:28
// Design Name: 
// Module Name: clk_rst_top
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////


module clk_rst_top (
    input                               pin_clk_xi                 ,//外部时钟
    input                               pin_rst_n_xi               ,//外部复位管脚
    input                               pin_rgmii_rxc_xi           ,//phy芯片125M时钟
    input                               rst_cfg                    ,//复位配置
    output                              clk0                       ,
    output                              clk1                       ,
    output                              clk2                       ,
    output                              clk_rxc                    ,
    output                              rxc_bufio                  ,
    output                              rst0                       ,
    output                              rst1                       ,
    output                              rst2                       ,
    output                              rst_rxc                    ,
    input                               pll_unlock_dfx_clr         ,
    output reg         [  15:0]         pll_unlock_cnt_dfx=16'b0   ,
    output reg                          pll_unlock_flag_dfx=1'b0

);

wire                                    rst_pll                    ;
wire                                    pll_locked                 ;
reg                                     pll_locked_1d              ;
reg                                     pll_locked_2d              ;
reg                                     pll_locked_3d              ;
reg                                     pll_locked_neg             ;
reg                                     pll_unlock_dfx_clr_1d      ;
reg                                     pll_unlock_dfx_clr_2d      ;
reg                                     pll_unlock_dfx_clr_3d      ;
reg                                     pll_unlock_dfx_clr_pos     ;
parameter                           time_delay_ctrl1 = 32'd500_000 ;
localparam                              U_DLY = 1                  ;

  IBUF  u_pin_clk_i (.I(pin_clk_xi), .O(clk_0_ibuf));

  BUFG u0_bufg (
    .I                                 (clk_0_ibuf                ),// 1-bit input: Clock input
    .O                                 (clk0                      ) // 1-bit output: Clock output
  );

  IBUF  u_rxc_ibuf (.I(pin_rgmii_rxc_xi), .O(rxc_ibuf));

  BUFIO u_rxc_bufio(.I(rxc_ibuf),        .O(rxc_bufio));            // 给 IDDR.C

  BUFG u1_bufg (
    .I                                 (rxc_ibuf                  ),// 1-bit input: Clock input
    .O                                 (clk_rxc                   ) // 1-bit output: Clock output
  );

  clk_wiz_0 u0_clk_mmcm (
    .clk_out1                          (clk1                      ),// output clk_out1
    .clk_out2                          (clk2                      ),// output clk_out2
    .reset                             (rst_pll                   ),// input reset
    .locked                            (pll_locked                ),// output locked
    .clk_in1                           (clk0                      ) // input clk_in1
  );

  rst_gen #(
    .time_delay_ctrl1                  (time_delay_ctrl1          )
  )u0_rst_gen (
    .clk0                              (clk0                      ),
    .pin_rst_n_xi                      (pin_rst_n_xi              ),
    .rst_cfg                           (rst_cfg                   ),
    .clk1                              (clk1                      ),
    .clk2                              (clk2                      ),
    .clk_rxc                           (clk_rxc                   ),
    .rst0                              (rst0                      ),
    .rst1                              (rst1                      ),
    .rst2                              (rst2                      ),
    .rst_rxc                           (rst_rxc                   ),
    .rst_pll                           (rst_pll                   )
  );

  /*
dfx
统计pll 失锁
*/

always @(posedge clk0) begin
    pll_unlock_dfx_clr_1d<= #U_DLY pll_unlock_dfx_clr;
    pll_unlock_dfx_clr_2d<= #U_DLY pll_unlock_dfx_clr_1d;
    pll_unlock_dfx_clr_3d<= #U_DLY pll_unlock_dfx_clr_2d;
    pll_unlock_dfx_clr_pos<= #U_DLY (pll_unlock_dfx_clr_2d&&(pll_unlock_dfx_clr_3d==1'b0));
end

always @(posedge clk0) begin
    pll_locked_1d<= #U_DLY pll_locked;
    pll_locked_2d<= #U_DLY pll_locked_1d;
    pll_locked_3d<= #U_DLY pll_locked_2d;
    pll_locked_neg<= #U_DLY (pll_locked_2d==1'b0&&(pll_locked_3d==1'b1));
end


always @(posedge clk0) begin
  if(pll_unlock_dfx_clr_pos==1'b1)
  pll_unlock_flag_dfx<= #U_DLY 1'b0;
  else if(pll_locked_neg==1'b1)
  pll_unlock_flag_dfx<= #U_DLY 1'b1;
  else ;
end

always @(posedge clk0) begin
  if(pll_unlock_dfx_clr_pos==1'b1)
  pll_unlock_cnt_dfx<= #U_DLY 16'd0;
  else if(pll_locked_neg==1'b1)
  pll_unlock_cnt_dfx<= #U_DLY pll_unlock_cnt_dfx+16'd1;
  else ;
end
endmodule
