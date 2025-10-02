`timescale 1ns/1ps

module sam_data0_buf(
    input                               clk0                       ,
    input                               rst0                       ,
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input                               sam_start0                 ,
    input                               data0_vld                  ,
    input              [  15:0]         data0_in                   ,
    output reg                          sam0_udp_trg_125m          ,
    input                               data0_rdout_en             ,
    output             [  15:0]         sam_data0                   

);

reg                                     sam_start0_1d              ;
reg                                     sam_start0_2d              ;
reg                                     sam_start0_3d              ;
reg                                     sam_start0_pos             ;
reg                                     sam_en0_sync               ;

reg                    [   9:0]         addra                      ;
reg                    [   8:0]         addrb                      ;

reg                                     udp_trg_50m                ;
reg                                     udp_trg_125m_1d            ;
reg                                     udp_trg_125m_2d            ;
reg                                     udp_trg_125m_3d            ;
reg                                     ping_pong_sel_125m_1d      ;
reg                                     ping_pong_sel_125m_2d      ;
reg                                     ping_pong_sel_125m_3d      ;
reg                                     div_rd                     ;

localparam                              U_DLY =1                   ;

always@(posedge clk0) begin
sam_start0_1d<= #U_DLY sam_start0;
sam_start0_2d<= #U_DLY sam_start0_1d;
sam_start0_3d<= #U_DLY sam_start0_2d;
end

always@(posedge clk0 or posedge rst0) begin
if(rst0==1'b1)
sam_start0_pos<=#U_DLY 1'b0;
else if(sam_start0_2d==1'b1&&(sam_start0_3d==1'b0))
sam_start0_pos<=#U_DLY 1'b1;
else
sam_start0_pos<=#U_DLY 1'b0;
end

always@(posedge clk0 or posedge rst0) begin
if(rst0==1'b1)
sam_en0_sync<=#U_DLY 1'b0;
else if(sam_start0_pos==1'b1)
sam_en0_sync<=#U_DLY 1'b1;
else if((addra==10'd1023)&&(data0_vld==1'b1)&&(sam_start0_3d==1'b0))
sam_en0_sync<=#U_DLY 1'b0;
else ;
end

always@(posedge clk0 or posedge rst0) begin
if(rst0==1'b1)
addra<=#U_DLY 10'd0;
else if(sam_en0_sync==1'b1&&(data0_vld==1'b1))
addra<=#U_DLY addra+10'd1;
else if(sam_en0_sync==1'b0)
addra<=#U_DLY 10'd0;
end

always@(posedge clk0 or posedge rst0) begin
if(rst0==1'b1)
udp_trg_50m<=#U_DLY 1'b0;
else if(((addra==10'd511)||(addra==10'd1023))&&(data0_vld==1'b1))
udp_trg_50m<= #U_DLY 1'b1;
else
udp_trg_50m<=#U_DLY 1'b0;
end

always@(posedge clk_rxc or posedge rst_rxc) begin
if(rst_rxc==1'b1) begin
udp_trg_125m_1d<=#U_DLY 1'b0;
udp_trg_125m_2d<=#U_DLY 1'b0;
udp_trg_125m_3d<=#U_DLY 1'b0;
sam0_udp_trg_125m<=#U_DLY 1'b0;
end
else begin
  udp_trg_125m_1d<=#U_DLY udp_trg_50m;
  udp_trg_125m_2d<=#U_DLY udp_trg_125m_1d;
  udp_trg_125m_3d<=#U_DLY udp_trg_125m_2d;
  sam0_udp_trg_125m<= #U_DLY ((udp_trg_125m_2d==1'b1)&&(udp_trg_125m_3d==1'b0));
end
end

always@(posedge clk_rxc or posedge rst_rxc) begin
if(rst_rxc==1'b1)
div_rd<= #U_DLY 1'b0;
else if(data0_rdout_en==1'b1)
div_rd<=#U_DLY ~div_rd;
else ;
end


always@(posedge clk_rxc or posedge rst_rxc) begin
if(rst_rxc==1'b1)
addrb<= #U_DLY 9'd0;
else if(data0_rdout_en==1'b1)
    if(div_rd==1'b1)
    addrb<= #U_DLY addrb+9'd1;
    else ;
else
addrb<= #U_DLY 9'd0;
end

always@(posedge clk_rxc) begin
ping_pong_sel_125m_1d<=#U_DLY addra[9];
ping_pong_sel_125m_2d<=#U_DLY ping_pong_sel_125m_1d;
ping_pong_sel_125m_3d<=#U_DLY ping_pong_sel_125m_2d;
end




blk_mem_gen_0 u0_blk_mem_instance (
    .clka                              (clk0                      ),// input wire clka
    .wea                               (data0_vld&&sam_en0_sync    ),// input wire [0 : 0] wea
    .addra                             (addra                     ),// input wire [9 : 0] addra
    .dina                              (data0_in                  ),// input wire [15 : 0] dina
    .clkb                              (clk_rxc                   ),// input wire clkb
    .addrb                             ({~ping_pong_sel_125m_3d,addrb}),// input wire [9 : 0] addrb
    .doutb                             (sam_data0                 ) // output wire [15 : 0] doutb
);

endmodule