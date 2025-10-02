`timescale 1ns/1ps

module rx_preamble_sfd_parse (
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [   7:0]         rxd                        ,
    input                               rx_dv                      ,
    output reg                          preamble_sfd_check_ok       
);


reg                    [  55:0]         preamble_tmp               ;
reg                    [   3:0]         cnt                        ;

localparam                              U_DLY=1                    ;

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cnt<= #U_DLY 4'd0;
    else if(rx_dv==1'b0)
    cnt<= #U_DLY 4'd0;
    else if(cnt==4'hf)
    ;
    else
    cnt<= #U_DLY cnt+4'd1;
end

always @(posedge clk_rxc) begin
    preamble_tmp<= #U_DLY {preamble_tmp[47:0],rxd};
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    preamble_sfd_check_ok<= #U_DLY 1'b0;
    else if(rx_dv==1'b0)
    preamble_sfd_check_ok<= #U_DLY 1'b0;
    else if((cnt==4'd7)&&(preamble_tmp==56'h55_55_55_55_55_55_55)&&(rxd==8'hd5))
    preamble_sfd_check_ok<= #U_DLY 1'b1;
    else
    ;
end

endmodule