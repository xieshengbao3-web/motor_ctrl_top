`timescale 1ns/1ps

module rx_eth_header_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               preamble_sfd_check_ok      ,
    input              [  47:0]         pc_mac_addr                ,
    output reg         [  47:0]         eth_header_src_mac_addr    ,
    output reg                          eth_header_0806_check_ok   ,//arp帧
    output reg                          eth_header_0800_check_ok    //udp icmp
);


reg                    [   3:0]         cnt                        ;
reg                    [   7:0]         rxd_1d                     ;
reg                    [  47:0]         eth_header_des_mac_addr    ;




localparam                              U_DLY =1                   ;
parameter                           FPGA_MAC_ADDR = 48'h00_0A_35_00_01_02;




always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 4'd0;
    else if((rx_dv==1'b1)&&(preamble_sfd_check_ok==1'b1))
        if(cnt==4'hf)
        ;
        else
        cnt<= #U_DLY cnt+4'd1;
    else
    cnt<= #U_DLY 4'd0;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    eth_header_des_mac_addr<= #U_DLY 48'd0;
    else if(preamble_sfd_check_ok==1'b1)
        if(cnt<=4'd5)
        eth_header_des_mac_addr<= #U_DLY {eth_header_des_mac_addr[39:0],rxd};
        else ;
    else ;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    eth_header_src_mac_addr<= #U_DLY 48'd0;
    else if((cnt<=4'd11)&&(cnt>=4'd6))
        eth_header_src_mac_addr<= #U_DLY {eth_header_src_mac_addr[39:0],rxd};
    else ;
end

always @(posedge clk_rxc) begin
    rxd_1d<= #U_DLY rxd;
end

//arp 时只校验 目的mac地址是否正确
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    eth_header_0806_check_ok<= #U_DLY 1'b0;
    else if (rx_dv==1'b0)
    eth_header_0806_check_ok<= #U_DLY 1'b0;
    else if((cnt==4'd13) && ((eth_header_des_mac_addr==48'hff_ff_ff_ff_ff_ff)||(eth_header_des_mac_addr==FPGA_MAC_ADDR)) && (rxd_1d==8'h08) && (rxd==8'h06))
    eth_header_0806_check_ok<= #U_DLY 1'b1;
    else;
end

//udp 时 目的mac和源mac均校验是否正确
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    eth_header_0800_check_ok<= #U_DLY 1'b0;
    else if (rx_dv==1'b0)
    eth_header_0800_check_ok<= #U_DLY 1'b0;
    else if((cnt==4'd13) && (eth_header_des_mac_addr==FPGA_MAC_ADDR)&&(eth_header_src_mac_addr==pc_mac_addr) && (rxd_1d==8'h08) && (rxd==8'h00))
    eth_header_0800_check_ok<= #U_DLY 1'b1;
    else;
end



    

endmodule