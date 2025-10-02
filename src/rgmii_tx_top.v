`timescale 1ns/1ps

module rgmii_tx_top(
    input                               clk0                       ,
    input                               rst0                       ,
    input                               clk_rxc                    ,
    input                               rst_rxc                    ,
    input              [  47:0]         pc_mac_addr                ,
    input              [  31:0]         pc_ip_addr                 ,
    input              [  15:0]         pc_port_addr               ,
    input                               pc_arp_req                 ,
    output                              pin_rgmii_txc_xo           ,
    output             [   3:0]         pin_rgmii_txd_xo           ,
    output                              pin_rgmii_tx_en_xo         ,
    input              [  15:0]         mux_data_out0              ,
    input                               rd_start0                  ,
    input              [  15:0]         ip_header_identification   ,
    input              [  15:0]         ip_header_flag_fragoffset  ,
    input              [  15:0]         ip_header_total_length     ,
    input                               pc_icmp_req                ,
    input  wire        [  15:0]         icmp_header_identifier     ,
    input  wire        [  15:0]         icmp_header_sequence       ,
    input              [   7:0]         icmp_data                  ,
    input  wire                         icmp_data_vld              ,
    input                               sam0_udp_trg_125m          ,
    input              [  15:0]         sam_data0                  ,
    output                              data0_rdout_en               

);

wire                                    tx_en                      ;
wire                                    txc                        ;
wire                   [   7:0]         txd                        ;


parameter FPGA_MAC_ADDR = 48'h00_0A_35_00_01_02;
parameter FPGA_IP_ADDR={8'd192,8'd168,8'd1,8'd10};
parameter FPGA_PORT = 16'd21105;


tx_frame 
#(
    .FPGA_MAC_ADDR                     (FPGA_MAC_ADDR             ),
    .FPGA_IP_ADDR                      (FPGA_IP_ADDR              ),
    .FPGA_PORT                         (FPGA_PORT                 ) 
)
u0_tx_frame(
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .pc_arp_req                        (pc_arp_req                ),
    .pc_mac_addr                       (pc_mac_addr               ),
    .pc_ip_addr                        (pc_ip_addr                ),
    .pc_port_addr                      (pc_port_addr              ),
    .ip_header_identification          (ip_header_identification  ),
    .ip_header_flag_fragoffset         (ip_header_flag_fragoffset ),
    .ip_header_total_length            (ip_header_total_length    ),
    .pc_icmp_req                       (pc_icmp_req               ),
    .icmp_header_identifier            (icmp_header_identifier    ),
    .icmp_header_sequence              (icmp_header_sequence      ),
    .icmp_data                         (icmp_data                 ),
    .icmp_data_vld                     (icmp_data_vld             ),
    .tx_en                             (tx_en                     ),
    .txd                               (txd                       ),
    .txc                               (txc                       ),
    .mux_data_out0                     (mux_data_out0             ),
    .rd_start0                         (rd_start0                 ),
    .sam0_udp_trg_125m                 (sam0_udp_trg_125m         ),
    .sam_data0                         (sam_data0                 ),
    .data0_rdout_en                    (data0_rdout_en            ) 
);

rgmii_tx u0_rgmii_tx(
    .txc                               (txc                       ),
    .tx_en                             (tx_en                     ),
    .txd                               (txd                       ),
    .pin_rgmii_txc_xo                  (pin_rgmii_txc_xo          ),
    .pin_rgmii_tx_en_xo                (pin_rgmii_tx_en_xo        ),
    .pin_rgmii_txd_xo                  (pin_rgmii_txd_xo          ) 

);

endmodule