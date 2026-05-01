module asyn_fifo (
input  wire        s_aclk,
input  wire        s_aresetn,

input  wire        m_aclk,
input  wire        m_aresetn,

input  wire [31:0] s_axis_tdata,
input  wire [3:0]  s_axis_tkeep,
input  wire        s_axis_tvalid,
input  wire        s_axis_tlast,
output wire        s_axis_tready,

output wire [31:0] m_axis_tdata,
output wire [3:0]  m_axis_tkeep,
output wire        m_axis_tvalid,
output wire        m_axis_tlast,
input  wire        m_axis_tready
);

parameter FIFO_DEPTH = 32;
parameter ADDR_WIDTH = 5;
localparam AFULL_THRESHOLD = FIFO_DEPTH - 5;
(* ram_style = "distributed" *)
reg [36:0] fifo_mem [0:FIFO_DEPTH - 1]; 

wire almost_full;
wire full;
wire empty;

reg [ADDR_WIDTH:0] wr_ptr_bin;  
reg [ADDR_WIDTH:0] wr_ptr_gray;
reg [ADDR_WIDTH:0] rd_ptr_gray_sync1, rd_ptr_gray_sync2;
reg [ADDR_WIDTH:0] rd_ptr_bin_sync;

reg [ADDR_WIDTH:0] rd_ptr_bin;   
reg [ADDR_WIDTH:0] rd_ptr_gray;
reg [ADDR_WIDTH:0] wr_ptr_gray_sync1, wr_ptr_gray_sync2;

wire [ADDR_WIDTH:0] next_wr_ptr_bin  = wr_ptr_bin + 1;
wire [ADDR_WIDTH:0] next_wr_ptr_gray = (next_wr_ptr_bin >> 1) ^ next_wr_ptr_bin;

always @(posedge s_aclk or negedge s_aresetn) begin
    if (!s_aresetn) begin
        wr_ptr_bin  <= 0;
        wr_ptr_gray <= 0;
    end
    else if(s_axis_tready && s_axis_tvalid && !full) begin
        wr_ptr_bin  <= next_wr_ptr_bin;
        wr_ptr_gray <= next_wr_ptr_gray;
    end
end

always @(posedge s_aclk) begin
    if (s_axis_tready && s_axis_tvalid && !full) begin
        fifo_mem[wr_ptr_bin[ADDR_WIDTH-1:0]] <= {s_axis_tlast, s_axis_tkeep, s_axis_tdata};
    end
end

always @(posedge s_aclk or negedge s_aresetn) begin
    if (!s_aresetn) begin
        rd_ptr_gray_sync1 <= 0;
        rd_ptr_gray_sync2 <= 0;
    end else begin
        rd_ptr_gray_sync1 <= rd_ptr_gray;
        rd_ptr_gray_sync2 <= rd_ptr_gray_sync1;
    end
end

integer i;
always @(*) begin
    rd_ptr_bin_sync[ADDR_WIDTH] = rd_ptr_gray_sync2[ADDR_WIDTH];
    for (i = ADDR_WIDTH-1; i >= 0; i = i - 1) begin
        rd_ptr_bin_sync[i] = rd_ptr_bin_sync[i+1] ^ rd_ptr_gray_sync2[i];
    end
end

wire [ADDR_WIDTH:0] num_elements_in_fifo = wr_ptr_bin - rd_ptr_bin_sync;
assign almost_full = (num_elements_in_fifo >= AFULL_THRESHOLD);
assign full        = (num_elements_in_fifo == FIFO_DEPTH);
assign s_axis_tready = ~almost_full;

wire [ADDR_WIDTH:0] next_rd_ptr_bin  = rd_ptr_bin + 1;
wire [ADDR_WIDTH:0] next_rd_ptr_gray = (next_rd_ptr_bin >> 1) ^ next_rd_ptr_bin;

always @(posedge m_aclk or negedge m_aresetn) begin
    if (!m_aresetn) begin
        rd_ptr_bin  <= 0;
        rd_ptr_gray <= 0;
    end 
    else if (m_axis_tready && m_axis_tvalid) begin
        rd_ptr_bin  <= next_rd_ptr_bin;
        rd_ptr_gray <= next_rd_ptr_gray;
    end
end

always @(posedge m_aclk or negedge m_aresetn) begin
    if (!m_aresetn) begin
        wr_ptr_gray_sync1 <= 0;
        wr_ptr_gray_sync2 <= 0;
    end else begin
        wr_ptr_gray_sync1 <= wr_ptr_gray;
        wr_ptr_gray_sync2 <= wr_ptr_gray_sync1;
    end
end

assign empty = (rd_ptr_gray == wr_ptr_gray_sync2);
assign m_axis_tvalid = ~empty;

wire [36:0] data_out = fifo_mem[rd_ptr_bin[ADDR_WIDTH-1:0]];
assign m_axis_tdata = data_out[31:0];
assign m_axis_tkeep = data_out[35:32];
assign m_axis_tlast = data_out[36];

endmodule
