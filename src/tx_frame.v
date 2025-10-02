module tx_frame(
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input                               pc_arp_req                 ,
    input              [  47:0]         pc_mac_addr                ,
    input              [  31:0]         pc_ip_addr                 ,
    input              [  15:0]         pc_port_addr               ,
    input              [  15:0]         ip_header_identification   ,
    input              [  15:0]         ip_header_flag_fragoffset  ,
    input              [  15:0]         ip_header_total_length     ,
    input                               pc_icmp_req                ,
    input  wire        [  15:0]         icmp_header_identifier     ,
    input  wire        [  15:0]         icmp_header_sequence       ,
    input              [   7:0]         icmp_data                  ,
    input  wire                         icmp_data_vld              ,
    output reg                          tx_en                      ,
    output reg         [   7:0]         txd                        ,
    output                              txc                        ,
    input              [  15:0]         mux_data_out0              ,
    input                               rd_start0                  ,
    input                               sam0_udp_trg_125m          ,
    input              [  15:0]         sam_data0                  ,
    output reg                          data0_rdout_en
);

localparam                              U_DLY=1                    ;
localparam                              IDLE =                          16'b0000_0000_0000_0001;
localparam                              PREAMBLE_SFD_STATE=             16'b0000_0000_0000_0010;
localparam                              ETH_HEADER_STATE=               16'b0000_0000_0000_0100;
localparam                              ARP_DATA_STATE=                 16'b0000_0000_0000_1000;
localparam                              ARP_PADDING_STATE=              16'b0000_0000_0001_0000;
localparam                              IP_HEADER_STATE   =             16'b0000_0000_0010_0000;
localparam                              UDP_HEADER_STATE  =             16'b0000_0000_0100_0000;
localparam                              UDP_READ_REG_DATA_STATE  =      16'b0000_0000_1000_0000;
localparam                              UDP_READ_SAM_DATA_STATE  =      16'b0000_0001_0000_0000;
localparam                              FCS_STATE=                      16'b0000_0010_0000_0000;
localparam                              IFG_STATE=                      16'b0000_0100_0000_0000;
localparam                              ICMP_HEADER_STATE=              16'b0000_1000_0000_0000;
localparam                              ICMP_DATA_STATE=                16'b0001_0000_0000_0000;


parameter FPGA_MAC_ADDR = 48'h00_0A_35_00_01_02;
parameter FPGA_IP_ADDR={8'd192,8'd168,8'd1,8'd10};
parameter FPGA_PORT = 16'd21105;


reg                                     tx_busy                    ;
reg                                     arp_reply_start            ;
reg                                     arp_reply_en               ;
reg                                     icmp_reply_start           ;
reg                                     icmp_reply_en              ;
reg                                     reg_read_start             ;
reg                                     sam_read_start             ;
reg                                     sam_read_en                ;
reg                                     reg_read_en                ;


reg                    [   15:0]         cur_state                  ;
reg                    [  15:0]         next_state                 ;

reg                    [   3:0]         preamble_sfd_byte_cnt      ;
reg                    [   3:0]         eth_header_byte_cnt        ;
reg                    [   4:0]         arp_byte_cnt               ;
reg                    [   4:0]         arp_padding_byte_cnt       ;
reg                    [   4:0]         ip_header_byte_cnt         ;
reg                    [   4:0]         icmp_header_byte_cnt       ;
reg                    [   5:0]         icmp_data_byte_cnt         ;
reg                    [   3:0]         udp_header_byte_cnt        ;
reg                    [   4:0]         udp_read_reg_byte_cnt      ;
reg                    [  10:0]         udp_read_sam_byte_cnt      ;
reg                    [   2:0]         fcs_byte_cnt               ;
reg                    [   3:0]         ifg_byte_cnt               ;





reg                                     crc_en                     ;
wire                   [  31:0]         crc_data                   ;
wire                   [  31:0]         crc_next                   ;
wire                   [  31:0]         tx_crc_data_cal            ;
reg                    [  23:0]         tx_crc_data_act            ;
reg                    [  15:0]         eth_header_tx_type         ;
reg                    [  15:0]         mux_data_out               ;
reg                    [  15:0]         ip_header_16bit[0:9]       ;
reg                    [  16:0]         sum0_1                     ;
reg                    [  16:0]         sum2_3                     ;
reg                    [  16:0]         sum4_5                     ;
reg                    [  16:0]         sum6_7                     ;
reg                    [  16:0]         sum8_9                     ;
reg                    [  23:0]         total_sum                  ;
reg                    [  15:0]         carry_corrected_sum        ;
reg                    [  15:0]         ip_checksum_cal            ;

wire                   [   7:0]         preamble_sfd_tx_data[0:7]     ;
reg                    [   7:0]         eth_header_tx_data [0:13]     ;
reg                    [   7:0]         arp_data_tx_data[0:27]        ;
reg                    [   7:0]         ip_header_tx_data[0:19]      ;
reg                    [   7:0]         udp_header_tx_data[0:7]      ;
reg                    [   7:0]         udp_tx_data[0:17]            ; //读寄存器返回udp数据

