`timescale 1ns/1ps

module scp0_comm (
    input                               clk_rxc                     ,
    input                               rst_rxc                    ,
    input                               wr_en_scp0                 ,
    input                               rd_en_scp0                 ,
    input              [  11:0]         addr                       ,
    input              [  15:0]         wr_data                    ,
    output reg         [  15:0]         mux_data_out0              ,
    output reg                          rd_start0                  ,
    output reg                          rst_cfg                    ,
    output reg                          rgmii_rx_dfx_clr           ,
    input                               rx_err_flag_dfx            ,
    input              [  15:0]         rx_err_cnt_dfx             ,
    output reg                          pll_unlock_dfx_clr         ,
    input              [  15:0]         pll_unlock_cnt_dfx         ,
    input                               pll_unlock_flag_dfx        ,
    output reg                          sam_start0                   
);

localparam                              U_DLY= 1'b1                ;

    parameter                           YEAR    = 16'h2024         ;
    parameter                           MONTH   = 16'h0012         ;
    parameter                           DATE    = 16'h0006         ;
    parameter                           VERSION = 16'h0000         ;
    parameter                           BATCH   = 16'h0b01         ;
    parameter                           INTERNAL= 16'h0000         ;

reg                    [  15:0]         test0                      ;

always@(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin
        test0<= #U_DLY 16'd1234;
        rst_cfg<= #U_DLY 1'b0;
        rgmii_rx_dfx_clr<= #U_DLY 1'b0;
        pll_unlock_dfx_clr<= #U_DLY 1'b0;
        sam_start0<= #U_DLY 1'b0;
    end
    else if(wr_en_scp0==1'b1) begin
      case (addr)
      12'h0:test0<= #U_DLY wr_data;
      12'h7:rst_cfg<= #U_DLY wr_data[0];
      12'h8:rgmii_rx_dfx_clr<= #U_DLY wr_data[0];
      12'hb:pll_unlock_dfx_clr<= #U_DLY wr_data[0];
      12'h10:sam_start0<= #U_DLY wr_data[0];

      default ;
      endcase  
    end
end

always@(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
        mux_data_out0<= #U_DLY 16'd0;
    else if(rd_en_scp0==1'b1)
        case(addr)
        12'h0:mux_data_out0<= #U_DLY test0;
        12'h1:mux_data_out0<= #U_DLY YEAR;//RO
        12'h2:mux_data_out0<= #U_DLY MONTH;//RO
        12'h3:mux_data_out0<= #U_DLY DATE;//RO
        12'h4:mux_data_out0<= #U_DLY VERSION;//RO
        12'h5:mux_data_out0<= #U_DLY BATCH;//RO
        12'h6:mux_data_out0<= #U_DLY INTERNAL;//RO
        12'h7:mux_data_out0<= #U_DLY {15'h0,rst_cfg};
        12'h8:mux_data_out0<= #U_DLY {15'h0,rgmii_rx_dfx_clr};
        12'h9:mux_data_out0<= #U_DLY {15'h0,rx_err_flag_dfx};//RO
        12'ha:mux_data_out0<= #U_DLY rx_err_cnt_dfx;//RO
        12'hb:mux_data_out0<= #U_DLY {15'h0 ,pll_unlock_dfx_clr};
        12'hc:mux_data_out0<= #U_DLY {15'h0,pll_unlock_flag_dfx};//RO
        12'hd:mux_data_out0<= #U_DLY pll_unlock_cnt_dfx;//RO

        12'h10:mux_data_out0<= #U_DLY {15'd0,sam_start0};
        default :mux_data_out0<= #U_DLY 16'hdead;
        endcase
    else ;
end

always@(posedge clk_rxc) begin
    rd_start0<=#U_DLY rd_en_scp0;
end

    
endmodule