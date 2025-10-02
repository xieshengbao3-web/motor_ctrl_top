`timescale 1ns/1ps

module rx_icmp_header_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               ip_header_icmp_check_ok    ,
    output reg                          icmp_header_req_check_ok   ,
    output reg                          pc_icmp_req                ,
    output reg         [  15:0]         icmp_header_identifier     ,
    output reg         [  15:0]         icmp_header_sequence        
);
    
reg                    [   3:0]         cnt                        ;
reg                    [   7:0]         icmp_header_type_tmp       ;
reg                    [   7:0]         icmp_header_code_tmp       ;
reg                    [  15:0]         icmp_header_identifier_tmp ;
reg                    [  15:0]         icmp_header_sequence_tmp   ;

localparam                              U_DLY =1                   ;



always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 4'd0;
    else if((rx_dv==1'b1)&&(ip_header_icmp_check_ok==1'b1))
        if(cnt==4'hf)
        ;
        else
        cnt<= #U_DLY cnt+4'd1;
    else
    cnt<= #U_DLY 4'd0;
end


//icmp首部  type 8--req  0--reply
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_type_tmp<= #U_DLY 8'd0;
    else if((ip_header_icmp_check_ok)&&(cnt==4'd0))
    icmp_header_type_tmp<= #U_DLY rxd;
    else ;
end

//icmp首部  code 0
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_code_tmp<= #U_DLY 8'd0;
    else if((ip_header_icmp_check_ok)&&(cnt==4'd1))
    icmp_header_code_tmp<= #U_DLY rxd;
    else ;
end

//icmp 首部校验和 不校验

//icmp首部 identifier
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_identifier_tmp<= #U_DLY 16'd0;
    else if((ip_header_icmp_check_ok)&&(cnt>=4'd4)&&(cnt<=4'd5))
    icmp_header_identifier_tmp<= #U_DLY {icmp_header_identifier_tmp[7:0],rxd};
    else ;
end

//icmp首部 sequence
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_sequence_tmp<= #U_DLY 16'd0;
    else if((ip_header_icmp_check_ok)&&(cnt>=4'd6)&&(cnt<=4'd7))
    icmp_header_sequence_tmp<= #U_DLY {icmp_header_sequence_tmp[7:0],rxd};
    else ;
end

//校验 icmp请求
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_req_check_ok<= #U_DLY 1'd0;
    else if(rx_dv==1'b0)
    icmp_header_req_check_ok<= #U_DLY 1'd0;
    else if((ip_header_icmp_check_ok)&&(cnt==4'd7)&&(icmp_header_type_tmp==8'd8)&&(icmp_header_code_tmp==8'd0))
    icmp_header_req_check_ok<= #U_DLY 1'd1;
    else ;
end

//pc icmp req
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    pc_icmp_req<= #U_DLY 1'b0;
    else if(icmp_header_req_check_ok&&(rx_dv==1'b0))
    pc_icmp_req<= #U_DLY 1'b1;
    else
    pc_icmp_req<= #U_DLY 1'b0;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_identifier<= #U_DLY 16'b0;
    else if(icmp_header_req_check_ok&&(rx_dv==1'b0))
    icmp_header_identifier<= #U_DLY icmp_header_identifier_tmp;
    else ;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_header_sequence<= #U_DLY 16'b0;
    else if(icmp_header_req_check_ok&&(rx_dv==1'b0))
    icmp_header_sequence<= #U_DLY icmp_header_sequence_tmp;
    else ;
end


endmodule