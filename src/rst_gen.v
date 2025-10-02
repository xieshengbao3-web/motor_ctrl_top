`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date: 17.07.2025 23:45:55
// Design Name: 
// Module Name: rst_gen
// Project Name: 
// Target Devices: 
// Tool Versions: 
// Description: 
// 
// Dependencies: 
// 
// Revision:
// Revision 0.01 - File Created
// Additional Comments:
// 
//////////////////////////////////////////////////////////////////////////////////
module rst_gen (
    input                               clk0                       ,
    input                               pin_rst_n_xi               ,
    input                               rst_cfg                    ,
    input                               clk1                       ,
    input                               clk2                       ,
    input                               clk_rxc                    ,

    output reg                          rst_pll                    ,
    (*max_fanout="200"*) output reg rst0 = 1'b1,
    (*max_fanout="200"*) output reg rst1 = 1'b1,
    (*max_fanout="200"*) output reg rst2 = 1'b1,
    (*max_fanout="200"*) output reg rst_rxc = 1'b1

);

localparam                              U_DLY = 1'b1               ;

  /* 20ns*time_delay_ctrl1  */
    parameter                           time_delay_ctrl1 = 32'd500_000;



reg                    [   1:0]         rst_n = 2'b11              ;
reg                    [   7:0]         rst_8d                     ;
reg                                     rst_f                      ;//滤波
reg                    [   1:0]         rst_f_2d                   ;
reg                                     rst_pos                    ;

reg                    [  31:0]         delay_cnt1 = 32'd0         ;

reg                    [   7:0]         rst0_8d = 8'hff            ;
reg                    [   7:0]         rst1_8d = 8'hff            ;
reg                    [   7:0]         rst2_8d = 8'hff            ;
reg                    [   7:0]         rst_rxc_8d = 8'hff         ;
reg                    [   2:0]         rst_cfg_dly                ;
reg                                     rst_cfg_pos                ;
reg                                     rst_all                    ;
reg                                     pulse_10ms                 ;
reg                    [   3:0]         cnt_pulse_10ms=4'd0        ;
reg                                     rst_merge                  ;



  //-------对pin_rst_n_xi管脚进行同步处理----------      //
  always @(posedge clk0) begin
    rst_n <= #U_DLY{rst_n[0], pin_rst_n_xi};
  end

  always @(posedge clk0) begin
    rst_8d <= #U_DLY{rst_8d[6:0], ~rst_n[1]};
  end

  always @(posedge clk0) begin
    rst_f <= #U_DLY &rst_8d;
  end

  always @(posedge clk0) begin
    rst_f_2d <= #U_DLY{rst_f_2d[0], rst_f};
  end

  always @(posedge clk0) begin
    rst_pos <= #U_DLY(rst_f_2d[0] == 1'b1) && (rst_f_2d[1] == 1'b0);
  end


  always @(posedge clk0) begin
    rst_cfg_dly <= #U_DLY{rst_cfg_dly[1:0], rst_cfg};
    rst_cfg_pos <= #U_DLY((rst_cfg_dly[1] == 1'b1) && (rst_cfg_dly[2] == 1'b0));
  end

   always @(posedge clk0) begin
    rst_merge<= #U_DLY rst_cfg_pos||rst_pos;
   end



  //---------------计数器---------------------///
  always @(posedge clk0) begin
    if (rst_merge == 1'b1)
      delay_cnt1 <= #U_DLY 32'd0;
    else if (delay_cnt1 >= time_delay_ctrl1)
      delay_cnt1 <= #U_DLY 32'd0;
    else
      delay_cnt1 <= #U_DLY delay_cnt1 + 32'b1;
  end

  always @(posedge clk0) begin
    if(delay_cnt1==time_delay_ctrl1)
      pulse_10ms <=#U_DLY 1'b1;
    else
      pulse_10ms <=#U_DLY 1'b0;
  end

  always @(posedge clk0) begin
    if (rst_merge == 1'b1)
      cnt_pulse_10ms<= #U_DLY 4'd0;
    else if((pulse_10ms==1'b1)&&(cnt_pulse_10ms==4'd15))
      ;
    else if(pulse_10ms==1'b1)
      cnt_pulse_10ms<= #U_DLY cnt_pulse_10ms+4'd1;
    else
      ;
  end


  ///-------------rst_all---------------//
  always @(posedge clk0) begin
    if(rst_merge == 1'b1)
      rst_all <= #U_DLY 1'b1;
    else if (cnt_pulse_10ms >= 4'd10)
      rst_all <= #U_DLY 1'b0;
    else
      rst_all <= #U_DLY 1'b1;
  end

  ///-------------rst_pll---------------//
  always @(posedge clk0) begin
    if(rst_merge == 1'b1)
      rst_pll <= #U_DLY 1'b1;
    else if (cnt_pulse_10ms >= 4'd5)
      rst_pll <= #U_DLY 1'b0;
    else
      rst_pll <= #U_DLY 1'b1;
  end

  /////////////////////////////////////////

  always @(posedge clk0 or posedge rst_all) begin
    if (rst_all == 1'b1) begin
      rst0_8d <= #U_DLY 8'hff;
      rst0 <= #U_DLY 1'b1;
    end else begin
      rst0_8d <= #U_DLY {rst0_8d[6:0],1'b0};
      rst0 <= #U_DLY rst0_8d[7];
    end
  end

  always @(posedge clk1 or posedge rst_all) begin
    if (rst_all == 1'b1) begin
      rst1_8d <= #U_DLY 8'hff;
      rst1 <= #U_DLY 1'b1;
    end else begin
      rst1_8d <= #U_DLY {rst1_8d[6:0],1'b0};
      rst1 <= #U_DLY rst1_8d[7];
    end
  end

  always @(posedge clk2 or posedge rst_all) begin
    if (rst_all == 1'b1) begin
      rst2_8d <= #U_DLY 8'hff;
      rst2 <= #U_DLY 1'b1;
    end else begin
      rst2_8d <= #U_DLY {rst2_8d[6:0],1'b0};
      rst2 <= #U_DLY rst2_8d[7];
    end
  end

  always @(posedge clk_rxc or posedge rst_all) begin
    if (rst_all == 1'b1) begin
      rst_rxc_8d <= #U_DLY 8'hff;
      rst_rxc <= #U_DLY 1'b1;
    end else begin
      rst_rxc_8d <= #U_DLY {rst_rxc_8d[6:0],1'b0};
      rst_rxc <= #U_DLY rst_rxc_8d[7];
    end
  end





endmodule
