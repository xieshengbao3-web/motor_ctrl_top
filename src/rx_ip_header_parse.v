`timescale 1ns/1ps

module rx_ip_header_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               eth_header_0800_check_ok   ,
    input              [  31:0]         pc_ip_addr                 ,
    output reg         [   7:0]         ip_header_version_length   ,
    output reg         [   7:0]         ip_header_service          ,
    output reg         [  15:0]         ip_header_total_length     ,
    output reg         [  15:0]         ip_header_identification   ,
    output reg         [  15:0]         ip_header_flag_fragoffset  ,
    output reg                          ip_header_udp_check_ok     ,
    output reg                          ip_header_icmp_check_ok    ,
    output reg         [  31:0]         ip_header_src_ip_addr       
);
    
reg                    [   4:0]         cnt                        ;

reg                    [   7:0]         ip_header_protocal_tmp     ;

reg                    [  23:0]         ip_header_des_ip_addr_tmp  ;

reg                                     ip_header_src_ip_addr_check_ok;


localparam                              U_DLY =1                   ;
parameter                           FPGA_IP_ADDR  = {8'd192,8'd168,8'd1,8'd10};

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 5'd0;
    else if((rx_dv==1'b1)&&(eth_header_0800_check_ok==1'b1))
        if(cnt==5'h1f)
        ;
        else 
        cnt<= #U_DLY cnt+5'd1;
    else 
    cnt<= #U_DLY 5'd0;
end


//ip首部  版本号 首部长度
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_version_length<= #U_DLY 8'd0;
    else if((eth_header_0800_check_ok==1'b1)&&(cnt==5'd0))
    ip_header_version_length<= #U_DLY rxd;
    else ;
end

//ip首部  服务类型
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_service<= #U_DLY 8'd0;
    else if((eth_header_0800_check_ok==1'b1)&&(cnt==5'd1))
    ip_header_service<= #U_DLY rxd;
    else ;
end

//ip首部 总长度，单位字节，包含ip首部20字节+udp/icmp首部8字节+udp/icmp数据
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_total_length<= #U_DLY 16'd0;
    else if((cnt<=5'd3)&&(cnt>=5'd2))
    ip_header_total_length<= #U_DLY {ip_header_total_length[7:0],rxd};
    else ;
end

//ip首部 ip_header_identification
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_identification<=#U_DLY 16'b0;
    else if((cnt<=5'd5)&&(cnt>=5'd4))
    ip_header_identification<= #U_DLY {ip_header_identification[7:0],rxd};
    else ;
end

//ip首部 ip_header_flag_fragoffset
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_flag_fragoffset<=#U_DLY 16'b0;
    else if((cnt<=5'd7)&&(cnt>=5'd6))
    ip_header_flag_fragoffset<= #U_DLY {ip_header_flag_fragoffset[7:0],rxd};
    else ;
end

//ip首部 ip_header_protocal_tmp
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_protocal_tmp<=#U_DLY 16'b0;
    else if(cnt==5'd9)
    ip_header_protocal_tmp<= #U_DLY rxd;
    else ;
end

//ip首部 ip_header_src_ip_addr
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_src_ip_addr<=#U_DLY 32'b0;
    else if((cnt<=5'd15)&&(cnt>=5'd12))
    ip_header_src_ip_addr<= #U_DLY {ip_header_src_ip_addr[23:0],rxd};
    else ;
end

// 校验pc ip地址
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_src_ip_addr_check_ok<= #U_DLY 1'b0;
    else if(rx_dv==1'b0)
    ip_header_src_ip_addr_check_ok<= #U_DLY 1'b0;
    else if((cnt==5'd16)&&(ip_header_src_ip_addr==pc_ip_addr))
    ip_header_src_ip_addr_check_ok<= #U_DLY 1'b1;
    else ;
end


//ip首部 ip_header_des_ip_addr_tmp
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_des_ip_addr_tmp<=#U_DLY 24'b0;
    else if((cnt<=5'd18)&&(cnt>=5'd16))
    ip_header_des_ip_addr_tmp<= #U_DLY {ip_header_des_ip_addr_tmp[15:0],rxd};
    else ;
end

//校验udp协议格式
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_udp_check_ok<=#U_DLY 1'b0;
    else if(rx_dv==1'b0)
    ip_header_udp_check_ok<=#U_DLY 1'b0;
    else if((cnt==5'd19)&&(ip_header_version_length==8'h45)&&(ip_header_protocal_tmp==8'h11)&&(ip_header_src_ip_addr_check_ok)&&(ip_header_des_ip_addr_tmp==FPGA_IP_ADDR[31:8])&&(rxd==FPGA_IP_ADDR[7:0]))
    ip_header_udp_check_ok<=#U_DLY 1'b1;
    else ;
end

//校验icmp协议格式 icmp不校验ip首部中的源ip地址
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    ip_header_icmp_check_ok<=#U_DLY 1'b0;
    else if(rx_dv==1'b0)
    ip_header_icmp_check_ok<=#U_DLY 1'b0;
    else if((cnt==5'd19)&&(ip_header_version_length==8'h45)&&(ip_header_protocal_tmp==8'h01)&&(ip_header_des_ip_addr_tmp==FPGA_IP_ADDR[31:8])&&(rxd==FPGA_IP_ADDR[7:0]))
    ip_header_icmp_check_ok<=#U_DLY 1'b1;
    else ;
end


endmodule