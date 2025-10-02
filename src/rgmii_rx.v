`timescale 1ns/1ps


module rgmii_rx(
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input                               rxc_bufio                  ,
    input              [   3:0]         pin_rgmii_rxd_xi           ,
    input                               pin_rgmii_rx_dv_xi         ,
    output reg         [   7:0]         rxd                        ,
    output reg                          rx_dv                      ,
    input                               rgmii_rx_dfx_clr           ,//dfx
    output reg         [  15:0]         rx_err_cnt_dfx             ,//dfx
    output reg                          rx_err_flag_dfx             //dfx

);

localparam                              U_DLY =1                   ;

wire                                    rgmii_rxc_bufio            ;
wire                                    rx_dv1                     ;
wire                                    rx_dv2                     ;
wire                   [   7:0]         rxd_tmp                    ;

reg                                     rgmii_rx_dfx_clr_1d        ;
reg                                     rgmii_rx_dfx_clr_2d        ;
reg                                     rgmii_rx_dfx_clr_3d        ;
reg                                     rgmii_rx_dfx_clr_pos       ;
reg                                     rx_err                     ;

IDDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE_PIPELINED"     ),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                   //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1                           (1'b0                      ),// Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2                           (1'b0                      ),// Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) IDDR_inst (
    .Q1                                (rx_dv1                    ),// 1-bit output for positive edge of clock
    .Q2                                (rx_dv2                    ),// 1-bit output for negative edge of clock
    .C                                 (rxc_bufio                 ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D                                 (pin_rgmii_rx_dv_xi        ),// 1-bit DDR data input
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

IDDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE_PIPELINED"     ),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                   //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1                           (1'b0                      ),// Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2                           (1'b0                      ),// Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) IDDR_inst0 (
    .Q1                                (rxd_tmp[0]                ),// 1-bit output for positive edge of clock
    .Q2                                (rxd_tmp[4]                ),// 1-bit output for negative edge of clock
    .C                                 (rxc_bufio                 ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D                                 (pin_rgmii_rxd_xi[0]       ),// 1-bit DDR data input
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

IDDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE_PIPELINED"     ),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                   //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1                           (1'b0                      ),// Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2                           (1'b0                      ),// Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) IDDR_inst1 (
    .Q1                                (rxd_tmp[1]                ),// 1-bit output for positive edge of clock
    .Q2                                (rxd_tmp[5]                ),// 1-bit output for negative edge of clock
    .C                                 (rxc_bufio                 ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D                                 (pin_rgmii_rxd_xi[1]       ),// 1-bit DDR data input
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

IDDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE_PIPELINED"     ),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                   //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1                           (1'b0                      ),// Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2                           (1'b0                      ),// Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) IDDR_inst2 (
    .Q1                                (rxd_tmp[2]                ),// 1-bit output for positive edge of clock
    .Q2                                (rxd_tmp[6]                ),// 1-bit output for negative edge of clock
    .C                                 (rxc_bufio                 ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D                                 (pin_rgmii_rxd_xi[2]       ),// 1-bit DDR data input
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

IDDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE_PIPELINED"     ),// "OPPOSITE_EDGE", "SAME_EDGE" 
                                   //    or "SAME_EDGE_PIPELINED" 
    .INIT_Q1                           (1'b0                      ),// Initial value of Q1: 1'b0 or 1'b1
    .INIT_Q2                           (1'b0                      ),// Initial value of Q2: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) IDDR_inst3 (
    .Q1                                (rxd_tmp[3]                ),// 1-bit output for positive edge of clock
    .Q2                                (rxd_tmp[7]                ),// 1-bit output for negative edge of clock
    .C                                 (rxc_bufio                 ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D                                 (pin_rgmii_rxd_xi[3]       ),// 1-bit DDR data input
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

always@(posedge clk_rxc ) begin
    rxd<= #U_DLY rxd_tmp;
    rx_dv<= #U_DLY  rx_dv1;
    rx_err<= #U_DLY rx_dv1^rx_dv2;
end



always@(posedge clk_rxc ) begin
    rgmii_rx_dfx_clr_1d<= #U_DLY rgmii_rx_dfx_clr;
    rgmii_rx_dfx_clr_2d<= #U_DLY rgmii_rx_dfx_clr_1d;
    rgmii_rx_dfx_clr_3d<= #U_DLY rgmii_rx_dfx_clr_2d;
    rgmii_rx_dfx_clr_pos<= #U_DLY (rgmii_rx_dfx_clr_2d&&(rgmii_rx_dfx_clr_3d==1'b0));
end

always@(posedge clk_rxc or posedge rst_rxc ) begin
    if(rst_rxc==1'b1)
    rx_err_cnt_dfx<= #U_DLY 16'd0;
    else if(rgmii_rx_dfx_clr_pos==1'b1)
    rx_err_cnt_dfx<= #U_DLY 16'd0;
    else if(rx_err==1'b1)
    rx_err_cnt_dfx<= #U_DLY rx_err_cnt_dfx+16'd1;
end

always@(posedge clk_rxc or posedge rst_rxc ) begin
    if(rst_rxc==1'b1)
    rx_err_flag_dfx<= #U_DLY 1'd0;
    else if(rgmii_rx_dfx_clr_pos==1'b1)
    rx_err_flag_dfx<= #U_DLY 1'd0;
    else if(rx_err==1'b1)
    rx_err_flag_dfx<= #U_DLY 1'd1;
end


endmodule
