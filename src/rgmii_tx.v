`timescale 1ns/1ps

module rgmii_tx(
    //GMII发送端口
    input                               txc                        ,//GMII发送时钟    
    input                               tx_en                      ,//GMII输出数据有效信号
    input              [   7:0]         txd                        ,//GMII输出数据        
    output                              pin_rgmii_txc_xo           ,//RGMII发送数据时钟    
    output                              pin_rgmii_tx_en_xo         ,//RGMII输出数据有效信号
    output             [   3:0]         pin_rgmii_txd_xo            //RGMII输出数据     
    );

//*****************************************************
//**                    main code
//*****************************************************

// assign rgmii_txc = gmii_tx_clk;

ODDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE"               ),// "OPPOSITE_EDGE" or "SAME_EDGE" 
    .INIT                              (1'b0                      ),// Initial value of Q: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) ODDR_inst0 (
    .Q                                 (pin_rgmii_txc_xo          ),// 1-bit DDR output
    .C                                 (txc                       ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D1                                (1'b1                      ),// 1-bit data input (positive edge)
    .D2                                (1'b0                      ),// 1-bit data input (negative edge)
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

//输出双沿采样寄存器 (rgmii_tx_en)
ODDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE"               ),// "OPPOSITE_EDGE" or "SAME_EDGE" 
    .INIT                              (1'b0                      ),// Initial value of Q: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
) ODDR_inst1 (
    .Q                                 (pin_rgmii_tx_en_xo        ),// 1-bit DDR output
    .C                                 (txc                       ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D1                                (tx_en                     ),// 1-bit data input (positive edge)
    .D2                                (tx_en                     ),// 1-bit data input (negative edge)
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
);

genvar i;
generate for (i=0; i<4; i=i+1)
    begin : txdata_bus
        //输出双沿采样寄存器 (rgmii_txd)
        ODDR #(
    .DDR_CLK_EDGE                      ("SAME_EDGE"               ),// "OPPOSITE_EDGE" or "SAME_EDGE" 
    .INIT                              (1'b0                      ),// Initial value of Q: 1'b0 or 1'b1
    .SRTYPE                            ("SYNC"                    ) // Set/Reset type: "SYNC" or "ASYNC" 
        ) ODDR_inst (
    .Q                                 (pin_rgmii_txd_xo[i]       ),// 1-bit DDR output
    .C                                 (txc                       ),// 1-bit clock input
    .CE                                (1'b1                      ),// 1-bit clock enable input
    .D1                                (txd[i]                    ),// 1-bit data input (positive edge)
    .D2                                (txd[4+i]                  ),// 1-bit data input (negative edge)
    .R                                 (1'b0                      ),// 1-bit reset
    .S                                 (1'b0                      ) // 1-bit set
        );
    end
endgenerate

endmodule