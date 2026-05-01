module Top_Level(
input  wire        clk_200mhz,    
input  wire        clk_125mhz,   
input  wire        sys_resetn,    

input  wire [31:0] s_axis_net_tdata,
input  wire [3:0]  s_axis_net_tkeep,
input  wire        s_axis_net_tlast,
input  wire        s_axis_net_tvalid,
output wire        s_axis_net_tready,

output wire [31:0] m_axis_net_tdata,
output wire [3:0]  m_axis_net_tkeep,
output wire        m_axis_net_tlast,
output wire        m_axis_net_tvalid,
input  wire        m_axis_net_tready,
output wire        m_axis_net_tuser,

input  wire [12:0] s_axi_awaddr,
input  wire        s_axi_awvalid,
output wire        s_axi_awready,
input  wire [63:0] s_axi_wdata,
input  wire [7:0]  s_axi_wstrb,
input  wire        s_axi_wvalid,
output wire        s_axi_wready,
output wire [1:0]  s_axi_bresp,
output wire        s_axi_bvalid,
input  wire        s_axi_bready,
input  wire [12:0] s_axi_araddr,
input  wire        s_axi_arvalid,
output wire        s_axi_arready,
output wire [63:0] s_axi_rdata,
output wire [1:0]  s_axi_rresp,
output wire        s_axi_rvalid,
input  wire        s_axi_rready
);

wire        bram_rst_a;
wire        bram_clk_a;
wire        bram_en_a;
wire [7:0]  bram_we_a;     
wire [12:0] bram_addr_a;    
wire [63:0] bram_wrdata_a;
wire [63:0] bram_rddata_a;

wire [9:0]  bram_addr_b;
wire        bram_en_b;
wire [63:0] bram_rddata_b;

wire [31:0] fifo_to_parser_tdata;
wire [3:0]  fifo_to_parser_tkeep;
wire        fifo_to_parser_tvalid;
wire        fifo_to_parser_tlast;
wire        fifo_to_parser_tready;

wire [31:0] parser_to_fw_tdata;
wire [3:0]  parser_to_fw_tkeep;
wire        parser_to_fw_tvalid;
wire        parser_to_fw_tlast;
wire        parser_to_fw_tready;
wire [31:0] parsed_src_ip;
wire        parsed_ip_valid;
wire        parsed_is_ipv4;

wire        crc_done_wire;
wire        crc_pass_wire;

axi_bram_ctrl_0 axi_controller (
        .s_axi_aclk(clk_200mhz),
        .s_axi_aresetn(sys_resetn),
        
        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awlen(8'b0),        
        .s_axi_awsize(3'b011),      
        .s_axi_awburst(2'b01),     
        .s_axi_awlock(1'b0),
        .s_axi_awcache(4'b0),
        .s_axi_awprot(3'b0),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),
        
        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wlast(1'b1),        
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),
        
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bready(s_axi_bready),
        
        .s_axi_araddr(s_axi_araddr),
        .s_axi_arlen(8'b0),
        .s_axi_arsize(3'b011),
        .s_axi_arburst(2'b01),
        .s_axi_arlock(1'b0),
        .s_axi_arcache(4'b0),
        .s_axi_arprot(3'b0),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),
        
        .s_axi_rdata(s_axi_rdata),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rlast(),             
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rready(s_axi_rready),

        .bram_rst_a(bram_rst_a),
        .bram_clk_a(bram_clk_a),
        .bram_en_a(bram_en_a),
        .bram_we_a(bram_we_a),
        .bram_addr_a(bram_addr_a),
        .bram_wrdata_a(bram_wrdata_a),
        .bram_rddata_a(bram_rddata_a)
    );
    
    blk_mem_gen_0 shared_memory (
        .clka(bram_clk_a),
        .ena(bram_en_a),
        .wea(bram_we_a[0]),         
        .addra(bram_addr_a[12:3]),  
        .dina(bram_wrdata_a),
        .douta(bram_rddata_a),

        .clkb(clk_200mhz),
        .enb(bram_en_b),
        .web(1'b0),               
        .addrb(bram_addr_b),
        .dinb(64'b0),            
        .doutb(bram_rddata_b)
    );
    
    asyn_fifo packet_asyn_fifo (
        .s_aclk(clk_125mhz),        
        .s_aresetn(sys_resetn),
        .m_aclk(clk_200mhz),        
        .m_aresetn(sys_resetn),

        .s_axis_tdata(s_axis_net_tdata),
        .s_axis_tkeep(s_axis_net_tkeep),
        .s_axis_tvalid(s_axis_net_tvalid),
        .s_axis_tlast(s_axis_net_tlast),
        .s_axis_tready(s_axis_net_tready),

        .m_axis_tdata(fifo_to_parser_tdata),
        .m_axis_tkeep(fifo_to_parser_tkeep),
        .m_axis_tvalid(fifo_to_parser_tvalid),
        .m_axis_tlast(fifo_to_parser_tlast),
        .m_axis_tready(fifo_to_parser_tready)
    );
    
    parser packet_parser (
        .clk(clk_200mhz),
        .resetn(sys_resetn),

        .s_axis_tdata(fifo_to_parser_tdata),
        .s_axis_tkeep(fifo_to_parser_tkeep),
        .s_axis_tvalid(fifo_to_parser_tvalid),
        .s_axis_tlast(fifo_to_parser_tlast),
        .s_axis_tready(fifo_to_parser_tready),

        .m_axis_tdata(parser_to_fw_tdata),
        .m_axis_tkeep(parser_to_fw_tkeep),
        .m_axis_tvalid(parser_to_fw_tvalid),
        .m_axis_tlast(parser_to_fw_tlast),
        .m_axis_tready(parser_to_fw_tready),

        .src_ip(parsed_src_ip),
        .ip_valid(parsed_ip_valid),
        .is_ipv4(parsed_is_ipv4)
    );
    
    CRC packet_crc (
        .clk(clk_200mhz),
        .resetn(sys_resetn),

        .s_axis_tdata(fifo_to_parser_tdata),
        .s_axis_tkeep(fifo_to_parser_tkeep),
        .s_axis_tvalid(fifo_to_parser_tvalid),
        .s_axis_tlast(fifo_to_parser_tlast),
        .s_axis_tready(fifo_to_parser_tready),

        .crc_done(crc_done_wire),
        .crc_pass(crc_pass_wire)
    );
    
    Firewall main_firewall (
        .clk(clk_200mhz),
        .resetn(sys_resetn),

        .s_axis_tdata(parser_to_fw_tdata),
        .s_axis_tkeep(parser_to_fw_tkeep),
        .s_axis_tvalid(parser_to_fw_tvalid),
        .s_axis_tlast(parser_to_fw_tlast),
        .s_axis_tready(parser_to_fw_tready),

        .src_ip(parsed_src_ip),
        .ip_valid(parsed_ip_valid),
        .is_ipv4(parsed_is_ipv4),

        .crc_done(crc_done_wire),
        .crc_pass(crc_pass_wire),

        .bram_en(bram_en_b),
        .bram_addr(bram_addr_b),
        .bram_dout(bram_rddata_b),

        .m_axis_tdata(m_axis_net_tdata),
        .m_axis_tkeep(m_axis_net_tkeep),
        .m_axis_tvalid(m_axis_net_tvalid),
        .m_axis_tlast(m_axis_net_tlast),
        .m_axis_tready(m_axis_net_tready),
        .m_axis_tuser(m_axis_net_tuser)
    );
    
endmodule
