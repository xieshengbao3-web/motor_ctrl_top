`timescale 1ns/1ps

module rx_icmp_data_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               icmp_header_req_check_ok   ,
    input              [  15:0]         ip_header_total_length     ,
    output reg         [   7:0]         icmp_data                  ,
    output reg                          icmp_data_vld               
);
    
reg                    [   6:0]         cnt                        ;
reg                    [   6:0]         icmp_data_length           ;

localparam                              U_DLY =1                   ;



always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 7'd0;
    else if((rx_dv==1'b1)&&(icmp_header_req_check_ok==1'b1))
        if(cnt==7'h7f)
        ;
        else
        cnt<= #U_DLY cnt+7'd1;
    else
    cnt<= #U_DLY 7'd0;
end


//判断icmp数据长度
always @(posedge clk_rxc) begin
    if((ip_header_total_length<=16'd46))
    icmp_data_length<= #U_DLY 7'd18;
    else 
    icmp_data_length<= #U_DLY ip_header_total_length[6:0]-7'd28;
end


always @(posedge clk_rxc) begin
    icmp_data<= #U_DLY rxd;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_data_vld<= #U_DLY 1'b0;
    else if(icmp_header_req_check_ok==1'b0)
    icmp_data_vld<= #U_DLY 1'b0;
    else if(cnt<icmp_data_length)
    icmp_data_vld<= #U_DLY 1'b1;
    else 
    icmp_data_vld<= #U_DLY 1'b0;
end



endmodule