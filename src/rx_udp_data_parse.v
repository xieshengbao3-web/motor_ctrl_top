`timescale 1ns/1ps

module rx_udp_data_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    input                               udp_header_check_ok        ,
    input              [  15:0]         udp_data_length            ,
    output reg         [  11:0]         addr                       ,
    output reg         [  15:0]         wr_data                    ,
    output reg                          wr_en_scp0                 ,
    output reg                          rd_en_scp0                  
);
    
reg                    [   3:0]         cnt                        ;
reg                                     udp_cmd                    ;
reg                    [  15:0]         addr_tmp                   ;
reg                    [  15:0]         wr_data_tmp                ;
reg                                     udp_data_length_valid      ;


localparam                              U_DLY =1                   ;



always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 4'd0;
    else if((rx_dv==1'b1)&&(udp_header_check_ok==1'b1))
        if(cnt==4'hf)
        ;
        else
        cnt<= #U_DLY cnt+4'd1;
    else
    cnt<= #U_DLY 4'd0;
end


//udp数据第一个字节 0x00表示读，0x01表示写
always @(posedge clk_rxc) begin
    if((udp_header_check_ok==1'b1)&&(cnt==4'd0))
    udp_cmd<= #U_DLY rxd;
    else ;
end


//校验udp数据长度是否正确
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    udp_data_length_valid<= #U_DLY 1'd0;
    else if(rx_dv==1'b0)
    udp_data_length_valid<= #U_DLY 1'd0;
    else if((cnt==4'd1)&&(((udp_cmd==8'd0)&&(udp_data_length==16'd8+16'd3))||((udp_cmd==8'h01)&&(udp_data_length==16'd8+16'd5))))
    udp_data_length_valid<= #U_DLY 1'd1;
    else ;
end

//获取地址缓存
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    addr_tmp<= #U_DLY 16'd0;
    else if((cnt>=4'd1)&&(cnt<=4'd2))
    addr_tmp<= #U_DLY {addr_tmp[7:0],rxd};
    else ;
end


//获取写数据缓存
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    wr_data_tmp<= #U_DLY 16'd0;
    else if((cnt>=4'd3)&&(cnt<=4'd4))
    wr_data_tmp<= #U_DLY {wr_data_tmp[7:0],rxd};
    else ;
end



//读写地址
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    addr<= #U_DLY 12'd0;
    else if((udp_data_length_valid==1'b1)&&(rx_dv==1'b0))
    addr<= #U_DLY addr_tmp[11:0];
    else ;
end

//写使能
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    wr_en_scp0<= #U_DLY 1'd0;
    else if((udp_data_length_valid==1'b1)&&(rx_dv==1'b0)&&(udp_cmd==8'd1))
        case(addr_tmp[15:12])
            4'h0: wr_en_scp0<=#U_DLY 1'b1;
        default :;
        endcase
    else
    wr_en_scp0<= #U_DLY 1'd0;
end

//写数据
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    wr_data<= #U_DLY 16'd0;
    else if((udp_data_length_valid==1'b1)&&(rx_dv==1'b0)&&(udp_cmd==8'd1))
    wr_data<= #U_DLY wr_data_tmp;
    else ;
end

//读使能
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    rd_en_scp0<= #U_DLY 1'd0;
    else if((udp_data_length_valid==1'b1)&&(rx_dv==1'b0)&&(udp_cmd==8'd0))
        case(addr_tmp[15:12])
            4'h0: rd_en_scp0<=#U_DLY 1'b1;
            default :;
        endcase
    else
    rd_en_scp0<= #U_DLY 1'd0;
end



endmodule