reg                    [   7:0]         icmp_header_tx_data[0:7]      ;
reg                    [   7:0]         icmp_tx_data[0:63]            ;
reg                    [   5:0]         icmp_data_num_cnt          ;
wire                   [  15:0]         icmp_data_num              ;
reg                    [  15:0]         icmp_data_16bit_tmp        ;
reg                    [  31:0]         icmp_data_16bit_sum        ;
reg                    [  31:0]         icmp_header_data_16bit_sum ;
reg                    [  15:0]         icmp_header_checksum       ;



assign  txc=clk_rxc ;

//有效的arp请求信号
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    arp_reply_start<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(pc_arp_req==1'b1))
    arp_reply_start<= #U_DLY 1'b1;
    else 
    arp_reply_start<= #U_DLY 1'b0;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    arp_reply_en<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(pc_arp_req==1'b1))
    arp_reply_en<= #U_DLY 1'b1;
    else if(ifg_byte_cnt==4'd15)
    arp_reply_en<= #U_DLY 1'b0;
    else ;
end

//有效的icmp请求信号
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    icmp_reply_start<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(pc_icmp_req==1'b1))
    icmp_reply_start<= #U_DLY 1'b1;
    else 
    icmp_reply_start<= #U_DLY 1'b0;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    icmp_reply_en<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(pc_icmp_req==1'b1))
    icmp_reply_en<= #U_DLY 1'b1;
    else if(ifg_byte_cnt==4'd15)
    icmp_reply_en<= #U_DLY 1'b0;
    else ;
end

//有效读请求
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    reg_read_start<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(rd_start0==1'b1))
    reg_read_start<= #U_DLY 1'b1;
    else 
    reg_read_start<= #U_DLY 1'b0;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    reg_read_en<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(rd_start0==1'b1))
    reg_read_en<= #U_DLY 1'b1;
    else if(ifg_byte_cnt==4'd15)
    reg_read_en<= #U_DLY 1'b0;
    else ;
end

//采集数据请求
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    sam_read_start<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(sam0_udp_trg_125m==1'b1))
    sam_read_start<= #U_DLY 1'b1;
    else 
    sam_read_start<= #U_DLY 1'b0;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    sam_read_en<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(sam0_udp_trg_125m==1'b1))
    sam_read_en<= #U_DLY 1'b1;
    else if(ifg_byte_cnt==4'd15)
    sam_read_en<= #U_DLY 1'b0;
    else ;
end

//eth header 帧type
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    eth_header_tx_type<= #U_DLY 16'd0;
    else if((tx_busy==1'b0&&((rd_start0==1'b1)||(sam0_udp_trg_125m==1'b1)||(pc_icmp_req==1'b1))))
    eth_header_tx_type<= #U_DLY 16'h0800;
    else if((tx_busy==1'b0&&(pc_arp_req==1'b1)))
    eth_header_tx_type<= #U_DLY 16'h0806;
    else ;
end

//preamble and sfd data
assign preamble_sfd_tx_data[0]=8'h55;
assign preamble_sfd_tx_data[1]=8'h55;
assign preamble_sfd_tx_data[2]=8'h55;
assign preamble_sfd_tx_data[3]=8'h55;
assign preamble_sfd_tx_data[4]=8'h55;
assign preamble_sfd_tx_data[5]=8'h55;
assign preamble_sfd_tx_data[6]=8'h55;
assign preamble_sfd_tx_data[7]=8'hd5;


//********************************************
//eth header data
//*********************************************
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin 
        eth_header_tx_data[0]<= #U_DLY 8'h0;
        eth_header_tx_data[1]<= #U_DLY 8'h0;
        eth_header_tx_data[2]<= #U_DLY 8'h0;
        eth_header_tx_data[3]<= #U_DLY 8'h0;
        eth_header_tx_data[4]<= #U_DLY 8'h0;
        eth_header_tx_data[5]<= #U_DLY 8'h0;
        eth_header_tx_data[6]<= #U_DLY 8'h0;
        eth_header_tx_data[7]<= #U_DLY 8'h0;
        eth_header_tx_data[8]<= #U_DLY 8'h0;
        eth_header_tx_data[9]<= #U_DLY 8'h0;
        eth_header_tx_data[10]<= #U_DLY 8'h0;
        eth_header_tx_data[11]<= #U_DLY 8'h0;
        eth_header_tx_data[12]<= #U_DLY 8'h0;
        eth_header_tx_data[13]<= #U_DLY 8'h0;
    end
    else begin
        eth_header_tx_data[0]<= #U_DLY pc_mac_addr[47:40];
        eth_header_tx_data[1]<= #U_DLY pc_mac_addr[39:32];
        eth_header_tx_data[2]<= #U_DLY pc_mac_addr[31:24];
        eth_header_tx_data[3]<= #U_DLY pc_mac_addr[23:16];
        eth_header_tx_data[4]<= #U_DLY pc_mac_addr[15:8];
        eth_header_tx_data[5]<= #U_DLY pc_mac_addr[7:0];
        eth_header_tx_data[6]<= #U_DLY FPGA_MAC_ADDR[47:40];
        eth_header_tx_data[7]<= #U_DLY FPGA_MAC_ADDR[39:32];
        eth_header_tx_data[8]<= #U_DLY FPGA_MAC_ADDR[31:24];
        eth_header_tx_data[9]<= #U_DLY FPGA_MAC_ADDR[23:16];
        eth_header_tx_data[10]<= #U_DLY FPGA_MAC_ADDR[15:8];
        eth_header_tx_data[11]<= #U_DLY FPGA_MAC_ADDR[7:0];
        eth_header_tx_data[12]<= #U_DLY eth_header_tx_type[15:8];
        eth_header_tx_data[13]<= #U_DLY eth_header_tx_type[7:0];
    end
end


//********************************************
//定义arp数据
//*********************************************
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin
      arp_data_tx_data[0]<= #U_DLY 8'd0;
      arp_data_tx_data[1]<= #U_DLY 8'd0;
      arp_data_tx_data[2]<= #U_DLY 8'd0;
      arp_data_tx_data[3]<= #U_DLY 8'd0;
      arp_data_tx_data[4]<= #U_DLY 8'd0;
      arp_data_tx_data[5]<= #U_DLY 8'd0;
      arp_data_tx_data[6]<= #U_DLY 8'd0;
      arp_data_tx_data[7]<= #U_DLY 8'd0;
      arp_data_tx_data[8]<= #U_DLY 8'd0;
      arp_data_tx_data[9]<= #U_DLY 8'd0;
      arp_data_tx_data[10]<= #U_DLY 8'd0;
      arp_data_tx_data[11]<= #U_DLY 8'd0;
      arp_data_tx_data[12]<= #U_DLY 8'd0;
      arp_data_tx_data[13]<= #U_DLY 8'd0;
      arp_data_tx_data[14]<= #U_DLY 8'd0;
      arp_data_tx_data[15]<= #U_DLY 8'd0;
      arp_data_tx_data[16]<= #U_DLY 8'd0;
      arp_data_tx_data[17]<= #U_DLY 8'd0;
      arp_data_tx_data[18]<= #U_DLY 8'd0;
      arp_data_tx_data[19]<= #U_DLY 8'd0;
      arp_data_tx_data[20]<= #U_DLY 8'd0;
      arp_data_tx_data[21]<= #U_DLY 8'd0;
      arp_data_tx_data[22]<= #U_DLY 8'd0;
      arp_data_tx_data[23]<= #U_DLY 8'd0;
      arp_data_tx_data[24]<= #U_DLY 8'd0;
      arp_data_tx_data[25]<= #U_DLY 8'd0;
      arp_data_tx_data[26]<= #U_DLY 8'd0;
      arp_data_tx_data[27]<= #U_DLY 8'd0;
    end
    else begin
      arp_data_tx_data[0]<= #U_DLY 8'h00;
      arp_data_tx_data[1]<= #U_DLY 8'h01;
      arp_data_tx_data[2]<= #U_DLY 8'h08;
      arp_data_tx_data[3]<= #U_DLY 8'h00;
      arp_data_tx_data[4]<= #U_DLY 8'h06;
      arp_data_tx_data[5]<= #U_DLY 8'h04;
      arp_data_tx_data[6]<= #U_DLY 8'h00;
      arp_data_tx_data[7]<= #U_DLY 8'h02;
      arp_data_tx_data[8]<= #U_DLY FPGA_MAC_ADDR[47:40];
      arp_data_tx_data[9]<= #U_DLY FPGA_MAC_ADDR[39:32];
      arp_data_tx_data[10]<= #U_DLY FPGA_MAC_ADDR[31:24];
      arp_data_tx_data[11]<= #U_DLY FPGA_MAC_ADDR[23:16];
      arp_data_tx_data[12]<= #U_DLY FPGA_MAC_ADDR[15:8];
      arp_data_tx_data[13]<= #U_DLY FPGA_MAC_ADDR[7:0];
      arp_data_tx_data[14]<= #U_DLY FPGA_IP_ADDR[31:24];
      arp_data_tx_data[15]<= #U_DLY FPGA_IP_ADDR[23:16];
      arp_data_tx_data[16]<= #U_DLY FPGA_IP_ADDR[15:8];
      arp_data_tx_data[17]<= #U_DLY FPGA_IP_ADDR[7:0];
      arp_data_tx_data[18]<= #U_DLY pc_mac_addr[47:40];
      arp_data_tx_data[19]<= #U_DLY pc_mac_addr[39:32];
      arp_data_tx_data[20]<= #U_DLY pc_mac_addr[31:24];
      arp_data_tx_data[21]<= #U_DLY pc_mac_addr[23:16];
      arp_data_tx_data[22]<= #U_DLY pc_mac_addr[15:8];
      arp_data_tx_data[23]<= #U_DLY pc_mac_addr[7:0];
      arp_data_tx_data[24]<= #U_DLY pc_ip_addr[31:24];
      arp_data_tx_data[25]<= #U_DLY pc_ip_addr[23:16];
      arp_data_tx_data[26]<= #U_DLY pc_ip_addr[15:8];
      arp_data_tx_data[27]<= #U_DLY pc_ip_addr[7:0];
    end
end


//********************************************
//ip首部
//*********************************************
always @(posedge clk_rxc) begin
    if(reg_read_start==1'b1) begin
      ip_header_16bit[0]<= #U_DLY 16'h4500; //ipv4 ip首部长度 5个32bit 服务类型00
      ip_header_16bit[1]<= #U_DLY 16'h001e; //总长度 20ip首部 udp首部8 udp数据2
      ip_header_16bit[2]<= #U_DLY 16'h0001; //标识
      ip_header_16bit[3]<= #U_DLY 16'h4000; //标志位和片偏移
      ip_header_16bit[4]<= #U_DLY 16'h8011; //TTL：0x80 协议类型 17为udp 17--udp  6--tcp 1--icmp 
      ip_header_16bit[5]<= #U_DLY 16'h0; //校验和暂为0
      ip_header_16bit[6]<= #U_DLY FPGA_IP_ADDR[31:16];
      ip_header_16bit[7]<= #U_DLY FPGA_IP_ADDR[15:0];
      ip_header_16bit[8]<= #U_DLY pc_ip_addr[31:16];
      ip_header_16bit[9]<= #U_DLY pc_ip_addr[15:0];
    end
    else if(sam_read_start==1'b1) begin
      ip_header_16bit[0]<= #U_DLY 16'h4500; //ipv4 ip首部长度 5个32bit 服务类型00
      ip_header_16bit[1]<= #U_DLY 16'd1052; //总长度 20ip首部 udp首部8 udp数据1024
      ip_header_16bit[2]<= #U_DLY 16'h0001; //标识
      ip_header_16bit[3]<= #U_DLY 16'h4000; //标志位和片偏移
      ip_header_16bit[4]<= #U_DLY 16'h8011; //TTL：0x80 协议类型 17为udp 17--udp  6--tcp 1--icmp 
      ip_header_16bit[5]<= #U_DLY 16'h0;//校验和暂为0
      ip_header_16bit[6]<= #U_DLY FPGA_IP_ADDR[31:16];
      ip_header_16bit[7]<= #U_DLY FPGA_IP_ADDR[15:0];
      ip_header_16bit[8]<= #U_DLY pc_ip_addr[31:16];
      ip_header_16bit[9]<= #U_DLY pc_ip_addr[15:0];
    end
    else if(icmp_reply_start==1'b1) begin
      ip_header_16bit[0]<= #U_DLY 16'h4500; //ipv4 ip首部长度 5个32bit 服务类型00 
      ip_header_16bit[1]<= #U_DLY ip_header_total_length; //和icmp请求保持一致
      ip_header_16bit[2]<= #U_DLY ip_header_identification; //标识
      ip_header_16bit[3]<= #U_DLY ip_header_flag_fragoffset; //标志位和片偏移
      ip_header_16bit[4]<= #U_DLY 16'h8001; //TTL：0x80 协议类型 17为udp 17--udp  6--tcp 1--icmp 
      ip_header_16bit[5]<= #U_DLY 16'h0;//校验和暂为0
      ip_header_16bit[6]<= #U_DLY FPGA_IP_ADDR[31:16];
      ip_header_16bit[7]<= #U_DLY FPGA_IP_ADDR[15:0];
      ip_header_16bit[8]<= #U_DLY pc_ip_addr[31:16];
      ip_header_16bit[9]<= #U_DLY pc_ip_addr[15:0];
    end
    else ;
end

always @(posedge clk_rxc) begin
    sum0_1<=#U_DLY ip_header_16bit[0]+ip_header_16bit[1];           //固定值 0x4531
    sum2_3<=#U_DLY ip_header_16bit[2]+ip_header_16bit[3];           //固定值 0x4001
    sum4_5<=#U_DLY ip_header_16bit[4]+ip_header_16bit[5];           //固定值 0x8011
    sum6_7<=#U_DLY ip_header_16bit[6]+ip_header_16bit[7];
    sum8_9<=#U_DLY ip_header_16bit[8]+ip_header_16bit[9];
    total_sum <=#U_DLY sum0_1+sum2_3 + sum4_5 + sum6_7 + sum8_9    ;
    carry_corrected_sum <=#U_DLY total_sum[15:0] + {8'h0,total_sum[23:16]}  ;
    ip_checksum_cal<=#U_DLY ~carry_corrected_sum;
end

//ip header
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin
      ip_header_tx_data[0]<= #U_DLY 8'd0;
      ip_header_tx_data[1]<= #U_DLY 8'd0;
      ip_header_tx_data[2]<= #U_DLY 8'd0;
      ip_header_tx_data[3]<= #U_DLY 8'd0;
      ip_header_tx_data[4]<= #U_DLY 8'd0;
      ip_header_tx_data[5]<= #U_DLY 8'd0;
      ip_header_tx_data[6]<= #U_DLY 8'd0;
      ip_header_tx_data[7]<= #U_DLY 8'd0;
      ip_header_tx_data[8]<= #U_DLY 8'd0;
      ip_header_tx_data[9]<= #U_DLY 8'd0;
      ip_header_tx_data[10]<= #U_DLY 8'd0;
      ip_header_tx_data[11]<= #U_DLY 8'd0;
      ip_header_tx_data[12]<= #U_DLY 8'd0;
      ip_header_tx_data[13]<= #U_DLY 8'd0;
      ip_header_tx_data[14]<= #U_DLY 8'd0;
      ip_header_tx_data[15]<= #U_DLY 8'd0;
      ip_header_tx_data[16]<= #U_DLY 8'd0;
      ip_header_tx_data[17]<= #U_DLY 8'd0;
      ip_header_tx_data[18]<= #U_DLY 8'd0;
      ip_header_tx_data[19]<= #U_DLY 8'd0;
    end
    else  begin
      ip_header_tx_data[0]<= #U_DLY ip_header_16bit[0][15:8];
      ip_header_tx_data[1]<= #U_DLY ip_header_16bit[0][7:0];
      ip_header_tx_data[2]<= #U_DLY ip_header_16bit[1][15:8];//总长度 
      ip_header_tx_data[3]<= #U_DLY ip_header_16bit[1][7:0];//总长度
      ip_header_tx_data[4]<= #U_DLY ip_header_16bit[2][15:8];//标识
      ip_header_tx_data[5]<= #U_DLY ip_header_16bit[2][7:0];//标识
      ip_header_tx_data[6]<= #U_DLY ip_header_16bit[3][15:8];//标志位和片偏移
      ip_header_tx_data[7]<= #U_DLY ip_header_16bit[3][7:0];//标志位和片偏移
      ip_header_tx_data[8]<= #U_DLY ip_header_16bit[4][15:8];//TTL
      ip_header_tx_data[9]<= #U_DLY ip_header_16bit[4][7:0];//17--udp
      ip_header_tx_data[10]<= #U_DLY ip_checksum_cal[15:8];//首部校验和
      ip_header_tx_data[11]<= #U_DLY ip_checksum_cal[7:0];//首部校验和
      ip_header_tx_data[12]<= #U_DLY FPGA_IP_ADDR[31:24];
      ip_header_tx_data[13]<= #U_DLY FPGA_IP_ADDR[23:16];
      ip_header_tx_data[14]<= #U_DLY FPGA_IP_ADDR[15:8];
      ip_header_tx_data[15]<= #U_DLY FPGA_IP_ADDR[7:0];
      ip_header_tx_data[16]<= #U_DLY pc_ip_addr[31:24];
      ip_header_tx_data[17]<= #U_DLY pc_ip_addr[23:16];
      ip_header_tx_data[18]<= #U_DLY pc_ip_addr[15:8];
      ip_header_tx_data[19]<= #U_DLY pc_ip_addr[7:0];
    end
end

//udp header
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin
      udp_header_tx_data[0]<= #U_DLY 8'd0;
      udp_header_tx_data[1]<= #U_DLY 8'd0;
      udp_header_tx_data[2]<= #U_DLY 8'd0;
      udp_header_tx_data[3]<= #U_DLY 8'd0;
      udp_header_tx_data[4]<= #U_DLY 8'd0;
      udp_header_tx_data[5]<= #U_DLY 8'd0;
      udp_header_tx_data[6]<= #U_DLY 8'd0;
      udp_header_tx_data[7]<= #U_DLY 8'd0;
    end
    else if(reg_read_start==1'b1)  begin
      //udp 首部
      udp_header_tx_data[0]<= #U_DLY FPGA_PORT[15:8];
      udp_header_tx_data[1]<= #U_DLY FPGA_PORT[7:0];
      udp_header_tx_data[2]<= #U_DLY pc_port_addr[15:8];
      udp_header_tx_data[3]<= #U_DLY pc_port_addr[7:0];
      udp_header_tx_data[4]<= #U_DLY 8'h00;//udp长度 8（udp首部）+2
      udp_header_tx_data[5]<= #U_DLY 8'h0a;//udp长度
      udp_header_tx_data[6]<= #U_DLY 8'h00;//udp校验和 不校验
      udp_header_tx_data[7]<= #U_DLY 8'h00;//udp校验和
    end
    else if(sam_read_start==1'b1) begin
      //udp 首部
      udp_header_tx_data[0]<= #U_DLY FPGA_PORT[15:8];
      udp_header_tx_data[1]<= #U_DLY FPGA_PORT[7:0];
      udp_header_tx_data[2]<= #U_DLY pc_port_addr[15:8];
      udp_header_tx_data[3]<= #U_DLY pc_port_addr[7:0];
      udp_header_tx_data[4]<= #U_DLY 8'h04;//udp长度 8（udp首部）+1024
      udp_header_tx_data[5]<= #U_DLY 8'h08;//udp长度
      udp_header_tx_data[6]<= #U_DLY 8'h00;//udp校验和 不校验
      udp_header_tx_data[7]<= #U_DLY 8'h00;//udp校验和
    end
end

//选取那个scp数据读出
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    mux_data_out<= #U_DLY 16'd0;
    else if(rd_start0==1'b1)
    mux_data_out<= #U_DLY mux_data_out0;
    else ;
end

//udp read reg data
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin
      udp_tx_data[0]<= #U_DLY 8'd0;
      udp_tx_data[1]<= #U_DLY 8'd0;
      udp_tx_data[2]<= #U_DLY 8'd0;
      udp_tx_data[3]<= #U_DLY 8'd0;
      udp_tx_data[4]<= #U_DLY 8'd0;
      udp_tx_data[5]<= #U_DLY 8'd0;
      udp_tx_data[6]<= #U_DLY 8'd0;
      udp_tx_data[7]<= #U_DLY 8'd0;
      udp_tx_data[8]<= #U_DLY 8'd0;
      udp_tx_data[9]<= #U_DLY 8'd0;
      udp_tx_data[10]<= #U_DLY 8'd0;
      udp_tx_data[11]<= #U_DLY 8'd0;
      udp_tx_data[12]<= #U_DLY 8'd0;
      udp_tx_data[13]<= #U_DLY 8'd0;
      udp_tx_data[14]<= #U_DLY 8'd0;
      udp_tx_data[15]<= #U_DLY 8'd0;
      udp_tx_data[16]<= #U_DLY 8'd0;
      udp_tx_data[17]<= #U_DLY 8'd0;
    end
    else  begin
      udp_tx_data[0]<= #U_DLY mux_data_out[15:8];//udp数据
      udp_tx_data[1]<= #U_DLY mux_data_out[7:0];//udp数据
      udp_tx_data[2]<= #U_DLY 8'd0; //padding
      udp_tx_data[3]<= #U_DLY 8'd0;
      udp_tx_data[4]<= #U_DLY 8'd0;
      udp_tx_data[5]<= #U_DLY 8'd0;
      udp_tx_data[6]<= #U_DLY 8'd0;
      udp_tx_data[7]<= #U_DLY 8'd0;
      udp_tx_data[8]<= #U_DLY 8'd0;
      udp_tx_data[9]<= #U_DLY 8'd0;
      udp_tx_data[10]<= #U_DLY 8'd0;
      udp_tx_data[11]<= #U_DLY 8'd0;
      udp_tx_data[12]<= #U_DLY 8'd0;
      udp_tx_data[13]<= #U_DLY 8'd0;
      udp_tx_data[14]<= #U_DLY 8'd0;
      udp_tx_data[15]<= #U_DLY 8'd0;
      udp_tx_data[16]<= #U_DLY 8'd0;
      udp_tx_data[17]<= #U_DLY 8'd0;
    end
end

//icmp数据处理
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_data_num_cnt<= #U_DLY 6'd0;
    else if(icmp_data_vld==1'b1)
    icmp_data_num_cnt<= #U_DLY icmp_data_num_cnt+6'd1;
    else
    icmp_data_num_cnt<= #U_DLY 6'd0;
end


always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    icmp_data_16bit_sum<=#U_DLY 32'd0;
    else if(icmp_data_num_cnt>6'd0&&(icmp_data_num_cnt[0]==1'b0))
    icmp_data_16bit_sum<=#U_DLY icmp_data_16bit_sum+{16'd0,icmp_data_16bit_tmp};
    else if(ifg_byte_cnt==4'd15)
    icmp_data_16bit_sum<=#U_DLY 32'd0;
    else ;
end

always @(posedge clk_rxc) begin
    icmp_header_data_16bit_sum<= #U_DLY icmp_data_16bit_sum+icmp_header_identifier+icmp_header_sequence;
end

always @(posedge clk_rxc) begin
    icmp_header_checksum<=#U_DLY ~(icmp_header_data_16bit_sum[31:16]+icmp_header_data_16bit_sum[15:0]);
end


always @(posedge clk_rxc) begin
    icmp_data_16bit_tmp<= #U_DLY {icmp_data_16bit_tmp[7:0],icmp_data};
end


assign icmp_data_num=ip_header_total_length-16'd20-16'd8; //20--ip头 8--icmp头

always @(posedge clk_rxc)begin
    if(icmp_data_vld==1'b1)
    icmp_tx_data[icmp_data_num_cnt]<=icmp_data;
    else ;
end



//icmp header
always @(posedge clk_rxc) begin
      icmp_header_tx_data[0]<= #U_DLY 8'd0; //8 请求  0--响应
      icmp_header_tx_data[1]<= #U_DLY 8'd0; //code 固定0
      icmp_header_tx_data[2]<= #U_DLY icmp_header_checksum[15:8]; //checksum 校验和
      icmp_header_tx_data[3]<= #U_DLY icmp_header_checksum[7:0];
      icmp_header_tx_data[4]<= #U_DLY icmp_header_identifier[15:8];
      icmp_header_tx_data[5]<= #U_DLY icmp_header_identifier[7:0];
      icmp_header_tx_data[6]<= #U_DLY icmp_header_sequence[15:8];
      icmp_header_tx_data[7]<= #U_DLY icmp_header_sequence[7:0];
    end





//tx busy 标志
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    tx_busy<= #U_DLY 1'b0;
    else if(tx_busy==1'b0&&(pc_arp_req==1'b1||rd_start0==1'b1||sam0_udp_trg_125m==1'b1))
    tx_busy<= #U_DLY 1'b1;
    else if(ifg_byte_cnt==4'd15)
    tx_busy<= #U_DLY 1'b0;
    else ;
end

//状态机
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1)
    cur_state<= #U_DLY IDLE;
    else
    cur_state<= #U_DLY next_state;
end

//第二段状态机
always @* begin
    next_state= IDLE;
    case (cur_state)
    IDLE: begin
        if(arp_reply_start||reg_read_start||sam_read_start||icmp_reply_start)
        next_state= PREAMBLE_SFD_STATE;
        else 
        next_state= IDLE;
    end
    PREAMBLE_SFD_STATE: begin
        if(preamble_sfd_byte_cnt==4'd7)
        next_state=ETH_HEADER_STATE;
        else 
        next_state=PREAMBLE_SFD_STATE;
    end
    ETH_HEADER_STATE: begin
        if((eth_header_byte_cnt==4'd13)&&arp_reply_en) //arp 优先级最高
        next_state=ARP_DATA_STATE;
        else if((eth_header_byte_cnt==4'd13)&&(reg_read_en||sam_read_en||icmp_reply_en))
        next_state=IP_HEADER_STATE;
        else
        next_state=ETH_HEADER_STATE;
    end
    //arp state
    ARP_DATA_STATE: begin
        if(arp_byte_cnt==5'd27)
        next_state=ARP_PADDING_STATE;
        else 
        next_state=ARP_DATA_STATE;
    end
    ARP_PADDING_STATE: begin
        if(arp_padding_byte_cnt==5'd17)
        next_state=FCS_STATE;
        else 
        next_state=ARP_PADDING_STATE;
    end
    //ip state
    IP_HEADER_STATE: begin
        if(ip_header_byte_cnt==5'd19)
            if(icmp_reply_en)
            next_state=ICMP_HEADER_STATE;
            else if(reg_read_en||sam_read_en)
            next_state=UDP_HEADER_STATE;
            else
            next_state=IP_HEADER_STATE;
        else
        next_state=IP_HEADER_STATE;
    end

    ICMP_HEADER_STATE: begin
        if(icmp_header_byte_cnt==4'd7)
        next_state=ICMP_DATA_STATE;
        else 
        next_state=ICMP_HEADER_STATE;
    end
    ICMP_DATA_STATE:begin
        if(icmp_data_byte_cnt==(icmp_data_num[5:0]-6'd1))
        next_state=FCS_STATE;
        else 
        next_state=ICMP_DATA_STATE;
    end

    UDP_HEADER_STATE: begin
        if(udp_header_byte_cnt==4'd7&&(reg_read_en))
        next_state=UDP_READ_REG_DATA_STATE;
        else if(udp_header_byte_cnt==4'd7&&(sam_read_en))
        next_state=UDP_READ_SAM_DATA_STATE;
        else 
        next_state=UDP_HEADER_STATE;
    end

    UDP_READ_REG_DATA_STATE: begin
        if(udp_read_reg_byte_cnt==5'd17)
        next_state=FCS_STATE;
        else 
        next_state=UDP_READ_REG_DATA_STATE;
    end
    UDP_READ_SAM_DATA_STATE: begin
        if(udp_read_sam_byte_cnt==11'd1023)
        next_state=FCS_STATE;
        else 
        next_state=UDP_READ_SAM_DATA_STATE;
    end


    FCS_STATE: begin
        if(fcs_byte_cnt==3'd3)
        next_state= IFG_STATE;
        else 
        next_state=FCS_STATE;
    end
    IFG_STATE: begin
        if(ifg_byte_cnt==4'd15)
        next_state=IDLE;
        else 
        next_state=IFG_STATE;
    end 
    default :
        next_state=IDLE;
    endcase
end

//第三段
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    else  begin
    case (cur_state)
    IDLE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    PREAMBLE_SFD_STATE: begin
        preamble_sfd_byte_cnt<= #U_DLY preamble_sfd_byte_cnt+4'd1;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    ETH_HEADER_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY eth_header_byte_cnt+4'd1;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    ARP_DATA_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY arp_byte_cnt+5'd1;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    ARP_PADDING_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY arp_padding_byte_cnt+5'd1;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    IP_HEADER_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY ip_header_byte_cnt+ 5'd1;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    UDP_HEADER_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY udp_header_byte_cnt+4'd1;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    ICMP_HEADER_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY icmp_header_byte_cnt+4'd1;
        icmp_data_byte_cnt<= #U_DLY  6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    ICMP_DATA_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY icmp_data_byte_cnt+6'd1;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end

    UDP_READ_REG_DATA_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY udp_read_reg_byte_cnt+ 5'd1;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    UDP_READ_SAM_DATA_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY udp_read_sam_byte_cnt+11'd1;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    FCS_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY fcs_byte_cnt+3'd1;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    IFG_STATE: begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY ifg_byte_cnt+4'd1;
    end
    default :begin
        preamble_sfd_byte_cnt <= #U_DLY 4'd0;
        eth_header_byte_cnt<= #U_DLY 4'd0;
        arp_byte_cnt<=#U_DLY 5'd0;
        arp_padding_byte_cnt<=#U_DLY 5'd0;
        ip_header_byte_cnt<= #U_DLY 5'd0;
        icmp_header_byte_cnt<= #U_DLY 4'd0;
        icmp_data_byte_cnt<= #U_DLY 6'd0;
        udp_header_byte_cnt<= #U_DLY 4'd0;
        udp_read_reg_byte_cnt<= #U_DLY 5'd0;
        udp_read_sam_byte_cnt<= #U_DLY 11'd0;
        fcs_byte_cnt<= #U_DLY 3'd0;
        ifg_byte_cnt<= #U_DLY 4'd0;
    end
    endcase
    end
end

always @(posedge clk_rxc or posedge rst_rxc) begin
if(rst_rxc==1'b1) 
data0_rdout_en<= #U_DLY 1'b0;
else if(udp_header_byte_cnt==4'd5&&(sam_read_en))
data0_rdout_en<= #U_DLY 1'b1;
else if(udp_read_sam_byte_cnt==11'd1021)
data0_rdout_en<= #U_DLY 1'b0;
else ;
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    tx_en<= #U_DLY 1'b0;
    else if(cur_state==PREAMBLE_SFD_STATE)
    tx_en<= #U_DLY 1'b1;
    else if (fcs_byte_cnt==3'd4)
    tx_en<= #U_DLY 1'b0;
    else ;
end
always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    txd<= #U_DLY 8'd0;
    else case (cur_state)
    IDLE: begin
      txd<=#U_DLY 8'd0;
    end
    PREAMBLE_SFD_STATE: begin
      txd<= #U_DLY preamble_sfd_tx_data[preamble_sfd_byte_cnt];
    end
    ETH_HEADER_STATE: begin
      txd<= #U_DLY eth_header_tx_data[eth_header_byte_cnt];
    end
    ARP_DATA_STATE: begin
      txd<= #U_DLY arp_data_tx_data[arp_byte_cnt];
    end
    ARP_PADDING_STATE: begin
      txd<=#U_DLY 8'd0;
    end
    IP_HEADER_STATE: begin
      txd<= #U_DLY ip_header_tx_data[ip_header_byte_cnt];
    end

    ICMP_HEADER_STATE:begin
      txd<= #U_DLY icmp_header_tx_data[icmp_header_byte_cnt];
    end
    ICMP_DATA_STATE:begin
      txd<= #U_DLY icmp_tx_data[icmp_data_byte_cnt];
    end
    UDP_HEADER_STATE: begin
      txd<= #U_DLY udp_header_tx_data[udp_header_byte_cnt];
    end

    UDP_READ_REG_DATA_STATE: begin
      txd<= #U_DLY udp_tx_data[udp_read_reg_byte_cnt];
    end
    UDP_READ_SAM_DATA_STATE: begin
      if(udp_read_sam_byte_cnt[0]==1'b1)
      txd<= #U_DLY sam_data0[7:0];
      else
      txd<= #U_DLY sam_data0[15:8]; 
    end
    FCS_STATE: begin
      if(fcs_byte_cnt==3'd0)
      txd<= #U_DLY tx_crc_data_cal[31:24];
      else 
      txd<= #U_DLY tx_crc_data_act[23:16];
    end
    IFG_STATE:begin
      txd<= #U_DLY 8'd0;
    end
    default :
      txd<= #U_DLY 8'd0;
    endcase
end

always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    crc_en<= #U_DLY 1'b0;
    else if((preamble_sfd_byte_cnt==4'd8))
    crc_en<= #U_DLY 1'b1;
    else if(tx_en==1'b0)
    crc_en<= #U_DLY 1'b0;
    else ;
end

///crc32
crc32_d8 u0_crc32_d8(
    .clk                               (clk_rxc                   ),

    .rst                               (rst_rxc                   ),
    .data                              (txd                       ),
    .crc_en                            (crc_en                    ),
    .crc_data                          (crc_data                  ),
    .crc_next                          (crc_next                  ) 
);

assign tx_crc_data_cal= ~{crc_next[24],crc_next[25],crc_next[26],crc_next[27],crc_next[28],crc_next[29],crc_next[30],crc_next[31],
                    crc_next[16],crc_next[17],crc_next[18],crc_next[19],crc_next[20],crc_next[21],crc_next[22],crc_next[23],
                    crc_next[8],crc_next[9],crc_next[10],crc_next[11],crc_next[12],crc_next[13],crc_next[14],crc_next[15],
                    crc_next[0],crc_next[1],crc_next[2],crc_next[3],crc_next[4],crc_next[5],crc_next[6],crc_next[7]};


always @(posedge clk_rxc or posedge rst_rxc) begin
    if(rst_rxc==1'b1) 
    tx_crc_data_act<= #U_DLY 24'd0;
    else if(cur_state==FCS_STATE&&(fcs_byte_cnt==3'd0))
    tx_crc_data_act<= #U_DLY tx_crc_data_cal[23:0];
    else if((fcs_byte_cnt<=3'd3))
    tx_crc_data_act<= #U_DLY {tx_crc_data_act[15:0],8'h0};
    else ;
end


endmodule