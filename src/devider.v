`timescale 1ns/1ps

module devider (
input                               clk_sys             ,
input                               rst_sys             ,
input                               valid_i             ,
input                   [23:0]      dividend            ,//被除数
input                   [23:0]      divisor             ,//除数
output                  [23:0]      quotient            ,
output                  [3:0]       fractional          ,
output      reg                     valid_o             ,
output      reg                     busy                

);

parameter U_DLY=1;

reg     [23:0]      dividend_reg            ;
reg     [23:0]      divisor_reg             ;

reg                 sign                    ;//符号位

wire    [27:0]      dividend_reg_tmp        ;

reg     [4:0]       state_cnt               ;
reg     [27:0]      remainder               ;

reg     [27:0]      result_tmp              ;
reg     [27:0]      sign_result_tmp         ;


always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 ) 
     dividend_reg<= #U_DLY 24'd0;   
    else if(valid_i==1'b1&&(busy==1'b0))
           if(dividend[23]==1'b0)
           dividend_reg<= #U_DLY dividend;
           else if(dividend==24'h800000)
           dividend_reg<= #U_DLY 24'h7fffff;
           else 
           dividend_reg<= #U_DLY{~dividend[23:0]}+24'b1;
        else ; 
end

always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 ) 
     divisor_reg<= #U_DLY 24'h7fffff;   
    else if(valid_i==1'b1&&(busy==1'b0))
           if(divisor[23]==1'b0)
           divisor_reg<= #U_DLY divisor;
           else if(divisor==24'h800000|(divisor==24'd0))
            divisor_reg<= #U_DLY 24'h7fffff;
            else 
           divisor_reg<= #U_DLY{~divisor[23:0]}+24'b1;
        else ; 
end

always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 )
    sign<= #U_DLY 1'b0;
    else if(valid_i==1'b1&&(busy==1'b0))
            if(dividend[23]!=divisor[23])
            sign<= #U_DLY 1'b1;
            else 
            sign<= #U_DLY 1'b0;
        else ;
end

assign  dividend_reg_tmp={dividend_reg,4'b0};

always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 )
    state_cnt<= #U_DLY 5'd30;
    else if (valid_i==1'b1&&(busy==1'b0))
        state_cnt<=5'd0;
        else if(state_cnt==5'd30)
        ;
        else 
        state_cnt<= #U_DLY state_cnt+5'd1;
end

always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 ) 
    begin
    remainder<= #U_DLY 28'd0;
    result_tmp<= #U_DLY 28'd0;
    end
    else 
    case(state_cnt)
      5'd0: if(divisor_reg>dividend_reg_tmp[27]) 
            begin
            result_tmp[27]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY dividend_reg_tmp;
            end
            else 
            begin
            result_tmp[27]<= #U_DLY 1'b1 ;
            remainder<=#U_DLY 28'b0;
            end
      5'd1: if(divisor_reg>remainder[27:26]) 
            begin
            result_tmp[26]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[26]<= #U_DLY 1'b1 ;
            remainder[27:26]<=#U_DLY remainder[27:26]-divisor_reg;
            end
      5'd2: if(divisor_reg>remainder[27:25]) 
            begin
            result_tmp[25]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[25]<= #U_DLY 1'b1 ;
            remainder[27:25]<=#U_DLY remainder[27:25]-divisor_reg;
            end
      5'd3: if(divisor_reg>remainder[27:24]) 
            begin
            result_tmp[24]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[24]<= #U_DLY 1'b1 ;
            remainder[27:24]<=#U_DLY remainder[27:24]-divisor_reg;
            end
      5'd4: if(divisor_reg>remainder[27:23]) 
            begin
            result_tmp[23]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[23]<= #U_DLY 1'b1 ;
            remainder[27:23]<=#U_DLY remainder[27:23]-divisor_reg;
            end
      5'd5: if(divisor_reg>remainder[27:22]) 
            begin
            result_tmp[22]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[22]<= #U_DLY 1'b1 ;
            remainder[27:22]<=#U_DLY remainder[27:22]-divisor_reg;
            end
      5'd6: if(divisor_reg>remainder[27:21]) 
            begin
            result_tmp[21]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[21]<= #U_DLY 1'b1 ;
            remainder[27:21]<=#U_DLY remainder[27:21]-divisor_reg;
            end
      5'd7: if(divisor_reg>remainder[27:20]) 
            begin
            result_tmp[20]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[20]<= #U_DLY 1'b1 ;
            remainder[27:20]<=#U_DLY remainder[27:20]-divisor_reg;
            end
      5'd8: if(divisor_reg>remainder[27:19]) 
            begin
            result_tmp[19]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[19]<= #U_DLY 1'b1 ;
            remainder[27:19]<=#U_DLY remainder[27:19]-divisor_reg;
            end
      5'd9: if(divisor_reg>remainder[27:18]) 
            begin
            result_tmp[18]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[18]<= #U_DLY 1'b1 ;
            remainder[27:18]<=#U_DLY remainder[27:18]-divisor_reg;
            end
      5'd10: if(divisor_reg>remainder[27:17]) 
            begin
            result_tmp[17]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[17]<= #U_DLY 1'b1 ;
            remainder[27:17]<=#U_DLY remainder[27:17]-divisor_reg;
            end
      5'd11: if(divisor_reg>remainder[27:16]) 
            begin
            result_tmp[16]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[16]<= #U_DLY 1'b1 ;
            remainder[27:16]<=#U_DLY remainder[27:16]-divisor_reg;
            end
      5'd12: if(divisor_reg>remainder[27:15]) 
            begin
            result_tmp[15]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[15]<= #U_DLY 1'b1 ;
            remainder[27:15]<=#U_DLY remainder[27:15]-divisor_reg;
            end
      5'd13: if(divisor_reg>remainder[27:14]) 
            begin
            result_tmp[14]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[14]<= #U_DLY 1'b1 ;
            remainder[27:14]<=#U_DLY remainder[27:14]-divisor_reg;
            end
      5'd14: if(divisor_reg>remainder[27:13]) 
            begin
            result_tmp[13]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[13]<= #U_DLY 1'b1 ;
            remainder[27:13]<=#U_DLY remainder[27:13]-divisor_reg;
            end
      5'd15: if(divisor_reg>remainder[27:12]) 
            begin
            result_tmp[12]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[12]<= #U_DLY 1'b1 ;
            remainder[27:12]<=#U_DLY remainder[27:12]-divisor_reg;
            end
      5'd16: if(divisor_reg>remainder[27:11]) 
            begin
            result_tmp[11]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[11]<= #U_DLY 1'b1 ;
            remainder[27:11]<=#U_DLY remainder[27:11]-divisor_reg;
            end
      5'd17: if(divisor_reg>remainder[27:10]) 
            begin
            result_tmp[10]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[10]<= #U_DLY 1'b1 ;
            remainder[27:10]<=#U_DLY remainder[27:10]-divisor_reg;
            end
      5'd18: if(divisor_reg>remainder[27:9]) 
            begin
            result_tmp[9]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[9]<= #U_DLY 1'b1 ;
            remainder[27:9]<=#U_DLY remainder[27:9]-divisor_reg;
            end
      5'd19: if(divisor_reg>remainder[27:8]) 
            begin
            result_tmp[8]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[8]<= #U_DLY 1'b1 ;
            remainder[27:8]<=#U_DLY remainder[27:8]-divisor_reg;
            end
      5'd20: if(divisor_reg>remainder[27:7]) 
            begin
            result_tmp[7]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[7]<= #U_DLY 1'b1 ;
            remainder[27:7]<=#U_DLY remainder[27:7]-divisor_reg;
            end
      5'd21: if(divisor_reg>remainder[27:6]) 
            begin
            result_tmp[6]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[6]<= #U_DLY 1'b1 ;
            remainder[27:6]<=#U_DLY remainder[27:6]-divisor_reg;
            end
      5'd22: if(divisor_reg>remainder[27:5]) 
            begin
            result_tmp[5]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[5]<= #U_DLY 1'b1 ;
            remainder[27:5]<=#U_DLY remainder[27:5]-divisor_reg;
            end
      5'd23: if(divisor_reg>remainder[27:4]) 
            begin
            result_tmp[4]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[4]<= #U_DLY 1'b1 ;
            remainder[27:4]<=#U_DLY remainder[27:4]-divisor_reg;
            end
      5'd24: if(divisor_reg>remainder[27:3]) 
            begin
            result_tmp[3]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[3]<= #U_DLY 1'b1 ;
            remainder[27:3]<=#U_DLY remainder[27:3]-divisor_reg;
            end
      5'd25: if(divisor_reg>remainder[27:2]) 
            begin
            result_tmp[2]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[2]<= #U_DLY 1'b1 ;
            remainder[27:2]<=#U_DLY remainder[27:2]-divisor_reg;
            end
      5'd26: if(divisor_reg>remainder[27:1]) 
            begin
            result_tmp[1]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[1]<= #U_DLY 1'b1 ;
            remainder[27:1]<=#U_DLY remainder[27:1]-divisor_reg;
            end
      5'd27: if(divisor_reg>remainder[27:0]) 
            begin
            result_tmp[0]<= #U_DLY 1'b0 ;
            remainder<=#U_DLY remainder;
            end
            else 
            begin
            result_tmp[0]<= #U_DLY 1'b1 ;
            remainder[27:0]<=#U_DLY remainder[27:0]-divisor_reg;
            end
      default : ;

    endcase
end


always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 )
    begin
      valid_o<= #U_DLY 1'b0;
      sign_result_tmp<=#U_DLY 28'd0;
    end
    else if(state_cnt==5'd28)
        if(sign==1'b1)
        begin
          sign_result_tmp<= #U_DLY ((~result_tmp)+28'd1);
          valid_o<=#U_DLY 1'b1;
        end
        else 
        begin
          sign_result_tmp<= #U_DLY result_tmp;
          valid_o<=#U_DLY 1'b1;
        end
    else valid_o<=#U_DLY 1'b0;
end

assign  quotient=sign_result_tmp[27:4];
assign  fractional=sign_result_tmp[3:0];

always@(posedge clk_sys  or posedge rst_sys) begin
    if(rst_sys==1'b1 )
    busy<= #U_DLY 1'b0;
    else if(valid_i==1'b1&&(busy==1'b0))
    busy<= #U_DLY 1'b1;
    else if(state_cnt==5'd29)
    busy<= #U_DLY 1'b0;
    else ;
end

endmodule