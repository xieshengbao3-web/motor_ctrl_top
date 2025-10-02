`timescale 1ns/1ps

module rgmii_rx_top(
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input                               rxc_bufio                  ,
    input                               pin_rgmii_rx_dv_xi         ,
    input              [   3:0]         pin_rgmii_rxd_xi           ,
    input                               rgmii_rx_dfx_clr           ,
    output                              rx_err_flag_dfx            ,
    output             [  15:0]         rx_err_cnt_dfx             ,
    output                              pc_arp_req                 ,
    output reg         [  47:0]         pc_mac_addr                ,
    output reg         [  31:0]         pc_ip_addr                 ,
    output             [  15:0]         pc_port_addr               ,
    output             [  11:0]         addr                       ,
    output             [  15:0]         wr_data                    ,
    output                              wr_en_scp0                 ,
    output                              rd_en_scp0                 ,
    output             [  15:0]         ip_header_identification   ,
    output             [  15:0]         ip_header_flag_fragoffset  ,
    output             [  15:0]         ip_header_total_length     ,
    output wire                         pc_icmp_req                ,
    output wire        [  15:0]         icmp_header_identifier     ,
    output wire        [  15:0]         icmp_header_sequence       ,
    output             [   7:0]         icmp_data                  ,
    output wire                         icmp_data_vld


);

parameter                           FPGA_MAC_ADDR = 48'h00_0A_35_00_01_02;
parameter                           FPGA_IP_ADDR  = {8'd192,8'd168,8'd1,8'd10};
parameter                           FPGA_PORT = 16'd21105      ;
localparam                              U_DLY=1                    ;

wire                                    preamble_sfd_check_ok      ;
wire                                    eth_header_0806_check_ok   ;
wire                                    eth_header_0800_check_ok   ;
wire                   [  47:0]         arp_src_mac_addr            ;
wire                   [  31:0]         arp_src_ip_addr             ;



wire                                    ip_header_udp_check_ok     ;
wire                                    ip_header_icmp_check_ok    ;

wire                   [  15:0]         udp_data_length            ;
wire                                    udp_header_check_ok        ;

wire                                    icmp_header_req_check_ok   ;


wire                   [   7:0]         rxd                        ;
wire                                    rx_dv                      ;
wire                   [  31:0]         ip_header_src_ip_addr      ;
wire                   [  47:0]         eth_header_src_mac_addr    ;

rgmii_rx u_rgmii_rx(
    .rxc_bufio                         (rxc_bufio                 ),
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .pin_rgmii_rxd_xi                  (pin_rgmii_rxd_xi          ),
    .pin_rgmii_rx_dv_xi                (pin_rgmii_rx_dv_xi        ),
    .rxd                               (rxd                       ),//o
    .rx_dv                             (rx_dv                     ),//o
    .rgmii_rx_dfx_clr                  (rgmii_rx_dfx_clr          ),//i
    .rx_err_cnt_dfx                    (rx_err_cnt_dfx            ),//o
    .rx_err_flag_dfx                   (rx_err_flag_dfx           ) //o
);

rx_preamble_sfd_parse u0_rx_preamble_sfd_parse(
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .rxd                               (rxd                       ),
    .rx_dv                             (rx_dv                     ),
    .preamble_sfd_check_ok             (preamble_sfd_check_ok     ) //o
);

rx_eth_header_parse #(
    .FPGA_MAC_ADDR                     (FPGA_MAC_ADDR             ) 
)
u0_rx_eth_header_parse (
    .clk_rxc                           (clk_rxc                   ),//i
    .rst_rxc                           (rst_rxc                   ),//i
    .rxd                               (rxd                       ),//i
    .rx_dv                             (rx_dv                     ),//i
    .preamble_sfd_check_ok             (preamble_sfd_check_ok     ),//i
    .pc_mac_addr                       (pc_mac_addr               ),//i
    .eth_header_src_mac_addr           (eth_header_src_mac_addr   ),//o
    .eth_header_0806_check_ok          (eth_header_0806_check_ok  ),//o arp֡
    .eth_header_0800_check_ok          (eth_header_0800_check_ok  ) //o
);

rx_arp_parse
#(
    .FPGA_IP_ADDR                      (FPGA_IP_ADDR              ) 
)
u0_rx_arp_parse (
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .rxd                               (rxd                       ),//i
    .rx_dv                             (rx_dv                     ),//i
    .eth_header_0806_check_ok          (eth_header_0806_check_ok  ),//i
    .pc_arp_req                        (pc_arp_req                ),//o
    .arp_src_mac_addr                  (arp_src_mac_addr          ),//o
    .arp_src_ip_addr                   (arp_src_ip_addr           ) //o
);

rx_ip_header_parse
#(
    .FPGA_IP_ADDR(FPGA_IP_ADDR)
)
u0_rx_ip_header_parse (
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .rxd                               (rxd                       ),//i
    .rx_dv                             (rx_dv                     ),//i
    .eth_header_0800_check_ok          (eth_header_0800_check_ok  ),//i
    .pc_ip_addr                        (pc_ip_addr                ),//i
    .ip_header_version_length          (ip_header_version_length  ),//o
    .ip_header_service                 (ip_header_service         ),//o
    .ip_header_total_length            (ip_header_total_length    ),//o
    .ip_header_identification          (ip_header_identification  ),//o
    .ip_header_flag_fragoffset         (ip_header_flag_fragoffset ),//o
    .ip_header_udp_check_ok            (ip_header_udp_check_ok    ),//o
    .ip_header_icmp_check_ok           (ip_header_icmp_check_ok   ), //o
    .ip_header_src_ip_addr             (ip_header_src_ip_addr     ) //o
);

always @(posedge clk_rxc) begin
    if(pc_arp_req==1'b1) begin
    pc_mac_addr<= #U_DLY arp_src_mac_addr;
    pc_ip_addr<= #U_DLY arp_src_ip_addr;
    end
    else if(pc_icmp_req==1'b1) begin
    pc_mac_addr<= #U_DLY eth_header_src_mac_addr;
    pc_ip_addr<= #U_DLY ip_header_src_ip_addr;
    end
end


rx_udp_header_parse
#(.FPGA_PORT(FPGA_PORT)
)
u0_rx_udp_header_parse(
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .rxd                               (rxd                       ),
    .rx_dv                             (rx_dv                     ),
    .ip_header_udp_check_ok            (ip_header_udp_check_ok    ),
    .pc_port_addr                      (pc_port_addr              ),
    .udp_data_length                   (udp_data_length           ),
    .udp_header_check_ok               (udp_header_check_ok       ) 
);

rx_udp_data_parse u0_rx_udp_data_parse(
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .rxd                               (rxd                       ),
    .rx_dv                             (rx_dv                     ),
    .udp_header_check_ok               (udp_header_check_ok       ),//i
    .udp_data_length                   (udp_data_length           ),//i
    .addr                              (addr                      ),//o
    .wr_data                           (wr_data                   ),//o
    .wr_en_scp0                        (wr_en_scp0                ),//o
    .rd_en_scp0                        (rd_en_scp0                ) //o
);


rx_icmp_header_parse u0_rx_icmp_header_parse(
    .clk_rxc                    (clk_rxc                 ),
    .rst_rxc                    (rst_rxc                 ),
    .rxd                        (rxd                     ),
    .rx_dv                      (rx_dv                   ),
    .ip_header_icmp_check_ok    (ip_header_icmp_check_ok ),//i
    .icmp_header_req_check_ok   (icmp_header_req_check_ok),//o
    .pc_icmp_req                (pc_icmp_req             ),//o
    .icmp_header_identifier     (icmp_header_identifier  ),//o
    .icmp_header_sequence       (icmp_header_sequence    ) //o
);

rx_icmp_data_parse u0_rx_icmp_data_parse(
    .clk_rxc                   (clk_rxc                 ),
    .rst_rxc                   (rst_rxc                 ),
    .rxd                       (rxd                     ),
    .rx_dv                     (rx_dv                   ),
    .icmp_header_req_check_ok  (icmp_header_req_check_ok),//i
    .ip_header_total_length    (ip_header_total_length  ),//i
    .icmp_data                 (icmp_data               ),//o
    .icmp_data_vld             (icmp_data_vld           ) //o
);

endmodule