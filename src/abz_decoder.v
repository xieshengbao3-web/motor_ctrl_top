`timescale 1ns/1ps


module abz_decoder (
input                       clk0         ,
input                       rst0         ,
input                       a_i             ,
input                       b_i             ,
input                       z_i             ,
input                       u_i             ,
input                       v_i             ,
input                       w_i             ,
input    [11:0]             iupoleoffset    ,
input    [11:0]             z_mark_e_neg      ,
input    [11:0]             z_mark_e_pos      ,
input    [15:0]             z_mark_m_neg      ,
input    [15:0]             z_mark_m_pos      ,

input    [11:0]             init_e_ang0     ,
input    [11:0]             init_e_ang1     ,
input    [11:0]             init_e_ang2     ,
input    [11:0]             init_e_ang3     ,
input    [11:0]             init_e_ang4     ,
input    [11:0]             init_e_ang5     ,
input                       speed_en        ,
output  reg [11:0]          current_e_ang   ,
output  reg [15:0]          current_m_ang   ,
output   [15:0]             speed           ,//rpm (16,12)
output                      speed_valid
     

);
parameter U_DLY=1;

reg        [11:0]   init_e_ang                  ;//初始电角度
reg        [2:0]    a_d                         ;
reg        [2:0]    b_d                         ;
reg        [2:0]    z_d                         ;
reg        [2:0]    u_d                         ;
reg        [2:0]    v_d                         ;
reg        [2:0]    w_d                         ;

reg        [2:0]    cnt_flag_init_e_ang         ;
reg        [1:0]    delta_ang                   ;
reg                 tick_1d                     ;
reg                 tick_2d                     ;
wire                tick                        ;
wire                z_pos                       ;

reg        [20:0]   cnt_clk_0tick               ;
reg        [20:0]   cnt_clk_1tick               ;
reg        [21:0]   cnt_clk_2tick               ;
reg        [22:0]   cnt_clk_3tick               ;
(*mark_debug="true"*)
reg        [23:0]   cnt_clk_4tick               ;
reg                 valid_i                     ;
reg        [5:0]    valid_cnt                   ;

wire       [23:0]   quotient                    ;
wire       [3:0]    fractional                  ;
wire                busy                        ;
(*mark_debug="true"*)
reg        [7:0]    abz_history_4tick           ;//记录前4个tick 转子转动情况
(*mark_debug="true"*)
wire       [3:0]    abz_history_4tick_add       ;//
(*mark_debug="true"*)
reg        [23:0]   delta_ang_4tick             ;

////检测边缘变化
always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    begin
      a_d <= #U_DLY 3'b0;
      b_d <= #U_DLY 3'b0;
      z_d <= #U_DLY 3'b0;
      u_d <= #U_DLY 3'b0;
      v_d <= #U_DLY 3'b0;
      w_d <= #U_DLY 3'b0;
    end
    else 
    begin
      a_d <= #U_DLY {a_d[1:0],a_i};
      b_d <= #U_DLY {b_d[1:0],b_i};
      z_d <= #U_DLY {z_d[1:0],z_i};
      u_d <= #U_DLY {u_d[1:0],u_i};
      v_d <= #U_DLY {v_d[1:0],v_i};
      w_d <= #U_DLY {w_d[1:0],w_i};       
    end  
end
assign tick=~({a_d[1],b_d[1]}=={a_d[2],b_d[2]}); 
assign z_pos= (z_d[1]&(~z_d[2]));


always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    begin
      tick_1d<= #U_DLY 1'b0;
      tick_2d<= #U_DLY 1'b0;
    end
    else 
    begin
      tick_1d<= #U_DLY tick ;
      tick_2d<= #U_DLY tick_1d ;
    end
end


/////初始位置检测
always @(*) begin
  case ({u_d[2],v_d[2],w_d[2]}) 
    3'b110 : init_e_ang = init_e_ang0;  //1459
    3'b010 : init_e_ang = init_e_ang1;  //1042
    3'b011 : init_e_ang = init_e_ang2;  //626
    3'b001 : init_e_ang = init_e_ang3;  //209
    3'b101 : init_e_ang = init_e_ang4;  //2242
    3'b100 : init_e_ang = init_e_ang5;  //1816
   default : init_e_ang = 12'h000; 
  endcase
end


always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    cnt_flag_init_e_ang <= #U_DLY 3'd0;
    else if(cnt_flag_init_e_ang==3'b111)
    ;
    else cnt_flag_init_e_ang <= #U_DLY cnt_flag_init_e_ang+3'b1;
end


 
always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    delta_ang<= #U_DLY 2'b0;
    else if(tick==1'b1)
    begin
    case ({a_d[2],b_d[2],a_d[1],b_d[1]})			// detect ENCA,ENCB have changes
    //a超前b
    4'b1011 : delta_ang <= #U_DLY 2'b11;		// delta_ang, detect movement direction
    4'b1101 : delta_ang <= #U_DLY 2'b11;
    4'b0100 : delta_ang <= #U_DLY 2'b11;
    4'b0010 : delta_ang <= #U_DLY 2'b11;
    //b超前a
    4'b1110 : delta_ang <= #U_DLY 2'b01;
    4'b1000 : delta_ang <= #U_DLY 2'b01;
    4'b0001 : delta_ang <= #U_DLY 2'b01;
    4'b0111 : delta_ang <= #U_DLY 2'b01;
    default : delta_ang <= #U_DLY 2'b00;
    endcase
    end
    else ;
end




always @(posedge clk0 or posedge rst0) begin
    if(rst0)  
      current_e_ang<= #U_DLY 12'd0;
    else if (cnt_flag_init_e_ang==3'd5)
      current_e_ang<= #U_DLY init_e_ang ;
    else if(z_pos==1'b1&&(delta_ang[1]==1'b0))
      current_e_ang<= #U_DLY iupoleoffset + z_mark_e_pos;
    else if (z_pos==1'b1&&(delta_ang[1]==1'b1))
      current_e_ang<= #U_DLY iupoleoffset + z_mark_e_neg;
    else if(tick_1d)
      if(current_e_ang>=12'd2499&&(delta_ang[1]==1'b0))
        current_e_ang<= #U_DLY 12'd0;
      else if(current_e_ang==12'd0&&(delta_ang[1]==1'b1))
        current_e_ang<= #U_DLY 12'd2499;
      else 
        current_e_ang<= #U_DLY current_e_ang+{{10{delta_ang[1]}},delta_ang};
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)  
      current_m_ang<= #U_DLY 16'd0;
    else if (cnt_flag_init_e_ang==3'd5)
      current_m_ang<= #U_DLY {4'd0,init_e_ang} ;
    else if(z_pos==1'b1&&(delta_ang[1]==1'b0))
      current_m_ang<= #U_DLY z_mark_m_pos;
    else if (z_pos==1'b1&&(delta_ang[1]==1'b1))
      current_m_ang<= #U_DLY z_mark_m_neg;
    else if(tick_1d)
      if(current_m_ang>=16'd9999&&(delta_ang[1]==1'b0))
        current_m_ang<= #U_DLY 16'd0;
      else if(current_m_ang==16'd0&&(delta_ang[1]==1'b1))
        current_m_ang<= #U_DLY 16'd9999;
      else 
        current_m_ang<= #U_DLY current_m_ang+{{14{delta_ang[1]}},delta_ang};
end





always @(posedge clk0 or posedge rst0) begin
    if(rst0)
      abz_history_4tick<= #U_DLY 8'd0  ;
    else if(tick_1d)
      abz_history_4tick<= #U_DLY {abz_history_4tick[5:0],delta_ang};
    else ;
end

assign abz_history_4tick_add = {abz_history_4tick[7],abz_history_4tick[7],abz_history_4tick[7:6]} + 
                               {abz_history_4tick[5],abz_history_4tick[5],abz_history_4tick[5:4]} +
                               {abz_history_4tick[3],abz_history_4tick[3],abz_history_4tick[3:2]} +
                               {abz_history_4tick[1],abz_history_4tick[1],abz_history_4tick[1:0]};

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
      delta_ang_4tick<= #U_DLY 24'd0;
    else 
      case (abz_history_4tick_add)
      4'b0001: delta_ang_4tick<= #U_DLY 24'd300_000;
      4'b0010: delta_ang_4tick<= #U_DLY 24'd600_000;
      4'b0011: delta_ang_4tick<= #U_DLY 24'd900_000;
      4'b0100: delta_ang_4tick<= #U_DLY 24'd1_200_000;

      4'b1111: delta_ang_4tick<= #U_DLY 24'hFB6_C20 ;
      4'b1110: delta_ang_4tick<= #U_DLY 24'hF6D_840 ;
      4'b1101: delta_ang_4tick<= #U_DLY 24'hF24_460 ;
      4'b1100: delta_ang_4tick<= #U_DLY 24'hEDB_080 ;
      default :delta_ang_4tick<= #U_DLY 24'h0;
      endcase
end
        




always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    cnt_clk_0tick<= #U_DLY 21'hfffff;
    else if(tick_2d)
    cnt_clk_0tick<= #U_DLY 21'd1;
    else if(cnt_clk_0tick>=21'hfffff)
    ;
    else 
    cnt_clk_0tick<= #U_DLY cnt_clk_0tick+21'd1;
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    cnt_clk_1tick<= #U_DLY 21'hfffff;
    else if(tick_2d)
    cnt_clk_1tick<= #U_DLY cnt_clk_0tick;
    else if(cnt_clk_0tick>=21'hfffff)
    cnt_clk_1tick<= #U_DLY 21'hfffff;
    else 
    ;
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    cnt_clk_2tick<= #U_DLY 22'h1fffff;
    else if(tick_2d)
    cnt_clk_2tick<= #U_DLY {1'b0,cnt_clk_0tick}+{1'b0,cnt_clk_1tick};
    else if(cnt_clk_0tick>=21'hfffff)
    cnt_clk_2tick<= #U_DLY 22'h1fffff;
    else 
    ;
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    cnt_clk_3tick<= #U_DLY 23'h3fffff;
    else if(tick_2d)
    cnt_clk_3tick<= #U_DLY {2'd0,cnt_clk_0tick}+{1'b0,cnt_clk_2tick};
    else if(cnt_clk_0tick>=21'hfffff)
    cnt_clk_3tick<= #U_DLY 23'h3fffff;
    else 
    ;
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    cnt_clk_4tick<= #U_DLY 24'h7fffff;
    else if(tick_2d)
    cnt_clk_4tick<= #U_DLY {3'd0,cnt_clk_0tick}+{1'b0,cnt_clk_3tick};
    else if(cnt_clk_0tick>=21'hfffff)
    cnt_clk_4tick<= #U_DLY 24'h7fffff;
    else if({1'b0,cnt_clk_0tick[20:1]}>cnt_clk_1tick)
    cnt_clk_4tick<= #U_DLY {3'd0,cnt_clk_0tick}+{1'b0,cnt_clk_3tick};
    else ;
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    valid_cnt<= #U_DLY 6'd0;
    else if(speed_en)
    if(valid_cnt==6'd49)  
    valid_cnt<= #U_DLY 6'd0;
    else 
    valid_cnt<= #U_DLY valid_cnt+6'd1;
    else valid_cnt<= #U_DLY 6'd0;
end

always @(posedge clk0 or posedge rst0) begin
    if(rst0)
    valid_i<= #U_DLY 1'b0;
    else if(valid_cnt==6'd1)
    valid_i<=#U_DLY 1'b1;
    else 
    valid_i<= #U_DLY 1'b0;
end

devider u0_devider(
.clk_sys   (clk0   ),
.rst_sys   (rst0   ),
.valid_i   (valid_i   ),
.dividend  (delta_ang_4tick  ),
.divisor   (cnt_clk_4tick   ),
.quotient  (quotient  ),
.fractional(fractional),
.valid_o   (speed_valid   ),
.busy      (busy      )

);

assign    speed={quotient[11:0],fractional};


endmodule