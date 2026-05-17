`timescale 1ns/1ps

module fpga_top(
    input                               pin_clk_xi                 ,
    input                               pin_rst_n_xi               ,
    input                               pin_rgmii_rxc_xi           ,//rgmii rx
    input                               pin_rgmii_rx_dv_xi         ,//rgmii rx
    input              [   3:0]         pin_rgmii_rxd_xi           ,//rgmii rx
    input                               pin_a_i                    ,
    input                               pin_b_i                    ,
    input                               pin_z_i                    ,
    input                               pin_u_i                    ,
    input                               pin_v_i                    ,
    input                               pin_w_i                    ,
   
    output reg                          test1                      ,//doing test 为了防止时钟被优化
    output reg                          test2                      ,//doing test 为了防止时钟被优化
    output                              pin_eth_rst_n_xo           ,

    output                              pin_rgmii_txc_xo           ,//rgmii tx
    output             [   3:0]         pin_rgmii_txd_xo           ,//rgmii tx
    output                              pin_rgmii_tx_en_xo         ,//rgmii tx
    output                              pin_drv_ha_xo              ,
    output                              pin_drv_la_xo              ,
    output                              pin_drv_hb_xo              ,
    output                              pin_drv_lb_xo              ,
    output                              pin_drv_hc_xo              ,
    output                              pin_drv_lc_xo              ,

    output                              pin_adc_spi_csn_xo         ,
    input                               pin_adc_spi_sdoa_xi        ,
    input                               pin_adc_spi_sdob_xi        ,
    output                              pin_adc_spi_mosi_xo        ,
    output                              pin_adc_spi_sclk_xo        ,

    output                              pin_drv_en_xo              ,
    input                               pin_drv_fault_xi           ,
    output                              pin_drv_spi_csn_xo         ,
    output                              pin_drv_spi_sclk_xo        ,
    output                              pin_drv_spi_mosi_xo        ,
    input                               pin_drv_spi_miso_xi         ,
    output              pin_test_t11_x0

             
);

wire                                    clk0                       ;
wire                                    clk1                       ;
wire                                    clk2                       ;
wire                                    clk_rxc                    ;
wire                                    rst0                       ;
wire                                    rst1                       ;
wire                                    rst2                       ;
wire                                    rst_rxc                    ;
wire                                    rxc_bufio                  ;

wire                                    wr_en_scp0                 ;
wire                                    rd_en_scp0                 ;
wire                   [  11:0]         addr                       ;
wire                   [  15:0]         wr_data                    ;
wire                   [  15:0]         mux_data_out0              ;
wire                                    rd_start0                  ;

wire                                    rst_cfg                    ;

wire                                    rgmii_rx_dfx_clr           ;
wire                                    rx_err_flag_dfx            ;
wire                   [  15:0]         rx_err_cnt_dfx             ;
wire                                    pll_unlock_dfx_clr         ;
wire                   [  15:0]         pll_unlock_cnt_dfx         ;
wire                                    pll_unlock_flag_dfx        ;

wire                                    pc_arp_req                 ;
wire                                    pc_icmp_req                ;
wire                   [  47:0]         pc_mac_addr                ;
wire                   [  31:0]         pc_ip_addr                 ;
wire                   [  15:0]         pc_port_addr               ;
wire                   [  15:0]         ip_header_identification   ;
wire                   [  15:0]         ip_header_flag_fragoffset  ;
wire                   [  15:0]         ip_header_total_length     ;
wire                   [  15:0]         icmp_header_identifier     ;
wire                   [  15:0]         icmp_header_sequence       ;
wire                   [   7:0]         icmp_data                  ;
wire                                    icmp_data_vld              ;


wire                                    sam_start0                 ;
wire                                    data_vld                   ;
wire                   [  15:0]         data                       ;
wire                                    data0_rdout_en             ;
wire                                    sam0_udp_trg_125m          ;
wire                   [  15:0]         sam_data0                  ;


    parameter                           YEAR    = 16'h2025         ;
    parameter                           MONTH   = 16'h0008         ;
    parameter                           DATE    = 16'h0003         ;
    parameter                           VERSION = 16'h0003         ;
    parameter                           BATCH   = 16'h0001         ;
    parameter                           INTERNAL= 16'h0000         ;

    parameter                           FPGA_MAC_ADDR = 48'h00_0A_35_00_01_02;
    parameter                           FPGA_IP_ADDR  = {8'd192,8'd168,8'd1,8'd10};
    parameter                           FPGA_PORT = 16'd21105      ;


//phy rst_n
assign pin_eth_rst_n_xo=1'b1;

// assign pin_drv_ha_xo=1'b1;
// assign pin_drv_la_xo=1'b0;
// assign pin_drv_hb_xo=1'b1;
// assign pin_drv_lb_xo=1'b0;
// assign pin_drv_hc_xo=1'b0;
// assign pin_drv_lc_xo=1'b1;

assign pin_adc_spi_csn_xo=1'b0;
assign pin_adc_spi_mosi_xo=1'b0;
assign pin_adc_spi_sclk_xo=1'b0;

assign pin_drv_en_xo=1'b1;
assign pin_drv_spi_csn_xo=1'b1;
assign pin_drv_spi_sclk_xo=1'b0;
assign pin_drv_spi_mosi_xo=1'b0;
assign pin_test_t11_x0=1'b0;

sixstep_vf_lut u0_sixstep_vf_lut(
    .clk_50m(clk0),
    .rst_50m(rst0),
    .drv_ha (pin_drv_ha_xo ),
    .drv_la (pin_drv_la_xo ),
    .drv_hb (pin_drv_hb_xo ),
    .drv_lb (pin_drv_lb_xo ),
    .drv_hc (pin_drv_hc_xo ),
    .drv_lc (pin_drv_lc_xo )
);

clk_rst_top u0_clk_rst_top(
    .pin_clk_xi                        (pin_clk_xi                ),
    .pin_rst_n_xi                      (pin_rst_n_xi              ),
    .pin_rgmii_rxc_xi                  (pin_rgmii_rxc_xi          ),
    .rst_cfg                           (rst_cfg                   ),//i
    .clk0                              (clk0                      ),//o bufg
    .clk1                              (clk1                      ),//o
    .clk2                              (clk2                      ),//o
    .clk_rxc                           (clk_rxc                   ),//o bufg
    .rxc_bufio                         (rxc_bufio                 ),
    .rst0                              (rst0                      ),//o
    .rst1                              (rst1                      ),//o
    .rst2                              (rst2                      ),//o
    .rst_rxc                           (rst_rxc                   ),//o
    .pll_unlock_dfx_clr                (pll_unlock_dfx_clr        ),//i
    .pll_unlock_cnt_dfx                (pll_unlock_cnt_dfx        ),//o
    .pll_unlock_flag_dfx               (pll_unlock_flag_dfx       ) //o
);


rgmii_rx_top
#(
    .FPGA_MAC_ADDR                     (FPGA_MAC_ADDR             ),
    .FPGA_IP_ADDR                      (FPGA_IP_ADDR              ),
    .FPGA_PORT                         (FPGA_PORT                 )
)
u_rgmii_rx_top(
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .rxc_bufio                         (rxc_bufio                 ),//i
    .pin_rgmii_rx_dv_xi                (pin_rgmii_rx_dv_xi        ),//i
    .pin_rgmii_rxd_xi                  (pin_rgmii_rxd_xi          ),//i
    //rgmii rx dfx
    .rgmii_rx_dfx_clr                  (rgmii_rx_dfx_clr          ),//i
    .rx_err_flag_dfx                   (rx_err_flag_dfx           ),//o
    .rx_err_cnt_dfx                    (rx_err_cnt_dfx            ),//o
    //arp req
    .pc_arp_req                        (pc_arp_req                ),//o
    //pc info
    .pc_mac_addr                       (pc_mac_addr               ),//o
    .pc_ip_addr                        (pc_ip_addr                ),//o
    .pc_port_addr                      (pc_port_addr              ),//o
    //reg
    .addr                              (addr                      ),
    .wr_data                           (wr_data                   ),
    .wr_en_scp0                        (wr_en_scp0                ),
    .rd_en_scp0                        (rd_en_scp0                ),
    //icmp use
    .ip_header_identification          (ip_header_identification  ),
    .ip_header_flag_fragoffset         (ip_header_flag_fragoffset ),
    .ip_header_total_length            (ip_header_total_length    ),
    .pc_icmp_req                       (pc_icmp_req               ),
    .icmp_header_identifier            (icmp_header_identifier    ),
    .icmp_header_sequence              (icmp_header_sequence      ),
    .icmp_data                         (icmp_data                 ),
    .icmp_data_vld                     (icmp_data_vld             ) 
);


rgmii_tx_top
#(
    .FPGA_MAC_ADDR                     (FPGA_MAC_ADDR             ),
    .FPGA_IP_ADDR                      (FPGA_IP_ADDR              ),
    .FPGA_PORT                         (FPGA_PORT                 )
)
u0_rgmii_tx_top(
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    //arp req
    .pc_arp_req                        (pc_arp_req                ),//i
    //pc info
    .pc_mac_addr                       (pc_mac_addr               ),//i
    .pc_ip_addr                        (pc_ip_addr                ),//i
    .pc_port_addr                      (pc_port_addr              ),//i
    //pin rgmii tx
    .pin_rgmii_txc_xo                  (pin_rgmii_txc_xo          ),//o
    .pin_rgmii_tx_en_xo                (pin_rgmii_tx_en_xo        ),//o
    .pin_rgmii_txd_xo                  (pin_rgmii_txd_xo          ),//o
    //reg
    .mux_data_out0                     (mux_data_out0             ),//i
    .rd_start0                         (rd_start0                 ),//i
    //icmp use
    .ip_header_identification          (ip_header_identification  ),
    .ip_header_flag_fragoffset         (ip_header_flag_fragoffset ),
    .ip_header_total_length            (ip_header_total_length    ),
    .pc_icmp_req                       (pc_icmp_req               ),//i
    .icmp_header_identifier            (icmp_header_identifier    ),//i
    .icmp_header_sequence              (icmp_header_sequence      ),//i
    .icmp_data                         (icmp_data                 ),//i
    .icmp_data_vld                     (icmp_data_vld             ),//i
    //sam data0
    .sam0_udp_trg_125m                 (sam0_udp_trg_125m         ),//i
    .sam_data0                         (sam_data0                 ),//i
    .data0_rdout_en                    (data0_rdout_en            )
);

scp0_comm
#(
    .YEAR                              (YEAR                      ),
    .MONTH                             (MONTH                     ),
    .DATE                              (DATE                      ),
    .VERSION                           (VERSION                   ),
    .BATCH                             (BATCH                     ),
    .INTERNAL                          (INTERNAL                  ) 
)
u0_scp0_comm (
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .wr_en_scp0                        (wr_en_scp0                ),//i
    .rd_en_scp0                        (rd_en_scp0                ),//i
    .addr                              (addr                      ),//i
    .wr_data                           (wr_data                   ),//i
    .mux_data_out0                     (mux_data_out0             ),//o
    .rd_start0                         (rd_start0                 ),//o
    .rst_cfg                           (rst_cfg                   ),//o
    .rgmii_rx_dfx_clr                  (rgmii_rx_dfx_clr          ),//o
    .rx_err_flag_dfx                   (rx_err_flag_dfx           ),//i
    .rx_err_cnt_dfx                    (rx_err_cnt_dfx            ),//i
    .pll_unlock_dfx_clr                (pll_unlock_dfx_clr        ),//o
    .pll_unlock_cnt_dfx                (pll_unlock_cnt_dfx        ),//i
    .pll_unlock_flag_dfx               (pll_unlock_flag_dfx       ),//i
    .sam_start0                        (sam_start0                )
);


abz_decoder u0_abz_decoder(
    .clk0                              (clk0                     ),
    .rst0                              (rst0                      ),
    .a_i                               (pin_a_i                   ),
    .b_i                               (pin_b_i                   ),
    .z_i                               (pin_z_i                   ),
    .u_i                               (pin_u_i                   ),
    .v_i                               (pin_v_i                   ),
    .w_i                               (pin_w_i                   ),
    .iupoleoffset                      (12'd0                     ),
    .z_mark_e_neg                      (12'd3                     ),
    .z_mark_e_pos                      (12'd2498                  ),
    .z_mark_m_neg                      (16'd3                     ),
    .z_mark_m_pos                      (16'd9998                  ),
    .init_e_ang0                       (12'd1042                  ),
    .init_e_ang1                       (12'd1459                  ),
    .init_e_ang2                       (12'd1816                  ),
    .init_e_ang3                       (12'd2242                  ),
    .init_e_ang4                       (12'd208                   ),
    .init_e_ang5                       (12'd626                   ),
    .speed_en                          (1'b1                      ),
    .current_e_ang                     (                          ),
    .current_m_ang                     (                          ),
    .speed                             (data                          ),
    .speed_valid                       (data_vld                          ) 
);

sam_data0_buf u0_sam_data0_buf(
    .clk0                              (clk0                      ),
    .rst0                              (rst0                      ),
    .clk_rxc                           (clk_rxc                   ),
    .rst_rxc                           (rst_rxc                   ),
    .sam_start0                        (sam_start0                ),//i
    .data0_vld                         (data_vld                  ),//i
    .data0_in                          (data                      ),//i
    .sam0_udp_trg_125m                 (sam0_udp_trg_125m         ),//o
    .data0_rdout_en                    (data0_rdout_en            ),//i
    .sam_data0                         (sam_data0                 ) //o

);

/*
防止时钟被优化
*/
always@(posedge clk1 or posedge rst1)
if(rst1==1'b1)
test1<=1'b0;
else
test1<=~test1;

always@(posedge clk2 or posedge rst2)
if(rst2==1'b1)
test2<=1'b0;
else
test2<=~test2;

endmodule