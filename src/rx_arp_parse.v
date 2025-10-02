`timescale 1ns/1ps

module rx_arp_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               eth_header_0806_check_ok   ,
    output reg                          pc_arp_req                 ,
    output reg         [  47:0]         arp_src_mac_addr           ,
    output reg         [  31:0]         arp_src_ip_addr              
);
    
reg                    [   7:0]         cnt                        ;
reg                    [  31:0]         arp_data_tmp1              ;
reg                    [  31:0]         arp_data_tmp2              ;
reg                                     arp_data_tmp1_check_ok     ;
reg                                     arp_data_tmp2_check_ok     ;
reg                    [  47:0]         arp_data_src_mac_addr      ;
reg                    [  31:0]         arp_data_src_ip_addr       ;
reg                    [  31:0]         arp_data_des_ip_addr       ;
reg                                     arp_data_des_ip_addr_check_ok;
reg                                     arp_data_req_check_ok      ;


parameter                           FPGA_IP_ADDR  = {8'd192,8'd168,8'd1,8'd10};
localparam                              U_DLY =1                   ;

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 8'd0;
    else if((rx_dv==1'b1)&&(eth_header_0806_check_ok==1'b1))
        if(cnt==8'hff)
        ;
        else 
        cnt<= #U_DLY cnt+8'd1;
    else 
    cnt<= #U_DLY 8'd0;
end


//arp 数据缓存
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_tmp1<= #U_DLY 32'd0;
    else if((eth_header_0806_check_ok==1'b1)&&(cnt<=8'd3))
    arp_data_tmp1<= #U_DLY {arp_data_tmp1[23:0],rxd};
    else ;
end

//arp 数据缓存
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_tmp2<= #U_DLY 32'd0;
    else if((cnt<=8'd7)&&(cnt>=8'd4))
    arp_data_tmp2<= #U_DLY {arp_data_tmp2[23:0],rxd};
    else ;
end

//校验协议格式
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_tmp1_check_ok<=#U_DLY 1'b0;
    else if(rx_dv==1'b0)
    arp_data_tmp1_check_ok<=#U_DLY 1'b0;
    else if((cnt==8'd10)&&(arp_data_tmp1==32'h0001_0800))
    arp_data_tmp1_check_ok<=#U_DLY 1'b1;
    else ;
end

//校验协议格式
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_tmp2_check_ok<=#U_DLY 1'b0;
    else if(rx_dv==1'b0)
    arp_data_tmp2_check_ok<=#U_DLY 1'b0;
    else if((cnt==8'd10)&&(arp_data_tmp2==32'h0604_0001))
    arp_data_tmp2_check_ok<=#U_DLY 1'b1;
    else ;
end

//arp 数据中的源mac
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_src_mac_addr<= #U_DLY 48'd0;
    else if((cnt<=8'd13)&&(cnt>=8'd8))
    arp_data_src_mac_addr<= #U_DLY {arp_data_src_mac_addr[39:0],rxd};
    else ;
end

//arp 数据中的源ip
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_src_ip_addr<= #U_DLY 32'd0;
    else if((cnt<=8'd17)&&(cnt>=8'd14))
    arp_data_src_ip_addr<= #U_DLY {arp_data_src_ip_addr[23:0],rxd};
    else ;
end

//arp 数据中的目的ip
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    arp_data_des_ip_addr<= #U_DLY 32'd0;
    else if(cnt>=6'd24&&(cnt<=6'd27))
    arp_data_des_ip_addr<= #U_DLY {arp_data_des_ip_addr[23:0],rxd};
    else ;
end

//校验arp 数据中的目的ip是否为fpga ip addr
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_des_ip_addr_check_ok<=#U_DLY 1'b0;
    else if(rx_dv==1'b0)
    arp_data_des_ip_addr_check_ok<=#U_DLY 1'b0;
    else if((cnt==8'd28)&&(arp_data_des_ip_addr==FPGA_IP_ADDR))
    arp_data_des_ip_addr_check_ok<=#U_DLY 1'b1;
    else ;
end


//arp所有校验通过
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    arp_data_req_check_ok<=#U_DLY 1'b0;
    else if(rx_dv==1'b0)
    arp_data_req_check_ok<=#U_DLY 1'b0;
    else if((cnt==8'd29)&&(arp_data_des_ip_addr_check_ok)&&(arp_data_tmp1_check_ok)&&(arp_data_tmp2_check_ok))
    arp_data_req_check_ok<=#U_DLY 1'b1;
    else ;
end

//主机请求arp
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    pc_arp_req<= #U_DLY 1'b0;
    else if(rx_dv==1'b0&&(arp_data_req_check_ok==1'b1))
    pc_arp_req<= #U_DLY 1'b1;
    else 
    pc_arp_req<= #U_DLY 1'b0;
end

//对主机mac 和ip进行获取
always @(posedge clk_rxc) begin
    if((arp_data_req_check_ok==1'b1)&&(cnt==8'd30)) begin
      arp_src_mac_addr<=#U_DLY arp_data_src_mac_addr;
      arp_src_ip_addr<= #U_DLY arp_data_src_ip_addr;
    end
    else;
end

endmodule