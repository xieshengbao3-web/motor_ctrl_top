set_property -dict {PACKAGE_PIN N16 IOSTANDARD LVCMOS33} [get_ports pin_rst_n_xi]
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports pin_clk_xi]

set_property -dict {PACKAGE_PIN K17 IOSTANDARD LVCMOS33} [get_ports pin_rgmii_rxc_xi]
set_property -dict {PACKAGE_PIN E17 IOSTANDARD LVCMOS33} [get_ports pin_rgmii_rx_dv_xi]
set_property -dict {PACKAGE_PIN B19 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_rxd_xi[0]}]
set_property -dict {PACKAGE_PIN A20 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_rxd_xi[1]}]
set_property -dict {PACKAGE_PIN H17 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_rxd_xi[2]}]
set_property -dict {PACKAGE_PIN H16 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_rxd_xi[3]}]
set_property -dict {PACKAGE_PIN B20 IOSTANDARD LVCMOS33} [get_ports pin_rgmii_txc_xo]
set_property -dict {PACKAGE_PIN K18 IOSTANDARD LVCMOS33} [get_ports pin_rgmii_tx_en_xo]
set_property -dict {PACKAGE_PIN D18 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_txd_xo[0]}]
set_property -dict {PACKAGE_PIN C20 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_txd_xo[1]}]
set_property -dict {PACKAGE_PIN D19 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_txd_xo[2]}]
set_property -dict {PACKAGE_PIN D20 IOSTANDARD LVCMOS33} [get_ports {pin_rgmii_txd_xo[3]}]

set_property -dict {PACKAGE_PIN G15 IOSTANDARD LVCMOS33} [get_ports pin_eth_rst_n_xo]

set_property -dict {PACKAGE_PIN U14 IOSTANDARD LVCMOS33} [get_ports pin_a_i]
set_property -dict {PACKAGE_PIN V12 IOSTANDARD LVCMOS33} [get_ports pin_b_i]
set_property -dict {PACKAGE_PIN W13 IOSTANDARD LVCMOS33} [get_ports pin_z_i]
set_property -dict {PACKAGE_PIN Y14 IOSTANDARD LVCMOS33} [get_ports pin_u_i]
set_property -dict {PACKAGE_PIN W14 IOSTANDARD LVCMOS33} [get_ports pin_w_i]
set_property -dict {PACKAGE_PIN V15 IOSTANDARD LVCMOS33} [get_ports pin_v_i]

set_property -dict {PACKAGE_PIN T5 IOSTANDARD LVCMOS33} [get_ports test1]
set_property -dict {PACKAGE_PIN U5 IOSTANDARD LVCMOS33} [get_ports test2]
#set_property -dict {PACKAGE_PIN H15 IOSTANDARD LVCMOS33} [get_ports test_led]



create_clock -period 8.000 -name pin_rgmii_rxc_xi [get_ports pin_rgmii_rxc_xi]
create_clock -period 20.000 -name pin_clk_xi [get_ports pin_clk_xi]
set_clock_groups -name pin_clk_clk_rx -asynchronous -group [get_clocks [get_clocks -of_objects [get_pins u0_clk_rst_top/u0_clk_mmcm/inst/mmcm_adv_inst/CLKOUT0]]] -group [get_clocks [get_clocks -of_objects [get_pins u0_clk_rst_top/u0_clk_mmcm/inst/mmcm_adv_inst/CLKOUT1]]] -group [get_clocks pin_rgmii_rxc_xi] -group [get_clocks pin_clk_xi]






