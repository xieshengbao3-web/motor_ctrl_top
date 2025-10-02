`timescale 1ns/1ps

module test_data (
    input clk0,
    input rst0,
    output reg data_vld,
    output reg [15:0] data
);

reg [5:0] cnt ;

localparam U_DLY =1;

always @(posedge clk0 or posedge rst0 ) begin
    if(rst0==1'b1)
    cnt<= #U_DLY 6'd0;
    else if(cnt<6'd49)
    cnt<= #U_DLY cnt+6'd1;
    else
    cnt<= #U_DLY 6'd0;
end


always @(posedge clk0 or posedge rst0 ) begin
    if(rst0==1'b1)
    data_vld<= #U_DLY 1'b0;
    else if(cnt==6'd49)
    data_vld<= #U_DLY 1'b1;
    else
    data_vld<= #U_DLY 1'b0;
end

always @(posedge clk0 or posedge rst0 ) begin
    if(rst0==1'b1)
    data<= #U_DLY 16'd0;
    else if(data_vld==1'b1)
    data<= #U_DLY data+16'd1;
    else
    data<= #U_DLY data;
end


endmodule