`timescale 1ns/1ps

module rx_udp_header_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               ip_header_udp_check_ok     ,
    output reg         [  15:0]         pc_port_addr               ,
    output reg         [  15:0]         udp_data_length            ,
    output reg                          udp_header_check_ok
);

reg                    [   3:0]         cnt                        ;
reg                    [  15:0]         des_port_tmp               ;
reg                    [  15:0]         src_port_tmp               ;




localparam                              U_DLY =1               ;
parameter                           FPGA_PORT = 16'd21105      ;


always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 4'd0;
    else if((rx_dv==1'b1)&&(ip_header_udp_check_ok==1'b1))
        if(cnt==4'hf)
        ;
        else 
        cnt<= #U_DLY cnt+4'd1;
    else 
    cnt<= #U_DLY 4'd0;
end


//udp首部  源端口号
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    src_port_tmp<= #U_DLY 16'd0;
    else if((ip_header_udp_check_ok)&&(cnt<=4'd1))
    src_port_tmp<= #U_DLY {src_port_tmp[7:0],rxd};
    else ;
end

//udp首部  目的端口号
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    des_port_tmp<= #U_DLY 16'd0;
    else if((cnt>=4'd2)&&(cnt<=4'd3))
    des_port_tmp<= #U_DLY {des_port_tmp[7:0],rxd};
    else ;
end

//udp首部  udp数据长度
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    udp_data_length<= #U_DLY 16'd0;
    else if((cnt>=4'd4)&&(cnt<=4'd5))
    udp_data_length<= #U_DLY {udp_data_length[7:0],rxd};
    else ;
end

//udp首部  udp校验和 不校验


always @(posedge clk_rxc) begin
  if((cnt==4'd7)&&(des_port_tmp==FPGA_PORT))
  pc_port_addr<=#U_DLY src_port_tmp;
  else ;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    udp_header_check_ok<= #U_DLY 1'd0;
    else if(rx_dv==1'b0)
    udp_header_check_ok<= #U_DLY 1'd0;
    else if((cnt==4'd7)&&(des_port_tmp==FPGA_PORT))
    udp_header_check_ok<= #U_DLY 1'd1;
    else ;
end




endmodule